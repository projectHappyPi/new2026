import 'package:flutter_test/flutter_test.dart';
import 'package:parenting_log/data/models/activity.dart';
import 'package:parenting_log/data/models/activity_type.dart';
import 'package:parenting_log/data/models/calendar_event.dart';
import 'package:parenting_log/data/sync/sync_service.dart';
import 'package:parenting_log/features/widgets/widget_config.dart';
import 'package:parenting_log/features/widgets/widget_status.dart';

Activity _a(
  ActivityType type,
  DateTime start, {
  DateTime? end,
  Map<String, dynamic> payload = const {},
}) => Activity(
  id: '${type.name}-${start.millisecondsSinceEpoch}',
  type: type,
  startedAt: start,
  endedAt: end,
  payload: payload,
  createdAt: start,
  updatedAt: start,
);

void main() {
  final t = DateTime(2026, 9, 28, 3, 0);

  test('두 번째 캡처: 모유 끝난 시각 기준, 다음 수유는 최근 간격 평균', () {
    final recent = [
      _a(ActivityType.formula, t.subtract(const Duration(hours: 8))),
      _a(ActivityType.formula, t.subtract(const Duration(hours: 4))),
      _a(
        ActivityType.breast,
        t.subtract(const Duration(minutes: 20)),
        end: t.subtract(const Duration(minutes: 5)),
      ),
      _a(
        ActivityType.sleep,
        t.subtract(const Duration(minutes: 3)),
        payload: {'period': 'night'},
      ),
    ];
    final st = computeWidgetStatus(recent, const WidgetConfig());
    expect(st.feedLabel, '모유');
    expect(st.lastFeedAt, t.subtract(const Duration(minutes: 5)));
    // 간격: 4h, 3h55m → 평균 3h57m30s
    expect(
      st.nextFeedAt,
      t.subtract(const Duration(minutes: 5)).add(
        const Duration(hours: 3, minutes: 57, seconds: 30),
      ),
    );
    expect(st.sleepLabel, '밤잠');
    expect(st.sleeping, isTrue);
  });

  test('고정 간격·"수유" 표기', () {
    final st = computeWidgetStatus(
      [_a(ActivityType.formula, t)],
      const WidgetConfig(
        feedLabel: WidgetFeedLabel.generic,
        nextFeedMode: NextFeedMode.fixed,
        fixedIntervalMin: 150,
      ),
    );
    expect(st.feedLabel, '수유');
    expect(st.nextFeedAt, t.add(const Duration(minutes: 150)));
  });

  test('깬 뒤에는 기상 시각', () {
    final st = computeWidgetStatus([
      _a(ActivityType.sleep, t, end: t.add(const Duration(hours: 1))),
    ], const WidgetConfig());
    expect(st.sleepLabel, '기상');
    expect(st.sleepAt, t.add(const Duration(hours: 1)));
    expect(st.sleeping, isFalse);
  });

  test('relativeText', () {
    expect(relativeText(const Duration(minutes: 48, seconds: 14)), '48분 14초');
    expect(relativeText(const Duration(hours: 3, minutes: 35)), '3시간 35분');
    expect(relativeText(const Duration(seconds: 9)), '9초');
  });

  test('WidgetConfig JSON 왕복', () {
    const c = WidgetConfig(showSleep: false, theme: WidgetTheme.light);
    final back = WidgetConfig.fromJson(c.toJson());
    expect(back.showSleep, isFalse);
    expect(back.theme, WidgetTheme.light);
  });

  test('동기화 JSON 왕복(기록·일정)', () {
    final a = _a(ActivityType.temperature, t, payload: {'celsius': 38.5});
    final back = SyncWire.activityFrom(
      SyncWire.activity(a).cast<String, dynamic>(),
    )!;
    expect(back.celsius, 38.5);
    expect(back.startedAt, t);
    expect(SyncWire.activityFrom({...SyncWire.activity(a), 'type': 'future'}), isNull);

    final e = CalendarEvent(
      id: 'e1',
      title: '예방접종',
      startAt: t,
      endAt: t.add(const Duration(hours: 1)),
      color: EventColor.red,
      createdBy: '아빠',
      createdAt: t,
      updatedAt: t,
    );
    final eb = SyncWire.eventFrom(SyncWire.event(e).cast<String, dynamic>());
    expect(eb.title, '예방접종');
    expect(eb.color, EventColor.red);
    expect(eb.allDay, isFalse);
    expect(eb.occursOn(DateTime(2026, 9, 28)), isTrue);
    expect(eb.occursOn(DateTime(2026, 9, 29)), isFalse);
  });
}
