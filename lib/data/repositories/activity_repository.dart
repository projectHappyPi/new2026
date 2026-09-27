import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';

abstract class ActivityRepository {
  Stream<List<Activity>> watchByDay(DateTime day);
  Stream<List<Activity>> watchRange(DateTime from, DateTime to);

  /// endedAt == null && type.isRange (동시에 1건만 존재).
  Stream<Activity?> watchRunning();

  Future<Activity> create(Activity a);
  Future<void> update(Activity a);
  Future<void> softDelete(String id);
  Future<Activity?> lastOf(ActivityType type);

  /// 이유식 시트의 "최근 사용한 식재료" 칩용.
  Future<List<String>> recentFoods({int limit = 5});

  /// 동기화: [sinceSec] 이후 바뀐 기록(예시 데이터 제외, 삭제 포함).
  Future<List<Activity>> changedSince(int sinceSec);

  /// 동기화: 서버에서 받은 기록 반영(더 최신일 때만 덮어씀).
  Future<void> applyRemote(List<Activity> activities);
}

/// 예시(시드) 기록의 작성자 값. 동기화로 올리지 않는다.
const kSeedCreatedBy = 'seed';

class DriftActivityRepository implements ActivityRepository {
  final AppDatabase db;
  final Uuid _uuid;

  /// 가족 공유에서 쓰는 내 이름(엄마/아빠). 새 기록의 작성자로 남는다.
  final String Function() memberName;

  DriftActivityRepository(this.db, {Uuid? uuid, String Function()? memberName})
    : _uuid = uuid ?? const Uuid(),
      memberName = memberName ?? (() => 'me');

  Activity _toDomain(ActivityRow r) => Activity(
    id: r.id,
    type: r.type,
    startedAt: r.startedAt,
    endedAt: r.endedAt,
    payload: Activity.decodePayload(r.payload),
    createdBy: r.createdBy,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deletedAt: r.deletedAt,
  );

  @override
  Stream<List<Activity>> watchRange(DateTime from, DateTime to) {
    final q = db.select(db.activities)
      ..where((t) => t.deletedAt.isNull())
      ..where(
        (t) =>
            t.startedAt.isBiggerOrEqualValue(from) &
            t.startedAt.isSmallerThanValue(to),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
      ]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<Activity>> watchByDay(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    return watchRange(from, to);
  }

  @override
  Stream<Activity?> watchRunning() {
    final q = db.select(db.activities)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.endedAt.isNull() &
            (t.type.equalsValue(ActivityType.sleep) |
                t.type.equalsValue(ActivityType.breast)),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  @override
  Future<Activity> create(Activity a) async {
    final id = a.id.isEmpty ? _uuid.v4() : a.id;
    final now = DateTime.now();
    await db
        .into(db.activities)
        .insert(
          ActivitiesCompanion.insert(
            id: id,
            type: a.type,
            startedAt: a.startedAt,
            endedAt: Value(a.endedAt),
            payload: Value(a.payloadJson),
            createdBy: Value(
              a.createdBy == 'me' ? memberName() : a.createdBy,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return a.copyWith(
      id: id,
      createdAt: now,
      updatedAt: now,
      createdBy: a.createdBy == 'me' ? memberName() : a.createdBy,
    );
  }

  @override
  Future<void> update(Activity a) async {
    final now = DateTime.now();
    await (db.update(db.activities)..where((t) => t.id.equals(a.id))).write(
      ActivitiesCompanion(
        type: Value(a.type),
        startedAt: Value(a.startedAt),
        endedAt: Value(a.endedAt),
        payload: Value(a.payloadJson),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> softDelete(String id) async {
    // updatedAt도 바꿔야 동기화로 삭제가 상대 폰에 전달된다.
    final now = DateTime.now();
    await (db.update(db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<List<Activity>> changedSince(int sinceSec) async {
    final since = DateTime.fromMillisecondsSinceEpoch(sinceSec * 1000);
    final q = db.select(db.activities)
      ..where(
        (t) =>
            t.updatedAt.isBiggerThanValue(since) &
            t.createdBy.equals(kSeedCreatedBy).not(),
      );
    final rows = await q.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> applyRemote(List<Activity> activities) async {
    if (activities.isEmpty) return;
    int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
    var changed = 0;
    await db.transaction(() async {
      for (final a in activities) {
        await db.customStatement(
          'INSERT INTO activities (id, type, started_at, ended_at, payload, created_by, created_at, updated_at, deleted_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET type = excluded.type, started_at = excluded.started_at, '
          'ended_at = excluded.ended_at, payload = excluded.payload, created_by = excluded.created_by, '
          'created_at = excluded.created_at, updated_at = excluded.updated_at, deleted_at = excluded.deleted_at '
          'WHERE excluded.updated_at > activities.updated_at',
          [
            a.id,
            a.type.name,
            sec(a.startedAt),
            a.endedAt == null ? null : sec(a.endedAt!),
            a.payloadJson,
            a.createdBy,
            sec(a.createdAt),
            sec(a.updatedAt),
            a.deletedAt == null ? null : sec(a.deletedAt!),
          ],
        );
        final r = await db.customSelect('SELECT changes() AS c').getSingle();
        changed += r.data['c'] as int;
      }
    });
    // 서버가 내가 보낸 걸 되돌려준 것뿐이면(바뀐 행 없음) 화면·위젯·동기화를 깨우지 않는다.
    if (changed > 0) db.markTablesUpdated({db.activities});
  }

  @override
  Future<Activity?> lastOf(ActivityType type) async {
    final q = db.select(db.activities)
      ..where((t) => t.deletedAt.isNull() & t.type.equalsValue(type))
      ..orderBy([
        (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<String>> recentFoods({int limit = 5}) async {
    final q = db.select(db.activities)
      ..where(
        (t) => t.deletedAt.isNull() & t.type.equalsValue(ActivityType.solid),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
      ])
      ..limit(50);
    final rows = await q.get();
    final foods = <String>[];
    for (final row in rows) {
      final food = _toDomain(row).food;
      if (food != null && food.isNotEmpty && !foods.contains(food)) {
        foods.add(food);
      }
      if (foods.length >= limit) break;
    }
    return foods;
  }
}
