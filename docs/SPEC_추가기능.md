# 베베로그 추가 기능 명세

Claude Code 작업용 명세. 대상 기능 3가지.

1. 관리자 스토리지 대시보드
2. 홈 PC 업로드 환경 구성 (환경변수 기반)
3. 카카오톡 공유

---

## 1. 관리자 스토리지 대시보드

### 1.1 용량 산출 방식

세 가지 수치를 구분해서 다룬다. 셋을 섞으면 "왜 숫자가 안 맞지" 하는 상황이 반드시 생긴다.

| 구분 | 산출 | 용도 |
|---|---|---|
| 디스크 실사용 | `statvfs(STORAGE_CHECK_PATH)` | 3단계 임계치 판정 기준 |
| 서비스 사용량 | `SUM(media.bytes) + SUM(media_variants.bytes)` | 사진첩별 순위, 증가 추이 |
| 휴지통 점유 | `SUM(media.bytes) WHERE deleted_at IS NOT NULL` | 정리 유도 |

```ts
import checkDiskSpace from 'check-disk-space';

async function getStorageStatus() {
  const disk = await checkDiskSpace(env.STORAGE_CHECK_PATH);
  const total = env.STORAGE_TOTAL_BYTES_OVERRIDE || disk.size;
  const quota = env.STORAGE_QUOTA_BYTES || total;
  const used  = total - disk.free;

  const percent = (used / quota) * 100;
  const level =
    percent >= env.STORAGE_BLOCK_PERCENT ? 'block' :
    percent >= env.STORAGE_ALERT_PERCENT ? 'alert' :
    percent >= env.STORAGE_WARN_PERCENT  ? 'warn'  : 'ok';

  return { total, quota, used, free: disk.free, percent, level };
}
```

> Docker 주의: 컨테이너 안에서 `df /` 를 하면 오버레이FS 용량이 나온다.
> `STORAGE_CHECK_PATH` 는 반드시 호스트 디스크가 마운트된 볼륨 내부 경로여야 한다.

### 1.2 API

```
GET  /admin/storage
  → { total, quota, used, free, percent, level,
      trashBytes, mediaCount, albumCount,
      trend: { dailyAvgBytes, daysRemaining },
      topAlbums: [{ albumId, title, owner, bytes, mediaCount }] }

GET  /admin/storage/history?days=30
  → storage_stats 일별 시계열

POST /admin/storage/recalculate     // 전체 재집계 (수동)
POST /admin/storage/purge-trash     // 만료 대기 없이 휴지통 즉시 비우기
```

`daysRemaining` = `free / dailyAvgBytes`. 최근 30일 `storage_stats` 증가분 평균으로 계산하고, 데이터가 7일 미만이면 `null` 을 반환해 UI에서 "산출 중"으로 표시한다.

### 1.3 배치

```
STORAGE_CHECK_CRON (기본 매시 정각)
  1. getStorageStatus()
  2. storage_stats 당일 레코드 upsert
  3. level 이 이전보다 상승했고,
     마지막 동일 level 알림으로부터 STORAGE_ALERT_COOLDOWN_HOURS 경과 시 알림 발송
       warn  → ADMIN_ALERT_EMAIL
       alert → ADMIN_ALERT_EMAIL + 전체 개설자 앱 내 배너 ON
       block → 위 + 업로드 API 차단 플래그 ON
  4. level 이 하락하면 차단 플래그 및 배너 해제
```

### 1.4 업로드 차단 지점

업로드 시작 API에서 매번 확인한다. 배치 결과만 믿으면 최대 1시간 지연이 생긴다.

```
POST /albums/:id/uploads/init
  ① 캐시된 level 조회 (Redis, TTL 60초)
  ② level === 'block' → 507 Insufficient Storage
     { code: 'STORAGE_FULL', message: '서버 저장 공간이 부족합니다' }
  ③ free - 요청 파일 총 크기 < 여유분(1GB) → 동일 에러
```

클라이언트는 이 에러를 받으면 해당 파일을 실패 큐에 `서버 용량 부족` 사유로 넣고 재시도 가능 상태로 둔다.

### 1.5 화면 (S20 스토리지 탭)

```
스토리지
─────────────────────────────────────────
  ████████████████░░░░░░  1.24TB / 2.00TB
  62% 사용 중 · 정상

  여유 공간   762GB
  휴지통      48GB      [ 비우기 ]
  일 평균 증가 6.2GB
  소진 예상   약 4개월 (2026년 12월)
─────────────────────────────────────────
  [최근 30일 증가 추이 라인 차트]
─────────────────────────────────────────
  사진첩별 사용량
  1. 우리아기   경민   82.4GB   3,120개
  2. 가족여행   민수   14.1GB     540개
  ...
─────────────────────────────────────────
  임계치   주의 80% / 경고 90% / 차단 95%
```

