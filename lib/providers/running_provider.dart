import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/models/activity.dart';
import 'activity_provider.dart';

/// 앱 전체에서 공유하는 단 하나의 1초 틱. 위젯마다 Timer를 만드는 대신
/// 이 provider 하나만 구독해 상태 헤더·실행 중 배지·배너와 12시간 자동 종료
/// 감시(autoEndGuardProvider)를 함께 갱신한다.
final nowTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// 진행 중인 range 활동(수면 또는 모유). 동시에 1건만 존재한다.
final runningActivityProvider = StreamProvider<Activity?>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchRunning();
});

/// 미종료 보호: 진행 중 기록이 12시간을 넘으면 자동 종료한다.
/// app_shell에서 한 번만 watch해 앱 전역에서 감시가 계속되게 한다.
final autoEndGuardProvider = Provider<void>((ref) {
  ref.listen(nowTickerProvider, (previous, next) async {
    final now = next.valueOrNull;
    if (now == null) return;
    final running = ref.read(runningActivityProvider).valueOrNull;
    if (running == null) return;
    if (now.difference(running.startedAt) >= RunningGuard.maxDuration) {
      final repo = ref.read(activityRepositoryProvider);
      await repo.update(
        running.copyWith(
          endedAt: () => now,
          payload: {...running.payload, 'autoEnded': true},
        ),
      );
    }
  });
});
