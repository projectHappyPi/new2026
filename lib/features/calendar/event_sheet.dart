import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../data/models/calendar_event.dart';
import '../../providers/event_provider.dart';

/// 일정 추가·수정 시트. [editing]이 있으면 수정, 없으면 [day]에 새 일정.
Future<void> showEventSheet(
  BuildContext context, {
  DateTime? day,
  CalendarEvent? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EventSheet(day: day, editing: editing),
  );
}

/// 자주 쓰는 육아 일정 제목.
const _kQuickTitles = ['예방접종', '영유아 검진', '소아과', '문화센터', '이유식 재료 장보기'];

class EventSheet extends ConsumerStatefulWidget {
  final DateTime? day;
  final CalendarEvent? editing;
  const EventSheet({super.key, this.day, this.editing});

  @override
  ConsumerState<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<EventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _memo;
  late DateTime _date;
  late DateTime _endDate;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _allDay;
  late EventColor _color;
  bool _saving = false;
  String? _titleError;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final base = widget.day ?? DateTime.now();
    _title = TextEditingController(text: e?.title ?? '');
    _memo = TextEditingController(text: e?.memo ?? '');
    final s = e?.startAt ?? DateTime(base.year, base.month, base.day, 10);
    final en = e?.effectiveEnd ?? s.add(const Duration(hours: 1));
    _date = DateTime(s.year, s.month, s.day);
    _endDate = DateTime(en.year, en.month, en.day);
    _start = TimeOfDay.fromDateTime(s);
    _end = TimeOfDay.fromDateTime(en);
    _allDay = e?.allDay ?? false;
    _color = e?.color ?? EventColor.blue;
  }

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  DateTime _at(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '제목을 입력해 주세요');
      return;
    }
    DateTime startAt;
    DateTime endAt;
    if (_allDay) {
      startAt = _date;
      endAt = _endDate.isBefore(_date) ? _date : _endDate;
    } else {
      startAt = _at(_date, _start);
      endAt = _at(_endDate, _end);
      if (endAt.isBefore(startAt)) endAt = startAt;
    }
    final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
    setState(() => _saving = true);
    final repo = ref.read(eventRepositoryProvider);
    try {
    if (_isEditing) {
      await repo.update(
        widget.editing!.copyWith(
          title: title,
          startAt: startAt,
          endAt: () => endAt,
          allDay: _allDay,
          color: _color,
          memo: () => memo,
        ),
      );
    } else {
      await repo.create(
        title: title,
        startAt: startAt,
        endAt: endAt,
        allDay: _allDay,
        color: _color,
        memo: memo,
      );
    }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(eventRepositoryProvider).softDelete(widget.editing!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate({required bool end}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? _endDate : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _endDate = picked;
      } else {
        final span = _endDate.difference(_date);
        _date = picked;
        _endDate = picked.add(span);
      }
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: end ? _end : _start,
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _end = picked;
      } else {
        final startMin = _start.hour * 60 + _start.minute;
        final endMin = _end.hour * 60 + _end.minute;
        final dur = (endMin - startMin).clamp(0, 24 * 60);
        _start = picked;
        final newEnd = picked.hour * 60 + picked.minute + dur;
        _end = TimeOfDay(
          hour: (newEnd ~/ 60).clamp(0, 23),
          minute: newEnd >= 24 * 60 ? 59 : newEnd % 60,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        t,
        style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
      ),
    );
    Widget pill(String text, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: AppTypography.mono.tabular.copyWith(color: colors.onSurface),
        ),
      ),
    );
    String dateText(DateTime d) =>
        '${d.month}월 ${d.day}일 (${'일월화수목금토'[d.weekday % 7]})';
    String timeText(TimeOfDay t) => hm(DateTime(2000, 1, 1, t.hour, t.minute));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
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
                  _isEditing ? '일정 수정' : '새 일정',
                  style: AppTypography.title.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  autofocus: !_isEditing,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurface,
                    fontSize: 16,
                  ),
                  onChanged: (_) {
                    if (_titleError != null) setState(() => _titleError = null);
                  },
                  decoration: InputDecoration(
                    errorText: _titleError,
                    hintText: '제목 (예: 예방접종)',
                    hintStyle: AppTypography.body.copyWith(color: colors.muted),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _kQuickTitles)
                      ActionChip(
                        label: Text(t),
                        onPressed: () => setState(() {
                          _title.text = t;
                          _titleError = null;
                        }),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: label('종일')),
                    Switch(
                      value: _allDay,
                      onChanged: (v) => setState(() => _allDay = v),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    pill(dateText(_date), () => _pickDate(end: false)),
                    if (!_allDay) pill(timeText(_start), () => _pickTime(end: false)),
                    Text('→', style: TextStyle(color: colors.muted)),
                    pill(dateText(_endDate), () => _pickDate(end: true)),
                    if (!_allDay) pill(timeText(_end), () => _pickTime(end: true)),
                  ],
                ),
                label('색'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in EventColor.values)
                      Semantics(
                        label: c.label,
                        selected: c == _color,
                        button: true,
                        child: GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c == _color
                                    ? colors.onSurface
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label('메모'),
                TextField(
                  controller: _memo,
                  minLines: 1,
                  maxLines: 4,
                  style: AppTypography.body.copyWith(color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: '준비물, 장소 등',
                    hintStyle: AppTypography.body.copyWith(color: colors.muted),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_isEditing)
                      TextButton.icon(
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('삭제'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
