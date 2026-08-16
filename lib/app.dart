import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'providers/baby_profile_provider.dart';
import 'providers/running_provider.dart';
import 'providers/settings_provider.dart';

class ParentingLogApp extends ConsumerWidget {
  const ParentingLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // 야간 자동 전환 구간을 실시간으로 반영하기 위해 앱 전역 1초 틱을 함께 본다.
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    // 아기 이름·생년월일이 없으면(첫 실행) 온보딩부터 보여준다.
    final profileComplete = ref.watch(
      babyProfileProvider.select((p) => p.isComplete),
    );

    return MaterialApp(
      title: '육아 기록',
      debugShowCheckedModeBanner: false,
      themeMode: resolveThemeMode(settings, now),
      theme: lightTheme,
      darkTheme: darkTheme,
      home: profileComplete ? const AppShell() : const OnboardingScreen(),
    );
  }
}
