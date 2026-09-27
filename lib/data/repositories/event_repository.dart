import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../models/calendar_event.dart';

/// 달력 일정 저장소. events 테이블은 drift 코드 생성 없이 SQL로 다루고,
/// 쓰기 후 notifyUpdates로 알려 watch 스트림·위젯 갱신·동기화가 따라오게 한다.
class EventRepository {
  final AppDatabase db;
  final String Function() memberName;
  final Uuid _uuid;

  EventRepository(this.db, {required this.memberName, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _cols =
      'id, title, start_at, end_at, all_day, color, memo, created_by, created_at, updated_at, deleted_at';

  Future<List<CalendarEvent>> range(DateTime from, DateTime to) async {
    final rows = await db
        .customSelect(
          'SELECT $_cols FROM $kEventsTable '
          'WHERE deleted_at IS NULL AND start_at < ? AND COALESCE(end_at, start_at) >= ? '
          'ORDER BY all_day DESC, start_at ASC',
          variables: [
            Variable.withInt(CalendarEvent.toSec(to)),
            Variable.withInt(CalendarEvent.toSec(from)),
          ],
        )
        .get();
    return rows.map((r) => CalendarEvent.fromRow(r.data)).toList();
  }

  /// [from, to) 구간에 걸친 일정. events 테이블이 바뀔 때마다 다시 읽는다.
  Stream<List<CalendarEvent>> watchRange(DateTime from, DateTime to) async* {
    yield await range(from, to);
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onTableName(kEventsTable),
    )) {
      yield await range(from, to);
    }
  }

  Future<CalendarEvent> create({
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    bool allDay = false,
    EventColor color = EventColor.blue,
    String? memo,
  }) async {
    final now = DateTime.now();
    final e = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      color: color,
      memo: memo,
      createdBy: memberName(),
      createdAt: now,
      updatedAt: now,
    );
    await _upsert([e], onlyIfNewer: false);
    return e;
  }

  Future<CalendarEvent> update(CalendarEvent e) async {
    final updated = e.copyWith(updatedAt: DateTime.now());
    await _upsert([updated], onlyIfNewer: false);
    return updated;
  }

  Future<void> softDelete(String id) async {
    final now = CalendarEvent.toSec(DateTime.now());
    await db.customStatement(
      'UPDATE $kEventsTable SET deleted_at = ?, updated_at = ? WHERE id = ?',
      [now, now, id],
    );
    db.notifyUpdates({const TableUpdate(kEventsTable)});
  }

  /// 동기화: [sinceSec] 이후 바뀐 일정(삭제 포함).
  Future<List<CalendarEvent>> changedSince(int sinceSec) async {
    final rows = await db
        .customSelect(
          'SELECT $_cols FROM $kEventsTable WHERE updated_at > ?',
          variables: [Variable.withInt(sinceSec)],
        )
        .get();
    return rows.map((r) => CalendarEvent.fromRow(r.data)).toList();
  }

  /// 동기화: 서버에서 받은 일정 반영(더 최신일 때만).
  Future<void> applyRemote(List<CalendarEvent> events) =>
      _upsert(events, onlyIfNewer: true);

  Future<void> _upsert(
    List<CalendarEvent> events, {
    required bool onlyIfNewer,
  }) async {
    if (events.isEmpty) return;
    final sql =
        'INSERT INTO $kEventsTable ($_cols) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET title = excluded.title, start_at = excluded.start_at, '
        'end_at = excluded.end_at, all_day = excluded.all_day, color = excluded.color, '
        'memo = excluded.memo, created_by = excluded.created_by, created_at = excluded.created_at, '
        'updated_at = excluded.updated_at, deleted_at = excluded.deleted_at'
        '${onlyIfNewer ? ' WHERE excluded.updated_at > $kEventsTable.updated_at' : ''}';
    var changed = 0;
    await db.transaction(() async {
      for (final e in events) {
        await db.customStatement(sql, e.toRowArgs());
        final r = await db.customSelect('SELECT changes() AS c').getSingle();
        changed += r.data['c'] as int;
      }
    });
    if (changed > 0) db.notifyUpdates({const TableUpdate(kEventsTable)});
  }
}
