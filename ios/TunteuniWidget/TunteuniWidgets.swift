import SwiftUI
import WidgetKit

struct TunteuniEntry: TimelineEntry {
  let date: Date
  let cfg: WidgetConfig
  let status: BabyStatus
  let events: [WidgetEvent]
}

/// 앱·시리가 기록하면 WidgetCenter.reloadAllTimelines()로 즉시 다시 그린다.
/// 그 사이에는 초 단위 글자(Text .relative)가 스스로 움직이고,
/// "남음 → 지남" 전환·자정(D+, 오늘 일정)에 맞춰 항목을 하나씩 더 둔다.
struct TunteuniProvider: TimelineProvider {
  let withEvents: Bool

  func placeholder(in context: Context) -> TunteuniEntry {
    let now = Date()
    var st = BabyStatus()
    st.feedLabel = "모유"
    st.lastFeed = now.addingTimeInterval(-48 * 60 - 14)
    st.nextFeed = now.addingTimeInterval(3 * 3600 + 35 * 60)
    st.sleepLabel = "밤잠"
    st.sleepAt = now.addingTimeInterval(-47 * 60 - 48)
    st.sleeping = true
    return TunteuniEntry(date: now, cfg: WidgetConfig(), status: st, events: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (TunteuniEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TunteuniEntry>) -> Void) {
    let now = Date()
    let first = entry(at: now)
    var entries = [first]
    let cal = Calendar.current
    let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
    if let next = first.status.nextFeed, next > now, next < midnight {
      entries.append(entry(at: next.addingTimeInterval(1)))
    }
    entries.append(entry(at: midnight))
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
  }

  private func entry(at date: Date) -> TunteuniEntry {
    let cfg = WidgetConfig.load()
    var events: [WidgetEvent] = []
    if withEvents {
      let (from, to) = monthGrid(for: date)
      events = WidgetStore.events(from: from, to: to.addingTimeInterval(14 * 86_400))
    }
    return TunteuniEntry(date: date, cfg: cfg, status: WidgetStore.status(cfg, now: date), events: events)
  }
}

/// 일요일 시작 6주 그리드의 시작·끝 자정.
func monthGrid(for date: Date) -> (Date, Date) {
  var cal = Calendar(identifier: .gregorian)
  cal.timeZone = .current
  let first = cal.date(from: cal.dateComponents([.year, .month], from: date))!
  let weekday = cal.component(.weekday, from: first)  // 1 = 일요일
  let start = cal.date(byAdding: .day, value: -(weekday - 1), to: first)!
  return (start, cal.date(byAdding: .day, value: 42, to: start)!)
}

// MARK: - 상태 위젯 (작게 · 중간 · 잠금화면)

struct StatusWidgetView: View {
  let entry: TunteuniEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let p = WidgetPalette.of(entry.cfg, scheme: scheme)
    switch family {
    case .accessoryRectangular:
      // 잠금화면: 시스템이 색을 입히므로 기본 색 사용
      StatusBlock(cfg: entry.cfg, st: entry.status, now: entry.date, big: 15, label: 13)
        .containerBackground(for: .widget) { Color.clear }
    default:
      StatusBlock(
        cfg: entry.cfg, st: entry.status, now: entry.date,
        fg: p.fg, dim: p.dim,
        big: family == .systemSmall ? 17 : 22,
        label: family == .systemSmall ? 13 : 15
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .containerBackground(for: .widget) { p.bg }
    }
  }
}

struct StatusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TunteuniStatus", provider: TunteuniProvider(withEvents: false)) { entry in
      StatusWidgetView(entry: entry)
    }
    .configurationDisplayName("튼튼이 상태")
    .description("마지막 수유·다음 수유·수면을 초 단위로 보여줘요. 표시 항목은 앱 설정 > 위젯에서 바꿔요.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

// MARK: - 달력 위젯 (크게)

struct CalendarWidgetView: View {
  let entry: TunteuniEntry
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let p = WidgetPalette.of(entry.cfg, scheme: scheme)
    let cal = Calendar.current
    let today = cal.startOfDay(for: entry.date)
    let todays = entry.events.filter { $0.occurs(on: today) }
    let (gridStart, _) = monthGrid(for: entry.date)
    let month = cal.component(.month, from: entry.date)

    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        // 왼쪽 위: 오늘 일정
        VStack(alignment: .leading, spacing: 3) {
          Text(entry.date, format: .dateTime.month().day().weekday(.wide))
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(p.fg)
          if entry.cfg.calendarShowToday {
            if todays.isEmpty {
              Text("오늘 일정 없음").font(.system(size: 11)).foregroundStyle(p.dim)
            }
            ForEach(todays.prefix(4)) { e in
              EventLine(e: e, prefix: e.allDay ? "종일" : e.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()), fg: p.fg)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // 오른쪽 위: 튼튼이 상태 (두 번째 캡처) — 끄면 다가오는 일정
        Group {
          if entry.cfg.calendarShowStatus {
            StatusBlock(cfg: entry.cfg, st: entry.status, now: entry.date, fg: p.fg, dim: p.dim, big: 15, label: 12)
          } else {
            let upcoming = entry.events.filter { $0.start >= cal.date(byAdding: .day, value: 1, to: today)! }
            VStack(alignment: .leading, spacing: 3) {
              Text("다가오는 일정").font(.system(size: 12, weight: .bold)).foregroundStyle(p.fg)
              if upcoming.isEmpty {
                Text("2주 안에 없음").font(.system(size: 11)).foregroundStyle(p.dim)
              }
              ForEach(upcoming.prefix(4)) { e in
                EventLine(e: e, prefix: e.start.formatted(.dateTime.month(.defaultDigits).day()), fg: p.fg)
              }
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      // 요일
      HStack(spacing: 0) {
        ForEach(0..<7, id: \.self) { i in
          Text(["일", "월", "화", "수", "목", "금", "토"][i])
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(i == 0 ? kSunday : i == 6 ? kSaturday : p.dim)
            .frame(maxWidth: .infinity)
        }
      }

      // 6주 그리드
      VStack(spacing: 1) {
        ForEach(0..<6, id: \.self) { w in
          HStack(alignment: .top, spacing: 1) {
            ForEach(0..<7, id: \.self) { d in
              let day = cal.date(byAdding: .day, value: w * 7 + d, to: gridStart)!
              DayCell(
                day: day,
                inMonth: cal.component(.month, from: day) == month,
                isToday: day == today,
                events: entry.events.filter { $0.occurs(on: day) },
                numColor: d == 0 ? kSunday : d == 6 ? kSaturday : p.fg,
                dim: p.dim
              )
            }
          }
          .frame(maxHeight: .infinity)
        }
      }
    }
    .padding(12)
    .containerBackground(for: .widget) { p.bg }
  }
}

struct EventLine: View {
  let e: WidgetEvent
  let prefix: String
  let fg: Color

  var body: some View {
    HStack(spacing: 4) {
      RoundedRectangle(cornerRadius: 1).fill(eventColor(e.colorName)).frame(width: 3, height: 11)
      Text("\(prefix) \(e.title)").font(.system(size: 11)).foregroundStyle(fg).lineLimit(1)
    }
  }
}

struct DayCell: View {
  let day: Date
  let inMonth: Bool
  let isToday: Bool
  let events: [WidgetEvent]
  let numColor: Color
  let dim: Color

  var body: some View {
    VStack(spacing: 1) {
      Text("\(Calendar.current.component(.day, from: day))")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(inMonth ? numColor : dim.opacity(0.6))
        .padding(.horizontal, 3)
        .background(isToday ? kSunday.opacity(0.28) : .clear, in: Capsule())
      ForEach(events.prefix(2)) { e in
        Text(e.title)
          .font(.system(size: 7, weight: .medium))
          .foregroundStyle(.white)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 1)
          .background(eventColor(e.colorName).opacity(0.9), in: RoundedRectangle(cornerRadius: 2))
      }
      if events.count > 2 {
        Text("+\(events.count - 2)").font(.system(size: 7)).foregroundStyle(dim)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .opacity(inMonth ? 1 : 0.5)
  }
}

struct CalendarWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TunteuniCalendar", provider: TunteuniProvider(withEvents: true)) { entry in
      CalendarWidgetView(entry: entry)
    }
    .configurationDisplayName("튼튼이 달력")
    .description("가족 일정 달력과 수유·수면 상태를 한 번에 보여줘요.")
    .supportedFamilies([.systemLarge])
    .contentMarginsDisabled()
  }
}

@main
struct TunteuniWidgetBundle: WidgetBundle {
  var body: some Widget {
    StatusWidget()
    CalendarWidget()
  }
}
