import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/activity_provider.dart';
import '../../providers/baby_profile_provider.dart';
import '../../providers/running_provider.dart';
import 'widget_config.dart';
import 'widget_status.dart';

/// 설정 > 위젯. 위의 미리보기는 실제 위젯과 같은 규칙으로 그린다.
class WidgetSettingsScreen extends ConsumerWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cfg = ref.watch(widgetConfigProvider);
    final n = ref.read(widgetConfigProvider.notifier);

    Widget section(String t) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Text(
        t,
        style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
      ),
    );
    Widget sw(String label, bool v, ValueChanged<bool> on, {String? sub}) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: AppTypography.body.copyWith(color: colors.onSurface)),
          subtitle: sub == null
              ? null
              : Text(sub, style: AppTypography.label.copyWith(color: colors.muted)),
          value: v,
          onChanged: on,
        );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('위젯', style: AppTypography.title.copyWith(color: colors.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const _Preview(),
          const SizedBox(height: 12),
          Text(
            '홈 화면을 길게 눌러 위젯 추가 → "튼튼이"에서 상태 위젯(작게·중간·잠금화면)과 달력 위젯(크게)을 고를 수 있어요.',
            style: AppTypography.label.copyWith(color: colors.muted),
          ),
          section('표시 항목'),
          sw('아기 이름', cfg.showName, (v) => n.update((c) => c.copyWith(showName: v))),
          sw('D+일수', cfg.showDday, (v) => n.update((c) => c.copyWith(showDday: v))),
          sw('마지막 수유', cfg.showFeeding, (v) => n.update((c) => c.copyWith(showFeeding: v))),
          if (cfg.showFeeding) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<WidgetFeedLabel>(
                segments: const [
                  ButtonSegment(value: WidgetFeedLabel.lastType, label: Text('모유·분유로')),
                  ButtonSegment(value: WidgetFeedLabel.generic, label: Text('"수유"로')),
                ],
                selected: {cfg.feedLabel},
                onSelectionChanged: (s) => n.update((c) => c.copyWith(feedLabel: s.first)),
              ),
            ),
            sw('다음 수유까지 남은 시간', cfg.showNextFeed,
                (v) => n.update((c) => c.copyWith(showNextFeed: v))),
            if (cfg.showNextFeed) ...[
              SegmentedButton<NextFeedMode>(
                segments: const [
                  ButtonSegment(value: NextFeedMode.auto, label: Text('최근 간격 평균')),
                  ButtonSegment(value: NextFeedMode.fixed, label: Text('고정 간격')),
                ],
                selected: {cfg.nextFeedMode},
                onSelectionChanged: (s) => n.update((c) => c.copyWith(nextFeedMode: s.first)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cfg.nextFeedMode == NextFeedMode.fixed
                            ? '수유 간격'
                            : '기록이 부족할 때 쓰는 간격',
                        style: AppTypography.body.copyWith(color: colors.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: '15분 줄이기',
                      onPressed: cfg.fixedIntervalMin <= 60
                          ? null
                          : () => n.update((c) => c.copyWith(fixedIntervalMin: c.fixedIntervalMin - 15)),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Text(
                      '${cfg.fixedIntervalMin ~/ 60}시간${cfg.fixedIntervalMin % 60 == 0 ? '' : ' ${cfg.fixedIntervalMin % 60}분'}',
                      style: AppTypography.mono.tabular.copyWith(color: colors.onSurface),
                    ),
                    IconButton(
                      tooltip: '15분 늘리기',
                      onPressed: cfg.fixedIntervalMin >= 480
                          ? null
                          : () => n.update((c) => c.copyWith(fixedIntervalMin: c.fixedIntervalMin + 15)),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ],
          sw('수면 (자는 중 / 기상)', cfg.showSleep, (v) => n.update((c) => c.copyWith(showSleep: v))),
          section('달력 위젯'),
          sw('오른쪽 위에 수유·수면 표시', cfg.calendarShowStatus,
              (v) => n.update((c) => c.copyWith(calendarShowStatus: v)),
              sub: '끄면 그 자리에 다가오는 일정이 나와요'),
          sw('왼쪽 위에 오늘 일정', cfg.calendarShowToday,
              (v) => n.update((c) => c.copyWith(calendarShowToday: v))),
          section('배경'),
          SegmentedButton<WidgetTheme>(
            segments: const [
              ButtonSegment(value: WidgetTheme.dark, label: Text('어둡게')),
              ButtonSegment(value: WidgetTheme.light, label: Text('밝게')),
              ButtonSegment(value: WidgetTheme.system, label: Text('시스템')),
            ],
            selected: {cfg.theme},
            onSelectionChanged: (s) => n.update((c) => c.copyWith(theme: s.first)),
          ),
        ],
      ),
    );
  }
}

/// 두 번째 캡처와 같은 모양: 이름 · D+ / 모유 48분 14초 전 / → 3시간 35분 남음 / 밤잠 47분 48초 전
class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(widgetConfigProvider);
    final recent = ref.watch(recentActivitiesProvider).valueOrNull ?? const [];
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final baby = ref.watch(babyProfileProvider);
    final st = computeWidgetStatus(recent, cfg);

    final dark = cfg.theme != WidgetTheme.light;
    final fg = dark ? Colors.white : const Color(0xFF1B1B1F);
    final dim = dark ? Colors.white60 : Colors.black54;
    final bg = dark ? const Color(0xFF26221F) : const Color(0xFFF4F1EC);

    final dday = baby.birthDate == null
        ? null
        : DateTime(now.year, now.month, now.day)
              .difference(baby.birthDate!)
              .inDays;
    TextStyle big(Color c) => TextStyle(
      color: c,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cfg.showName || cfg.showDday)
            Row(
              children: [
                if (cfg.showName)
                  Text(
                    baby.name ?? '튼튼이',
                    style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                const Spacer(),
                if (cfg.showDday && dday != null)
                  Text('D+$dday', style: TextStyle(color: dim, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          const SizedBox(height: 6),
          if (cfg.showFeeding)
            st.lastFeedAt == null
                ? Text('수유 기록 없음', style: TextStyle(color: dim))
                : Text.rich(TextSpan(children: [
                    TextSpan(text: '${st.feedLabel}  ', style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
                    TextSpan(text: '${relativeText(now.difference(st.lastFeedAt!))} 전', style: big(fg)),
                  ])),
          if (cfg.showFeeding && cfg.showNextFeed && st.nextFeedAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                st.nextFeedAt!.isAfter(now)
                    ? '→ ${relativeText(st.nextFeedAt!.difference(now))} 남음'
                    : '→ ${relativeText(now.difference(st.nextFeedAt!))} 지남',
                style: TextStyle(color: dim, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          if (cfg.showSleep && st.sleepAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${st.sleepLabel}  ', style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
                TextSpan(text: '${relativeText(now.difference(st.sleepAt!))} 전', style: big(fg)),
              ])),
            ),
        ],
      ),
    );
  }
}
