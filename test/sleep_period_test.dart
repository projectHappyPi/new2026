import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/data/models/activity_type.dart';

void main() {
  group('defaultSleepPeriod', () {
    test('18시 이전은 낮잠', () {
      expect(
        defaultSleepPeriod(DateTime(2026, 8, 16, 17, 59)),
        SleepPeriod.nap,
      );
      expect(defaultSleepPeriod(DateTime(2026, 8, 16, 3, 0)), SleepPeriod.nap);
    });

    test('18~20시(애매한 구간)의 기본값은 낮잠', () {
      expect(defaultSleepPeriod(DateTime(2026, 8, 16, 18, 0)), SleepPeriod.nap);
      expect(
        defaultSleepPeriod(DateTime(2026, 8, 16, 19, 59)),
        SleepPeriod.nap,
      );
    });

    test('20시 이후는 무조건 밤잠', () {
      expect(
        defaultSleepPeriod(DateTime(2026, 8, 16, 20, 0)),
        SleepPeriod.night,
      );
      expect(
        defaultSleepPeriod(DateTime(2026, 8, 16, 23, 30)),
        SleepPeriod.night,
      );
    });
  });

  group('isAmbiguousSleepWindow', () {
    test('18시~20시 미만만 애매한 구간이다', () {
      expect(isAmbiguousSleepWindow(DateTime(2026, 8, 16, 17, 59)), isFalse);
      expect(isAmbiguousSleepWindow(DateTime(2026, 8, 16, 18, 0)), isTrue);
      expect(isAmbiguousSleepWindow(DateTime(2026, 8, 16, 19, 59)), isTrue);
      expect(isAmbiguousSleepWindow(DateTime(2026, 8, 16, 20, 0)), isFalse);
    });
  });
}
