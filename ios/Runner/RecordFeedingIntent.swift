import AppIntents

/// "시리야, [앱 이름]에 분유 230 기록해줘" — 별도 App Intents 익스텐션
/// 타깃 없이 메인 앱 타깃에 그대로 둔다(최소 코드로 유지하기 위함).
/// openAppWhenRun을 false로 둬서 화면을 열지 않고 조용히 처리한다.
struct RecordFeedingIntent: AppIntent {
  static var title: LocalizedStringResource = "분유 기록"
  static var description = IntentDescription("분유 수유량을 육아 기록 앱에 기록합니다.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "용량(ml)")
  var amountMl: Int

  static var parameterSummary: some ParameterSummary {
    Summary("분유 \(\.$amountMl)ml 기록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      try SharedActivityStore.insertFormula(amountMl: amountMl)
      return .result(dialog: "분유 \(amountMl)ml 기록했어요")
    } catch {
      return .result(dialog: "기록에 실패했어요. 앱에서 App Group 설정을 확인해 주세요.")
    }
  }
}

/// 시리에게 이 앱이 어떤 문장을 알아들어야 하는지 알려준다.
struct ParentingLogShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RecordFeedingIntent(),
      phrases: [
        "\(.applicationName)에 수유 \(\.$amountMl) 기록해줘",
        "\(.applicationName)에 분유 \(\.$amountMl) 기록해줘",
        "\(.applicationName)에 분유 \(\.$amountMl)밀리리터 기록해줘"
      ],
      shortTitle: "분유 기록",
      systemImageName: "drop.fill"
    )
  }
}
