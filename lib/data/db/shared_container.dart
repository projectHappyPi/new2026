import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// AppDelegate.swift에 등록된 채널과 이름이 반드시 같아야 한다.
const _channel = MethodChannel('com.happypi.parentingLog/app_group');

/// Xcode에서 App Groups capability로 등록해야 하는 그룹 ID.
/// ios/Runner/Runner.entitlements와 반드시 같아야 한다.
const iosAppGroupId = 'group.com.happypi.parentingLog';

/// 시리 App Intent · 홈 화면 위젯과 기록을 같은 DB로 공유하기 위한 폴더.
///
/// - iOS: App Group 공유 컨테이너. 위젯/App Intent 익스텐션은 메인 앱과
///   별도 프로세스라 앱 전용 문서 폴더에는 접근할 수 없기 때문이다.
/// - Android: 기존 앱 문서 폴더 그대로. 홈 화면 위젯이 별도 프로세스가
///   아니라 같은 앱 프로세스(AppWidgetProvider)에서 돌기 때문에 App Group
///   같은 별도 공유 장치가 필요 없다.
Future<Directory> sharedDataDirectory() async {
  if (Platform.isIOS) {
    final path = await _channel.invokeMethod<String>('containerPath', {
      'groupId': iosAppGroupId,
    });
    if (path != null) return Directory(path);
    // Xcode에서 App Groups capability를 아직 추가하지 않았으면 null이 온다.
    // 완전히 막히지 않도록 앱 전용 폴더로 폴백한다(이 경우 시리/위젯 공유는 안 된다).
  }
  return getApplicationDocumentsDirectory();
}
