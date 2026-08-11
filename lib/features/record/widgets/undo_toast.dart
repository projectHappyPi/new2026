import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/time_format.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';

/// 5.5: 저장 직후 5초간 뜨는 실행 취소 토스트. 기본 SnackBar는 여백·타이포를
/// 맞추기 어려워 직접 구현한다.
class UndoToast extends StatelessWidget {
  final Activity activity;
  final VoidCallback onEdit;
  final VoidCallback onUndo;

  const UndoToast({
    super.key,
    required this.activity,
    required this.onEdit,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = activity.summary;
    final label = summary.isEmpty
        ? activity.type.label
        : '${activity.type.label} $summary';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${hm(activity.startedAt)} $label',
                style: AppTypography.body.tabular.copyWith(
                  color: colors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              child: const Text('수정'),
            ),
            TextButton(
              onPressed: onUndo,
              style: TextButton.styleFrom(foregroundColor: colors.onSurface),
              child: const Text(
                '취소',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
