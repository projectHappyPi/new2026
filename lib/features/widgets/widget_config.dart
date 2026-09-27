import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

enum WidgetFeedLabel {
  /// "모유 48분 14초 전"처럼 마지막 수유 종류를 그대로.
  lastType,

  /// "수유 48분 14초 전"
  generic,
}

enum NextFeedMode {
  /// 최근 3번 수유 간격 평균(기록 화면의 "다음 수유 예상"과 같은 계산).
  auto,

  /// 마지막 수유 + 고정 간격.
  fixed,
}

enum WidgetTheme { dark, light, system }

/// 홈·잠금 화면 위젯 설정. 앱 설정 > 위젯 에서 바꾸고, 네이티브 위젯은
/// 이 값을 JSON으로 받아 쓴다(iOS: App Group UserDefaults, Android: SharedPreferences).
/// 키 이름을 바꾸면 ios/TunteuniWidget/WidgetData.swift 와
/// android/.../widget/WidgetData.kt 도 같이 바꾼다.
class WidgetConfig {
  final bool showName;
  final bool showDday;
  final bool showFeeding;
  final WidgetFeedLabel feedLabel;
  final bool showNextFeed;
  final NextFeedMode nextFeedMode;
  final int fixedIntervalMin;
  final bool showSleep;

  /// 달력 위젯 오른쪽 위에 수유·수면 상태를 넣을지.
  final bool calendarShowStatus;

  /// 달력 위젯 왼쪽 위 "오늘 일정" 목록.
  final bool calendarShowToday;
  final WidgetTheme theme;

  const WidgetConfig({
    this.showName = true,
    this.showDday = true,
    this.showFeeding = true,
    this.feedLabel = WidgetFeedLabel.lastType,
    this.showNextFeed = true,
    this.nextFeedMode = NextFeedMode.auto,
    this.fixedIntervalMin = 180,
    this.showSleep = true,
    this.calendarShowStatus = true,
    this.calendarShowToday = true,
    this.theme = WidgetTheme.dark,
  });

  WidgetConfig copyWith({
    bool? showName,
    bool? showDday,
    bool? showFeeding,
    WidgetFeedLabel? feedLabel,
    bool? showNextFeed,
    NextFeedMode? nextFeedMode,
    int? fixedIntervalMin,
    bool? showSleep,
    bool? calendarShowStatus,
    bool? calendarShowToday,
    WidgetTheme? theme,
  }) => WidgetConfig(
    showName: showName ?? this.showName,
    showDday: showDday ?? this.showDday,
    showFeeding: showFeeding ?? this.showFeeding,
    feedLabel: feedLabel ?? this.feedLabel,
    showNextFeed: showNextFeed ?? this.showNextFeed,
    nextFeedMode: nextFeedMode ?? this.nextFeedMode,
    fixedIntervalMin: fixedIntervalMin ?? this.fixedIntervalMin,
    showSleep: showSleep ?? this.showSleep,
    calendarShowStatus: calendarShowStatus ?? this.calendarShowStatus,
    calendarShowToday: calendarShowToday ?? this.calendarShowToday,
    theme: theme ?? this.theme,
  );

  Map<String, Object?> toJson() => {
    'showName': showName,
    'showDday': showDday,
    'showFeeding': showFeeding,
    'feedLabel': feedLabel.name,
    'showNextFeed': showNextFeed,
    'nextFeedMode': nextFeedMode.name,
    'fixedIntervalMin': fixedIntervalMin,
    'showSleep': showSleep,
    'calendarShowStatus': calendarShowStatus,
    'calendarShowToday': calendarShowToday,
    'theme': theme.name,
  };

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  factory WidgetConfig.fromJson(Map<String, dynamic> j) {
    const d = WidgetConfig();
    return WidgetConfig(
      showName: j['showName'] as bool? ?? d.showName,
      showDday: j['showDday'] as bool? ?? d.showDday,
      showFeeding: j['showFeeding'] as bool? ?? d.showFeeding,
      feedLabel: _enum(WidgetFeedLabel.values, j['feedLabel'], d.feedLabel),
      showNextFeed: j['showNextFeed'] as bool? ?? d.showNextFeed,
      nextFeedMode: _enum(NextFeedMode.values, j['nextFeedMode'], d.nextFeedMode),
      fixedIntervalMin: j['fixedIntervalMin'] as int? ?? d.fixedIntervalMin,
      showSleep: j['showSleep'] as bool? ?? d.showSleep,
      calendarShowStatus: j['calendarShowStatus'] as bool? ?? d.calendarShowStatus,
      calendarShowToday: j['calendarShowToday'] as bool? ?? d.calendarShowToday,
      theme: _enum(WidgetTheme.values, j['theme'], d.theme),
    );
  }
}

const _kWidgetConfig = 'widget.config';

class WidgetConfigNotifier extends Notifier<WidgetConfig> {
  @override
  WidgetConfig build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_kWidgetConfig);
    if (raw == null) return const WidgetConfig();
    try {
      return WidgetConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return const WidgetConfig();
    }
  }

  void update(WidgetConfig Function(WidgetConfig) change) {
    state = change(state);
    ref
        .read(sharedPreferencesProvider)
        .setString(_kWidgetConfig, jsonEncode(state.toJson()));
  }
}

final widgetConfigProvider =
    NotifierProvider<WidgetConfigNotifier, WidgetConfig>(
      WidgetConfigNotifier.new,
    );
