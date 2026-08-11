import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/db/database.dart';
import '../data/models/activity.dart';
import '../data/models/activity_type.dart';
import '../data/models/settings.dart';
import '../data/repositories/activity_repository.dart';
import 'settings_provider.dart';

/// main()에서 초기화한 인스턴스로 override 된다.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('main()에서 override 되어야 합니다');
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return DriftActivityRepository(ref.watch(databaseProvider));
});

/// 오늘 기록. 홈 화면의 오늘 합계 3분할 지표에 쓰인다.
final todayActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchByDay(DateTime.now());
});

/// 최근 3일. 마지막 수유 경과시간·다음 수유 예측·버튼 라벨(마지막 값)에 쓰인다.
/// 자정을 막 넘겼을 때도 어제 마지막 기록을 찾을 수 있도록 여유를 둔다.
final recentActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  final now = DateTime.now();
  final from = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 2));
  final to = now.add(const Duration(days: 1));
  return repo.watchRange(from, to);
});

/// 타임라인: 최근 7일.
final timelineActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(const Duration(days: 6));
  final to = today.add(const Duration(days: 1));
  return repo.watchRange(from, to);
});

/// 패턴: 최근 14일(히트맵 14줄).
final patternActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(const Duration(days: 13));
  final to = today.add(const Duration(days: 1));
  return repo.watchRange(from, to);
});

/// 이유식 시트의 "최근 사용한 식재료" 칩.
final recentFoodsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.recentFoods();
});

/// 목록에서 특정 유형의 가장 최근 값을 찾는다(가장 최근 것이 앞에 온다는 가정, 즉 startedAt desc 정렬 목록에 사용).
Activity? lastOfType(List<Activity> activities, ActivityType type) {
  for (final a in activities) {
    if (a.type == type && a.deletedAt == null) return a;
  }
  return null;
}

int _circularHourDiff(int a, int b) {
  final d = (a - b).abs();
  return d > 12 ? 24 - d : d;
}

/// 기록 생성·수정·삭제. UI는 이 클래스만 통해 쓰기 작업을 수행한다.
/// range 항목의 시작/종료 여부 판단은 화면(quick_button)이 runningActivityProvider를
/// 보고 결정하므로, 여기서는 순수 CRUD만 다뤄 provider 간 순환 의존을 피한다.
class ActivityActions {
  final Ref ref;
  ActivityActions(this.ref);

  ActivityRepository get _repo => ref.read(activityRepositoryProvider);

  /// 짧은 탭 저장(instant 유형 전용): 설정에서 정한 기본값으로 즉시 기록한다.
  Future<Activity> quickSaveInstant(ActivityType type) async {
    assert(!type.isRange);
    final payload = await _defaultPayload(type);
    final now = DateTime.now();
    return _repo.create(
      Activity(
        id: '',
        type: type,
        startedAt: now,
        payload: payload,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// range 유형 시작(짧은 탭 또는 상세 시트의 "시작 시각" 칩에서 호출).
  Future<Activity> startRange(
    ActivityType type, {
    DateTime? startedAt,
    Map<String, dynamic> payload = const {},
  }) async {
    assert(type.isRange);
    final now = DateTime.now();
    return _repo.create(
      Activity(
        id: '',
        type: type,
        startedAt: startedAt ?? now,
        payload: payload,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// range 유형 종료(진행 중인 항목을 다시 탭했을 때).
  Future<Activity> endRunning(Activity running) async {
    final ended = running.copyWith(endedAt: () => DateTime.now());
    await _repo.update(ended);
    return ended;
  }

  /// 상세 입력 시트 저장(신규).
  Future<Activity> createDetailed({
    required ActivityType type,
    required DateTime startedAt,
    DateTime? endedAt,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    return _repo.create(
      Activity(
        id: '',
        type: type,
        startedAt: startedAt,
        endedAt: endedAt,
        payload: payload,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// 상세 입력 시트 저장(기존 기록 수정).
  Future<void> updateActivity(Activity a) => _repo.update(a);

  /// 실행 취소 토스트의 "취소": soft delete.
  Future<void> undo(String id) => _repo.softDelete(id);

  /// 상세 시트에서 슬라이더 초기값으로 쓰는 분유 기본 용량.
  Future<int> defaultFormulaMl() =>
      _defaultFormulaMl(ref.read(settingsProvider));

  Future<Map<String, dynamic>> _defaultPayload(ActivityType type) async {
    final settings = ref.read(settingsProvider);
    switch (type) {
      case ActivityType.formula:
        return {'ml': await _defaultFormulaMl(settings)};
      case ActivityType.diaper:
        return settings.diaperDefaultSub == DiaperDefaultSub.poop
            ? {'sub': 'poop', 'texture': DiaperTextures.defaultTexture}
            : {'sub': 'pee'};
      case ActivityType.solid:
        final recentFoods = ref.read(recentFoodsProvider).valueOrNull ?? [];
        final food = recentFoods.isNotEmpty
            ? recentFoods.first
            : SolidDefaults.foods.first;
        return {'food': food, 'amount': '대부분'};
      case ActivityType.breast:
      case ActivityType.sleep:
        return {};
    }
  }

  /// 9.3 용량 결정 방식: 고정값 / 최근값 / 시간대별(최근 7일 ±2h 최빈값, 3건 미만이면 고정값).
  Future<int> _defaultFormulaMl(Settings settings) async {
    switch (settings.formulaMode) {
      case FormulaMode.fixed:
        return settings.formulaDefaultMl;
      case FormulaMode.recent:
        final last = await _repo.lastOf(ActivityType.formula);
        return last?.ml ?? settings.formulaDefaultMl;
      case FormulaMode.timeOfDay:
        final now = DateTime.now();
        final recent = ref.read(patternActivitiesProvider).valueOrNull ?? [];
        final weekAgo = now.subtract(const Duration(days: 7));
        final windowed = recent
            .where(
              (a) =>
                  a.type == ActivityType.formula &&
                  a.deletedAt == null &&
                  a.startedAt.isAfter(weekAgo) &&
                  _circularHourDiff(a.startedAt.hour, now.hour) <= 2,
            )
            .map((a) => a.ml)
            .whereType<int>()
            .toList();
        if (windowed.length < 3) return settings.formulaDefaultMl;
        final freq = <int, int>{};
        for (final ml in windowed) {
          freq[ml] = (freq[ml] ?? 0) + 1;
        }
        var bestMl = settings.formulaDefaultMl;
        var bestCount = 0;
        for (final entry in freq.entries) {
          if (entry.value > bestCount) {
            bestCount = entry.value;
            bestMl = entry.key;
          }
        }
        return bestMl;
    }
  }
}

final activityActionsProvider = Provider<ActivityActions>((ref) {
  return ActivityActions(ref);
});
