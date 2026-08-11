import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/app.dart';
import 'package:parenting_log/data/db/database.dart';
import 'package:parenting_log/providers/activity_provider.dart';
import 'package:parenting_log/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('앱이 4개 탭과 함께 기록 화면으로 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const ParentingLogApp(),
      ),
    );
    await tester.pump();

    expect(find.text('기록'), findsWidgets);
    expect(find.text('타임라인'), findsOneWidget);
    expect(find.text('패턴'), findsWidgets);
    expect(find.text('설정'), findsOneWidget);

    // 홈 화면의 1초 틱(nowTickerProvider)과 drift 스트림 정리용 타이머가 살아있는
    // 채로 테스트가 끝나면 "Timer가 남아있다" 단언에 걸리므로, 트리를 비워 정리하고
    // 한 번 더 pump해 정리용 타이머가 흘러가게 한다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
