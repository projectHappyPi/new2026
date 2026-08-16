import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../data/db/seed.dart';
import '../../data/models/settings.dart';
import '../../providers/activity_provider.dart';
import '../../providers/baby_profile_provider.dart';
import '../../providers/settings_provider.dart';

/// 9절 설정 화면. 여기서 바꾼 값은 홈 궤적·시트 정렬·스와이프 방향·테마에
/// 곧바로 반영된다(모두 settingsProvider 하나를 구독하므로 별도 새로고침이 없다).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          '설정',
          style: AppTypography.title.copyWith(color: colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        children: [
          const _SectionHeader('아기 정보'),
          const _BabyInfoRow(),
          const _SectionHeader('입력'),
          _SwitchRow(
            label: '한손 입력 모드',
            value: settings.oneHandMode,
            onChanged: notifier.setOneHandMode,
          ),
          _Row(
            label: '주 사용 손',
            child: SegmentedButton<HandSide>(
              segments: const [
                ButtonSegment(value: HandSide.left, label: Text('왼손')),
                ButtonSegment(value: HandSide.right, label: Text('오른손')),
              ],
              selected: {settings.handSide},
              onSelectionChanged: (v) => notifier.setHandSide(v.first),
            ),
          ),
          const _SectionHeader('화면'),
          _Row(
            label: '테마',
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in ThemeOption.values)
                  _OptionChip(
                    label: _themeOptionLabel(option),
                    selected: settings.themeOption == option,
                    onTap: () => notifier.setThemeOption(option),
                  ),
              ],
            ),
          ),
          if (settings.themeOption == ThemeOption.schedule)
            _TimeWindowRow(
              label: '어둡게 전환 시각',
              from: settings.darkFrom,
              to: settings.darkTo,
              onChanged: notifier.setDarkWindow,
            ),
          _SwitchRow(
            label: '야간 저자극 모드',
            value: settings.nightMode,
            onChanged: notifier.setNightMode,
          ),
          _TimeWindowRow(
            label: '야간 모드 자동 전환',
            from: settings.nightFrom,
            to: settings.nightTo,
            onChanged: notifier.setNightWindow,
          ),
          const _SectionHeader('기본값'),
          _StepperRow(
            label: '분유 기본 용량',
            value: settings.formulaDefaultMl,
            suffix: 'ml',
            step: 10,
            onChanged: notifier.setFormulaDefaultMl,
          ),
          _Row(
            label: '용량 결정 방식',
            child: Wrap(
              spacing: 8,
              children: [
                for (final mode in FormulaMode.values)
                  _OptionChip(
                    label: _formulaModeLabel(mode),
                    selected: settings.formulaMode == mode,
                    onTap: () => notifier.setFormulaMode(mode),
                  ),
              ],
            ),
          ),
          _Row(
            label: '기저귀 기본 유형',
            child: SegmentedButton<DiaperDefaultSub>(
              segments: const [
                ButtonSegment(value: DiaperDefaultSub.pee, label: Text('소변')),
                ButtonSegment(value: DiaperDefaultSub.poop, label: Text('대변')),
              ],
              selected: {settings.diaperDefaultSub},
              onSelectionChanged: (v) => notifier.setDiaperDefaultSub(v.first),
            ),
          ),
          const _SectionHeader('데이터'),
          _ActionRow(
            label: '기록 내보내기',
            icon: Icons.ios_share_rounded,
            onTap: () => _exportJson(context, ref),
          ),
          if (kDebugMode) ...[
            _ActionRow(
              label: '시드 데이터 넣기',
              icon: Icons.data_array_rounded,
              onTap: () async {
                await seedForce(ref.read(databaseProvider));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('시드 데이터를 새로 채웠습니다')),
                  );
                }
              },
            ),
            _ActionRow(
              label: '전체 초기화',
              icon: Icons.delete_forever_rounded,
              onTap: () async {
                await ref
                    .read(databaseProvider)
                    .delete(ref.read(databaseProvider).activities)
                    .go();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('모든 기록을 삭제했습니다')),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(activityRepositoryProvider);
    final all = await repo.watchRange(DateTime(2000), DateTime(2100)).first;
    final list = all
        .map(
          (a) => {
            'id': a.id,
            'type': a.type.name,
            'startedAt': a.startedAt.toIso8601String(),
            'endedAt': a.endedAt?.toIso8601String(),
            'payload': a.payload,
            'createdBy': a.createdBy,
          },
        )
        .toList();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        dir.path,
        'parenting_log_export_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('내보내기 완료: ${file.path}')));
    }
  }

  String _themeOptionLabel(ThemeOption o) => switch (o) {
    ThemeOption.system => '시스템 설정',
    ThemeOption.light => '밝게',
    ThemeOption.dark => '어둡게',
    ThemeOption.schedule => '시간 지정',
  };

  String _formulaModeLabel(FormulaMode m) => switch (m) {
    FormulaMode.fixed => '고정값',
    FormulaMode.recent => '최근값',
    FormulaMode.timeOfDay => '시간대별',
  };
}

