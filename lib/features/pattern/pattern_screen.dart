import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/activity_colors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/activity_provider.dart';
import 'widgets/rhythm_ring.dart';
import 'widgets/sleep_heatmap.dart';

/// 8절 패턴 화면. 리듬 링·히트맵 모두 보는 용도라 인터랙션(탭·확대)은 넣지 않는다.
class PatternScreen extends ConsumerWidget {
  const PatternScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(patternActivitiesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          '패턴',
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
          final today = DateTime.now();
          final todayStart = DateTime(today.year, today.month, today.day);
          final todayActivities = all
              .where((a) => !a.startedAt.isBefore(todayStart))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Text(
                '24시간 리듬',
                style: AppTypography.label.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: RhythmRing(todayActivities: todayActivities, day: today),
              ),
              const SizedBox(height: 12),
              _Legend(colors: colors),
              const SizedBox(height: 40),
              Text(
                '수면 히트맵 (14일)',
                style: AppTypography.label.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SleepHeatmap(activities: all, today: today),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final AppColors colors;

  const _Legend({required this.colors});

  @override
  Widget build(BuildContext context) {
    final activityColors = context.activityColors;
    final entries = <(String, Color)>[
      ('분유', activityColors.formula),
      ('모유', activityColors.breast),
      ('수면', activityColors.sleep),
      ('이유식', activityColors.solid),
      ('소변', activityColors.pee),
      ('대변', activityColors.poop),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: e.$2, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                e.$1,
                style: AppTypography.monoSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
