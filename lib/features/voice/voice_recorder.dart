import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/time/time_format.dart';
import '../../core/voice/voice_command.dart';
import '../../data/models/activity.dart';
import '../../data/models/activity_type.dart';
import '../../data/models/settings.dart';
import '../../providers/activity_provider.dart';
import '../../providers/baby_profile_provider.dart';
import '../../providers/settings_provider.dart';

/// 말로 기록 실패(알아듣지 못함, 진행 중인 수면 없음 등). [message]를 그대로 보여준다.
class VoiceRecordException implements Exception {
  final String message;
  const VoiceRecordException(this.message);

  @override
  String toString() => message;
}

class VoiceOutcome {
  final Activity activity;
  final String message;
  const VoiceOutcome(this.activity, this.message);
}

/// 인식된 문장 → [parseVoiceCommand] → DB 저장. 확인 다이얼로그 없이 바로 저장하고,
/// 잘못 들었으면 기록 화면의 실행 취소 토스트로 되돌린다(버튼 짧은 탭과 같은 원칙).
class VoiceRecorder {
  final Ref ref;
  VoiceRecorder(this.ref);

  static const _via = {'via': 'voice'};

  VoiceParseResult parse(String text) =>
      parseVoiceCommand(text, babyName: ref.read(babyProfileProvider).name);

  Future<VoiceOutcome> handleText(String text) async {
    final r = parse(text);
    if (!r.isOk) throw VoiceRecordException(r.error!);
    return execute(r.command!);
  }

  Future<VoiceOutcome> execute(VoiceCommand c, {DateTime? now}) async {
    final actions = ref.read(activityActionsProvider);
    final repo = ref.read(activityRepositoryProvider);
    final t = now ?? DateTime.now();

    switch (c.kind) {
      case VoiceCommandKind.formula:
        final ml = c.ml ?? await actions.defaultFormulaMl();
        final a = await actions.createDetailed(
          type: ActivityType.formula,
          startedAt: t,
          payload: {'ml': ml, ..._via},
        );
        return VoiceOutcome(a, '분유 ${ml}ml 기록했어요');

      case VoiceCommandKind.breast:
        // "모유 10분 먹었어" = 방금 끝난 수유. 지금부터 거꾸로 10분 구간으로 남긴다.
        final a = await actions.createDetailed(
          type: ActivityType.breast,
          startedAt: t.subtract(Duration(minutes: c.minutes!)),
          endedAt: t,
          payload: {..._via},
        );
        return VoiceOutcome(a, c.confirmation);

      case VoiceCommandKind.solid:
        final a = await actions.createDetailed(
          type: ActivityType.solid,
          startedAt: t,
          payload: {if (c.ml != null) 'ml': c.ml, ..._via},
        );
        return VoiceOutcome(a, c.confirmation);

      case VoiceCommandKind.diaper:
        final settings = ref.read(settingsProvider);
        final sub =
            c.diaper ??
            (settings.diaperDefaultSub == DiaperDefaultSub.poop
                ? DiaperSub.poop
                : DiaperSub.pee);
        final a = await actions.createDetailed(
          type: ActivityType.diaper,
          startedAt: t,
          payload: {
            'sub': sub.name,
            if (sub.hasPoop) 'texture': DiaperTextures.defaultTexture,
            ..._via,
          },
        );
        return VoiceOutcome(a, '${sub.label} 기록했어요');

      case VoiceCommandKind.sleepStart:
        final last = await repo.lastOf(ActivityType.sleep);
        if (last != null && last.isRunning) {
          throw VoiceRecordException('이미 ${hm(last.startedAt)}부터 자고 있어요');
        }
        final period = defaultSleepPeriod(t);
        final a = await actions.startRange(
          ActivityType.sleep,
          startedAt: t,
          payload: {'period': period.name, ..._via},
        );
        return VoiceOutcome(a, '${period.label} 시작을 기록했어요');

      case VoiceCommandKind.sleepEnd:
        final last = await repo.lastOf(ActivityType.sleep);
        if (last == null || !last.isRunning) {
          throw const VoiceRecordException(
            '진행 중인 수면이 없어요. 먼저 "잠들었어"라고 말해 주세요',
          );
        }
        final ended = await actions.endRunning(last);
        return VoiceOutcome(
          ended,
          '수면 종료 · ${durMin(ended.elapsed())} 잤어요',
        );

      case VoiceCommandKind.bath:
        final a = await actions.createDetailed(
          type: ActivityType.bath,
          startedAt: t,
          payload: {..._via},
        );
        return VoiceOutcome(a, c.confirmation);

      case VoiceCommandKind.temperature:
        final a = await actions.createDetailed(
          type: ActivityType.temperature,
          startedAt: t,
          payload: {'celsius': c.celsius, ..._via},
        );
        return VoiceOutcome(a, c.confirmation);

      case VoiceCommandKind.medicine:
        final a = await actions.createDetailed(
          type: ActivityType.medicine,
          startedAt: t,
          payload: {if (c.medicine != null) 'medicine': c.medicine, ..._via},
        );
        return VoiceOutcome(a, c.confirmation);
    }
  }
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  return VoiceRecorder(ref);
});

/// 앱 바로가기(Android "말로 기록")나 딥링크 tunteuni://voice 로 들어오면 1씩 늘어난다.
/// 기록 화면이 이 값을 지켜보다가 음성 시트를 연다.
final voiceLaunchTickProvider = StateProvider<int>((ref) => 0);
