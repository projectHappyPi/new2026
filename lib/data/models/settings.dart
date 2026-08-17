/// 주 사용 손. 홈 궤적, 마이크 위치, 시트 버튼 정렬, 스와이프 방향이 모두 이 값에 연동된다.
enum HandSide { left, right }

enum ThemeOption { system, light, dark, schedule }

enum FormulaMode { fixed, recent, timeOfDay }

enum DiaperDefaultSub { pee, poop }

/// 시:분만 다루는 경량 값 타입(TimeOfDay 대체, DB/Prefs 저장이 단순해짐).
class TimeHM {
  final int hour;
  final int minute;

  const TimeHM(this.hour, this.minute);

  static TimeHM parse(String s) {
    final parts = s.split(':');
    return TimeHM(int.parse(parts[0]), int.parse(parts[1]));
  }

  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  String toString() => formatted;

  @override
  bool operator ==(Object other) =>
      other is TimeHM && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class Settings {
  final bool oneHandMode;
  final HandSide handSide;
  final ThemeOption themeOption;
  final TimeHM darkFrom;
  final TimeHM darkTo;
  final bool nightMode;
  final TimeHM nightFrom;
  final TimeHM nightTo;
  final int formulaDefaultMl;
  final FormulaMode formulaMode;
  final DiaperDefaultSub diaperDefaultSub;

  /// 시작 로딩 화면에 아기 사진을 보여줄지. 끄면 최소 노출 시간 없이 곧바로 시작된다.
  final bool showSplashPhoto;

  const Settings({
    this.oneHandMode = true,
    this.handSide = HandSide.right,
    this.themeOption = ThemeOption.system,
    this.darkFrom = const TimeHM(20, 0),
    this.darkTo = const TimeHM(7, 0),
    this.nightMode = false,
    this.nightFrom = const TimeHM(22, 0),
    this.nightTo = const TimeHM(6, 0),
    this.formulaDefaultMl = 150,
    this.formulaMode = FormulaMode.fixed,
    this.diaperDefaultSub = DiaperDefaultSub.pee,
    this.showSplashPhoto = true,
  });

  bool get isRightHand => handSide == HandSide.right;

  Settings copyWith({
    bool? oneHandMode,
    HandSide? handSide,
    ThemeOption? themeOption,
    TimeHM? darkFrom,
    TimeHM? darkTo,
    bool? nightMode,
    TimeHM? nightFrom,
    TimeHM? nightTo,
    int? formulaDefaultMl,
    FormulaMode? formulaMode,
    DiaperDefaultSub? diaperDefaultSub,
    bool? showSplashPhoto,
  }) {
    return Settings(
      oneHandMode: oneHandMode ?? this.oneHandMode,
      handSide: handSide ?? this.handSide,
      themeOption: themeOption ?? this.themeOption,
      darkFrom: darkFrom ?? this.darkFrom,
      darkTo: darkTo ?? this.darkTo,
      nightMode: nightMode ?? this.nightMode,
      nightFrom: nightFrom ?? this.nightFrom,
      nightTo: nightTo ?? this.nightTo,
      formulaDefaultMl: formulaDefaultMl ?? this.formulaDefaultMl,
      formulaMode: formulaMode ?? this.formulaMode,
      diaperDefaultSub: diaperDefaultSub ?? this.diaperDefaultSub,
      showSplashPhoto: showSplashPhoto ?? this.showSplashPhoto,
    );
  }
}
