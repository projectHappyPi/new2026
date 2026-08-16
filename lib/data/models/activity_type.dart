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

/// 수면 구간이 낮잠인지 밤잠인지. 입력은 시간대 기준 자동 분류가 기본이고,
/// 애매한 구간(18~20시)에서만 길게 눌러 고를 수 있게 한다.
enum SleepPeriod {
  nap,
  night;

  String get label => switch (this) {
    SleepPeriod.nap => '낮잠',
    SleepPeriod.night => '밤잠',
  };
}

/// 18시 이전은 낮잠, 20시 이후는 무조건 밤잠. 그 사이(18~20시)는 애매한
/// 구간이라 기본값은 낮잠으로 두고(짧은 탭), 상세 시트(길게 누름)에서만
/// 밤잠으로 바꿀 수 있게 한다.
SleepPeriod defaultSleepPeriod(DateTime startedAt) {
  return startedAt.hour >= 20 ? SleepPeriod.night : SleepPeriod.nap;
}

/// 18~20시: 짧은 탭은 낮잠으로 자동 기록되지만, 길게 눌러 밤잠으로 바꿀 수 있는 구간.
bool isAmbiguousSleepWindow(DateTime startedAt) {
  final h = startedAt.hour;
  return h >= 18 && h < 20;
}
