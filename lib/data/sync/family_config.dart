import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

/// 가족 공유(동기화) 설정. 두 폰에 같은 서버 주소·가족 코드를 넣는다.
class FamilyConfig {
  /// 예: https://tunteuni.example.com (끝의 / 없이)
  final String serverUrl;
  final String familyCode;

  /// 기록·일정 작성자로 남는 내 이름(엄마, 아빠 …).
  final String memberName;

  const FamilyConfig({
    this.serverUrl = '',
    this.familyCode = '',
    this.memberName = '',
  });

  bool get isConfigured => serverUrl.isNotEmpty && familyCode.isNotEmpty;

  /// 이름을 정하지 않았으면 예전처럼 'me'(화면에는 "나")로 남긴다.
  String get authorName => memberName.trim().isEmpty ? 'me' : memberName.trim();
}

const _kServerUrl = 'family.serverUrl';
const _kFamilyCode = 'family.code';
const _kMemberName = 'family.memberName';
const kSyncCursorKey = 'family.cursor';
const kSyncLastPushKey = 'family.lastPushSec';

class FamilyConfigNotifier extends Notifier<FamilyConfig> {
  @override
  FamilyConfig build() {
    final p = ref.watch(sharedPreferencesProvider);
    return FamilyConfig(
      serverUrl: p.getString(_kServerUrl) ?? '',
      familyCode: p.getString(_kFamilyCode) ?? '',
      memberName: p.getString(_kMemberName) ?? '',
    );
  }

  Future<void> save({
    required String serverUrl,
    required String familyCode,
    required String memberName,
  }) async {
    final p = ref.read(sharedPreferencesProvider);
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isNotEmpty && !url.startsWith('http')) url = 'https://$url';
    final changedServer =
        url != state.serverUrl || familyCode.trim() != state.familyCode;
    if (changedServer) {
      // 다른 서버에 붙으면 처음부터 다시 주고받는다.
      await p.remove(kSyncCursorKey);
      await p.remove(kSyncLastPushKey);
    }
    await p.setString(_kServerUrl, url);
    await p.setString(_kFamilyCode, familyCode.trim());
    await p.setString(_kMemberName, memberName.trim());
    state = FamilyConfig(
      serverUrl: url,
      familyCode: familyCode.trim(),
      memberName: memberName.trim(),
    );
  }
}

final familyConfigProvider =
    NotifierProvider<FamilyConfigNotifier, FamilyConfig>(
      FamilyConfigNotifier.new,
    );
