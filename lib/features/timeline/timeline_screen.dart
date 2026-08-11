import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/activity_colors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../data/models/activity.dart';
import '../../data/models/activity_type.dart';
import '../../data/models/settings.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';
import '../record/detail_sheet.dart';

/// 7절 타임라인. 최근 7일(timelineActivitiesProvider)만 로드한다. 무한 스크롤은 다음 단계.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(timelineActivitiesProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          '타임라인',
          style: AppTypography.title.copyWith(color: colors.onSurface),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            '오류가 발생했습니다',
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return Center(
              child: Text(
                '아직 기록이 없어요',
                style: AppTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          }
          final grouped = _groupByDay(all);
          final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final day = days[i];
              final items = grouped[day]!;
              return _DaySection(day: day, items: items, settings: settings);
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<Activity>> _groupByDay(List<Activity> all) {
    final map = <DateTime, List<Activity>>{};
    for (final a in all) {
      final day = DateTime(
        a.startedAt.year,
        a.startedAt.month,
        a.startedAt.day,
      );
      map.putIfAbsent(day, () => []).add(a);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
        return b.startedAt.compareTo(a.startedAt);
      });
    }
    return map;
  }
}

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<Activity> items;
  final Settings settings;

  const _DaySection({
    required this.day,
    required this.items,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ml = items
        .where((a) => a.type == ActivityType.formula)
        .fold<int>(0, (sum, a) => sum + (a.ml ?? 0));
    final sleep = items
        .where((a) => a.type == ActivityType.sleep)
        .fold<Duration>(Duration.zero, (sum, a) => sum + a.elapsed());
    final diaperCount = items
        .where((a) => a.type == ActivityType.diaper)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayHeader(day),
                style: AppTypography.body.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${ml}ml · ${durMin(sleep)} · 기저귀 $diaperCount',
                style: AppTypography.monoSmall.tabular.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineSoft),
        for (final a in items) _TimelineRow(activity: a, settings: settings),
      ],
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  final Activity activity;
  final Settings settings;

  const _TimelineRow({required this.activity, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final color = context.activityColors.forActivity(activity);
    final dismissDirection = settings.isRightHand
        ? DismissDirection.endToStart
        : DismissDirection.startToEnd;

    return Dismissible(
      key: ValueKey(activity.id),
      direction: dismissDirection,
      background: _dismissBackground(
        context,
        alignRight: !settings.isRightHand,
      ),
      onDismissed: (_) async {
        await ref.read(activityActionsProvider).undo(activity.id);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('삭제됨')));
        }
      },
      child: InkWell(
        onTap: () =>
            showDetailSheet(context, type: activity.type, editing: activity),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  hm(activity.startedAt),
                  style: AppTypography.mono.tabular.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 3, height: 32, child: ColoredBox(color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          activity.type.label,
                          style: AppTypography.body.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (activity.summary.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            activity.summary,
                            style: AppTypography.body.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (activity.isRunning) ...[
                          const SizedBox(width: 8),
                          _Badge(text: '진행 중', color: color),
                        ],
                        if (activity.autoEnded) ...[
                          const SizedBox(width: 8),
                          const _Badge(text: '자동 종료', color: Color(0xFFCC8B3C)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                activity.createdBy == 'me' ? '나' : activity.createdBy,
                style: AppTypography.monoSmall.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dismissBackground(BuildContext context, {required bool alignRight}) {
    final colors = context.colors;
    return Container(
      color: colors.surfaceVariant,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(Icons.delete_outline_rounded, color: colors.onSurfaceVariant),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: AppTypography.monoSmall.copyWith(color: color)),
    );
  }
}
