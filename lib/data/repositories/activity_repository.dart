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
}

class DriftActivityRepository implements ActivityRepository {
  final AppDatabase db;
  final Uuid _uuid;

  DriftActivityRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

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
            createdBy: Value(a.createdBy),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return a.copyWith(id: id, createdAt: now, updatedAt: now);
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
    await (db.update(db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(deletedAt: Value(DateTime.now())),
    );
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
