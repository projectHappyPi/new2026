import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/calendar_event.dart';
import '../data/repositories/event_repository.dart';
import '../data/sync/family_config.dart';
import 'activity_provider.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(
    ref.watch(databaseProvider),
    memberName: () => ref.read(familyConfigProvider).authorName,
  );
});

/// 달력 화면에서 보고 있는 달(1일 자정).
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 선택한 날(자정).
final calendarSelectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 월 그리드(앞뒤 주 포함 6주)에 걸친 일정.
final monthEventsProvider = StreamProvider.autoDispose
    .family<List<CalendarEvent>, DateTime>((ref, month) {
      final repo = ref.watch(eventRepositoryProvider);
      final (from, to) = monthGridRange(month);
      return repo.watchRange(from, to);
    });

/// 일요일 시작 6주 그리드의 [시작, 끝) 자정.
(DateTime, DateTime) monthGridRange(DateTime month) {
  final first = DateTime(month.year, month.month);
  final start = first.subtract(Duration(days: first.weekday % 7));
  return (start, DateTime(start.year, start.month, start.day + 42));
}
