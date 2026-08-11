import 'package:flutter/material.dart';

import '../../../core/theme/activity_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/time_format.dart';
import '../../../data/models/activity_type.dart';

IconData iconForType(ActivityType type) => switch (type) {
  ActivityType.formula => Icons.local_drink_rounded,
  ActivityType.breast => Icons.favorite_rounded,
  ActivityType.sleep => Icons.bedtime_rounded,
  ActivityType.solid => Icons.restaurant_rounded,
  ActivityType.diaper => Icons.child_care_rounded,
};

/// 엄지 궤적/그리드 공통으로 쓰는 원형 버튼.
/// 저장 전에 무엇이 기록될지 보여주기 위해 라벨 아래 예상 값을 함께 표시한다.
class QuickButton extends StatelessWidget {
  final ActivityType type;
  final String? valuePreview;
  final bool isRunning;
  final Duration runningElapsed;
  final bool justSaved;
  final double size;
  final bool nightModeActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const QuickButton({
    super.key,
    required this.type,
    required this.valuePreview,
    required this.isRunning,
    required this.runningElapsed,
    required this.justSaved,
    required this.onTap,
    required this.onLongPress,
    this.size = 64,
    this.nightModeActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activityColors = context.activityColors;
    final activityColor = activityColors.forType(type);
    // 야간 저자극 모드에서는 버튼을 1.2배 키운다.
    final effectiveSize = nightModeActive ? size * 1.2 : size;

    Color bg = colors.surfaceVariant;
    Color border = colors.outline;
    if (isRunning) {
      bg = activityColor.withValues(alpha: 0.28);
      border = activityColor;
    } else if (justSaved) {
      bg = activityColor.withValues(alpha: 0.2);
      border = activityColor;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: nightModeActive
                ? Duration.zero
                : const Duration(milliseconds: 150),
            width: effectiveSize,
            height: effectiveSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(
                color: border,
                width: isRunning || justSaved ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: isRunning
                ? Text(
                    dur(runningElapsed),
                    style: AppTypography.mono.tabular.copyWith(
                      color: colors.onSurface,
                    ),
                  )
                : Icon(
                    justSaved ? Icons.check_rounded : iconForType(type),
                    color: justSaved ? activityColor : colors.onSurface,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            type.label,
            style: AppTypography.label.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          if (!isRunning && valuePreview != null && valuePreview!.isNotEmpty)
            Text(
              valuePreview!,
              style: AppTypography.monoSmall.tabular.copyWith(
                color: colors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

/// index 5: 버튼 구성 편집. 가장 손이 안 닿는 자리에 둔다.
class EditButtonsButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const EditButtonsButton({super.key, required this.onTap, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceVariant,
          border: Border.all(color: colors.outline),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.add_rounded,
          color: colors.onSurfaceVariant,
          size: 22,
        ),
      ),
    );
  }
}
