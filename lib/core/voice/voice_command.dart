/// "말로 기록" 명령 해석기.
///
/// 음성 인식(STT) 결과 문자열 → 기록 명령으로 바꾸는 순수 함수만 둔다.
/// 플랫폼·DB와 무관하게 단위 테스트(test/voice_command_test.dart)로 검증하고,
/// 목업(docs/mockup)에도 같은 규칙을 JS로 옮겨 쓴다. 규칙을 바꾸면 둘 다 바꾼다.
///
/// 지원 문장(예시):
///   튼튼이 분유 230ml 먹었어 / 모유 10분 먹었어 / 이유식 150ml 먹었어
///   소변 갈았어 / 대변 갈았어 / 잠들었어 / 깼어 / 목욕했어
///   체온 38도야 / 약 먹었어
library;

import '../../data/models/activity_type.dart';

enum VoiceCommandKind {
  formula,
  breast,
  solid,
  diaper,
  sleepStart,
  sleepEnd,
  bath,
  temperature,
  medicine,
}

class VoiceCommand {
  final VoiceCommandKind kind;

  /// 분유·이유식 용량. null이면 기본값(설정)을 쓴다.
  final int? ml;

  /// 모유 수유 시간(분).
  final int? minutes;

  /// 체온(섭씨).
  final double? celsius;

  /// 기저귀 종류. null이면 설정의 기본값(소변/대변)을 쓴다.
  final DiaperSub? diaper;

  /// 약 이름(해열제 등). 말하지 않았으면 null.
  final String? medicine;

  const VoiceCommand(
    this.kind, {
    this.ml,
    this.minutes,
    this.celsius,
    this.diaper,
    this.medicine,
  });

  /// 저장 직후 토스트·시리 응답에 쓰는 확인 문구.
  String get confirmation => switch (kind) {
    VoiceCommandKind.formula =>
      ml != null ? '분유 ${ml}ml 기록했어요' : '분유 기록했어요',
    VoiceCommandKind.breast => '모유 $minutes분 기록했어요',
    VoiceCommandKind.solid =>
      ml != null ? '이유식 ${ml}ml 기록했어요' : '이유식 기록했어요',
    VoiceCommandKind.diaper => '${diaper?.label ?? '기저귀'} 기록했어요',
    VoiceCommandKind.sleepStart => '수면 시작을 기록했어요',
    VoiceCommandKind.sleepEnd => '수면 종료를 기록했어요',
    VoiceCommandKind.bath => '목욕 기록했어요',
    VoiceCommandKind.temperature => '체온 ${formatCelsius(celsius!)}도 기록했어요',
    VoiceCommandKind.medicine =>
      medicine != null ? '$medicine 투약 기록했어요' : '투약 기록했어요',
  };

  @override
  bool operator ==(Object other) =>
      other is VoiceCommand &&
      other.kind == kind &&
      other.ml == ml &&
      other.minutes == minutes &&
      other.celsius == celsius &&
      other.diaper == diaper &&
      other.medicine == medicine;

  @override
  int get hashCode => Object.hash(kind, ml, minutes, celsius, diaper, medicine);

  @override
  String toString() =>
      'VoiceCommand($kind, ml: $ml, minutes: $minutes, celsius: $celsius, '
      'diaper: $diaper, medicine: $medicine)';
}

/// 해석 결과: [command]가 있으면 성공, 없으면 [error]를 사용자에게 보여준다.
class VoiceParseResult {
  final VoiceCommand? command;
  final String? error;

  const VoiceParseResult.ok(VoiceCommand this.command) : error = null;
  const VoiceParseResult.fail(String this.error) : command = null;

  bool get isOk => command != null;
}

