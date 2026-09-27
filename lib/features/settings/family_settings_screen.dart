import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../data/sync/family_config.dart';
import '../../data/sync/sync_service.dart';

/// 설정 > 가족 공유. 두 폰에 같은 서버 주소·가족 코드를 넣으면
/// 기록(수유·수면…)과 달력 일정이 서로 보인다.
class FamilySettingsScreen extends ConsumerStatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  ConsumerState<FamilySettingsScreen> createState() =>
      _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _code;
  late final TextEditingController _name;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final c = ref.read(familyConfigProvider);
    _url = TextEditingController(text: c.serverUrl);
    _code = TextEditingController(text: c.familyCode);
    _name = TextEditingController(text: c.memberName);
  }

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_code.text.trim().isNotEmpty && _code.text.trim().length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가족 코드는 16자 이상이에요 (서버 .env의 FAMILY_CODE)')),
      );
      return;
    }
    await ref
        .read(familyConfigProvider.notifier)
        .save(
          serverUrl: _url.text,
          familyCode: _code.text,
          memberName: _name.text,
        );
    final sync = ref.read(syncServiceProvider);
    sync.start();
    await sync.syncNow();
    if (!mounted) return;
    final status = ref.read(syncStatusProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status.error ?? '저장했어요 · 동기화 완료')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = ref.watch(syncStatusProvider);
    final configured = ref.watch(familyConfigProvider).isConfigured;

    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(color: colors.muted),
      filled: true,
      fillColor: colors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        t,
        style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
      ),
    );

    final String statusText;
    if (!configured) {
      statusText = '꺼짐 · 이 폰에만 저장돼요';
    } else if (status.running) {
      statusText = '동기화 중…';
    } else if (status.error != null) {
      statusText = status.error!;
    } else if (status.lastSuccessAt != null) {
      statusText = '${hm(status.lastSuccessAt!)} 동기화됨';
    } else {
      statusText = '대기 중';
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          '가족 공유',
          style: AppTypography.title.copyWith(color: colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            '엄마·아빠 폰에 같은 서버 주소와 가족 코드를 넣으면 기록과 달력 일정이 30초마다 서로 맞춰져요.',
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          label('내 이름 (기록·일정에 표시)'),
          TextField(
            controller: _name,
            style: AppTypography.body.copyWith(color: colors.onSurface),
            decoration: deco('엄마 / 아빠'),
          ),
          label('서버 주소'),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: AppTypography.body.copyWith(color: colors.onSurface),
            decoration: deco('https://tunteuni.example.com'),
          ),
          label('가족 코드'),
          TextField(
            controller: _code,
            obscureText: _obscure,
            autocorrect: false,
            style: AppTypography.mono.copyWith(color: colors.onSurface),
            decoration: deco('서버 .env 의 FAMILY_CODE').copyWith(
              suffixIcon: IconButton(
                tooltip: _obscure ? '보기' : '가리기',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _save, child: const Text('저장하고 동기화')),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                status.error != null
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (configured)
                TextButton(
                  onPressed: () => ref.read(syncServiceProvider).syncNow(),
                  child: const Text('지금 동기화'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '예시 기록(처음 설치 때 채워진 기록)은 공유되지 않아요. 서버 설치 방법은 저장소 server/README.md 에 있어요.',
            style: AppTypography.label.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
