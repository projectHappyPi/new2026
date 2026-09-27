import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/data/db/database.dart';
import 'package:parenting_log/data/models/calendar_event.dart';
import 'package:parenting_log/data/repositories/event_repository.dart';

void main() {
  late AppDatabase db;
  late EventRepository repo;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    repo = EventRepository(db, memberName: () => '엄마');
  });
  tearDown(() => db.close());

  test('만들기·범위 조회·삭제', () async {
    final e = await repo.create(
      title: '예방접종',
      startAt: DateTime(2026, 10, 2, 10),
      endAt: DateTime(2026, 10, 2, 11),
      color: EventColor.red,
    );
    expect(e.createdBy, '엄마');
    final oct = await repo.range(DateTime(2026, 10), DateTime(2026, 11));
    expect(oct.single.title, '예방접종');
    expect(await repo.range(DateTime(2026, 11), DateTime(2026, 12)), isEmpty);
    await repo.softDelete(e.id);
    expect(await repo.range(DateTime(2026, 10), DateTime(2026, 11)), isEmpty);
    expect((await repo.changedSince(0)).single.deletedAt, isNotNull);
  });

  test('원격 반영은 더 최신일 때만', () async {
    final e = await repo.create(title: 'A', startAt: DateTime(2026, 10, 1));
    await repo.applyRemote([
      e.copyWith(title: '옛날 값', updatedAt: e.updatedAt.subtract(const Duration(minutes: 1))),
    ]);
    expect((await repo.range(DateTime(2026, 10), DateTime(2026, 11))).single.title, 'A');
    await repo.applyRemote([
      e.copyWith(title: '새 값', updatedAt: e.updatedAt.add(const Duration(minutes: 1))),
    ]);
    expect((await repo.range(DateTime(2026, 10), DateTime(2026, 11))).single.title, '새 값');
  });

  test('watchRange는 쓰기 후 다시 알린다', () async {
    final stream = repo.watchRange(DateTime(2026, 10), DateTime(2026, 11));
    final seen = <int>[];
    final sub = stream.listen((l) => seen.add(l.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.create(title: 'B', startAt: DateTime(2026, 10, 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen, [0, 1]);
  });
}
