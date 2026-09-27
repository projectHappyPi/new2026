import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../data/models/calendar_event.dart';
import '../../data/sync/sync_service.dart';
import '../../providers/event_provider.dart';
import 'event_sheet.dart';

const _kSunday = Color(0xFFE0685A);
const _kSaturday = Color(0xFF5B8FD9);

/// 가족 달력. 타임트리처럼 월 그리드에 일정 막대를 보여주고, 날을 누르면
/// 아래에 그날 일정 목록이 나온다. 일정은 가족 공유(동기화)로 상대 폰에도 뜬다.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final month = ref.watch(calendarMonthProvider);
    final selected = ref.watch(calendarSelectedDayProvider);
    final events =
        ref.watch(monthEventsProvider(month)).valueOrNull ??
        const <CalendarEvent>[];
    final sync = ref.watch(syncStatusProvider);

    void goMonth(int delta) {
      ref.read(calendarMonthProvider.notifier).state = DateTime(
        month.year,
        month.month + delta,
      );
    }

    final dayEvents = events.where((e) => e.occursOn(selected)).toList();

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.onSurface,
        foregroundColor: colors.background,
        onPressed: () => showEventSheet(context, day: selected),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    '${month.year}년 ${month.month}월',
                    style: AppTypography.title.copyWith(
                      color: colors.onSurface,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (sync.error != null)
                    Tooltip(
                      message: sync.error!,
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 16,
                        color: colors.muted,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final now = DateTime.now();
                      ref.read(calendarMonthProvider.notifier).state =
                          DateTime(now.year, now.month);
                      ref.read(calendarSelectedDayProvider.notifier).state =
                          DateTime(now.year, now.month, now.day);
                    },
                    child: const Text('오늘'),
                  ),
                  IconButton(
                    tooltip: '이전 달',
                    onPressed: () => goMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    onPressed: () => goMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            _WeekdayRow(),
            GestureDetector(
              // 좌우로 밀어 달 이동
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 200) return;
                goMonth(v < 0 ? 1 : -1);
              },
              child: _MonthGrid(
                month: month,
                selected: selected,
                events: events,
                onTap: (day) {
                  ref.read(calendarSelectedDayProvider.notifier).state = day;
                  if (day.month != month.month) {
                    ref.read(calendarMonthProvider.notifier).state = DateTime(
                      day.year,
                      day.month,
                    );
                  }
                },
                onLongPress: (day) => showEventSheet(context, day: day),
              ),
            ),
            Divider(height: 1, color: colors.outlineSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                dayHeader(selected),
                style: AppTypography.body.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: dayEvents.isEmpty
                  ? Center(
                      child: Text(
                        '일정이 없어요 · + 로 추가',
                        style: AppTypography.body.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final e in dayEvents) _EventTile(event: e),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const names = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  names[i],
                  style: AppTypography.label.copyWith(
                    color: i == 0
                        ? _kSunday
                        : i == 6
                        ? _kSaturday
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime> onLongPress;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.onTap,
    required this.onLongPress,
  });

  static const _maxBars = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (start, _) = monthGridRange(month);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (var w = 0; w < 6; w++)
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = DateTime(
                            start.year,
                            start.month,
                            start.day + w * 7 + d,
                          );
                          final inMonth = day.month == month.month;
                          final isSel = day == selected;
                          final isToday = day == today;
                          final todays = events
                              .where((e) => e.occursOn(day))
                              .toList();
                          final numColor = d == 0
                              ? _kSunday
                              : d == 6
                              ? _kSaturday
                              : colors.onSurface;
                          return InkWell(
                            onTap: () => onTap(day),
                            onLongPress: () => onLongPress(day),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSel
                                    ? colors.onSurface.withValues(alpha: 0.07)
                                    : null,
                                border: Border(
                                  top: BorderSide(color: colors.outlineSoft),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(2, 3, 2, 0),
                              child: Opacity(
                                opacity: inMonth ? 1 : 0.35,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 20,
                                        height: 18,
                                        alignment: Alignment.center,
                                        decoration: isToday
                                            ? BoxDecoration(
                                                color: numColor,
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              )
                                            : null,
                                        child: Text(
                                          '${day.day}',
                                          style: AppTypography.monoSmall
                                              .copyWith(
                                                fontSize: 11,
                                                color: isToday
                                                    ? colors.background
                                                    : numColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    for (final e in todays.take(_maxBars))
                                      _Bar(event: e),
                                    if (todays.length > _maxBars)
                                      Text(
                                        '+${todays.length - _maxBars}',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.monoSmall.copyWith(
                                          fontSize: 9,
                                          color: colors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final CalendarEvent event;
  const _Bar({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = event.color.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      height: 13,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: const TextStyle(
          fontSize: 9,
          height: 1.4,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = event.allDay
        ? '종일'
        : event.endAt != null && event.endAt != event.startAt
        ? '${hm(event.startAt)}–${hm(event.endAt!)}'
        : hm(event.startAt);
    final author = switch (event.createdBy) {
      'me' => '나',
      final s => s,
    };
    return InkWell(
      onTap: () => showEventSheet(context, editing: event),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                time,
                style: AppTypography.mono.tabular.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: event.color.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.body.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (event.memo != null && event.memo!.isNotEmpty)
                    Text(
                      event.memo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(color: colors.muted),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                author,
                style: AppTypography.monoSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
