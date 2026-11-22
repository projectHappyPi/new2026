import ActivityKit
import Foundation

/// 잠금화면 빠른 기록(실시간 현황) 켜기·끄기·갱신. 앱 타깃 전용
/// (Activity.request 는 위젯 익스텐션에서 쓸 수 없다).
///
/// - 켜기: 앱 설정 › 위젯 › "잠금화면 빠른 기록" → 앱이 위젯 설정을 넘길 때 refresh()
/// - 갱신: 기록할 때마다(앱·시리·버튼) refresh()
/// - iOS가 실시간 현황을 최대 8시간(잠금화면에는 12시간)까지만 두므로, 사라지면
///   앱을 열 때(refresh) 다시 띄운다.
enum LivePanel {
  static func refresh() {
    let cfg = WidgetConfig.load()
    let activities = Activity<TunteuniPanelAttributes>.activities
    guard cfg.lockPanel else {
      Task {
        for a in activities { await a.end(nil, dismissalPolicy: .immediate) }
      }
      return
    }
    let content = ActivityContent(state: TunteuniPanelAttributes.ContentState.current(), staleDate: nil)
    let live = activities.filter { $0.activityState == .active }
    if live.isEmpty {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      _ = try? Activity.request(
        attributes: TunteuniPanelAttributes(babyName: cfg.babyName, birthDate: cfg.birthDate),
        content: content,
        pushType: nil
      )
    } else {
      Task {
        for a in live { await a.update(content) }
      }
    }
  }
}
