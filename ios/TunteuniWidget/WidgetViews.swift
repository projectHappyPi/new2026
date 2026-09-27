import SwiftUI
import WidgetKit

// lib/data/models/calendar_event.dart EventColor 와 같은 값
func eventColor(_ name: String) -> Color {
  switch name {
  case "red": return Color(red: 0.878, green: 0.408, blue: 0.353)
  case "orange": return Color(red: 0.898, green: 0.604, blue: 0.306)
  case "yellow": return Color(red: 0.851, green: 0.706, blue: 0.290)
  case "green": return Color(red: 0.435, green: 0.686, blue: 0.447)
  case "teal": return Color(red: 0.310, green: 0.659, blue: 0.627)
  case "purple": return Color(red: 0.604, green: 0.482, blue: 0.820)
  case "pink": return Color(red: 0.851, green: 0.498, blue: 0.655)
  default: return Color(red: 0.357, green: 0.561, blue: 0.851)
  }
}

let kSunday = Color(red: 0.878, green: 0.408, blue: 0.353)
let kSaturday = Color(red: 0.357, green: 0.561, blue: 0.851)

struct WidgetPalette {
  let bg: Color
  let fg: Color
  let dim: Color

  static func of(_ cfg: WidgetConfig, scheme: ColorScheme) -> WidgetPalette {
    let dark: Bool
    switch cfg.theme {
    case "light": dark = false
    case "system": dark = scheme == .dark
    default: dark = true
    }
    return dark
      ? WidgetPalette(bg: Color(red: 0.149, green: 0.133, blue: 0.122), fg: .white, dim: .white.opacity(0.6))
      : WidgetPalette(bg: Color(red: 0.957, green: 0.945, blue: 0.925), fg: Color(red: 0.106, green: 0.106, blue: 0.122), dim: .black.opacity(0.55))
  }
}

/// 두 번째 캡처와 같은 모양:
///   튼튼이                 D+248
///   모유  48분 14초 전
///    → 3시간 35분 남음
///   밤잠  47분 48초 전
/// Text(date, style: .relative)는 위젯이 스스로 초 단위로 갱신한다.
struct StatusBlock: View {
  let cfg: WidgetConfig
  let st: BabyStatus
  let now: Date
  var fg: Color = .primary
  var dim: Color = .secondary
  var big: CGFloat = 20
  var label: CGFloat = 15

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if cfg.showName || cfg.showDday {
        HStack {
          if cfg.showName {
            Text(cfg.babyName).font(.system(size: 14, weight: .bold)).foregroundStyle(fg)
          }
          Spacer(minLength: 4)
          if cfg.showDday, let d = cfg.dday(at: now) {
            Text("D+\(d)").font(.system(size: 14, weight: .semibold)).foregroundStyle(dim)
          }
        }
        .padding(.bottom, 2)
      }
      if cfg.showFeeding {
        if let last = st.lastFeed {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(st.feedLabel ?? "수유").font(.system(size: label, weight: .bold))
            (Text(last, style: .relative) + Text(" 전"))
              .font(.system(size: big, weight: .bold))
              .monospacedDigit()
          }
          .foregroundStyle(fg)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          if cfg.showNextFeed, let next = st.nextFeed {
            Group {
              if next > now {
                Text("→ ") + Text(next, style: .relative) + Text(" 남음")
              } else {
                Text("→ ") + Text(next, style: .relative) + Text(" 지남")
              }
            }
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(dim)
            .padding(.leading, 8)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          }
        } else {
          Text("수유 기록 없음").font(.system(size: 13)).foregroundStyle(dim)
        }
      }
      if cfg.showSleep, let at = st.sleepAt {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(st.sleepLabel ?? "수면").font(.system(size: label, weight: .bold))
          (Text(at, style: .relative) + Text(" 전"))
            .font(.system(size: big, weight: .bold))
            .monospacedDigit()
        }
        .foregroundStyle(fg)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      }
    }
  }
}
