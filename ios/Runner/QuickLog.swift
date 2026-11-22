import ActivityKit
import AppIntents
import Foundation

// 원클릭 기록: 홈 화면 "빠른 기록" 위젯과 잠금화면 실시간 현황(Live Activity)의 버튼.
// 이 파일은 앱(Runner)과 위젯 익스텐션(TunteuniWidget) 두 타깃에 모두 들어간다.
// LiveActivityIntent 라서 버튼을 누르면 시스템이 앱 프로세스에서 perform 을 실행하고,
// 앱은 DB(App Group 공유 파일)에 바로 쓴 뒤 위젯과 잠금화면 패널을 갱신한다.
// 규칙은 Android QuickLog.kt, 앱의 버튼 짧게 누르기와 같다.

enum QuickKind: String, AppEnum {
  case breast, formula, solid, poop, pee, sleep

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "기록 종류"
  static var caseDisplayRepresentations: [QuickKind: DisplayRepresentation] = [
    .breast: "모유",
    .formula: "분유",
    .solid: "이유식",
    .poop: "대변",
    .pee: "소변",
    .sleep: "수면",
  ]

  var label: String {
    switch self {
    case .breast: return "모유"
    case .formula: return "분유"
    case .solid: return "이유식"
    case .poop: return "대변"
    case .pee: return "소변"
    case .sleep: return "수면"
    }
  }
}

struct QuickLogIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "튼튼이 빠른 기록"
  static var description = IntentDescription("위젯·잠금화면 버튼으로 바로 기록합니다.")
  static var openAppWhenRun: Bool = false
  static var isDiscoverable: Bool = false

  @Parameter(title: "종류")
  var kind: QuickKind

  init() {}

  init(kind: QuickKind) {
    self.kind = kind
  }

  func perform() async throws -> some IntentResult {
    _ = SharedActivityStore.quickLog(kind)
    return .result()
  }
}

extension SharedActivityStore {
  /// 한 번 누르기 기록. 수면·모유는 진행 중이면 종료, 아니면 시작.
  @discardableResult
  static func quickLog(_ kind: QuickKind) -> String {
    do {
      switch kind {
      case .sleep, .breast:
        let type = kind == .sleep ? "sleep" : "breast"
        if let r = try running(type: type) {
          try end(id: r.id)
          return "\(kind.label) 종료"
        }
        var payload: [String: Any] = ["via": "widget"]
        if kind == .sleep {
          payload["period"] = Calendar.current.component(.hour, from: Date()) >= 20 ? "night" : "nap"
        }
        try insert(type: type, payload: payload)
        return "\(kind.label) 시작"
      case .formula:
        let ml = WidgetConfig.load().formulaMl
        try insert(type: "formula", payload: ["ml": ml, "via": "widget"])
        return "분유 \(ml)ml"
      case .pee:
        try insert(type: "diaper", payload: ["sub": "pee", "via": "widget"])
        return "소변"
      case .poop:
        try insert(type: "diaper", payload: ["sub": "poop", "texture": "보통", "via": "widget"])
        return "대변"
      case .solid:
        let food = lastSolidFood() ?? "쌀미음"
        try insert(type: "solid", payload: ["food": food, "amount": "보통", "via": "widget"])
        return "이유식 \(food)"
      }
    } catch {
      return (error as? LocalizedError)?.errorDescription ?? "기록하지 못했어요"
    }
  }
}

/// 잠금화면 실시간 현황(Live Activity) 데이터. 위젯 익스텐션이 이 모양으로 그린다.
struct TunteuniPanelAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var feedLabel: String?
    var lastFeed: Date?
    var nextFeed: Date?
    var sleepLabel: String?
    var sleepAt: Date?
    var sleeping: Bool
    var breastRunning: Bool
  }

  var babyName: String
  var birthDate: Date?
}

extension TunteuniPanelAttributes.ContentState {
  static func current() -> Self {
    let cfg = WidgetConfig.load()
    let st = WidgetStore.status(cfg)
    return .init(
      feedLabel: st.feedLabel, lastFeed: st.lastFeed, nextFeed: st.nextFeed,
      sleepLabel: st.sleepLabel, sleepAt: st.sleepAt,
      sleeping: st.sleeping, breastRunning: st.breastRunning
    )
  }
}
