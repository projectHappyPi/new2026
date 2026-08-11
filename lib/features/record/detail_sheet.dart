import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../data/models/activity.dart';
import '../../data/models/activity_type.dart';
import '../../data/models/settings.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';

/// 6절 상세 입력 시트. 신규 생성(editing == null)과 기존 기록 수정을 함께 다룬다.
Future<Activity?> showDetailSheet(
  BuildContext context, {
  required ActivityType type,
  Activity? editing,
}) {
  return showModalBottomSheet<Activity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DetailSheet(type: type, editing: editing),
  );
}

class DetailSheet extends ConsumerStatefulWidget {
  final ActivityType type;
  final Activity? editing;

  const DetailSheet({super.key, required this.type, this.editing});

  @override
  ConsumerState<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<DetailSheet> {
  late int _ml;
  late DiaperSub _diaperSub;
  String? _diaperTexture;
  late TextEditingController _diaperNoteCtrl;
  String? _solidFood;
  late String _solidAmount;
  late TextEditingController _solidNoteCtrl;
  int _startOffsetMinutes = 0;
  DateTime? _editStartedAt;
  DateTime? _editEndedAt;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _ml = e?.ml ?? FormulaPresets.defaultMl;
    _diaperSub = e?.diaperSub ?? DiaperSub.pee;
    _diaperTexture = e?.texture;
    _diaperNoteCtrl = TextEditingController(text: e?.note ?? '');
    _solidFood = e?.food;
    _solidAmount = e?.amount ?? SolidDefaults.amounts[2];
    _solidNoteCtrl = TextEditingController(text: e?.note ?? '');
    _editStartedAt = e?.startedAt;
    _editEndedAt = e?.endedAt;

    if (!_isEditing && widget.type == ActivityType.formula) {
      Future.microtask(() async {
        final ml = await ref.read(activityActionsProvider).defaultFormulaMl();
        if (mounted) setState(() => _ml = ml);
      });
    }
    if (!_isEditing && widget.type == ActivityType.diaper) {
      final settings = ref.read(settingsProvider);
      _diaperSub = settings.diaperDefaultSub == DiaperDefaultSub.poop
          ? DiaperSub.poop
          : DiaperSub.pee;
    }
  }

  @override
  void dispose() {
    _diaperNoteCtrl.dispose();
    _solidNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final actions = ref.read(activityActionsProvider);
    Activity result;
    switch (widget.type) {
      case ActivityType.formula:
        result = await _persist(actions, {'ml': _ml});
      case ActivityType.diaper:
        final payload = <String, dynamic>{'sub': _diaperSub.name};
        if (_diaperSub.hasPoop) {
          payload['texture'] = _diaperTexture ?? DiaperTextures.defaultTexture;
        }
        final note = _diaperNoteCtrl.text.trim();
        if (note.isNotEmpty) payload['note'] = note;
        result = await _persist(actions, payload);
      case ActivityType.solid:
        final foods =
            ref.read(recentFoodsProvider).valueOrNull ?? const <String>[];
        final food =
            _solidFood ??
            (foods.isNotEmpty ? foods.first : SolidDefaults.foods.first);
        final payload = <String, dynamic>{'food': food, 'amount': _solidAmount};
        final note = _solidNoteCtrl.text.trim();
        if (note.isNotEmpty) payload['note'] = note;
        result = await _persist(actions, payload);
      case ActivityType.sleep:
      case ActivityType.breast:
        if (_isEditing) {
          result = await _persist(actions, widget.editing!.payload);
        } else {
          final startedAt = DateTime.now().subtract(
            Duration(minutes: _startOffsetMinutes),
          );
          result = await actions.startRange(widget.type, startedAt: startedAt);
        }
    }
    if (mounted) Navigator.pop(context, result);
  }

