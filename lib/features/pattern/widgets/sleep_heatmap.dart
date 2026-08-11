import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/activity_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';

double _overlapFraction(
  List<Activity> sleeps,
  DateTime cellStart,
  Duration cellLen,
) {
  final cellEnd = cellStart.add(cellLen);
  var overlap = Duration.zero;
  for (final a in sleeps) {
    final s = a.startedAt;
    final e = a.endedAt ?? DateTime.now();
    final os = s.isAfter(cellStart) ? s : cellStart;
    final oe = e.isBefore(cellEnd) ? e : cellEnd;
    if (oe.isAfter(os)) overlap += oe.difference(os);
  }
  final frac = overlap.inMilliseconds / cellLen.inMilliseconds;
  return frac.clamp(0.0, 1.0);
}

/// 8.2 수면 히트맵. 가로 24칸(시간) × 세로 14줄(일). 인터랙션은 없다(보는 것만으로 충분).
class SleepHeatmap extends StatelessWidget {
  final List<Activity> activities;
  final DateTime today;

  const SleepHeatmap({
    super.key,
    required this.activities,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sleepColor = context.activityColors.sleep;
    final sleeps = activities
        .where((a) => a.type == ActivityType.sleep)
        .toList();
    final todayStart = DateTime(today.year, today.month, today.day);
    final days = List.generate(
      PatternWindow.heatmapDays,
      (i) => todayStart.subtract(
        Duration(days: PatternWindow.heatmapDays - 1 - i),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 4, right: 2),
          child: Row(
            children: [
              for (final h in const [0, 6, 12, 18, 24])
                Expanded(
                  child: Text(
                    '$h',
                    style: AppTypography.monoSmall.tabular.copyWith(
                      color: colors.muted,
                    ),
                    textAlign: h == 0
                        ? TextAlign.left
                        : (h == 24 ? TextAlign.right : TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1.7,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${d.day}',
                            style: AppTypography.monoSmall.tabular.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 24,
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 1,
                  ),
                  itemCount: 24 * days.length,
                  itemBuilder: (context, index) {
                    final row = index ~/ 24;
                    final hour = index % 24;
                    final day = days[row];
                    final cellStart = DateTime(
                      day.year,
                      day.month,
                      day.day,
                      hour,
                    );
                    final frac = _overlapFraction(
                      sleeps,
                      cellStart,
                      const Duration(hours: 1),
                    );
                    final color = frac <= 0
                        ? colors.outlineSoft
                        : sleepColor.withValues(alpha: 0.15 + frac * 0.85);
                    return ColoredBox(color: color);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
