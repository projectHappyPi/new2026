import 'package:flutter/material.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';
import 'quick_button.dart';
import 'thumb_arc_layout.dart' show kThumbArcOrder;

/// 한손 모드 OFF일 때: 궤적 대신 3열 그리드.
class GridLayout extends StatelessWidget {
  final Activity? running;
  final ActivityType? justSavedType;
  final Map<ActivityType, String> valuePreviews;
  final void Function(ActivityType type) onShortTap;
  final void Function(ActivityType type) onLongPress;
  final VoidCallback onEditButtons;

  const GridLayout({
    super.key,
    required this.running,
    required this.justSavedType,
    required this.valuePreviews,
    required this.onShortTap,
    required this.onLongPress,
    required this.onEditButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final type in kThumbArcOrder)
            Center(
              child: Builder(
                builder: (context) {
                  final isRunning = running != null && running!.type == type;
                  return QuickButton(
                    type: type,
                    valuePreview: valuePreviews[type],
                    isRunning: isRunning,
                    runningElapsed: isRunning
                        ? running!.elapsed()
                        : Duration.zero,
                    justSaved: justSavedType == type,
                    onTap: () => onShortTap(type),
                    onLongPress: () => onLongPress(type),
                  );
                },
              ),
            ),
          Center(child: EditButtonsButton(onTap: onEditButtons)),
        ],
      ),
    );
  }
}
