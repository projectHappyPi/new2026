import 'package:flutter/material.dart';

import '../../data/models/activity.dart';
import '../../data/models/activity_type.dart';

/// 활동별 색. 기저귀는 입력은 통합이지만 표시(차트·목록)는 sub에 따라 분리한다.
@immutable
class ActivityColors extends ThemeExtension<ActivityColors> {
  final Color formula;
  final Color sleep;
  final Color solid;
  final Color pee;
  final Color poop;
  final Color breast;

  const ActivityColors({
    required this.formula,
    required this.sleep,
    required this.solid,
    required this.pee,
    required this.poop,
    required this.breast,
  });

  static const dark = ActivityColors(
    formula: Color(0xFFE5B478),
    sleep: Color(0xFF8189C9),
    solid: Color(0xFF9CAF6C),
    pee: Color(0xFF6FA79E),
    poop: Color(0xFFA8794F),
    breast: Color(0xFFD4909B),
  );

  static const light = ActivityColors(
    formula: Color(0xFFB87A28),
    sleep: Color(0xFF4F58A3),
    solid: Color(0xFF617536),
    pee: Color(0xFF367A70),
    poop: Color(0xFF845328),
    breast: Color(0xFFAC5C6C),
  );

  Color forType(ActivityType type, {DiaperSub? diaperSub}) {
    switch (type) {
      case ActivityType.formula:
        return formula;
      case ActivityType.sleep:
        return sleep;
      case ActivityType.solid:
        return solid;
      case ActivityType.breast:
        return breast;
      case ActivityType.diaper:
        return (diaperSub?.hasPoop ?? false) ? poop : pee;
    }
  }

  Color forActivity(Activity a) => forType(a.type, diaperSub: a.diaperSub);

  @override
  ActivityColors copyWith({
    Color? formula,
    Color? sleep,
    Color? solid,
    Color? pee,
    Color? poop,
    Color? breast,
  }) {
    return ActivityColors(
      formula: formula ?? this.formula,
      sleep: sleep ?? this.sleep,
      solid: solid ?? this.solid,
      pee: pee ?? this.pee,
      poop: poop ?? this.poop,
      breast: breast ?? this.breast,
    );
  }

  @override
  ActivityColors lerp(ThemeExtension<ActivityColors>? other, double t) {
    if (other is! ActivityColors) return this;
    return ActivityColors(
      formula: Color.lerp(formula, other.formula, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      solid: Color.lerp(solid, other.solid, t)!,
      pee: Color.lerp(pee, other.pee, t)!,
      poop: Color.lerp(poop, other.poop, t)!,
      breast: Color.lerp(breast, other.breast, t)!,
    );
  }
}

extension ActivityColorsContext on BuildContext {
  ActivityColors get activityColors =>
      Theme.of(this).extension<ActivityColors>()!;
}
