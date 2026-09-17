// ⚠️ 이 파일은 아직 어떤 Xcode 타깃에도 연결돼 있지 않다.
// Xcode에서 File > New > Target > Widget Extension으로 새 타깃을 만들면
// 자동 생성되는 스켈레톤 파일이 하나 생기는데, 그 파일 내용을 전부 지우고
// 이 파일 내용으로 바꿔치기하면 된다. 자세한 순서는 대화의 안내를 참고.
//
// 위젯은 앱과 완전히 다른 프로세스라 SharedActivityStore.swift를 그대로
// import해서 쓸 수 없다(타깃이 다르면 파일도 "Target Membership"에 새로
// 체크해야 보인다). 헷갈리지 않도록 최소한의 읽기 코드를 이 파일 안에
// 그대로 다시 둔다 — SQLite에 값을 쓰는 SharedActivityStore.swift와 달리
// 위젯은 읽기만 하면 되므로 코드가 더 짧다.

import SQLite3
import SwiftUI
import WidgetKit

private struct LastFeeding {
  let startedAt: Date
  let ml: Int?
}

/// lib/data/db/database.g.dart(drift 생성 코드)와 스키마를 맞춰야 한다.
private enum SharedFeedingReader {
  static let appGroupId = "group.com.happypi.parentingLog"
  static let dbFileName = "parenting_log.sqlite"

  static func readLastFeeding() -> LastFeeding? {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId
      )
    else { return nil }
    let dbURL = containerURL.appendingPathComponent(dbFileName)

    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db
    else { return nil }
    defer { sqlite3_close(db) }

    // 분유·모유 중 가장 최근 것 하나만 본다(홈 화면 헤더와 같은 개념).
    let sql = """
      SELECT started_at, payload FROM activities
      WHERE deleted_at IS NULL AND type IN ('formula', 'breast')
      ORDER BY started_at DESC LIMIT 1
      """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement
    else { return nil }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

    let startedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 0)))

    var ml: Int?
    if let payloadCStr = sqlite3_column_text(statement, 1) {
      // 최소 코드를 위해 JSON 라이브러리 없이 "ml" 키 값만 뽑아낸다.
      let payload = String(cString: payloadCStr)
      if let range = payload.range(of: "\"ml\":") {
        let digits = payload[range.upperBound...].prefix(while: { $0.isNumber })
        ml = Int(digits)
      }
    }
    return LastFeeding(startedAt: startedAt, ml: ml)
  }
}

struct FeedingEntry: TimelineEntry {
  let date: Date
  let lastFeeding: LastFeeding?
}

struct FeedingProvider: TimelineProvider {
  func placeholder(in context: Context) -> FeedingEntry {
    FeedingEntry(date: Date(), lastFeeding: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (FeedingEntry) -> Void) {
    completion(FeedingEntry(date: Date(), lastFeeding: SharedFeedingReader.readLastFeeding()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FeedingEntry>) -> Void) {
    let entry = FeedingEntry(date: Date(), lastFeeding: SharedFeedingReader.readLastFeeding())
    // 위젯엔 1초 타이머가 없다. 경과 시간이 눈에 띄게 갱신되도록 15분마다 다시 그린다.
    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
    completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
  }
}

struct ParentingLogWidgetView: View {
  var entry: FeedingEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("마지막 수유 이후")
        .font(.caption)
        .foregroundStyle(.secondary)
      if let feeding = entry.lastFeeding {
        Text(elapsedText(since: feeding.startedAt))
          .font(.system(size: 28, weight: .regular))
          .monospacedDigit()
        if let ml = feeding.ml {
          Text("\(ml)ml")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else {
        Text("기록 없음")
          .font(.system(size: 20, weight: .regular))
      }
    }
    .padding()
    .containerBackground(for: .widget) {
      Color(red: 0.08, green: 0.07, blue: 0.06)
    }
  }

  private func elapsedText(since date: Date) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    return String(format: "%d:%02d", h, m)
  }
}

struct ParentingLogWidget: Widget {
  let kind: String = "ParentingLogWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: FeedingProvider()) { entry in
      ParentingLogWidgetView(entry: entry)
    }
    .configurationDisplayName("마지막 수유")
    .description("마지막 수유 이후 경과 시간을 보여줍니다.")
    .supportedFamilies([.systemSmall])
  }
}

@main
struct ParentingLogWidgetBundle: WidgetBundle {
  var body: some Widget {
    ParentingLogWidget()
  }
}
