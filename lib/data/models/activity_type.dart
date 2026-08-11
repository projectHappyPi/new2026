/// 활동 유형. 값 순서는 DB에 textEnum으로 저장되므로 임의로 바꾸지 않는다.
enum ActivityType { formula, breast, sleep, solid, diaper }

/// instant: 즉시 기록, range: 시작~종료 구간 기록.
enum ActivityKind { instant, range }

extension ActivityTypeX on ActivityType {
  String get label => switch (this) {
    ActivityType.formula => '분유',
    ActivityType.breast => '모유',
    ActivityType.sleep => '수면',
    ActivityType.solid => '이유식',
    ActivityType.diaper => '기저귀',
  };

  ActivityKind get kind => switch (this) {
    ActivityType.breast || ActivityType.sleep => ActivityKind.range,
    ActivityType.formula ||
    ActivityType.solid ||
    ActivityType.diaper => ActivityKind.instant,
  };

  bool get isRange => kind == ActivityKind.range;
}

/// 기저귀 하위 유형. 입력 버튼은 하나로 통합하고, 표시(차트·목록)에서만 분리한다.
enum DiaperSub {
  pee,
  poop,
  both;

  String get label => switch (this) {
    DiaperSub.pee => '소변',
    DiaperSub.poop => '대변',
    DiaperSub.both => '소변+대변',
  };

  /// 대변이 섞인 계열인지(색·묽기 표시 분기용).
  bool get hasPoop => this == poop || this == both;
}
