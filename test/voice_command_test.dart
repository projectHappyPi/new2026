import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/core/voice/voice_command.dart';
import 'package:parenting_log/data/models/activity_type.dart';

/// test/voice_cases.json은 JS 목업 파서(docs/mockup/voice-parser.test.js)와
/// 같이 쓰는 케이스 표다. 두 구현이 같은 규칙을 지키는지 한 곳에서 관리한다.
void main() {
  final json =
      jsonDecode(File('test/voice_cases.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (json['cases'] as List).cast<Map<String, dynamic>>();

  group('parseVoiceCommand (voice_cases.json)', () {
    for (final c in cases) {
      final say = c['say'] as String;
      final expected = c['expect'] as Map<String, dynamic>?;
      test('"$say"', () {
        final r = parseVoiceCommand(say, babyName: c['babyName'] as String?);
        if (expected == null) {
          expect(r.isOk, isFalse, reason: '${r.command}');
          expect(r.error, isNotEmpty);
          return;
        }
        expect(r.isOk, isTrue, reason: r.error);
        final cmd = r.command!;
        expect(cmd.kind.name, expected['kind']);
        expect(cmd.ml, expected['ml']);
        expect(cmd.minutes, expected['minutes']);
        expect(cmd.celsius, (expected['celsius'] as num?)?.toDouble());
        expect(cmd.diaper?.name, expected['diaper']);
        expect(cmd.medicine, expected['medicine']);
      });
    }
  });

  group('koreanNumber', () {
    test('단위 읽기', () {
      expect(koreanNumber('이백삼십'), 230);
      expect(koreanNumber('삼십칠'), 37);
      expect(koreanNumber('십'), 10);
      expect(koreanNumber('백오십'), 150);
    });
    test('자리 읽기', () => expect(koreanNumber('이삼공'), 230));
  });

  group('confirmation', () {
    test('확인 문구', () {
      expect(
        const VoiceCommand(VoiceCommandKind.formula, ml: 230).confirmation,
        '분유 230ml 기록했어요',
      );
      expect(
        const VoiceCommand(
          VoiceCommandKind.diaper,
          diaper: DiaperSub.poop,
        ).confirmation,
        '대변 기록했어요',
      );
      expect(
        const VoiceCommand(
          VoiceCommandKind.temperature,
          celsius: 38.0,
        ).confirmation,
        '체온 38도 기록했어요',
      );
    });
  });
}
