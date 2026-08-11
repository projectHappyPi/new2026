import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_type.dart';
import 'database.dart';

const _uuid = Uuid();

/// 첫 실행 시 DB가 비어 있으면 오늘 5건 + 직전 13일치 그럴듯한 기록을 채운다.
/// 빈 화면으로 시작하면 타임라인·패턴 레이아웃 검증이 안 되기 때문이다.
Future<void> seedIfEmpty(AppDatabase db) async {
  final existing = await db.select(db.activities).get();
  if (existing.isNotEmpty) return;
  await _insertSeedData(db);
}

/// 설정 > 데이터(디버그 빌드 전용): 기존 기록을 지우고 시드를 새로 채운다.
Future<void> seedForce(AppDatabase db) async {
  await db.delete(db.activities).go();
  await _insertSeedData(db);
}

Future<void> _insertSeedData(AppDatabase db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rows = <ActivitiesCompanion>[..._todaySeed(today)];

  final rnd = Random(20260811);
  for (var i = 13; i >= 1; i--) {
    final day = today.subtract(Duration(days: i));
    final recency = (14 - i) / 13.0; // 0..1, 오늘에 가까울수록 1에 근접
    rows.addAll(_daySeed(day, recency, rnd));
  }

  await db.batch((b) {
    b.insertAll(db.activities, rows, mode: InsertMode.insertOrIgnore);
  });
}

ActivitiesCompanion _row({
  required ActivityType type,
  required DateTime startedAt,
  DateTime? endedAt,
  Map<String, dynamic> payload = const {},
}) {
  return ActivitiesCompanion.insert(
    id: _uuid.v4(),
    type: type,
    startedAt: startedAt,
    endedAt: Value(endedAt),
    payload: Value(jsonEncode(payload)),
    createdAt: startedAt,
    updatedAt: startedAt,
  );
}

List<ActivitiesCompanion> _todaySeed(DateTime today) {
  DateTime at(int h, int m) =>
      DateTime(today.year, today.month, today.day, h, m);
  return [
    _row(
      type: ActivityType.diaper,
      startedAt: at(5, 32),
      payload: const {'sub': 'pee'},
    ),
    _row(
      type: ActivityType.formula,
      startedAt: at(6, 11),
      payload: const {'ml': 220},
    ),
    _row(
      type: ActivityType.sleep,
      startedAt: at(7, 25),
      endedAt: at(8, 0),
      payload: const {'place': '아기침대'},
    ),
    _row(
      type: ActivityType.sleep,
      startedAt: at(10, 9),
      endedAt: at(11, 8),
      payload: const {'place': '아기침대'},
    ),
    _row(
      type: ActivityType.formula,
      startedAt: at(11, 25),
      payload: const {'ml': 150},
    ),
  ];
}

List<ActivitiesCompanion> _daySeed(DateTime day, double recency, Random rnd) {
  final rows = <ActivitiesCompanion>[];
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  // 밤잠: 최근일수록 길고(≈5.7h→8h) 덜 끊긴다(최근 1구간, 과거 최대 3구간).
  final nightTotalMin = (340 + recency * 150).round();
  final segments = recency > 0.7 ? 1 : (recency > 0.35 ? 2 : 3);
  var cursor = at(21, 0).add(Duration(minutes: rnd.nextInt(60)));
  var remaining = nightTotalMin;
  for (var s = 0; s < segments; s++) {
    final isLast = s == segments - 1;
    final segMin = isLast
        ? remaining
        : (remaining / (segments - s) * (0.7 + rnd.nextDouble() * 0.6)).round();
    final start = cursor;
    final end = start.add(Duration(minutes: segMin.clamp(20, remaining)));
    rows.add(
      _row(
        type: ActivityType.sleep,
        startedAt: start,
        endedAt: end,
        payload: const {'place': '아기침대'},
      ),
    );
    remaining -= segMin;
    cursor = end.add(Duration(minutes: 10 + rnd.nextInt(20)));
    if (remaining <= 0) break;
  }

  // 낮잠: 오전 1회, 오후 1회.
  final morningNapStart = at(9, 30).add(Duration(minutes: rnd.nextInt(60)));
  rows.add(
    _row(
      type: ActivityType.sleep,
      startedAt: morningNapStart,
      endedAt: morningNapStart.add(Duration(minutes: 30 + rnd.nextInt(40))),
      payload: const {'place': '거실'},
    ),
  );

  final afternoonNapStart = at(14, 0).add(Duration(minutes: rnd.nextInt(90)));
  rows.add(
    _row(
      type: ActivityType.sleep,
      startedAt: afternoonNapStart,
      endedAt: afternoonNapStart.add(Duration(minutes: 40 + rnd.nextInt(50))),
      payload: const {'place': '거실'},
    ),
  );

  // 수유: 대략 2.5~3.5시간 간격, 분유/모유 섞어서.
  const formulaOptions = [120, 150, 150, 180, 200];
  var feedTime = at(6, 0).add(Duration(minutes: rnd.nextInt(40)));
  final feedingEnd = at(22, 30);
  while (!feedTime.isAfter(feedingEnd)) {
    if (rnd.nextBool()) {
      rows.add(
        _row(
          type: ActivityType.formula,
          startedAt: feedTime,
          payload: {'ml': formulaOptions[rnd.nextInt(formulaOptions.length)]},
        ),
      );
    } else {
      rows.add(
        _row(
          type: ActivityType.breast,
          startedAt: feedTime,
          endedAt: feedTime.add(Duration(minutes: 10 + rnd.nextInt(15))),
          payload: {'side': rnd.nextBool() ? 'left' : 'right'},
        ),
      );
    }
    feedTime = feedTime.add(Duration(hours: 2, minutes: 30 + rnd.nextInt(60)));
  }

  // 기저귀: 하루 5~7회, 약 30%는 대변 포함.
  final diaperCount = 5 + rnd.nextInt(3);
  for (var i = 0; i < diaperCount; i++) {
    final t = at(6, 0).add(
      Duration(minutes: (16 * 60 * i / diaperCount).round() + rnd.nextInt(30)),
    );
    final isPoop = rnd.nextDouble() < 0.3;
    rows.add(
      _row(
        type: ActivityType.diaper,
        startedAt: t,
        payload: isPoop
            ? const {'sub': 'poop', 'texture': '보통'}
            : const {'sub': 'pee'},
      ),
    );
  }

  // 이유식: 최근 날짜 위주로 점심 무렵 1회.
  if (recency > 0.3) {
    const foods = ['쌀미음', '고구마', '단호박', '사과', '바나나'];
    final noon = at(11, 0).add(Duration(minutes: rnd.nextInt(60)));
    rows.add(
      _row(
        type: ActivityType.solid,
        startedAt: noon,
        payload: {'food': foods[rnd.nextInt(foods.length)], 'amount': '대부분'},
      ),
    );
  }

  return rows;
}
