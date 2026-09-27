import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/activity_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/settings_provider.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/calendar_event.dart';
import 'family_config.dart';

/// 서버 JSON(camelCase, 초 단위) ↔ 도메인 모델.
class SyncWire {
  const SyncWire._();

  static int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
  static DateTime date(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch((v as num).toInt() * 1000);
  static DateTime? dateOrNull(Object? v) => v == null ? null : date(v);

  static Map<String, Object?> activity(Activity a) => {
    'id': a.id,
    'type': a.type.name,
    'startedAt': sec(a.startedAt),
    'endedAt': a.endedAt == null ? null : sec(a.endedAt!),
    'payload': a.payloadJson,
    'createdBy': a.createdBy,
    'createdAt': sec(a.createdAt),
    'updatedAt': sec(a.updatedAt),
    'deletedAt': a.deletedAt == null ? null : sec(a.deletedAt!),
  };

  /// 모르는 type(새 버전 앱이 만든 기록)은 건너뛴다.
  static Activity? activityFrom(Map<String, dynamic> j) {
    ActivityType? type;
    for (final t in ActivityType.values) {
      if (t.name == j['type']) type = t;
    }
    if (type == null) return null;
    return Activity(
      id: j['id'] as String,
      type: type,
      startedAt: date(j['startedAt']),
      endedAt: dateOrNull(j['endedAt']),
      payload: Activity.decodePayload(j['payload'] as String? ?? '{}'),
      createdBy: j['createdBy'] as String? ?? 'me',
      createdAt: date(j['createdAt']),
      updatedAt: date(j['updatedAt']),
      deletedAt: dateOrNull(j['deletedAt']),
    );
  }

  static Map<String, Object?> event(CalendarEvent e) => {
    'id': e.id,
    'title': e.title,
    'startAt': sec(e.startAt),
    'endAt': e.endAt == null ? null : sec(e.endAt!),
    'allDay': e.allDay,
    'color': e.color.name,
    'memo': e.memo,
    'createdBy': e.createdBy,
    'createdAt': sec(e.createdAt),
    'updatedAt': sec(e.updatedAt),
    'deletedAt': e.deletedAt == null ? null : sec(e.deletedAt!),
  };

  static CalendarEvent eventFrom(Map<String, dynamic> j) => CalendarEvent(
    id: j['id'] as String,
    title: j['title'] as String,
    startAt: date(j['startAt']),
    endAt: dateOrNull(j['endAt']),
    allDay: j['allDay'] == true || j['allDay'] == 1,
    color: EventColor.parse(j['color'] as String?),
    memo: j['memo'] as String?,
    createdBy: j['createdBy'] as String? ?? 'me',
    createdAt: date(j['createdAt']),
    updatedAt: date(j['updatedAt']),
    deletedAt: dateOrNull(j['deletedAt']),
  );
}

class SyncStatus {
  final DateTime? lastSuccessAt;
  final String? error;
  final bool running;
  const SyncStatus({this.lastSuccessAt, this.error, this.running = false});
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);
  @override
  String toString() => message;
}

/// 폴링 동기화. 서버에는 "마지막 수정이 이긴다" 규칙으로 행 단위 병합.
///   1) 지난번 이후 바뀐 내 기록·일정을 올리고
///   2) cursor 이후 바뀐 것(상대 폰 기록 포함)을 받아 반영한다.
class SyncService {
  final Ref ref;
  SyncService(this.ref);

  static const pollInterval = Duration(seconds: 30);
  static const _debounce = Duration(seconds: 2);
  static const _timeout = Duration(seconds: 15);

  Timer? _poll;
  Timer? _debounceTimer;
  StreamSubscription<void>? _localChanges;
  Future<void>? _inFlight;
  bool _again = false;

  /// 앱이 켜지거나(포그라운드) 설정이 바뀌면 호출.
  void start() {
    stop();
    if (!ref.read(familyConfigProvider).isConfigured) return;
    _poll = Timer.periodic(pollInterval, (_) => syncNow());
    final db = ref.read(databaseProvider);
    // 기록·일정이 바뀌면(내가 썼든 시리가 썼든) 잠시 뒤 올린다.
    _localChanges = db
        .tableUpdates(TableUpdateQuery.any())
        .listen((_) => _scheduleSoon());
    syncNow();
  }

  void stop() {
    _poll?.cancel();
    _debounceTimer?.cancel();
    _localChanges?.cancel();
    _poll = null;
    _debounceTimer = null;
    _localChanges = null;
  }

