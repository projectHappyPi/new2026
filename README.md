# 튼튼이 (parenting_log)

새벽 3시, 아기를 안은 채 한 손으로 3초 안에 기록하는 육아 기록 앱. Flutter · Riverpod · Drift(SQLite), 서버 없음.

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
flutter run                              # 갤럭시 USB 디버깅
```

목업: `docs/mockup/index.html`을 브라우저로 열기.

## iOS 빌드 전 한 번만 (Codemagic)

1. Apple Developer 포털에서 App ID `com.happypi.parentingLog`에 **App Groups** capability 추가, 그룹 `group.com.happypi.parentingLog` 생성·연결 후 프로비저닝 프로필 재발급.
2. Siri capability는 필요 없음(App Shortcuts). 배포 타깃 iOS 17.0.
3. 시리 숫자 범위는 `scripts/gen_ios_voice_enums.py`에서 바꾸고 다시 실행.
4. 홈 화면 위젯(`ios/widget_extension_source/`)은 아직 Xcode 타깃 미연결.
