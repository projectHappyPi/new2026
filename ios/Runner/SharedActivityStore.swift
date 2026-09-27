import Foundation
import SQLite3
import WidgetKit

/// Flutter 쪽 lib/data/db/database.dart(drift)가 쓰는 것과 완전히 같은
/// 스키마(테이블 activities)에, drift 없이 SQLite C API로 최소한의 코드만
/// 써서 기록한다. 시리로 기록할 때 앱 화면(Flutter 엔진)이 필요 없게 하기
/// 위함이다 — App Intent가 App Group 공유 DB 파일에 곧바로 쓴다.
///
/// 컬럼 이름·저장 방식은 lib/data/db/database.g.dart(생성 코드)를 기준으로
/// 맞췄다. Dart 쪽 스키마를 바꾸면(마이그레이션) 이 파일도 같이 바꿔야 한다:
///   - type 컬럼: ActivityType enum의 .name 문자열 (예: "formula", "bath")
///   - 시각 컬럼(started_at 등): 초 단위 유닉스 타임스탬프(INTEGER)
///   - payload 컬럼: JSON 문자열
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SharedActivityStoreError: LocalizedError {
  case containerNotFound
  case openFailed
  case notInitialized
  case writeFailed(String)

  var errorDescription: String? {
    switch self {
    case .containerNotFound:
      return "App Group 설정이 없어 기록할 수 없어요."
    case .openFailed:
      return "기록 파일을 열 수 없어요."
    case .notInitialized:
      return "튼튼이 앱을 한 번 먼저 열어 주세요."
    case .writeFailed(let message):
      return "기록에 실패했어요. (\(message))"
    }
  }
}

struct RunningActivity {
  let id: String
  let startedAt: Date
}

enum SharedActivityStore {
  /// ios/Runner/Runner.entitlements의 App Group ID와 반드시 같아야 한다.
  static let appGroupId = "group.com.happypi.parentingLog"
  static let dbFileName = "parenting_log.sqlite"

  /// 한 건 추가. [payload]에는 via=voice가 자동으로 붙는다.
  static func insert(
    type: String,
    startedAt: Date = Date(),
    endedAt: Date? = nil,
    payload: [String: Any] = [:]
  ) throws {
    try withDatabase { db in
      var body = payload
      body["via"] = "voice"
      let json = try String(
        data: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]),
        encoding: .utf8
      ) ?? "{}"
      let now = Int64(Date().timeIntervalSince1970)

      let sql = """
        INSERT INTO activities
          (id, type, started_at, ended_at, payload, created_by, created_at, updated_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
        """
      try execute(db, sql) { stmt in
        sqlite3_bind_text(stmt, 1, UUID().uuidString.lowercased(), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, type, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 3, Int64(startedAt.timeIntervalSince1970))
        if let endedAt {
          sqlite3_bind_int64(stmt, 4, Int64(endedAt.timeIntervalSince1970))
        } else {
          sqlite3_bind_null(stmt, 4)
        }
        sqlite3_bind_text(stmt, 5, json, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, memberName(), -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 7, now)
        sqlite3_bind_int64(stmt, 8, now)
      }
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// 가족 공유에서 정한 내 이름(앱이 위젯 설정과 함께 넘겨준 값). 없으면 'me'.
  private static func memberName() -> String {
    guard
      let raw = UserDefaults(suiteName: appGroupId)?.string(forKey: "widgetConfig"),
      let data = raw.data(using: .utf8),
      let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let name = j["memberName"] as? String, !name.isEmpty
    else { return "me" }
    return name
  }

  /// 진행 중(ended_at IS NULL)인 가장 최근 [type] 기록.
  static func running(type: String) throws -> RunningActivity? {
    var found: RunningActivity?
    try withDatabase { db in
      let sql = """
        SELECT id, started_at FROM activities
        WHERE type = ? AND ended_at IS NULL AND deleted_at IS NULL
        ORDER BY started_at DESC LIMIT 1
        """
      var stmt: OpaquePointer?
      guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
        throw SharedActivityStoreError.writeFailed(lastError(db))
      }
      defer { sqlite3_finalize(stmt) }
      sqlite3_bind_text(stmt, 1, type, -1, SQLITE_TRANSIENT)
      if sqlite3_step(stmt) == SQLITE_ROW, let idPtr = sqlite3_column_text(stmt, 0) {
        found = RunningActivity(
          id: String(cString: idPtr),
          startedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 1)))
        )
      }
    }
    return found
  }

  /// 진행 중인 기록을 지금 시각으로 종료.
  static func end(id: String, at date: Date = Date()) throws {
    try withDatabase { db in
      let ts = Int64(date.timeIntervalSince1970)
      try execute(db, "UPDATE activities SET ended_at = ?, updated_at = ? WHERE id = ?") { stmt in
        sqlite3_bind_int64(stmt, 1, ts)
        sqlite3_bind_int64(stmt, 2, ts)
        sqlite3_bind_text(stmt, 3, id, -1, SQLITE_TRANSIENT)
      }
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  // MARK: - 내부

  private static func withDatabase(_ body: (OpaquePointer) throws -> Void) throws {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId
      )
    else {
      // Xcode/개발자 포털에서 App Groups capability를 아직 추가하지 않았을 때.
      throw SharedActivityStoreError.containerNotFound
    }
    let dbURL = containerURL.appendingPathComponent(dbFileName)
    // 앱을 한 번도 열지 않았으면 drift가 테이블을 만들기 전이다.
    guard FileManager.default.fileExists(atPath: dbURL.path) else {
      throw SharedActivityStoreError.notInitialized
    }

    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db else {
      throw SharedActivityStoreError.openFailed
    }
    defer { sqlite3_close(db) }
    // 앱(drift)이 같은 파일을 쓰는 중이면 잠깐 기다린다.
    sqlite3_busy_timeout(db, 3000)
    try body(db)
  }

  private static func execute(
    _ db: OpaquePointer,
    _ sql: String,
    bind: (OpaquePointer) -> Void
  ) throws {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
      throw SharedActivityStoreError.writeFailed(lastError(db))
    }
    defer { sqlite3_finalize(stmt) }
    bind(stmt)
    guard sqlite3_step(stmt) == SQLITE_DONE else {
      throw SharedActivityStoreError.writeFailed(lastError(db))
    }
  }

  private static func lastError(_ db: OpaquePointer) -> String {
    String(cString: sqlite3_errmsg(db))
  }
}
