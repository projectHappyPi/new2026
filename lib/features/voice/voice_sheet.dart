import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/activity.dart';
import 'voice_recorder.dart';

/// 말로 기록 시트. 열리자마자 듣기 시작하고, 문장이 끝나면(최종 인식 결과)
/// 확인 없이 바로 저장한 뒤 닫힌다. 저장된 기록을 돌려주므로 기록 화면이
/// 실행 취소 토스트를 띄울 수 있다.
///
/// 음성 인식이 안 되는 환경(권한 거부, 에뮬레이터 등)을 위해 직접 입력 칸도 둔다.
Future<Activity?> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<Activity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const VoiceSheet(),
  );
}

enum _Phase { starting, listening, saving, done, error, unavailable }

class VoiceSheet extends ConsumerStatefulWidget {
  const VoiceSheet({super.key});

  @override
  ConsumerState<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<VoiceSheet> {
  /// 한국어 인식. iOS/Android 모두 "ko_KR" 형식을 받는다.
  static const _localeId = 'ko_KR';

  /// 말이 끊기고 이만큼 조용하면 문장이 끝난 것으로 본다.
  static const _pauseFor = Duration(seconds: 2);
  static const _listenFor = Duration(seconds: 12);
  static const _closeDelay = Duration(milliseconds: 1100);

  final _stt = SpeechToText();
  final _textCtrl = TextEditingController();
  _Phase _phase = _Phase.starting;
  String _heard = '';
  String? _message;
  bool _submitted = false;

  /// 다시 듣기 직후 이전 세션의 늦은 'done' 상태를 무시하기 위한 시각.
  DateTime _listenStartedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _stt.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    bool available = false;
    try {
      available = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    if (!available) {
      setState(() {
        _phase = _Phase.unavailable;
        _message = '음성 인식을 쓸 수 없어요. 마이크 권한을 확인하거나 아래에 직접 입력해 주세요.';
      });
      return;
    }
    await _listen();
  }

  Future<void> _listen() async {
    _submitted = false;
    _listenStartedAt = DateTime.now();
    setState(() {
      _phase = _Phase.listening;
      _heard = '';
      _message = null;
    });
    await _stt.listen(
      onResult: _onResult,
      localeId: _localeId,
      listenFor: _listenFor,
      pauseFor: _pauseFor,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() => _heard = r.recognizedWords);
    if (r.finalResult) _submit(r.recognizedWords);
  }

  void _onStatus(String status) {
    // 일부 기기는 최종 결과 없이 'done'만 보낸다. 들은 게 있으면 그걸로 저장한다.
    if (!mounted || _phase != _Phase.listening) return;
    if (DateTime.now().difference(_listenStartedAt) <
        const Duration(milliseconds: 300)) {
      return;
    }
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      if (_heard.trim().isNotEmpty) {
        _submit(_heard);
      } else {
        setState(() {
          _phase = _Phase.error;
          _message = '아무 말도 듣지 못했어요';
        });
      }
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted || _submitted) return;
    if (_heard.trim().isNotEmpty) {
      _submit(_heard);
      return;
    }
    setState(() {
      _phase = _Phase.error;
      _message = e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout'
          ? '아무 말도 듣지 못했어요'
          : '음성 인식 오류가 났어요 (${e.errorMsg})';
    });
  }

  Future<void> _submit(String text) async {
    if (_submitted) return;
    _submitted = true;
    await _stt.stop();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.saving;
      _heard = text;
    });
    try {
      final outcome = await ref.read(voiceRecorderProvider).handleText(text);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = _Phase.done;
        _message = outcome.message;
      });
      await Future<void>.delayed(_closeDelay);
      if (mounted) Navigator.pop(context, outcome.activity);
    } on VoiceRecordException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _phase = _Phase.error;
        _message = e.message;
        _submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listening = _phase == _Phase.listening;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '말로 기록',
                  style: AppTypography.title.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: switch (_phase) {
                      _Phase.listening => () => _stt.stop(),
                      _Phase.error => _listen,
                      _ => null,
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: listening
                            ? colors.onSurface.withValues(alpha: 0.14)
                            : colors.surfaceVariant,
                        border: Border.all(
                          color: listening ? colors.onSurface : colors.outline,
                          width: listening ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        switch (_phase) {
                          _Phase.done => Icons.check_rounded,
                          _Phase.saving => Icons.hourglass_top_rounded,
                          _ => Icons.mic_rounded,
                        },
                        size: 36,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _heard.isEmpty
                      ? (listening ? '듣고 있어요…' : ' ')
                      : '“$_heard”',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurface,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (_message != null)
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: _phase == _Phase.done
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: _phase == _Phase.done
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  )
                else
                  Text(
                    '예) 분유 230ml 먹었어 · 모유 10분 먹었어 · 소변 갈았어\n'
                    '잠들었어 · 깼어 · 목욕했어 · 체온 38도야 · 약 먹었어',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(color: colors.muted),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _textCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    _submitted = false;
                    _submit(v);
                  },
                  style: AppTypography.body.copyWith(color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: '직접 입력: 분유 230ml 먹었어',
                    hintStyle: AppTypography.body.copyWith(
                      color: colors.muted,
                    ),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
