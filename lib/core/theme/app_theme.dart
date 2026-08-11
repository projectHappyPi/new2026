import 'package:flutter/material.dart';

import '../../data/models/settings.dart';
import 'activity_colors.dart';
import 'app_colors.dart';

extension TabularFigures on TextStyle {
  /// 1초마다 갱신되는 타이머 등 숫자 표시에서 자릿수가 흔들리지 않게 한다.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// 4.3 타이포그래피. 색은 호출부에서 context.colors로 입혀 라이트/다크에 맞춘다.
class AppTypography {
  const AppTypography._();

  static const statusNumber = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w400,
    height: 1.05,
  );
  static const metricValue = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w500,
  );
  static const title = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.8,
  );
  static const mono = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const monoSmall = TextStyle(fontSize: 10, fontWeight: FontWeight.w400);
}

ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors colors,
  required ActivityColors activityColors,
}) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    colorScheme: base.colorScheme.copyWith(
      surface: colors.surface,
      onSurface: colors.onSurface,
      outline: colors.outline,
      primary: activityColors.formula,
    ),
    dividerColor: colors.outlineSoft,
    dividerTheme: DividerThemeData(color: colors.outlineSoft, thickness: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
    extensions: [colors, activityColors],
  );
}

final lightTheme = _buildTheme(
  brightness: Brightness.light,
  colors: AppColors.light,
  activityColors: ActivityColors.light,
);

final darkTheme = _buildTheme(
  brightness: Brightness.dark,
  colors: AppColors.dark,
  activityColors: ActivityColors.dark,
);

/// 자정을 넘는 구간(예: 20시~7시)도 올바르게 처리한다.
bool inTimeWindow(DateTime now, TimeHM from, TimeHM to) {
  final h = now.hour + now.minute / 60.0;
  final f = from.hour + from.minute / 60.0;
  final t = to.hour + to.minute / 60.0;
  return f <= t ? (h >= f && h < t) : (h >= f || h < t);
}

/// 9.2 우선순위: 야간 저자극 모드 > 테마 설정.
ThemeMode resolveThemeMode(Settings s, DateTime now) {
  if (s.nightMode || inTimeWindow(now, s.nightFrom, s.nightTo)) {
    return ThemeMode.dark;
  }
  switch (s.themeOption) {
    case ThemeOption.light:
      return ThemeMode.light;
    case ThemeOption.dark:
      return ThemeMode.dark;
    case ThemeOption.schedule:
      return inTimeWindow(now, s.darkFrom, s.darkTo)
          ? ThemeMode.dark
          : ThemeMode.light;
    case ThemeOption.system:
      return ThemeMode.system;
  }
}

/// 야간 저자극 모드가 실제로 적용 중인지(배경을 한 단계 더 낮추고, 애니메이션을 끄고,
/// 버튼을 키우는 판단 기준). 강제 ON이거나 자동 전환 구간에 들어와 있으면 true.
bool isNightModeActive(Settings s, DateTime now) =>
    s.nightMode || inTimeWindow(now, s.nightFrom, s.nightTo);
