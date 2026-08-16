import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/activity_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/time_format.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';
import '../../../providers/running_provider.dart';
import 'quick_button.dart';

/// 5.1: 진행 중일 때만 헤더 아래 나타나는 배너. "종료" 버튼 제공.
class RunningBanner extends ConsumerWidget {
  final Activity running;
  final VoidCallback onEnd;

  const RunningBanner({super.key, required this.running, required this.onEnd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final color = context.activityColors.forActivity(running);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final elapsed = running.elapsed(now);
    final periodSuffix = running.sleepPeriod != null
        ? ' · ${running.sleepPeriod!.label}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(iconForType(running.type), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${running.type.label}$periodSuffix 기록 중  ${dur(elapsed)}',
              style: AppTypography.body.tabular.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onEnd,
            style: TextButton.styleFrom(foregroundColor: color),
            child: const Text(
              '종료',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
