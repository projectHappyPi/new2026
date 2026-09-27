import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/family_config.dart';
import '../../providers/activity_provider.dart';
import '../../providers/baby_profile_provider.dart';
import 'widget_config.dart';

/// iOS AppDelegate.swift / Android MainActivity.kt 와 이름이 같아야 한다.
const _channel = MethodChannel('com.happypi.parentingLog/widget');

/// 앱 → 홈 화면 위젯. 위젯은 DB 파일을 직접 읽으므로 여기서는
/// (1) 위젯 설정·아기 정보를 넘기고 (2) 기록·일정이 바뀌면 다시 그리라고만 알린다.
class WidgetBridge {
  final Ref ref;
  WidgetBridge(this.ref);

  StreamSubscription<void>? _sub;
  Timer? _debounce;
  bool _started = false;

  void start() {
    if (_started) {
      reload();
      return;
    }
    _started = true;
    pushConfig();
    final db = ref.read(databaseProvider);
    _sub = db.tableUpdates(TableUpdateQuery.any()).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), reload);
    });
    ref.listen(widgetConfigProvider, (_, _) => pushConfig());
    ref.listen(babyProfileProvider, (_, _) => pushConfig());
    ref.listen(familyConfigProvider, (_, _) => pushConfig());
  }

  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
  }

  Future<void> pushConfig() async {
    final cfg = ref.read(widgetConfigProvider);
    final baby = ref.read(babyProfileProvider);
    final family = ref.read(familyConfigProvider);
    final data = {
      ...cfg.toJson(),
      'babyName': baby.name ?? '',
      'birthDateSec': baby.birthDate == null
          ? null
          : baby.birthDate!.millisecondsSinceEpoch ~/ 1000,
      // 시리로 남긴 기록의 작성자 이름.
      'memberName': family.authorName,
    };
    try {
      await _channel.invokeMethod('saveConfig', {'json': jsonEncode(data)});
    } on MissingPluginException {
      // 테스트·지원하지 않는 플랫폼
    } on PlatformException {
      // 위젯이 아직 설치 안 됨 등 — 무시
    }
  }

  Future<void> reload() async {
    try {
      await _channel.invokeMethod('reload');
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }
}

final widgetBridgeProvider = Provider<WidgetBridge>((ref) {
  final b = WidgetBridge(ref);
  ref.onDispose(b.dispose);
  return b;
});
