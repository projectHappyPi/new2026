import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../providers/baby_profile_provider.dart';

/// 첫 실행 시(아기 프로필이 없을 때) 보여주는 온보딩. 이름·생년월일은 필수,
/// 사진은 선택이다. 완료하면 babyProfileProvider가 반응해 자동으로 앱 셸로 넘어간다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  DateTime? _birthDate;
  String? _pickedPhotoPath;
  bool _saving = false;

  bool get _canSubmit => _nameCtrl.text.trim().isNotEmpty && _birthDate != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _pickedPhotoPath = picked.path);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(babyProfileProvider.notifier);
    notifier.setName(_nameCtrl.text.trim());
    notifier.setBirthDate(_birthDate!);
    if (_pickedPhotoPath != null) {
      await notifier.setPhotoFromPath(_pickedPhotoPath!);
    }
    // 저장 즉시 babyProfileProvider가 완료 상태가 되어 app.dart가 앱 셸로 넘긴다.
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '아기 정보를 알려주세요',
                style: AppTypography.title.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                '이름과 생년월일은 나중에 설정에서 바꿀 수 있어요',
                style: AppTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceVariant,
                      border: Border.all(color: colors.outline),
                      image: _pickedPhotoPath != null
                          ? DecorationImage(
                              image: FileImage(File(_pickedPhotoPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: _pickedPhotoPath == null
                        ? Icon(
                            Icons.add_a_photo_outlined,
                            color: colors.onSurfaceVariant,
                            size: 26,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '사진 추가(선택)',
                  style: AppTypography.label.copyWith(color: colors.muted),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '이름',
                style: AppTypography.label.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                style: AppTypography.body.copyWith(color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: '아기 이름',
                  hintStyle: AppTypography.body.copyWith(color: colors.muted),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '생년월일',
                style: AppTypography.label.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _pickBirthDate,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  side: BorderSide(color: colors.outline),
                ),
                child: Text(
                  _birthDate != null ? '${md(_birthDate!)} 생' : '생년월일 선택',
                  style: AppTypography.body.tabular.copyWith(
                    color: _birthDate != null ? colors.onSurface : colors.muted,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _canSubmit && !_saving ? _submit : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_saving ? '저장 중…' : '시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
