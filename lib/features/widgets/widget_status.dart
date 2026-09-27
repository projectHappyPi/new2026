import '../../data/models/activity.dart';
import '../../data/models/activity_type.dart';
import 'widget_config.dart';

/// 위젯에 보여줄 한 줄 요약. 네이티브 위젯(Swift/Kotlin)이 같은 규칙을 따른다 —
/// 앱의 위젯 설정 미리보기와 단위 테스트가 이 Dart 구현을 기준으로 삼는다.
class WidgetStatus {
  /// "모유" / "분유" / "수유"
  final String? feedLabel;
  final DateTime? lastFeedAt;
  final DateTime? nextFeedAt;

  /// "밤잠" / "낮잠" (진행 중) 또는 "기상"(끝난 뒤)
  final String? sleepLabel;
  final DateTime? sleepAt;
  final bool sleeping;

  const WidgetStatus({
    this.feedLabel,
    this.lastFeedAt,
    this.nextFeedAt,
    this.sleepLabel,
    this.sleepAt,
    this.sleeping = false,
  });
}

bool _isFeed(Activity a) =>
    a.type == ActivityType.formula || a.type == ActivityType.breast;

/// 수유 대표 시각: 모유는 끝났으면 종료 시각(진행 중이면 시작), 분유는 기록 시각.
DateTime feedRef(Activity a) =>
    a.type == ActivityType.breast ? (a.endedAt ?? a.startedAt) : a.startedAt;

/// [recent]: 최근 며칠 기록(삭제 제외, 순서 무관).
WidgetStatus computeWidgetStatus(List<Activity> recent, WidgetConfig cfg) {
  final feeds = recent.where((a) => _isFeed(a) && a.deletedAt == null).toList()
    ..sort((a, b) => feedRef(a).compareTo(feedRef(b)));

  String? feedLabel;
  DateTime? lastFeedAt;
  DateTime? nextFeedAt;
  if (feeds.isNotEmpty) {
    final last = feeds.last;
    lastFeedAt = feedRef(last);
    feedLabel = cfg.feedLabel == WidgetFeedLabel.generic
        ? '수유'
        : last.type.label;
    Duration? interval;
    if (cfg.nextFeedMode == NextFeedMode.auto && feeds.length >= 2) {
      final refs = feeds.map(feedRef).toList();
      final tail = refs.length > 4 ? refs.sublist(refs.length - 4) : refs;
      var sum = 0;
      for (var i = 1; i < tail.length; i++) {
        sum += tail[i].difference(tail[i - 1]).inSeconds;
      }
      interval = Duration(seconds: sum ~/ (tail.length - 1));
    }
    interval ??= Duration(minutes: cfg.fixedIntervalMin);
    nextFeedAt = lastFeedAt.add(interval);
  }

  final sleeps = recent
      .where((a) => a.type == ActivityType.sleep && a.deletedAt == null)
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  String? sleepLabel;
  DateTime? sleepAt;
  var sleeping = false;
  if (sleeps.isNotEmpty) {
    final s = sleeps.last;
    if (s.endedAt == null) {
      sleeping = true;
      sleepLabel = (s.sleepPeriod ?? defaultSleepPeriod(s.startedAt)).label;
      sleepAt = s.startedAt;
    } else {
      sleepLabel = '기상';
      sleepAt = s.endedAt;
    }
  }

  return WidgetStatus(
    feedLabel: feedLabel,
    lastFeedAt: lastFeedAt,
    nextFeedAt: nextFeedAt,
    sleepLabel: sleepLabel,
    sleepAt: sleepAt,
    sleeping: sleeping,
  );
}

/// "48분 14초", "3시간 35분", "12초" — iOS Text(.relative) 표기와 맞춘다.
String relativeText(Duration d) {
  final s = d.inSeconds.abs();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  if (h > 0) return '$h시간 $m분';
  if (m > 0) return '$m분 $sec초';
  return '$sec초';
}
