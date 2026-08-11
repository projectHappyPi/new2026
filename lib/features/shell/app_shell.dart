import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/running_provider.dart';
import '../pattern/pattern_screen.dart';
import '../record/record_screen.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.edit_note_rounded, label: '기록'),
    (icon: Icons.view_list_rounded, label: '타임라인'),
    (icon: Icons.donut_large_rounded, label: '패턴'),
    (icon: Icons.settings_rounded, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    // 앱이 켜져 있는 동안 진행 중 기록의 12시간 미종료 보호를 계속 감시한다.
    ref.watch(autoEndGuardProvider);

    final colors = context.colors;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          RecordScreen(),
          TimelineScreen(),
          PatternScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineSoft)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
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

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.onSurface : colors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.monoSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
