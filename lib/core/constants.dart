/// 궤적 기하 상수와 각 시트의 프리셋 값을 한 곳에 모은다.
/// 매직 넘버가 위젯 코드 곳곳에 흩어지지 않도록 여기서만 정의한다.
library;

/// 홈 화면 엄지 궤적(thumb arc) 배치 기하.
class ThumbArc {
  const ThumbArc._();

  /// 화면 우측(또는 좌측) 끝에서 피벗까지 거리.
  static const double pivotFromRight = 48;

  /// 하단 탭바 위에서 피벗까지 거리.
  static const double pivotFromBottom = 88;

  static const double innerRadius = 128;
  static const double outerRadius = 216;
  static const double buttonSize = 64;

  /// 반시계, x축 기준 각도(도). index % 3으로 안쪽/바깥쪽 3개에 재사용된다.
  static const List<double> angles = [100, 141, 181];
}

/// 분유 시트: 프리셋 칩 + 슬라이더 범위.
class FormulaPresets {
  const FormulaPresets._();

  static const List<int> presets = [120, 150, 180, 200, 230];
  static const int min = 60;
  static const int max = 260;
  static const int step = 5;
  static const int defaultMl = 150;
}

/// 기저귀 시트: 대변 계열을 골랐을 때만 노출되는 묽기 칩.
class DiaperTextures {
  const DiaperTextures._();

  static const List<String> textures = ['된편', '보통', '묽음', '물똥'];
  static const String defaultTexture = '보통';
}

/// 이유식 시트 기본 식재료/섭취 정도.
class SolidDefaults {
  const SolidDefaults._();

  static const List<String> foods = ['쌀미음', '고구마', '단호박', '사과', '바나나'];
  static const List<String> amounts = ['조금', '절반', '대부분', '완식'];
  static const int recentFoodCount = 5;
}

/// 수면·모유 시트: 시작 시각 칩(분 단위 과거 오프셋).
class StartOffsets {
  const StartOffsets._();

  static const List<int> minutesAgo = [0, 5, 15, 30];
}

/// 진행 중 기록의 미종료 보호 임계값.
class RunningGuard {
  const RunningGuard._();

  static const Duration maxDuration = Duration(hours: 12);
}

/// 실행 취소 토스트 표시 시간(위젯 이름과 겹치지 않도록 Timing 접미사를 둔다).
class UndoToastTiming {
  const UndoToastTiming._();

  static const Duration visibleDuration = Duration(seconds: 5);
}

/// 짧은 탭 저장 직후 버튼이 체크 표시로 바뀌는 시간.
class SavedCheckmark {
  const SavedCheckmark._();

  static const Duration visibleDuration = Duration(milliseconds: 1500);
}

/// 길게 누름으로 상세 시트를 여는 기준 시간.
class LongPress {
  const LongPress._();

  static const Duration threshold = Duration(milliseconds: 500);
}

/// 다음 수유 예상: 최근 N회 텀 평균 ± 오차.
class FeedingPrediction {
  const FeedingPrediction._();

  static const int recentIntervalCount = 3;
  static const Duration errorMargin = Duration(minutes: 25);
}

/// 패턴 화면에서 히트맵에 표시하는 일수.
class PatternWindow {
  const PatternWindow._();

  static const int heatmapDays = 14;
}

/// 타임라인에서 불러오는 기간.
class TimelineWindow {
  const TimelineWindow._();

  static const int days = 7;
}
