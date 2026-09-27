import 'package:flutter/material.dart';

/// 달력 일정 색. DB·서버에는 name 문자열로 저장한다(iOS/Android 위젯도 같은 이름을 쓴다).
enum EventColor {
  red(Color(0xFFE0685A), '빨강'),
  orange(Color(0xFFE59A4E), '주황'),
  yellow(Color(0xFFD9B44A), '노랑'),
  green(Color(0xFF6FAF72), '초록'),
  teal(Color(0xFF4FA8A0), '청록'),
  blue(Color(0xFF5B8FD9), '파랑'),
  purple(Color(0xFF9A7BD1), '보라'),
  pink(Color(0xFFD97FA7), '분홍');

  final Color color;
  final String label;
  const EventColor(this.color, this.label);

  static EventColor parse(String? s) {
    for (final c in values) {
      if (c.name == s) return c;
    }
    return EventColor.blue;
  }
}

/// 가족이 같이 보는 달력 일정(예방접종, 병원, 영유아 검진…).
class CalendarEvent {
  final String id;
  final String title;
  final DateTime startAt;

  /// 종일 일정이면 마지막 날의 자정(포함), 시간 일정이면 끝나는 시각. 없으면 시작과 같음.
  final DateTime? endAt;
  final bool allDay;
  final EventColor color;
  final String? memo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    this.endAt,
    this.allDay = false,
    this.color = EventColor.blue,
    this.memo,
    this.createdBy = 'me',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  DateTime get effectiveEnd => endAt ?? startAt;

  /// [day](자정)에 걸쳐 있는 일정인지.
  bool occursOn(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final d1 = d0.add(const Duration(days: 1));
    final s = DateTime(startAt.year, startAt.month, startAt.day);
    final e = effectiveEnd;
    return s.isBefore(d1) && !e.isBefore(d0);
  }

  bool get isMultiDay {
    final e = effectiveEnd;
    return e.year != startAt.year ||
        e.month != startAt.month ||
        e.day != startAt.day;
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startAt,
    DateTime? Function()? endAt,
    bool? allDay,
    EventColor? color,
    String? Function()? memo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt != null ? endAt() : this.endAt,
      allDay: allDay ?? this.allDay,
      color: color ?? this.color,
      memo: memo != null ? memo() : this.memo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  // ── DB 행(snake_case, 초 단위) ──

  static DateTime _sec(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch((v as int) * 1000);
  static DateTime? _secOrNull(Object? v) => v == null ? null : _sec(v);
  static int toSec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  factory CalendarEvent.fromRow(Map<String, Object?> r) => CalendarEvent(
    id: r['id'] as String,
    title: r['title'] as String,
    startAt: _sec(r['start_at']),
    endAt: _secOrNull(r['end_at']),
    allDay: (r['all_day'] as int? ?? 0) == 1,
    color: EventColor.parse(r['color'] as String?),
    memo: r['memo'] as String?,
    createdBy: r['created_by'] as String? ?? 'me',
    createdAt: _sec(r['created_at']),
    updatedAt: _sec(r['updated_at']),
    deletedAt: _secOrNull(r['deleted_at']),
  );

  /// INSERT 순서: id, title, start_at, end_at, all_day, color, memo,
  /// created_by, created_at, updated_at, deleted_at
  List<Object?> toRowArgs() => [
    id,
    title,
    toSec(startAt),
    endAt == null ? null : toSec(endAt!),
    allDay ? 1 : 0,
    color.name,
    memo,
    createdBy,
    toSec(createdAt),
    toSec(updatedAt),
    deletedAt == null ? null : toSec(deletedAt!),
  ];
}