  void _scheduleSoon() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, syncNow);
  }

  /// 동시에 한 번만 돈다. 도는 중에 또 불리면 끝난 뒤 한 번 더.
  Future<void> syncNow() {
    if (_inFlight != null) {
      _again = true;
      return _inFlight!;
    }
    final f = _run().whenComplete(() {
      _inFlight = null;
      if (_again) {
        _again = false;
        syncNow();
      }
    });
    _inFlight = f;
    return f;
  }

  Future<void> _run() async {
    // initState 안에서 불려도 위젯 빌드 중에 provider를 바꾸지 않도록 한 틱 미룬다.
    await Future<void>.delayed(Duration.zero);
    final config = ref.read(familyConfigProvider);
    if (!config.isConfigured) return;
    final status = ref.read(syncStatusProvider.notifier);
    status.state = SyncStatus(
      lastSuccessAt: status.state.lastSuccessAt,
      running: true,
    );
    try {
      await _exchange(config);
      status.state = SyncStatus(lastSuccessAt: DateTime.now());
    } catch (e) {
      status.state = SyncStatus(
        lastSuccessAt: status.state.lastSuccessAt,
        error: e is SyncException ? e.message : '연결할 수 없어요 ($e)',
      );
    }
  }

  Future<void> _exchange(FamilyConfig config) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final activities = ref.read(activityRepositoryProvider);
    final events = ref.read(eventRepositoryProvider);

    var cursor = prefs.getInt(kSyncCursorKey) ?? 0;
    final lastPush = prefs.getInt(kSyncLastPushKey) ?? 0;
    // 보내는 동안 같은 초에 바뀐 행을 놓치지 않도록 1초 앞을 표시해 둔다
    // (서버는 같은 updatedAt 재전송을 무시하므로 중복은 문제없다).
    final pushMark = SyncWire.sec(DateTime.now()) - 1;

    // 이름을 정하기 전에 남긴 기록('me')은 상대 폰에서 "나"로 보이지 않게 내 이름으로 보낸다.
    String author(String by) => by == 'me' ? config.authorName : by;
    var outActs = (await activities.changedSince(lastPush))
        .map((a) => SyncWire.activity(a.copyWith(createdBy: author(a.createdBy))))
        .toList();
    var outEvents = (await events.changedSince(lastPush))
        .map((e) => SyncWire.event(e.copyWith(createdBy: author(e.createdBy))))
        .toList();

    for (var page = 0; page < 50; page++) {
      final res = await _post(config, {
        'cursor': cursor,
        'activities': outActs,
        'events': outEvents,
      });
      outActs = const [];
      outEvents = const [];

      final inActs = <Activity>[];
      for (final j in (res['activities'] as List? ?? const [])) {
        final a = SyncWire.activityFrom((j as Map).cast<String, dynamic>());
        if (a != null) inActs.add(a);
      }
      final inEvents = [
        for (final j in (res['events'] as List? ?? const []))
          SyncWire.eventFrom((j as Map).cast<String, dynamic>()),
      ];
      await activities.applyRemote(inActs);
      await events.applyRemote(inEvents);

      cursor = (res['cursor'] as num).toInt();
      await prefs.setInt(kSyncCursorKey, cursor);
      if (page == 0) await prefs.setInt(kSyncLastPushKey, pushMark);
      if (res['hasMore'] != true) break;
    }
  }

  Future<Map<String, dynamic>> _post(
    FamilyConfig config,
    Map<String, Object?> body,
  ) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client
          .postUrl(Uri.parse('${config.serverUrl}/v1/sync'))
          .timeout(_timeout);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.familyCode}');
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(_timeout);
      final text = await res.transform(utf8.decoder).join().timeout(_timeout);
      if (res.statusCode == 401) {
        throw const SyncException('가족 코드가 서버와 달라요');
      }
      if (res.statusCode != 200) {
        String msg = '서버 오류 (${res.statusCode})';
        try {
          msg = (jsonDecode(text) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        throw SyncException(msg);
      }
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } on SocketException {
      throw const SyncException('서버에 연결할 수 없어요. 주소와 인터넷을 확인해 주세요');
    } on TimeoutException {
      throw const SyncException('서버 응답이 없어요');
    } on HandshakeException {
      throw const SyncException('보안 연결(HTTPS)에 실패했어요');
    } finally {
      client.close(force: true);
    }
  }
}

final syncStatusProvider = StateProvider<SyncStatus>((ref) => const SyncStatus());

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(ref);
  ref.onDispose(s.stop);
  return s;
});