/// 37.0 → "37", 37.5 → "37.5"
String formatCelsius(double c) {
  final rounded = (c * 10).round() / 10;
  return rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────── 범위

class VoiceLimits {
  const VoiceLimits._();
  static const int formulaMinMl = 10, formulaMaxMl = 400;
  static const int solidMinMl = 10, solidMaxMl = 500;
  static const int breastMinMin = 1, breastMaxMin = 180;
  static const double tempMin = 34.0, tempMax = 43.0;
}

// ─────────────────────────────────────────────────────────────── 키워드

const _peeWords = ['소변', '쉬야', '오줌', '쉬했', '쉬 했'];
const _poopWords = ['대변', '응가', '똥', '큰일'];
const _sleepEndWords = ['깼', '깻', '깨어났', '일어났', '기상', '잠깸', '잠에서깸'];
const _sleepStartWords = ['잠들', '재웠', '잠이들', '잠시작', '자기시작', '낮잠시작', '밤잠시작'];
const _bathWords = ['목욕', '씻겼', '샤워'];
const _breastWords = ['모유', '직수', '젖먹'];

/// 이름만 말해도 알아듣는 약. 목록에 없으면 "OO약" 형태로 잡는다.
const _knownMedicines = [
  '해열제',
  '타이레놀',
  '챔프',
  '맥시부펜',
  '부루펜',
  '이부프로펜',
  '아세트아미노펜',
  '유산균',
  '비타민디',
  '비타민',
  '항생제',
  '소화제',
  '철분제',
];

const _defaultNames = ['튼튼이', '튼튼'];

const _unknownHelp =
    '알아듣지 못했어요. 예) "분유 230ml 먹었어", "모유 10분 먹었어", '
    '"소변 갈았어", "잠들었어", "체온 38도야"';

// ─────────────────────────────────────────────────────────────── 해석

/// [babyName]은 온보딩에서 입력한 이름. 문장 앞의 아기 이름은 있어도 없어도 된다.
VoiceParseResult parseVoiceCommand(String input, {String? babyName}) {
  final text = normalizeVoiceText(input, babyName: babyName);
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) return const VoiceParseResult.fail(_unknownHelp);

  bool has(Iterable<String> words) => words.any(compact.contains);

  // 1) 체온 — 숫자+도. "목욕물 38도" 같은 문장과 헷갈리지 않도록, '체온/열'이
  //    없으면 다른 활동 키워드가 없을 때만 체온으로 본다.
  final tempMatch = RegExp(r'(\d{2}(?:\.\d+)?)도').firstMatch(compact);
  final saysTemp = compact.contains('체온') || compact.contains('열');
  final otherActivity = has(['분유', '이유식', '목욕', ..._breastWords]);
  if (saysTemp || (tempMatch != null && !otherActivity)) {
    if (tempMatch == null) {
      if (compact.contains('체온')) {
        return const VoiceParseResult.fail('체온은 숫자와 함께 말해 주세요. 예) "체온 38도야"');
      }
    } else {
      final c = double.parse(tempMatch.group(1)!);
      if (c < VoiceLimits.tempMin || c > VoiceLimits.tempMax) {
        return VoiceParseResult.fail('체온 ${formatCelsius(c)}도는 범위를 벗어났어요');
      }
      return VoiceParseResult.ok(
        VoiceCommand(
          VoiceCommandKind.temperature,
          celsius: (c * 10).round() / 10,
        ),
      );
    }
  }

  // 2) 약
  final medicine = _parseMedicine(compact);
  if (medicine != null) {
    return VoiceParseResult.ok(
      VoiceCommand(
        VoiceCommandKind.medicine,
        medicine: medicine.isEmpty ? null : medicine,
      ),
    );
  }

  // 3) 분유
  if (compact.contains('분유')) {
    final ml = _firstMl(text);
    if (ml != null &&
        (ml < VoiceLimits.formulaMinMl || ml > VoiceLimits.formulaMaxMl)) {
      return VoiceParseResult.fail('분유 ${ml}ml는 범위를 벗어났어요');
    }
    return VoiceParseResult.ok(VoiceCommand(VoiceCommandKind.formula, ml: ml));
  }

  // 4) 이유식
  if (compact.contains('이유식')) {
    final ml = _firstMl(text);
    if (ml != null &&
        (ml < VoiceLimits.solidMinMl || ml > VoiceLimits.solidMaxMl)) {
      return VoiceParseResult.fail('이유식 ${ml}ml는 범위를 벗어났어요');
    }
    return VoiceParseResult.ok(VoiceCommand(VoiceCommandKind.solid, ml: ml));
  }

  // 5) 모유 — 끝난 수유를 말하는 것이므로 시간이 꼭 필요하다.
  if (has(_breastWords)) {
    final minutes = _minutes(compact);
    if (minutes == null) {
      return const VoiceParseResult.fail('모유는 시간과 함께 말해 주세요. 예) "모유 10분 먹었어"');
    }
    if (minutes < VoiceLimits.breastMinMin ||
        minutes > VoiceLimits.breastMaxMin) {
      return VoiceParseResult.fail('모유 $minutes분은 범위를 벗어났어요');
    }
    return VoiceParseResult.ok(
      VoiceCommand(VoiceCommandKind.breast, minutes: minutes),
    );
  }

  // 6) 기저귀
  final pee = has(_peeWords);
  final poop = has(_poopWords);
  if (pee || poop || compact.contains('기저귀')) {
    final sub = pee && poop
        ? DiaperSub.both
        : poop
        ? DiaperSub.poop
        : pee
        ? DiaperSub.pee
        : null;
    return VoiceParseResult.ok(
      VoiceCommand(VoiceCommandKind.diaper, diaper: sub),
    );
  }

  // 7) 수면 — "잠들었다가 깼어"는 종료로 본다(깼음을 먼저 검사).
  if (has(_sleepEndWords)) {
    return const VoiceParseResult.ok(VoiceCommand(VoiceCommandKind.sleepEnd));
  }
  if (has(_sleepStartWords)) {
    return const VoiceParseResult.ok(VoiceCommand(VoiceCommandKind.sleepStart));
  }

  // 8) 목욕
  if (has(_bathWords)) {
    return const VoiceParseResult.ok(VoiceCommand(VoiceCommandKind.bath));
  }

  return const VoiceParseResult.fail(_unknownHelp);
}

