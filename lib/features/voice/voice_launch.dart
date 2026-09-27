import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android MainActivity.kt와 이름이 반드시 같아야 한다.
const _channel = MethodChannel('com.happypi.parentingLog/voice_launch');

/// 앱 아이콘 길게 누르기 → "말로 기록" 바로가기, 또는 딥링크 tunteuni://voice 로
/// 앱이 열렸는지 네이티브 쪽에 묻는다. (현재 Android만 구현. iOS는 시리가
/// 앱을 열지 않고 바로 기록하므로 필요 없다 — 채널이 없으면 조용히 false.)
class VoiceLaunch {
  const VoiceLaunch._();

  /// 콜드 스타트: 앱을 연 인텐트가 "말로 기록"이었는지 한 번만 확인한다.
  static Future<bool> consumePendingListen() async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>(
        'consumeLaunch',
      );
      return r?['action'] == 'listen';
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 앱이 이미 켜져 있을 때 바로가기를 다시 누른 경우(onNewIntent).
  static void onListen(VoidCallback callback) {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method == 'onLaunch' && args is Map && args['action'] == 'listen') {
        callback();
      }
      return null;
    });
  }
}
