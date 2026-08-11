import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';
import 'quick_button.dart';

/// index 0~2: 안쪽(야간용), 3~5: 바깥쪽(주간용). 5.2절 배치 순서.
const List<ActivityType> kThumbArcOrder = [
  ActivityType.formula,
  ActivityType.sleep,
  ActivityType.diaper,
  ActivityType.solid,
  ActivityType.breast,
];

/// 오른손 기준 좌표. 왼손이면 x를 반전한다.
Offset seatPosition(Size screen, int index, bool isRightHand) {
  final pivot = Offset(
    isRightHand
        ? screen.width - ThumbArc.pivotFromRight
        : ThumbArc.pivotFromRight,
    screen.height - ThumbArc.pivotFromBottom,
  );
  final radius = index < 3 ? ThumbArc.innerRadius : ThumbArc.outerRadius;
  final angleDeg = ThumbArc.angles[index % 3];
  final rad = angleDeg * pi / 180;
  final dx = radius * cos(rad) * (isRightHand ? 1 : -1);
  final dy = -radius * sin(rad);
  return pivot + Offset(dx, dy);
}

/// 홈 화면의 정체성. 엄지 회전 궤적을 실제로 계산해 6개 버튼(분유·수면·기저귀·
/// 이유식·모유·버튼 구성 편집)을 배치한다. 궤적 가이드선은 장식이 아니라 배치
/// 논리를 보여주는 요소이므로 뺴지 않는다.
class ThumbArcLayout extends StatelessWidget {
  final bool isRightHand;
  final Activity? running;
  final ActivityType? justSavedType;
  final Map<ActivityType, String> valuePreviews;
  final bool nightModeActive;
  final void Function(ActivityType type) onShortTap;
  final void Function(ActivityType type) onLongPress;
  final VoidCallback onEditButtons;

  const ThumbArcLayout({
    super.key,
    required this.isRightHand,
    required this.running,
    required this.justSavedType,
    required this.valuePreviews,
    required this.onShortTap,
    required this.onLongPress,
    required this.onEditButtons,
    this.nightModeActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pivot = Offset(
          isRightHand
              ? size.width - ThumbArc.pivotFromRight
              : ThumbArc.pivotFromRight,
          size.height - ThumbArc.pivotFromBottom,
        );

        final buttons = <Widget>[];
        for (var i = 0; i < kThumbArcOrder.length; i++) {
          final type = kThumbArcOrder[i];
          final pos = seatPosition(size, i, isRightHand);
          final isRunning = running != null && running!.type == type;
          buttons.add(
            Positioned(
              left: pos.dx - ThumbArc.buttonSize / 2,
              top: pos.dy - ThumbArc.buttonSize / 2,
              child: QuickButton(
                type: type,
                valuePreview: valuePreviews[type],
                isRunning: isRunning,
                runningElapsed: isRunning ? running!.elapsed() : Duration.zero,
                justSaved: justSavedType == type,
                nightModeActive: nightModeActive,
                onTap: () => onShortTap(type),
                onLongPress: () => onLongPress(type),
              ),
            ),
          );
        }

        final editPos = seatPosition(size, 5, isRightHand);
        buttons.add(
          Positioned(
            left: editPos.dx - ThumbArc.buttonSize / 2,
            top: editPos.dy - ThumbArc.buttonSize / 2,
            child: EditButtonsButton(onTap: onEditButtons),
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ArcGuidePainter(
                  pivot: pivot,
                  isRightHand: isRightHand,
                  color: colors.outlineSoft,
                ),
              ),
            ),
            ...buttons,
          ],
        );
      },
    );
  }
}

/// 두 반지름을 따라 점선 호를 그리고 피벗에 점을 찍는다. 장식이 아니라
/// 버튼이 왜 이 자리에 있는지(엄지 회전 궤적) 눈에 보이게 하는 요소.
class _ArcGuidePainter extends CustomPainter {
  final Offset pivot;
  final bool isRightHand;
  final Color color;

  _ArcGuidePainter({
    required this.pivot,
    required this.isRightHand,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final startAngle = ThumbArc.angles.first;
    final endAngle = ThumbArc.angles.last;

    for (final radius in [ThumbArc.innerRadius, ThumbArc.outerRadius]) {
      final path = _arcPath(pivot, radius, startAngle, endAngle, isRightHand);
      canvas.drawPath(_dashPath(path, dashWidth: 2, dashGap: 5), paint);
    }

    canvas.drawCircle(pivot, 2.5, Paint()..color = color);
  }

  Path _arcPath(
    Offset center,
    double radius,
    double fromDeg,
    double toDeg,
    bool isRightHand,
  ) {
    final path = Path();
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final deg = fromDeg + (toDeg - fromDeg) * i / steps;
      final rad = deg * pi / 180;
      final dx = radius * cos(rad) * (isRightHand ? 1 : -1);
      final dy = -radius * sin(rad);
      final p = center + Offset(dx, dy);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  Path _dashPath(
    Path source, {
    required double dashWidth,
    required double dashGap,
  }) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashGap;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, min(distance + len, metric.length)),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _ArcGuidePainter oldDelegate) =>
      oldDelegate.pivot != pivot ||
      oldDelegate.isRightHand != isRightHand ||
      oldDelegate.color != color;
}
