import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/activity.dart';
import '../../data/models/activity_type.dart';
import '../../data/models/settings.dart';
import '../../providers/activity_provider.dart';
import '../../providers/running_provider.dart';
import '../../providers/settings_provider.dart';
import 'detail_sheet.dart';
import 'widgets/grid_layout.dart';
import 'widgets/running_banner.dart';
import 'widgets/status_header.dart';
import 'widgets/thumb_arc_layout.dart';
import 'widgets/undo_toast.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  Activity? _pendingUndo;
  Timer? _undoTimer;
  ActivityType? _justSavedType;
  Timer? _checkTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  void _showSavedCheckmark(ActivityType type) {
    _checkTimer?.cancel();
    setState(() => _justSavedType = type);
    _checkTimer = Timer(SavedCheckmark.visibleDuration, () {
      if (mounted) setState(() => _justSavedType = null);
    });
  }

  void _showUndoToast(Activity a) {
    _undoTimer?.cancel();
    setState(() => _pendingUndo = a);
    _undoTimer = Timer(UndoToastTiming.visibleDuration, () {
      if (mounted) setState(() => _pendingUndo = null);
    });
  }

  Future<void> _handleShortTap(ActivityType type) async {
    final actions = ref.read(activityActionsProvider);
    late final Activity saved;
    if (type.isRange) {
      final running = ref.read(runningActivityProvider).valueOrNull;
      if (running != null && running.type == type) {
        saved = await actions.endRunning(running);
      } else {
        saved = await actions.startRange(type);
      }
    } else {
      saved = await actions.quickSaveInstant(type);
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _showSavedCheckmark(type);
    _showUndoToast(saved);
  }

  Future<void> _handleLongPress(ActivityType type) async {
    final saved = await showDetailSheet(context, type: type);
    if (saved == null || !mounted) return;
    HapticFeedback.mediumImpact();
    _showUndoToast(saved);
  }

  Future<void> _undo() async {
    final a = _pendingUndo;
    if (a == null) return;
    _undoTimer?.cancel();
    setState(() => _pendingUndo = null);
    await ref.read(activityActionsProvider).undo(a.id);
  }

  Future<void> _editPending() async {
    final a = _pendingUndo;
    if (a == null) return;
    _undoTimer?.cancel();
    setState(() => _pendingUndo = null);
    if (!mounted) return;
    await showDetailSheet(context, type: a.type, editing: a);
  }

  void _onEditButtons() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('버튼 구성 편집은 다음 업데이트에서 제공됩니다')));
  }

  Map<ActivityType, String> _valuePreviews(
    Settings settings,
    List<Activity> recent,
    List<String> recentFoods,
  ) {
    final lastFormula = lastOfType(recent, ActivityType.formula);
    final formulaPreview = settings.formulaMode == FormulaMode.fixed
        ? '${settings.formulaDefaultMl}ml'
        : '${lastFormula?.ml ?? settings.formulaDefaultMl}ml';
    final diaperPreview = settings.diaperDefaultSub == DiaperDefaultSub.poop
        ? '대변'
        : '소변';
    final solidFood = recentFoods.isNotEmpty
        ? recentFoods.first
        : SolidDefaults.foods.first;
    return {
      ActivityType.formula: formulaPreview,
      ActivityType.diaper: diaperPreview,
      ActivityType.solid: solidFood,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = ref.watch(settingsProvider);
    final running = ref.watch(runningActivityProvider).valueOrNull;
    final recent =
        ref.watch(recentActivitiesProvider).valueOrNull ?? const <Activity>[];
    final recentFoods =
        ref.watch(recentFoodsProvider).valueOrNull ?? const <String>[];
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final nightModeActive = isNightModeActive(settings, now);
    final previews = _valuePreviews(settings, recent, recentFoods);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: StatusHeader(),
                ),
                if (running != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: RunningBanner(
                      running: running,
                      onEnd: () => _handleShortTap(running.type),
                    ),
                  ),
                Expanded(
                  child: settings.oneHandMode
                      ? ThumbArcLayout(
                          isRightHand: settings.isRightHand,
                          running: running,
                          justSavedType: _justSavedType,
                          valuePreviews: previews,
                          nightModeActive: nightModeActive,
                          onShortTap: _handleShortTap,
                          onLongPress: _handleLongPress,
                          onEditButtons: _onEditButtons,
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: GridLayout(
                              running: running,
                              justSavedType: _justSavedType,
                              valuePreviews: previews,
                              onShortTap: _handleShortTap,
                              onLongPress: _handleLongPress,
                              onEditButtons: _onEditButtons,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (_pendingUndo != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 8,
                child: UndoToast(
                  activity: _pendingUndo!,
                  onEdit: _editPending,
                  onUndo: _undo,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
