import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/activity_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';

/// 8.1 24시간 리듬 링. 0시가 12시 방향, 시계 방향으로 하루를 360도에 매핑한다.
/// range 항목(수면·모유)은 호로, instant 항목(분유·이유식·기저귀)은 점으로 그린다.
class RhythmRing extends StatelessWidget {
  static const double radius = 92;
  static const double strokeWidth = 14;

  final List<Activity> todayActivities;
  final DateTime day;

  const RhythmRing({
    super.key,
    required this.todayActivities,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activityColors = context.activityColors;
    final todayMl = todayActivities
        .where((a) => a.type == ActivityType.formula)
        .fold<int>(0, (sum, a) => sum + (a.ml ?? 0));

    return SizedBox(
      width: (radius + strokeWidth) * 2,
      height: (radius + strokeWidth) * 2,
      child: CustomPaint(
        painter: _RhythmRingPainter(
          activities: todayActivities,
          day: day,
          outlineColor: colors.outlineSoft,
          activityColors: activityColors,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${todayMl}ml',
                style: AppTypography.metricValue.tabular.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '오늘 수유',
                style: AppTypography.label.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RhythmRingPainter extends CustomPainter {
  final List<Activity> activities;
  final DateTime day;
  final Color outlineColor;
  final ActivityColors activityColors;

  _RhythmRingPainter({
    required this.activities,
    required this.day,
    required this.outlineColor,
    required this.activityColors,
  });

  double _angleForFraction(double t) => -pi / 2 + t * 2 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const r = RhythmRing.radius;
    const sw = RhythmRing.strokeWidth;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 배경 트랙
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    // 3시간 간격 눈금
    final tickPaint = Paint()
      ..color = outlineColor
      ..strokeWidth = 1;
    for (var h = 0; h < 24; h += 3) {
      final angle = _angleForFraction(h / 24);
      final inner = center + Offset(cos(angle), sin(angle)) * (r - sw / 2 - 4);
      final outer = center + Offset(cos(angle), sin(angle)) * (r + sw / 2 + 4);
      canvas.drawLine(inner, outer, tickPaint);
    }

    final rect = Rect.fromCircle(center: center, radius: r);

    for (final a in activities) {
      final color = activityColors.forActivity(a);
      if (a.type.isRange) {
        final start = a.startedAt.isAfter(dayStart) ? a.startedAt : dayStart;
        final end0 = a.endedAt ?? DateTime.now();
        final end = end0.isBefore(dayEnd) ? end0 : dayEnd;
        if (!end.isAfter(start)) continue;
        final startFrac =
            start.difference(dayStart).inSeconds /
            const Duration(days: 1).inSeconds;
        final endFrac =
            end.difference(dayStart).inSeconds /
            const Duration(days: 1).inSeconds;
        final startAngle = _angleForFraction(startFrac);
        final sweep = (endFrac - startFrac) * 2 * pi;
        canvas.drawArc(
          rect,
          startAngle,
          max(sweep, 0.03),
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap = StrokeCap.round,
        );
      } else {
        if (a.startedAt.isBefore(dayStart) || !a.startedAt.isBefore(dayEnd)) {
          continue;
        }
        final frac =
            a.startedAt.difference(dayStart).inSeconds /
            const Duration(days: 1).inSeconds;
        final angle = _angleForFraction(frac);
        final dot = center + Offset(cos(angle), sin(angle)) * r;
        canvas.drawCircle(dot, sw / 2 - 1, Paint()..color = color);
        canvas.drawCircle(
          dot,
          sw / 2 - 1,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RhythmRingPainter oldDelegate) =>
      oldDelegate.activities != activities || oldDelegate.day != day;
}