- 게이지 색상: ok 회색 / warn 앰버 / alert 주황 / block 적색
- block 상태일 때 상단에 "신규 업로드가 차단되었습니다" 배너 고정

---

## 2. 홈 PC 업로드 환경 구성

### 2.1 반드시 결정해야 하는 값

`.env.example` 의 ★ 표시 항목. 나머지는 기본값으로 동작한다.

| 변수 | 설명 | 확인 방법 |
|---|---|---|
| `MEDIA_ROOT` | 원본 저장 폴더 | 여유 큰 드라이브 선택 |
| `STORAGE_CHECK_PATH` | 용량 측정 기준 경로 | `MEDIA_ROOT` 와 같은 볼륨 |
| `APP_BASE_URL` | 외부 접속 주소 | Cloudflare Tunnel 도메인 |
| `DB_PASSWORD` | MySQL 비밀번호 | 직접 지정 |
| `JWT_SECRET` / `MEDIA_SIGN_SECRET` | 서명 키 | `openssl rand -hex 32` |
| `KAKAO_REST_API_KEY` 외 3종 | 카카오 앱 키 | Kakao Developers 앱 생성 |
| `ADMIN_KAKAO_IDS` | 관리자 계정 | 최초 로그인 후 DB 확인 |
| `ADMIN_ALERT_EMAIL` | 경고 수신 주소 | 본인 메일 |
| `SMTP_USER` / `SMTP_PASSWORD` | 메일 발송 | Gmail 앱 비밀번호 |

### 2.2 폴더 구조

```
/data
 ├─ media/      원본        (백업 필수)
 ├─ variants/   썸네일·변환본 (재생성 가능, 백업 제외 가능)
 ├─ trash/      휴지통
 └─ tmp/        업로드 청크  (재부팅 시 삭제 가능)
```

저장 경로 규칙: `{MEDIA_ROOT}/{albumId}/{yyyy}/{mm}/{uuid}.{ext}`

### 2.3 docker-compose 볼륨 예시

```yaml
services:
  api:
    env_file: .env
    volumes:
      - /mnt/photos/media:/data/media
      - /mnt/photos/variants:/data/variants
      - /mnt/photos/trash:/data/trash
      - /mnt/photos/tmp:/data/tmp
```

호스트 `/mnt/photos` 가 실제 저장 디스크. `STORAGE_CHECK_PATH=/data` 로 두면
이 볼륨의 용량이 측정된다.

### 2.4 사전 점검 체크리스트

- [ ] 저장 드라이브 여유 공간 확인 (`df -h`)
- [ ] `MEDIA_ROOT` 쓰기 권한 (컨테이너 UID와 폴더 소유자 일치)
- [ ] ffmpeg / ffprobe 설치 및 경로 확인
- [ ] MySQL `max_allowed_packet`, `innodb_buffer_pool_size` 조정
- [ ] nginx `client_max_body_size` — 청크 크기보다 크게 (예: 10m)
- [ ] Cloudflare Tunnel 무료 플랜은 요청당 100MB 제한 → 청크 5MB 이므로 문제 없음
- [ ] PC 절전 해제, 재부팅 시 Docker 자동 시작 (`restart: unless-stopped`)
- [ ] 외장 HDD rsync 백업 cron 등록

### 2.5 초기 실행 순서

```bash
cp .env.example .env
# .env 의 ★ 항목 채우기
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # MEDIA_SIGN_SECRET

docker compose up -d mysql redis
npm run migration:run
docker compose up -d

# 최초 카카오 로그인 후
mysql> SELECT id, kakao_id, nickname FROM users;
# 해당 kakao_id 를 ADMIN_KAKAO_IDS 에 넣고 재시작
```

---

## 3. 카카오톡 공유

### 3.1 전제: 사진 자체는 공유하지 않는다

카카오톡 공유 메시지의 썸네일은 카카오 서버가 이미지 URL을 직접 가져간다.
비공개 사진의 URL을 그대로 넣으면 **인증 없이 접근 가능한 상태여야 하므로
서비스의 비공개 원칙이 깨진다.**

따라서 공유는 **사진이 아니라 사진첩으로 가는 링크**를 보낸다.

| 공유 대상 | 링크 | 썸네일 |
|---|---|---|
| 사진첩 초대 | `/invite/{token}` | 앱 기본 커버 이미지 (고정, 공개) |
| 특정 날짜 그룹 | `/albums/{id}/days/{date}` | 앱 기본 커버 이미지 |
| 개별 사진 | `/albums/{id}/media/{mediaId}` | 앱 기본 커버 이미지 |

링크를 받은 사람이 열면 로그인 → 멤버 여부 확인 → 멤버면 해당 위치로 이동,
아니면 초대 랜딩(S17)이 뜬다. 링크만으로는 아무것도 볼 수 없다.

