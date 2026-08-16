import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/core/time/time_format.dart';

void main() {
  group('monthsAndDaysSince', () {
    test('한 달이 안 됐으면 0개월', () {
      final (months, days) = monthsAndDaysSince(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 11),
      );
      expect(months, 0);
      expect(days, 10);
    });

    test('개월 수와 남은 일수를 계산한다', () {
      final (months, days) = monthsAndDaysSince(
        DateTime(2025, 12, 1),
        DateTime(2026, 8, 11),
      );
      expect(months, 8);
      expect(days, 10);
    });

    test('말일 생일도 짧은 달을 건너뛰며 올바르게 계산한다(1/31생, 3/2 기준)', () {
      final (months, days) = monthsAndDaysSince(
        DateTime(2026, 1, 31),
        DateTime(2026, 3, 2),
      );
      expect(months, 1);
      expect(days, 2);
    });
  });

  group('babyAgeLabel', () {
    test('0개월이면 "일"만 표시한다', () {
      expect(
        babyAgeLabel(DateTime(2026, 8, 1), DateTime(2026, 8, 11)),
        'D+10 (10일)',
      );
    });

    test('개월 수가 있으면 "N개월 M일"을 표시한다', () {
      expect(
        babyAgeLabel(DateTime(2025, 12, 1), DateTime(2026, 8, 11)),
        'D+253 (8개월 10일)',
      );
    });
  });
}