  Future<Activity> _persist(
    ActivityActions actions,
    Map<String, dynamic> payload,
  ) {
    if (_isEditing) {
      final updated = widget.editing!.copyWith(
        payload: payload,
        startedAt: _editStartedAt,
        endedAt: () => _editEndedAt,
      );
      return actions.updateActivity(updated).then((_) => updated);
    }
    return actions.createDetailed(
      type: widget.type,
      startedAt: DateTime.now(),
      payload: payload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = ref.watch(settingsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditing ? '${widget.type.label} 수정' : widget.type.label,
                  style: AppTypography.title.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 20),
                if (_isEditing && widget.type.isRange) ..._timeRows(context),
                _buildBody(context),
                const SizedBox(height: 24),
                Row(children: _buildButtons(context, settings)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _timeRows(BuildContext context) {
    return [
      _TimeRow(
        label: '시작',
        time: _editStartedAt!,
        onChanged: (t) => setState(() => _editStartedAt = t),
      ),
      if (_editEndedAt != null)
        _TimeRow(
          label: '종료',
          time: _editEndedAt!,
          onChanged: (t) => setState(() => _editEndedAt = t),
        ),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.type) {
      case ActivityType.formula:
        return _buildFormula(context);
      case ActivityType.diaper:
        return _buildDiaper(context);
      case ActivityType.solid:
        return _buildSolid(context);
      case ActivityType.sleep:
      case ActivityType.breast:
        return _isEditing ? const SizedBox.shrink() : _buildRangeStart(context);
    }
  }

  Widget _buildFormula(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '자주 쓰는 용량',
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in FormulaPresets.presets)
              _Chip(
                label: '${preset}ml',
                selected: _ml == preset,
                onTap: () => setState(() => _ml = preset),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '직접 조절 · 5ml 단위',
              style: AppTypography.label.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Text(
              '${_ml}ml',
              style: AppTypography.mono.tabular.copyWith(
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.onSurface,
            inactiveTrackColor: colors.outlineSoft,
            thumbColor: colors.onSurface,
            overlayColor: colors.onSurface.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: _ml.toDouble(),
            min: FormulaPresets.min.toDouble(),
            max: FormulaPresets.max.toDouble(),
            divisions:
                (FormulaPresets.max - FormulaPresets.min) ~/
                FormulaPresets.step,
            onChanged: (v) => setState(
              () =>
                  _ml = (v / FormulaPresets.step).round() * FormulaPresets.step,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiaper(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '유형',
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final sub in DiaperSub.values)
              _Chip(
                label: sub.label,
                selected: _diaperSub == sub,
                onTap: () => setState(() => _diaperSub = sub),
              ),
          ],
        ),
        if (_diaperSub.hasPoop) ...[
          const SizedBox(height: 20),
          Text(
            '묽기',
            style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in DiaperTextures.textures)
                _Chip(
                  label: t,
                  selected:
                      (_diaperTexture ?? DiaperTextures.defaultTexture) == t,
                  onTap: () => setState(() => _diaperTexture = t),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _NoteField(controller: _diaperNoteCtrl),
      ],
    );
  }

  Widget _buildSolid(BuildContext context) {
    final colors = context.colors;
    final recentFoods =
        ref.watch(recentFoodsProvider).valueOrNull ?? const <String>[];
    final foods = recentFoods.isNotEmpty ? recentFoods : SolidDefaults.foods;
    final selectedFood = _solidFood ?? foods.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '식재료',
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in foods)
              _Chip(
                label: f,
                selected: selectedFood == f,
                onTap: () => setState(() => _solidFood = f),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '섭취 정도',
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final a in SolidDefaults.amounts)
              _Chip(
                label: a,
                selected: _solidAmount == a,
                onTap: () => setState(() => _solidAmount = a),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _NoteField(controller: _solidNoteCtrl),
      ],
    );
  }

  Widget _buildRangeStart(BuildContext context) {
    final colors = context.colors;
    const labels = {0: '방금', 5: '5분 전', 15: '15분 전', 30: '30분 전'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시작 시각',
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in StartOffsets.minutesAgo)
              _Chip(
                label: labels[m]!,
                selected: _startOffsetMinutes == m,
                onTap: () => setState(() => _startOffsetMinutes = m),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildButtons(BuildContext context, Settings settings) {
    final cancel = TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('취소'),
    );
    final save = ElevatedButton(onPressed: _save, child: const Text('저장'));
    return settings.isRightHand
        ? [
            Expanded(child: cancel),
            const SizedBox(width: 12),
            Expanded(child: save),
          ]
        : [
            Expanded(child: save),
            const SizedBox(width: 12),
            Expanded(child: cancel),
          ];
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.onSurface.withValues(alpha: 0.1)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.onSurface : colors.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            color: selected ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final TextEditingController controller;

  const _NoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      style: AppTypography.body.copyWith(color: colors.onSurface),
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: '메모',
        hintStyle: AppTypography.body.copyWith(color: colors.muted),
        filled: true,
        fillColor: colors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final ValueChanged<DateTime> onChanged;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(time),
              );
              if (picked != null) {
                onChanged(
                  DateTime(
                    time.year,
                    time.month,
                    time.day,
                    picked.hour,
                    picked.minute,
                  ),
                );
              }
            },
            child: Text(
              hm(time),
              style: AppTypography.mono.tabular.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