> 정식 미리보기 이미지를 쓰고 싶다면, 개설자가 사진첩 설정에서 명시적으로
> "공유 미리보기 사용"을 켰을 때만 해당 커버 사진의 저해상도(400px) 블러 처리본을
> `/public/preview/{albumId}.jpg` 로 별도 생성해 공개한다. v1 범위에서는 제외.

### 3.2 사전 준비

- Kakao Developers > 플랫폼 > Web 에 `WEB_BASE_URL` 도메인 등록 (미등록 시 공유 실패)
- Android/iOS 플랫폼에 패키지명·번들ID 등록
- 카카오톡 공유(구 카카오링크)는 **무료**, 비즈앱 전환 불필요
- 사이트 도메인 등록 후 `KAKAO_JS_KEY` 로 초기화

### 3.3 구현

**Flutter 앱**

```dart
// pubspec: kakao_flutter_sdk_share, kakao_flutter_sdk_template

Future<void> shareAlbum({
  required int albumId,
  required String title,
  required String description,
  String? path,            // 예: /albums/12/media/901
}) async {
  final url = '${Env.webBaseUrl}${path ?? '/albums/$albumId'}';

  final template = FeedTemplate(
    content: Content(
      title: title,                       // "우리아기"
      description: description,           // "6개월 11일 · 사진 51장"
      imageUrl: Uri.parse(Env.shareCoverImageUrl),  // 공개 고정 이미지
      link: Link(webUrl: Uri.parse(url), mobileWebUrl: Uri.parse(url)),
    ),
    buttons: [
      Button(
        title: '사진첩 열기',
        link: Link(
          webUrl: Uri.parse(url),
          mobileWebUrl: Uri.parse(url),
          androidExecutionParams: {'path': path ?? '/albums/$albumId'},
          iosExecutionParams: {'path': path ?? '/albums/$albumId'},
        ),
      ),
    ],
  );

  if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
    final uri = await ShareClient.instance.shareDefault(template: template);
    await ShareClient.instance.launchKakaoTalk(uri);
  } else {
    // 카카오톡 미설치 → 시스템 공유 시트로 폴백
    await Share.share(url);
  }
}
```

**Flutter Web**

```dart
// kakao_flutter_sdk_share 는 웹도 지원. KakaoSdk.init(javaScriptAppKey: ...)
// 공유 불가 환경이면 링크 복사로 폴백
```

### 3.4 화면 반영

**S06 미디어 뷰어 [⋮] 메뉴**

```
┌──────────────────────────┐
│  카카오톡으로 공유         │
│  링크 복사                │
│  원본 다운로드            │
│  ─────────────────────    │
│  커버로 지정      (개설자) │
│  삭제             (개설자) │
└──────────────────────────┘
```

공유 시트 진입 시 안내 문구:
`받는 사람이 멤버가 아니면 참여 신청 화면이 열립니다`

**S04 타임라인 카드 [⋮]** 에도 `이 날짜 공유` 추가.

### 3.5 딥링크 처리

```
go_router:
  /albums/:id
  /albums/:id/days/:date
  /albums/:id/media/:mediaId
  /invite/:token

진입 시 순서
  ① 로그인 여부 → 미로그인이면 카카오 로그인 후 원래 경로 복귀
  ② 멤버 여부 조회
  ③ 멤버면 해당 화면, 아니면 초대 랜딩(S17)
  ④ 삭제된 미디어면 "삭제된 사진입니다" 안내 후 타임라인으로
```

앱 미설치 상태에서 링크를 열면 웹으로 뜨므로, Flutter Web 이 있으면
별도 앱 설치 유도 없이 그대로 동작한다.

### 3.6 추가 환경변수

```
# 카카오 공유
SHARE_COVER_IMAGE_URL=https://bebelog.example.com/static/share-cover.png
SHARE_ENABLED=true
```

`share-cover.png` 는 인증 없이 접근 가능한 정적 파일이어야 한다 (800x400 권장).
아기 사진이 아닌 앱 로고·일러스트를 사용한다.

### 3.7 로그

공유 버튼 클릭도 `access_logs` 에 `action='share'` 로 기록해 개설자가
"누가 이 사진첩 링크를 공유했는지" 확인할 수 있게 한다.

---

## 작업 순서 제안

1. `.env` 로딩 + 설정 검증 모듈 (필수값 누락 시 부팅 실패)
2. 저장 경로 초기화 및 쓰기 권한 확인
3. `getStorageStatus()` + `GET /admin/storage`
4. 업로드 init API 에 차단 로직 연결
5. `storage_stats` 배치 + 알림 메일
6. 관리자 스토리지 탭 UI
7. 카카오 공유 (딥링크 라우팅 → 공유 템플릿 → 메뉴 연결)
