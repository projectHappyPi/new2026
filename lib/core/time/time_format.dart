import 'package:intl/intl.dart';

/// 시:분 (24시간제, 예: 05:32)
String hm(DateTime t) => DateFormat('HH:mm').format(t);

/// 월.일 (예: 8.11)
String md(DateTime t) => DateFormat('M.d').format(t);

/// 경과 시간 h:mm (예: 2:49). 자릿수가 흔들리지 않도록 분은 항상 2자리.
String dur(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// 1시간 미만이면 "35분", 이상이면 dur()과 동일한 h:mm.
String durMin(Duration d) {
  if (d.inHours > 0) return dur(d);
  return '${d.inMinutes}분';
}

/// 요일 포함 날짜 헤더 (예: 8월 11일 화요일)
String dayHeader(DateTime t) => DateFormat('M월 d일 EEEE', 'ko_KR').format(t);

/// 생년월일 기준 만 나이를 개월+일로 계산한다(달력 기준, 28~31일 월 길이 차이를 보정).
(int months, int days) monthsAndDaysSince(DateTime birth, DateTime now) {
  final b = DateTime(birth.year, birth.month, birth.day);
  final n = DateTime(now.year, now.month, now.day);
  var months = (n.year - b.year) * 12 + (n.month - b.month);
  DateTime anchor;
  while (true) {
    final totalMonths = b.month - 1 + months;
    final targetYear = b.year + totalMonths ~/ 12;
    final targetMonth = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = b.day > daysInTargetMonth ? daysInTargetMonth : b.day;
    anchor = DateTime(targetYear, targetMonth, clampedDay);
    if (!anchor.isAfter(n)) break;
    months--;
  }
  final days = n.difference(anchor).inDays;
  return (months, days);
}

/// 헤더에 쓰는 생후 표시. 예: D+250 (8개월 10일), D+10 (10일).
String babyAgeLabel(DateTime birth, DateTime now) {
  final b = DateTime(birth.year, birth.month, birth.day);
  final n = DateTime(now.year, now.month, now.day);
  final dPlus = n.difference(b).inDays;
  final (months, days) = monthsAndDaysSince(birth, now);
  final ageText = months > 0 ? '$months개월 $days일' : '$days일';
  return 'D+$dPlus ($ageText)';
}
