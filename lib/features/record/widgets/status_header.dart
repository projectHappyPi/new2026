import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/time_format.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/activity_type.dart';
import '../../../providers/activity_provider.dart';
import '../../../providers/baby_profile_provider.dart';
import '../../../providers/running_provider.dart';

/// 수유 대표 시각: 분유는 즉시 기록 시각, 모유는 끝났으면 종료 시각, 진행 중이면 시작 시각.
DateTime _feedingRef(Activity a) =>
    a.type == ActivityType.breast ? (a.endedAt ?? a.startedAt) : a.startedAt;

Activity? _lastFeeding(List<Activity> activities) {
  Activity? last;
  for (final a in activities) {
    if (a.type != ActivityType.formula && a.type != ActivityType.breast) {
      continue;
    }
    if (last == null || _feedingRef(a).isAfter(_feedingRef(last))) last = a;
  }
  return last;
}

/// 최근 N회 텀 평균 ± 오차. 정교한 EMA는 Phase 2.
(DateTime, DateTime)? _predictNextFeeding(
  List<Activity> activities,
  DateTime now,
) {
  final feedings =
      activities
          .where(
            (a) =>
                a.type == ActivityType.formula || a.type == ActivityType.breast,
          )
          .toList()
        ..sort((a, b) => _feedingRef(a).compareTo(_feedingRef(b)));
  if (feedings.length < 2) return null;

  final refs = feedings.map(_feedingRef).toList();
  final recentRefs = refs.length > FeedingPrediction.recentIntervalCount + 1
      ? refs.sublist(refs.length - FeedingPrediction.recentIntervalCount - 1)
      : refs;

  final intervals = <Duration>[];
  for (var i = 1; i < recentRefs.length; i++) {
    intervals.add(recentRefs[i].difference(recentRefs[i - 1]));
  }
  if (intervals.isEmpty) return null;

  final avgMs =
      intervals.fold<int>(0, (sum, d) => sum + d.inMilliseconds) ~/
      intervals.length;
  final avg = Duration(milliseconds: avgMs);
  final center = refs.last.add(avg);
  return (
    center.subtract(FeedingPrediction.errorMargin),
    center.add(FeedingPrediction.errorMargin),
  );
}

class StatusHeader extends ConsumerWidget {
  const StatusHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final recent =
        ref.watch(recentActivitiesProvider).valueOrNull ?? const <Activity>[];
    final today =
        ref.watch(todayActivitiesProvider).valueOrNull ?? const <Activity>[];
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final profile = ref.watch(babyProfileProvider);
    // 온보딩이 먼저 이름·생년월일을 강제하므로 이 시점엔 항상 값이 있다.
    final ageLabel = profile.birthDate != null
        ? babyAgeLabel(profile.birthDate!, now)
        : '';

    final lastFeeding = _lastFeeding(recent);
    final elapsed = lastFeeding == null
        ? null
        : now.difference(_feedingRef(lastFeeding));
    final prediction = _predictNextFeeding(recent, now);

    final todayMl = today
        .where((a) => a.type == ActivityType.formula)
        .fold<int>(0, (sum, a) => sum + (a.ml ?? 0));
    final todaySleep = today
        .where((a) => a.type == ActivityType.sleep)
        .fold<Duration>(Duration.zero, (sum, a) => sum + a.elapsed(now));
    final todayDiaper = today
        .where((a) => a.type == ActivityType.diaper)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                profile.name ?? '',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ageLabel,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono.tabular.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '마지막 수유 이후',
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              elapsed == null ? '--:--' : dur(elapsed),
              style: AppTypography.statusNumber.tabular.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '경과',
              style: AppTypography.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (prediction != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '다음 수유 예상 ${hm(prediction.$1)}~${hm(prediction.$2)}',
              style: AppTypography.body.tabular.copyWith(color: colors.muted),
            ),
          ),
        const SizedBox(height: 16),
        Divider(height: 1, color: colors.outlineSoft),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Metric(label: '오늘 수유', value: '${todayMl}ml'),
            ),
            _VDivider(color: colors.outlineSoft),
            Expanded(
              child: _Metric(label: '수면', value: durMin(todaySleep)),
            ),
            _VDivider(color: colors.outlineSoft),
            Expanded(
              child: _Metric(label: '기저귀', value: '$todayDiaper'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.metricValue.tabular.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.label.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  final Color color;

  const _VDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(width: 1, height: 32, child: ColoredBox(color: color)),
    );
  }
}
