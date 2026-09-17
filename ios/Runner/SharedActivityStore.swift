import Foundation
import SQLite3

/// Flutter 쪽 lib/data/db/database.dart(drift)가 쓰는 것과 완전히 같은
/// 스키마(테이블 activities)에, drift 없이 SQLite C API로 최소한의 코드만
/// 써서 한 줄을 추가한다. 시리로 기록할 때 앱(Flutter 엔진)이 켜져 있을
/// 필요가 없게 하기 위함이다 — App Intent가 별도 프로세스에서 곧바로
/// App Group 공유 DB 파일에 쓴다.
///
/// 컬럼 이름·저장 방식은 lib/data/db/database.g.dart(생성 코드)를 기준으로
/// 맞췄다. dart 쪽 스키마를 바꾸면(마이그레이션) 이 파일도 같이 바꿔야 한다:
///   - type 컬럼: enum의 .name 문자열 그대로 저장 (예: "formula")
///   - 시각 컬럼(started_at 등): 초 단위 유닉스 타임스탬프(INTEGER)
///   - payload 컬럼: JSON 문자열
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SharedActivityStoreError: Error {
  case containerNotFound
  case openFailed
  case insertFailed
}

enum SharedActivityStore {
  /// ios/Runner/Runner.entitlements의 App Group ID와 반드시 같아야 한다.
  static let appGroupId = "group.com.happypi.parentingLog"
  static let dbFileName = "parenting_log.sqlite"

  static func insertFormula(amountMl: Int) throws {
    let db = try openSharedDatabase()
    defer { sqlite3_close(db) }

    let id = UUID().uuidString
    let now = Int64(Date().timeIntervalSince1970)
    let payload = "{\"ml\":\(amountMl)}"

    let sql = """
      INSERT INTO activities
        (id, type, started_at, ended_at, payload, created_by, created_at, updated_at, deleted_at)
      VALUES (?, 'formula', ?, NULL, ?, 'me', ?, ?, NULL)
      """

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      throw SharedActivityStoreError.insertFailed
    }
    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int64(statement, 2, now)
    sqlite3_bind_text(statement, 3, payload, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int64(statement, 4, now)
    sqlite3_bind_int64(statement, 5, now)

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw SharedActivityStoreError.insertFailed
    }
  }

  private static func openSharedDatabase() throws -> OpaquePointer {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId
      )
    else {
      // Xcode에서 App Groups capability를 아직 추가하지 않았을 때 여기로 온다.
      throw SharedActivityStoreError.containerNotFound
    }
    let dbURL = containerURL.appendingPathComponent(dbFileName)

    var db: OpaquePointer?
    guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else {
      throw SharedActivityStoreError.openFailed
    }
    return db
  }
}
