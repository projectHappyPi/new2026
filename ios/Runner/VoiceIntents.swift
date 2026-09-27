import AppIntents
import Foundation

// "시리야, 튼튼이 분유 230ml 먹었어" — 앱을 열지 않고(openAppWhenRun = false)
// App Group 공유 DB에 바로 기록한다. 앱 이름(CFBundleDisplayName)이 "튼튼이"라서
// \(.applicationName)이 곧 아기 이름 자리에 들어간다.
//
// 문장 규칙은 Dart 쪽 lib/core/voice/voice_command.dart(앱 안 마이크)와 맞춘다.
// 숫자 매개변수는 VoiceIntentEnums.swift(자동 생성)의 케이스로 받는다.

private func sleepPeriod(for date: Date) -> String {
  // lib/data/models/activity_type.dart defaultSleepPeriod와 동일: 20시 이후 밤잠.
  Calendar.current.component(.hour, from: date) >= 20 ? "night" : "nap"
}

private func friendly(_ error: Error) -> IntentDialog {
  IntentDialog(stringLiteral: (error as? LocalizedError)?.errorDescription ?? "기록에 실패했어요.")
}

// MARK: - 수유

struct RecordFormulaIntent: AppIntent {
  static var title: LocalizedStringResource = "분유 기록"
  static var description = IntentDescription("분유 먹은 양을 튼튼이에 기록합니다.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "용량", requestValueDialog: "분유 몇 ml 먹었어요?")
  var amount: FormulaAmount

  static var parameterSummary: some ParameterSummary {
    Summary("분유 \(\.$amount) 기록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      try SharedActivityStore.insert(type: "formula", payload: ["ml": amount.ml])
      return .result(dialog: "분유 \(amount.ml)ml 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

struct RecordBreastIntent: AppIntent {
  static var title: LocalizedStringResource = "모유 기록"
  static var description = IntentDescription("방금 끝난 모유 수유 시간을 기록합니다.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "시간", requestValueDialog: "모유 몇 분 먹었어요?")
  var minutes: BreastMinutes

  static var parameterSummary: some ParameterSummary {
    Summary("모유 \(\.$minutes) 기록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      let now = Date()
      let start = now.addingTimeInterval(TimeInterval(-60 * minutes.minutes))
      try SharedActivityStore.insert(type: "breast", startedAt: start, endedAt: now)
      return .result(dialog: "모유 \(minutes.minutes)분 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

struct RecordSolidIntent: AppIntent {
  static var title: LocalizedStringResource = "이유식 기록"
  static var description = IntentDescription("이유식 먹은 양을 기록합니다.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "용량", requestValueDialog: "이유식 몇 ml 먹었어요?")
  var amount: SolidAmount

  static var parameterSummary: some ParameterSummary {
    Summary("이유식 \(\.$amount) 기록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      try SharedActivityStore.insert(type: "solid", payload: ["ml": amount.ml])
      return .result(dialog: "이유식 \(amount.ml)ml 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

// MARK: - 기저귀

struct RecordDiaperIntent: AppIntent {
  static var title: LocalizedStringResource = "기저귀 기록"
  static var description = IntentDescription("소변/대변 기저귀 교체를 기록합니다.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "종류", requestValueDialog: "소변이에요, 대변이에요?")
  var kind: DiaperKind

  static var parameterSummary: some ParameterSummary {
    Summary("기저귀 \(\.$kind) 기록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      var payload: [String: Any] = ["sub": kind.rawValue]
      // lib/core/constants.dart DiaperTextures.defaultTexture
      if kind != .pee { payload["texture"] = "보통" }
      try SharedActivityStore.insert(type: "diaper", payload: payload)
      let label = kind == .pee ? "소변" : (kind == .poop ? "대변" : "소변+대변")
      return .result(dialog: "\(label) 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

// MARK: - 수면

struct SleepStartIntent: AppIntent {
  static var title: LocalizedStringResource = "수면 시작"
  static var description = IntentDescription("아기가 잠든 시각을 기록합니다.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      if try SharedActivityStore.running(type: "sleep") != nil {
        return .result(dialog: "이미 자는 중으로 기록돼 있어요")
      }
      let now = Date()
      let period = sleepPeriod(for: now)
      try SharedActivityStore.insert(type: "sleep", startedAt: now, payload: ["period": period])
      return .result(dialog: period == "night" ? "밤잠 시작을 기록했어요" : "낮잠 시작을 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

struct SleepEndIntent: AppIntent {
  static var title: LocalizedStringResource = "수면 종료"
  static var description = IntentDescription("아기가 깬 시각을 기록합니다.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      guard let running = try SharedActivityStore.running(type: "sleep") else {
        return .result(dialog: "진행 중인 수면이 없어요. 먼저 잠들었다고 말해 주세요")
      }
      let now = Date()
      try SharedActivityStore.end(id: running.id, at: now)
      let minutes = Int(now.timeIntervalSince(running.startedAt) / 60)
      let slept = minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
      return .result(dialog: "수면 종료, \(slept) 잤어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

// MARK: - 목욕 · 체온 · 약

struct RecordBathIntent: AppIntent {
  static var title: LocalizedStringResource = "목욕 기록"
  static var description = IntentDescription("목욕한 시각을 기록합니다.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      try SharedActivityStore.insert(type: "bath")
      return .result(dialog: "목욕 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

struct RecordTemperatureIntent: AppIntent {
  static var title: LocalizedStringResource = "체온 기록"
  static var description = IntentDescription("아기 체온을 기록합니다.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "체온", requestValueDialog: "체온이 몇 도예요?")
  var temperature: BodyTemperature

  static var parameterSummary: some ParameterSummary {
    Summary("체온 \(\.$temperature) 기록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      let c = temperature.celsius
      try SharedActivityStore.insert(type: "temperature", payload: ["celsius": c])
      let text = c == c.rounded() ? String(Int(c)) : String(format: "%.1f", c)
      return .result(dialog: "체온 \(text)도 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

struct RecordMedicineIntent: AppIntent {
  static var title: LocalizedStringResource = "투약 기록"
  static var description = IntentDescription("약 먹인 시각을 기록합니다.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      try SharedActivityStore.insert(type: "medicine")
      return .result(dialog: "투약 기록했어요")
    } catch {
      return .result(dialog: friendly(error))
    }
  }
}

// MARK: - 시리 문구

/// 설치만 하면 자동 등록된다(단축어 앱에서 따로 만들 필요 없음).
/// 앱 하나당 AppShortcut은 최대 10개 — 지금 9개.
struct TunteuniShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RecordFormulaIntent(),
      phrases: [
        "\(.applicationName) 분유 \(\.$amount) 먹었어",
        "\(.applicationName) 분유 \(\.$amount) 기록해줘",
        "\(.applicationName) 분유 먹었어",
      ],
      shortTitle: "분유 기록",
      systemImageName: "drop.fill"
    )
    AppShortcut(
      intent: RecordBreastIntent(),
      phrases: [
        "\(.applicationName) 모유 \(\.$minutes) 먹었어",
        "\(.applicationName) 모유 먹었어",
      ],
      shortTitle: "모유 기록",
      systemImageName: "heart.fill"
    )
    AppShortcut(
      intent: RecordSolidIntent(),
      phrases: [
        "\(.applicationName) 이유식 \(\.$amount) 먹었어",
        "\(.applicationName) 이유식 먹었어",
      ],
      shortTitle: "이유식 기록",
      systemImageName: "fork.knife"
    )
    AppShortcut(
      intent: RecordDiaperIntent(),
      phrases: [
        "\(.applicationName) \(\.$kind) 갈았어",
        "\(.applicationName) \(\.$kind) 기저귀 갈았어",
        "\(.applicationName) 기저귀 갈았어",
      ],
      shortTitle: "기저귀 기록",
      systemImageName: "checkmark.circle"
    )
    AppShortcut(
      intent: SleepStartIntent(),
      phrases: [
        "\(.applicationName) 잠들었어",
        "\(.applicationName) 재웠어",
      ],
      shortTitle: "수면 시작",
      systemImageName: "moon.zzz.fill"
    )
    AppShortcut(
      intent: SleepEndIntent(),
      phrases: [
        "\(.applicationName) 깼어",
        "\(.applicationName) 일어났어",
      ],
      shortTitle: "수면 종료",
      systemImageName: "sun.max.fill"
    )
    AppShortcut(
      intent: RecordBathIntent(),
      phrases: [
        "\(.applicationName) 목욕했어",
        "\(.applicationName) 목욕 시켰어",
      ],
      shortTitle: "목욕 기록",
      systemImageName: "bathtub.fill"
    )
    AppShortcut(
      intent: RecordTemperatureIntent(),
      phrases: [
        "\(.applicationName) 체온 \(\.$temperature)야",
        "\(.applicationName) 체온 기록해줘",
      ],
      shortTitle: "체온 기록",
      systemImageName: "thermometer.medium"
    )
    AppShortcut(
      intent: RecordMedicineIntent(),
      phrases: [
        "\(.applicationName) 약 먹었어",
        "\(.applicationName) 약 먹였어",
      ],
      shortTitle: "투약 기록",
      systemImageName: "pills.fill"
    )
  }
}
