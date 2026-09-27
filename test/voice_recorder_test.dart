import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/data/db/database.dart';
import 'package:parenting_log/data/models/activity_type.dart';
import 'package:parenting_log/features/voice/voice_recorder.dart';
import 'package:parenting_log/providers/activity_provider.dart';
import 'package:parenting_log/providers/baby_profile_provider.dart';
import 'package:parenting_log/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 말로 기록 → 실제 DB 저장까지(메모리 DB).
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({kBabyNameKey: '튼튼이'});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  VoiceRecorder recorder() => container.read(voiceRecorderProvider);

  test('10가지 기본 문장이 모두 저장된다', () async {
    final said = [
      '튼튼이 분유 230ml 먹었어',
      '튼튼이 모유 10분 먹었어',
      '튼튼이 이유식 150ml 먹었어',
      '튼튼이 소변 갈았어',
      '튼튼이 대변갈았어',
      '튼튼이 잠들었어',
      '튼튼이 깼어',
      '튼튼이 목욕했어',
      '튼튼이 체온 38도야',
      '튼튼이 약먹었어',
    ];
    for (final s in said) {
      await recorder().handleText(s);
    }
    final rows = await db.select(db.activities).get();
    // 잠들었어/깼어는 같은 수면 한 건을 시작·종료한다.
    expect(rows.length, 9);
    expect(
      rows.map((r) => r.type).toSet(),
      ActivityType.values.toSet(),
    );
  });

  test('분유 230ml → ml 230, via=voice', () async {
    final o = await recorder().handleText('튼튼이 분유 230ml 먹었어');
    expect(o.activity.type, ActivityType.formula);
    expect(o.activity.ml, 230);
    expect(o.activity.viaVoice, isTrue);
    expect(o.message, '분유 230ml 기록했어요');
  });

  test('모유 10분 → 지금 끝난 10분 구간', () async {
    final o = await recorder().handleText('튼튼이 모유 10분 먹었어');
    final a = o.activity;
    expect(a.type, ActivityType.breast);
    expect(a.endedAt, isNotNull);
    expect(a.endedAt!.difference(a.startedAt).inMinutes, 10);
  });

  test('잠들었어 → 깼어 는 같은 수면 기록을 닫는다', () async {
    final start = await recorder().handleText('튼튼이 잠들었어');
    expect(start.activity.isRunning, isTrue);
    expect(start.activity.sleepPeriod, isNotNull);
    final end = await recorder().handleText('튼튼이 깼어');
    expect(end.activity.id, start.activity.id);
    expect(end.activity.endedAt, isNotNull);
  });

  test('자는 중이 아닌데 깼어 → 안내 문구', () async {
    expect(
      () => recorder().handleText('튼튼이 깼어'),
      throwsA(isA<VoiceRecordException>()),
    );
  });

  test('이미 자는 중인데 잠들었어 → 중복 시작하지 않는다', () async {
    await recorder().handleText('튼튼이 잠들었어');
    expect(
      () => recorder().handleText('튼튼이 잠들었어'),
      throwsA(isA<VoiceRecordException>()),
    );
  });

  test('분유 용량을 말하지 않으면 설정 기본값', () async {
    final o = await recorder().handleText('튼튼이 분유 먹었어');
    expect(o.activity.ml, container.read(settingsProvider).formulaDefaultMl);
  });

  test('체온·약 payload', () async {
    final t = await recorder().handleText('튼튼이 체온 38도 5부야');
    expect(t.activity.celsius, 38.5);
    expect(t.activity.summary, '38.5℃');
    final m = await recorder().handleText('튼튼이 해열제 먹었어');
    expect(m.activity.medicine, '해열제');
  });

  test('못 알아들으면 VoiceRecordException', () async {
    expect(
      () => recorder().handleText('안녕'),
      throwsA(isA<VoiceRecordException>()),
    );
  });
}
