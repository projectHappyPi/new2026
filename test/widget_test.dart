import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/app.dart';
import 'package:parenting_log/data/db/database.dart';
import 'package:parenting_log/providers/activity_provider.dart';
import 'package:parenting_log/providers/baby_profile_provider.dart';
import 'package:parenting_log/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp(SharedPreferences prefs, AppDatabase db) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
    ],
    child: const ParentingLogApp(),
  );
}

/// 홈 화면의 1초 틱(nowTickerProvider)과 drift 스트림 정리용 타이머가 살아있는
/// 채로 테스트가 끝나면 "Timer가 남아있다" 단언에 걸리므로, 트리를 비워 정리하고
/// 한 번 더 pump해 정리용 타이머가 흘러가게 한다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('아기 프로필이 있으면 4개 탭과 함께 기록 화면으로 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kBabyNameKey: '튼튼이',
      kBabyBirthDateKey: DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_buildApp(prefs, db));
    await tester.pump();

    expect(find.text('기록'), findsWidgets);
    expect(find.text('타임라인'), findsOneWidget);
    expect(find.text('패턴'), findsWidgets);
    expect(find.text('설정'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('아기 프로필이 없으면 온보딩부터 보여주고, 저장하면 앱 셸로 넘어간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_buildApp(prefs, db));
    await tester.pump();

    expect(find.text('아기 정보를 알려주세요'), findsOneWidget);
    expect(find.text('타임라인'), findsNothing);

    await tester.enterText(find.byType(TextField), '튼튼이');
    await tester.tap(find.text('생년월일 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('아기 정보를 알려주세요'), findsNothing);
    expect(find.text('타임라인'), findsOneWidget);

    await _settle(tester);
  });
}