/// 소문자화 · 아기 이름 제거 · 한글 숫자("이백삼십") → 아라비아 숫자 ·
/// "37점5" → "37.5" · "38도5부" → "38.5도" 까지 처리한 문자열.
String normalizeVoiceText(String input, {String? babyName}) {
  var t = input.toLowerCase().replaceAll(RegExp(r'[^\w\s.가-힣]'), ' ');

  final names = <String>{
    if (babyName != null && babyName.trim().length >= 2) babyName.trim(),
    ..._defaultNames,
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final n in names) {
    t = t.replaceAll(n.toLowerCase(), ' ');
  }

  // 단위 앞에 붙은 한글 숫자만 바꾼다("이유식"의 '이', "일어났어"의 '일'은 그대로).
  t = t.replaceAllMapped(
    RegExp(
      r'(?<![가-힣])([영공일이삼사오육칠팔구십백천]+)(?=\s*(?:밀리|미리|씨씨|시시|ml|cc|분(?!유)|시간|도|점|부))',
    ),
    (m) => '${koreanNumber(m.group(1)!) ?? m.group(1)}',
  );
  // "37 점 5" → "37.5", "37점오" → "37.5"
  t = t.replaceAllMapped(
    RegExp(r'(\d+)\s*점\s*([영공일이삼사오육칠팔구]|\d)'),
    (m) => '${m.group(1)}.${_digit(m.group(2)!)}',
  );
  // "38도 5부" → "38.5도"
  t = t.replaceAllMapped(
    RegExp(r'(\d+)\s*도\s*([일이삼사오육칠팔구]|\d)\s*부'),
    (m) => '${m.group(1)}.${_digit(m.group(2)!)}도',
  );
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _digit(String s) => RegExp(r'\d').hasMatch(s) ? s : '${koreanNumber(s)}';

/// "이백삼십" → 230, "삼십칠" → 37, "십" → 10, "이삼공" → 230(자리 읽기).
int? koreanNumber(String s) {
  const digits = {
    '영': 0,
    '공': 0,
    '일': 1,
    '이': 2,
    '삼': 3,
    '사': 4,
    '오': 5,
    '육': 6,
    '칠': 7,
    '팔': 8,
    '구': 9,
  };
  const units = {'십': 10, '백': 100, '천': 1000};
  var total = 0;
  var current = 0;
  var lastWasDigit = false;
  for (final ch in s.split('')) {
    final d = digits[ch];
    if (d != null) {
      current = lastWasDigit ? current * 10 + d : d;
      lastWasDigit = true;
      continue;
    }
    final u = units[ch];
    if (u == null) return null;
    total += (current == 0 ? 1 : current) * u;
    current = 0;
    lastWasDigit = false;
  }
  return total + current;
}

/// 첫 번째 용량. 단위(ml·밀리·cc…)가 없어도 숫자만 있으면 ml로 본다.
int? _firstMl(String text) {
  final m = RegExp(r'(\d{1,4})\s*(?:ml|밀리리터|밀리|미리|cc|씨씨|시시)?')
      .firstMatch(text);
  return m == null ? null : int.parse(m.group(1)!);
}

/// "10분", "1시간", "1시간 20분" → 분.
int? _minutes(String compact) {
  final h = RegExp(r'(\d{1,2})시간').firstMatch(compact);
  final m = RegExp(r'(\d{1,3})분(?!유)').firstMatch(compact);
  if (h == null && m == null) return null;
  final hours = h == null ? 0 : int.parse(h.group(1)!);
  final mins = m == null ? 0 : int.parse(m.group(1)!);
  return hours * 60 + mins;
}

/// 약 명령이면 약 이름(없으면 빈 문자열), 약 명령이 아니면 null.
String? _parseMedicine(String compact) {
  for (final name in _knownMedicines) {
    if (compact.contains(name)) return name;
  }
  if (compact.contains('투약')) return '';
  final m = RegExp(r'([가-힣]{0,6}?)약(?:을|를|도)?(?:먹|복용|줬|주었|투여|넣)')
      .firstMatch(compact);
  if (m == null) return null;
  var prefix = m.group(1)!;
  // "튼튼이가 약 먹었어"에서 이름을 지우고 남은 조사는 버린다.
  const particles = {'가', '이', '는', '은', '도', '한테', '에게'};
  if (particles.contains(prefix) ||
      prefix.contains('먹') ||
      prefix.contains('했') ||
      prefix.endsWith('고')) {
    prefix = '';
  }
  return prefix.isEmpty ? '' : '$prefix약';
}