/// 아기 정보(이름·생년월일·사진). 사진은 갤러리에서 골라 앱 문서 폴더로
/// 복사해두므로 온보딩·설정·로딩 화면에서 언제든 같은 경로로 보여줄 수 있다.
class _BabyInfoRow extends ConsumerWidget {
  const _BabyInfoRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(babyProfileProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showPhotoSheet(context, ref),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceVariant,
                border: Border.all(color: colors.outline),
                image: profile.photoPath != null
                    ? DecorationImage(
                        image: FileImage(File(profile.photoPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: profile.photoPath == null
                  ? Icon(
                      Icons.add_a_photo_outlined,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _editName(context, ref, profile.name ?? ''),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.name?.isNotEmpty == true
                            ? profile.name!
                            : '이름 없음',
                        style: AppTypography.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined, size: 14, color: colors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _editBirthDate(context, ref, profile.birthDate),
                  child: Text(
                    profile.birthDate != null
                        ? '${md(profile.birthDate!)} 생'
                        : '생년월일 설정',
                    style: AppTypography.label.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 수정'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      ref.read(babyProfileProvider.notifier).setName(result);
    }
  }

  Future<void> _editBirthDate(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(babyProfileProvider.notifier).setBirthDate(picked);
    }
  }

  Future<void> _showPhotoSheet(BuildContext context, WidgetRef ref) async {
    final hasPhoto = ref.read(babyProfileProvider).photoPath != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('사진 삭제'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final notifier = ref.read(babyProfileProvider.notifier);
    if (action == 'pick') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) await notifier.setPhotoFromPath(picked.path);
    } else if (action == 'clear') {
      await notifier.clearPhoto();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;

  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(color: colors.onSurface),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.step,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(color: colors.onSurface),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: () => onChanged(value - step),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$value$suffix',
                  textAlign: TextAlign.center,
                  style: AppTypography.mono.tabular.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () => onChanged(value + step),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeWindowRow extends StatelessWidget {
  final String label;
  final TimeHM from;
  final TimeHM to;
  final void Function(TimeHM from, TimeHM to) onChanged;

  const _TimeWindowRow({
    required this.label,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final current = isFrom ? from : to;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    final newValue = TimeHM(picked.hour, picked.minute);
    onChanged(isFrom ? newValue : from, isFrom ? to : newValue);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TimeButton(time: from, onTap: () => _pick(context, true)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '~',
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              _TimeButton(time: to, onTap: () => _pick(context, false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final TimeHM time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(side: BorderSide(color: colors.outline)),
      child: Text(
        time.formatted,
        style: AppTypography.mono.tabular.copyWith(color: colors.onSurface),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionChip({
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

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.body.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
