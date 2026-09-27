import 'dart:convert';

import '../../core/time/time_format.dart';
import 'activity_type.dart';

/// 도메인 모델. DB 행(ActivityRow)과 별개로 두어 payload를 타입 있는 게터로 감싼다.
class Activity {
  final String id;
  final ActivityType type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Map<String, dynamic> payload;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Activity({
    required this.id,
    required this.type,
    required this.startedAt,
    this.endedAt,
    this.payload = const {},
    this.createdBy = 'me',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isRunning => type.isRange && endedAt == null;
  bool get autoEnded => payload['autoEnded'] == true;

  Duration elapsed([DateTime? now]) =>
      (endedAt ?? now ?? DateTime.now()).difference(startedAt);

  int? get ml => payload['ml'] as int?;
  String? get food => payload['food'] as String?;
  String? get amount => payload['amount'] as String?;
  String? get texture => payload['texture'] as String?;
  String? get place => payload['place'] as String?;
  String? get side => payload['side'] as String?;
  String? get note => payload['note'] as String?;

  /// 체온(섭씨). JSON에서 38처럼 정수로 올 수도 있어 num으로 받는다.
  double? get celsius => (payload['celsius'] as num?)?.toDouble();

  /// 약 이름(해열제 등). 이름 없이 "약 먹었어"면 null.
  String? get medicine => payload['medicine'] as String?;

  /// 말로 기록한 항목인지(타임라인 표시용).
  bool get viaVoice => payload['via'] == 'voice';

  DiaperSub? get diaperSub {
    final s = payload['sub'] as String?;
    for (final e in DiaperSub.values) {
      if (e.name == s) return e;
    }
    return null;
  }

  SleepPeriod? get sleepPeriod {
    final s = payload['period'] as String?;
    for (final e in SleepPeriod.values) {
      if (e.name == s) return e;
    }
    return null;
  }

  /// 버튼·토스트에 쓰는 짧은 요약. 누르기 전에 무엇이 기록될지 보여주기 위함.
  String get summary => switch (type) {
    ActivityType.formula => ml != null ? '${ml}ml' : '',
    ActivityType.breast => isRunning ? '진행 중' : dur(elapsed()),
    ActivityType.sleep =>
      isRunning
          ? '진행 중'
          : (sleepPeriod != null
                ? '${sleepPeriod!.label} · ${dur(elapsed())}'
                : dur(elapsed())),
    ActivityType.solid => [
      if (food != null) food!,
      if (ml != null) '${ml}ml',
    ].join(' '),
    ActivityType.diaper => diaperSub?.label ?? '',
    ActivityType.bath => '',
    ActivityType.temperature => celsius != null ? '${_c(celsius!)}℃' : '',
    ActivityType.medicine => medicine ?? '',
  };

  static String _c(double v) {
    final r = (v * 10).round() / 10;
    return r == r.truncateToDouble() ? '${r.toInt()}' : r.toStringAsFixed(1);
  }

  Activity copyWith({
    String? id,
    ActivityType? type,
    DateTime? startedAt,
    DateTime? Function()? endedAt,
    Map<String, dynamic>? payload,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      type: type ?? this.type,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt != null ? endedAt() : this.endedAt,
      payload: payload ?? this.payload,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  String get payloadJson => jsonEncode(payload);

  static Map<String, dynamic> decodePayload(String s) {
    if (s.isEmpty) return {};
    final decoded = jsonDecode(s);
    return decoded is Map<String, dynamic> ? decoded : {};
  }
}
