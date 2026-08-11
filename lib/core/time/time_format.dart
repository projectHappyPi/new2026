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
