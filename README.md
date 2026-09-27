# 튼튼이 (parenting_log)

새벽 3시, 아기를 안은 채 한 손으로 3초 안에 기록하는 육아 기록 앱. Flutter · Riverpod · Drift(SQLite).
엄마·아빠 폰은 작은 동기화 서버(`server/`)로 기록과 달력 일정을 공유한다.

## 가족 공유 (동기화)

- 서버: `server/` — Docker + Cloudflare Tunnel, 설치는 [server/README.md](server/README.md).
- 앱 **설정 › 가족 공유**에 서버 주소 · 가족 코드 · 내 이름(엄마/아빠)을 두 폰 모두 입력.
- 30초마다 + 기록 직후 동기화. 같은 기록은 마지막 수정이 이김, 삭제도 전파. 예시(시드) 기록은 올리지 않음.

## 달력

- 5번째 탭 **달력**: 월 그리드에 일정 막대, 날짜를 누르면 그날 목록, ＋로 추가(제목·종일·시간·색·메모).
- 일정에는 작성자(엄마/아빠)가 붙고 상대 폰에도 뜬다.

## 위젯

| | iPhone | Galaxy |
|---|---|---|
| 튼튼이 상태 | 작게·중간·잠금화면. "모유 48분 14초 전 / → 3시간 35분 남음 / 밤잠 47분 48초 전" 초 단위 | 2×2. 같은 구성, 시간은 "48:14 전" 형식(안드로이드 위젯 제약) + 🎤 말로 기록 |
| 튼튼이 달력 | 크게. 왼쪽 위 오늘 일정, 오른쪽 위 상태, 아래 한 달 | 4×4. 같은 구성 |

표시 항목·다음 수유 계산(최근 간격 평균/고정)·배경은 **설정 › 위젯**에서.
iOS 위젯 타깃: `ios/TunteuniWidget/` (번들 ID `com.happypi.parentingLog.TunteuniWidget`).

## 말로 기록

| 말하기 | 저장 |
|---|---|
| 튼튼이 분유 230ml 먹었어 | 분유 230ml |
| 튼튼이 모유 10분 먹었어 | 지금 끝난 10분 모유 구간 |
| 튼튼이 이유식 150ml 먹었어 | 이유식 150ml |
| 튼튼이 소변 갈았어 / 대변 갈았어 | 기저귀 소변 / 대변 |
| 튼튼이 잠들었어 → 깼어 | 수면 시작 → 같은 기록 종료 |
| 튼튼이 목욕했어 | 목욕 |
| 튼튼이 체온 38도야 | 체온 38℃ (38도 5부, 37.5도도 가능) |
| 튼튼이 약 먹었어 | 투약 (해열제 등 이름도 인식) |

- **앱 안 🎤 버튼 (iOS·Android 공통)**: 기록 화면 엄지 궤적 6번째 자리. 확인 없이 저장하고 5초 되돌리기 토스트.
- **iPhone 시리**: "시리야, 튼튼이 분유 230ml 먹었어" → 앱을 열지 않고 App Group 공유 DB에 저장 (iOS 17+). 앱 이름이 `튼튼이`라 설치만 하면 문구가 등록됨.
- **Android**: 앱 아이콘 길게 누르기 → "말로 기록" (홈 화면에 끌어다 두면 한 번에 듣기 시작). 딥링크 `tunteuni://voice`.

인식 규칙: `lib/core/voice/voice_command.dart` (목업용 JS 사본 `docs/mockup/voice-parser.js`, 공통 케이스 `test/voice_cases.json`).

## 실행

```bash
flutter pub get
flutter test
node docs/mockup/voice-parser.test.js   # JS 파서도 같은 케이스로 확인
(cd server && npm test)                 # 동기화 서버
flutter run                              # 갤럭시 USB 디버깅
```

목업: `docs/mockup/index.html`을 브라우저로 열기.

## iOS 빌드 전 한 번만 (Codemagic)

1. Apple Developer 포털에서 App ID `com.happypi.parentingLog`에 **App Groups** capability 추가, 그룹 `group.com.happypi.parentingLog` 생성·연결 후 프로비저닝 프로필 재발급.
2. Siri capability는 필요 없음(App Shortcuts). 배포 타깃 iOS 17.0.
3. 시리 숫자 범위는 `scripts/gen_ios_voice_enums.py`에서 바꾸고 다시 실행.
4. 위젯용 번들 ID `com.happypi.parentingLog.TunteuniWidget`도 등록하고 같은 App Group을 켠 뒤 프로비저닝 프로필을 만들어 Codemagic에 추가(앱·위젯 프로필 2개).
