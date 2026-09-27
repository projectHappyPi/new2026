import Foundation
import SQLite3

// 위젯은 앱과 다른 프로세스라 App Group 공유 폴더의 DB 파일을 읽기 전용으로 연다.
// 계산 규칙은 lib/features/widgets/widget_status.dart 와 같다.
// 설정 키는 lib/features/widgets/widget_config.dart(toJson) + widget_bridge.dart.

let kAppGroupId = "group.com.happypi.parentingLog"
let kWidgetConfigKey = "widgetConfig"

struct WidgetConfig {
  var showName = true
  var showDday = true
  var showFeeding = true
  var genericFeedLabel = false
  var showNextFeed = true
  var autoNextFeed = true
  var fixedIntervalMin = 180
  var showSleep = true
  var calendarShowStatus = true
  var calendarShowToday = true
  var theme = "dark"
  var babyName = "튼튼이"
  var birthDate: Date?

  static func load() -> WidgetConfig {
    var c = WidgetConfig()
    guard
      let raw = UserDefaults(suiteName: kAppGroupId)?.string(forKey: kWidgetConfigKey),
      let data = raw.data(using: .utf8),
      let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return c }
    c.showName = j["showName"] as? Bool ?? true
    c.showDday = j["showDday"] as? Bool ?? true
    c.showFeeding = j["showFeeding"] as? Bool ?? true
    c.genericFeedLabel = (j["feedLabel"] as? String) == "generic"
    c.showNextFeed = j["showNextFeed"] as? Bool ?? true
    c.autoNextFeed = (j["nextFeedMode"] as? String) != "fixed"
    c.fixedIntervalMin = j["fixedIntervalMin"] as? Int ?? 180
    c.showSleep = j["showSleep"] as? Bool ?? true
    c.calendarShowStatus = j["calendarShowStatus"] as? Bool ?? true
    c.calendarShowToday = j["calendarShowToday"] as? Bool ?? true
    c.theme = j["theme"] as? String ?? "dark"
    if let n = j["babyName"] as? String, !n.isEmpty { c.babyName = n }
    if let b = j["birthDateSec"] as? NSNumber {
      c.birthDate = Date(timeIntervalSince1970: b.doubleValue)
    }
    return c
  }

  func dday(at now: Date) -> Int? {
    guard let birthDate else { return nil }
    let cal = Calendar.current
    return cal.dateComponents([.day], from: cal.startOfDay(for: birthDate), to: cal.startOfDay(for: now)).day
  }
}

struct BabyStatus {
  var feedLabel: String?
  var lastFeed: Date?
  var nextFeed: Date?
  var sleepLabel: String?
  var sleepAt: Date?
  var sleeping = false
}

struct WidgetEvent: Identifiable {
  let id: String
  let title: String
  let start: Date
  let end: Date
  let allDay: Bool
  let colorName: String

  func occurs(on day: Date) -> Bool {
    let cal = Calendar.current
    let d0 = cal.startOfDay(for: day)
    let d1 = cal.date(byAdding: .day, value: 1, to: d0)!
    return cal.startOfDay(for: start) < d1 && end >= d0
  }
}

enum WidgetStore {
  private static func withDB<T>(_ fallback: T, _ body: (OpaquePointer) -> T) -> T {
    guard
      let url = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kAppGroupId)?
        .appendingPathComponent("parenting_log.sqlite"),
      FileManager.default.fileExists(atPath: url.path)
    else { return fallback }
    var db: OpaquePointer?
    guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
      return fallback
    }
    defer { sqlite3_close(db) }
    sqlite3_busy_timeout(db, 2000)
    return body(db)
  }

  private static func query(_ db: OpaquePointer, _ sql: String, _ args: [Int64] = [], row: (OpaquePointer) -> Void) {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
    defer { sqlite3_finalize(stmt) }
    for (i, a) in args.enumerated() { sqlite3_bind_int64(stmt, Int32(i + 1), a) }
    while sqlite3_step(stmt) == SQLITE_ROW { row(stmt) }
  }

  private static func text(_ s: OpaquePointer, _ i: Int32) -> String {
    guard let p = sqlite3_column_text(s, i) else { return "" }
    return String(cString: p)
  }

  private static func date(_ s: OpaquePointer, _ i: Int32) -> Date {
    Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(s, i)))
  }

  static func status(_ cfg: WidgetConfig, now: Date = Date()) -> BabyStatus {
    withDB(BabyStatus()) { db in
      var st = BabyStatus()
      var feeds: [(type: String, ref: Date)] = []
      let since = Int64(now.timeIntervalSince1970) - 3 * 86_400
      query(db, """
        SELECT type, started_at, ended_at FROM activities
        WHERE deleted_at IS NULL AND type IN ('formula','breast') AND started_at >= ?
        """, [since]) { s in
        let type = text(s, 0)
        let ended = sqlite3_column_type(s, 2) != SQLITE_NULL
        feeds.append((type, type == "breast" && ended ? date(s, 2) : date(s, 1)))
      }
      feeds.sort { $0.ref < $1.ref }
      if let last = feeds.last {
        st.lastFeed = last.ref
        st.feedLabel = cfg.genericFeedLabel ? "수유" : (last.type == "breast" ? "모유" : "분유")
        var interval = TimeInterval(cfg.fixedIntervalMin * 60)
        if cfg.autoNextFeed && feeds.count >= 2 {
          let tail = Array(feeds.suffix(4)).map(\.ref)
          interval = tail.last!.timeIntervalSince(tail.first!) / Double(tail.count - 1)
        }
        st.nextFeed = last.ref.addingTimeInterval(interval)
      }
      query(db, """
        SELECT started_at, ended_at, payload FROM activities
        WHERE deleted_at IS NULL AND type = 'sleep' ORDER BY started_at DESC LIMIT 1
        """) { s in
        if sqlite3_column_type(s, 1) == SQLITE_NULL {
          st.sleeping = true
          st.sleepAt = date(s, 0)
          let payload = text(s, 2)
          if payload.contains("\"night\"") {
            st.sleepLabel = "밤잠"
          } else if payload.contains("\"nap\"") {
            st.sleepLabel = "낮잠"
          } else {
            st.sleepLabel = Calendar.current.component(.hour, from: st.sleepAt!) >= 20 ? "밤잠" : "낮잠"
          }
        } else {
          st.sleepLabel = "기상"
          st.sleepAt = date(s, 1)
        }
      }
      return st
    }
  }

  static func events(from: Date, to: Date) -> [WidgetEvent] {
    withDB([]) { db in
      var out: [WidgetEvent] = []
      query(db, """
        SELECT id, title, start_at, end_at, all_day, color FROM events
        WHERE deleted_at IS NULL AND start_at < ? AND COALESCE(end_at, start_at) >= ?
        ORDER BY all_day DESC, start_at
        """, [Int64(to.timeIntervalSince1970), Int64(from.timeIntervalSince1970)]) { s in
        let start = date(s, 2)
        out.append(WidgetEvent(
          id: text(s, 0),
          title: text(s, 1),
          start: start,
          end: sqlite3_column_type(s, 3) == SQLITE_NULL ? start : date(s, 3),
          allDay: sqlite3_column_int(s, 4) == 1,
          colorName: text(s, 5)
        ))
      }
      return out
    }
  }
}
