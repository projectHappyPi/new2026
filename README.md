# 베베로그 (BebeLog)

가족과 함께 보는 우리 아이 사진첩 — 사진/영상 업로드, 사진첩 초대, 관리자 스토리지 대시보드, 카카오톡 공유를 갖춘 웹 앱입니다.

Next.js(App Router) + SQLite(Prisma) 기반의 단일 프로세스 웹 스택으로 구현했습니다. 원래 명세(`SPEC_추가기능.md`)는 Node 백엔드 + MySQL/Redis + Flutter 앱/웹 조합을 전제로 했지만, 로컬 실행을 가볍게 하기 위해 아래처럼 스택을 조정했습니다.

| 원래 명세 | 이 프로젝트 |
|---|---|
| MySQL | SQLite (파일 하나, `prisma migrate`) |
| Redis (level 캐시) | 프로세스 내 인메모리 캐시 (TTL 동일하게 적용) |
| Flutter 앱 / Flutter Web | Next.js 웹 (반응형, PC/모바일 브라우저 겸용) |
| ffmpeg 트랜스코딩 | 원본은 그대로 저장, `<video>` 태그로 재생 (트랜스코딩 없음). 다만 동영상 썸네일은 번들된 `ffmpeg-static` 바이너리로 프레임을 추출해 생성 — 별도 ffmpeg 설치 불필요 |
| 5MB 청크 업로드 | 파일당 단일 요청 업로드 (사양 문서의 "업로드 시작 시 용량 체크" 로직은 동일하게 적용) |
| Docker Compose | 로컬 `npm run dev` / `npm run build && npm start` |

핵심 기능(로그인, 사진첩, 업로드, 뷰어, 초대, 휴지통)과 명세에 있던 추가 기능 3가지(관리자 스토리지 대시보드 / 홈 PC 업로드 환경설정 / 카카오톡 공유)를 모두 이 스택으로 새로 구현했습니다.

## 시작하기

```bash
npm install
cp .env.example .env
# .env 의 ★ 항목 채우기 (아래 참고)
openssl rand -hex 32   # JWT_SECRET 에 채워 넣기

npx prisma migrate deploy   # 최초 1회 (또는 npm run migrate)
npm run dev                 # http://localhost:3000
```

첫 번째로 가입하는 계정이 자동으로 관리자(admin)가 됩니다. (`ADMIN_EMAILS` 에 이메일을 미리 등록해두면 해당 이메일로 가입 시에도 관리자로 승격됩니다 — 원래 명세의 `ADMIN_KAKAO_IDS` 와 동일한 역할)

프로덕션 실행은 `npm run build && npm start` 입니다.

## .env 필수 값 (★)

`.env.example` 전체 항목 중 반드시 채워야 부팅되는 값입니다. 나머지는 기본값으로 동작합니다.

| 변수 | 설명 |
|---|---|
| `JWT_SECRET` | 세션 서명 키. `openssl rand -hex 32` |
| `ADMIN_ALERT_EMAIL` | 스토리지 경고 수신 주소 |
| `ADMIN_EMAILS` | (권장) 관리자로 자동 승격할 이메일. 비워두면 최초 가입자가 관리자가 됩니다 |

카카오 로그인/공유(`KAKAO_REST_API_KEY`, `KAKAO_JS_KEY` 등)와 메일 발송(`SMTP_*`)은 값이 비어 있으면 자동으로 비활성화되고, 각각 "이메일 로그인만 사용" / "콘솔 로그로 대체"로 동작합니다. Kakao Developers에서 앱을 만들고 Web 플랫폼에 `WEB_BASE_URL` 을 등록하면 카카오 로그인·공유가 즉시 활성화됩니다.

## 저장 경로

```
{MEDIA_ROOT}/{albumId}/{yyyy}/{mm}/{uuid}.{ext}     원본
{VARIANT_ROOT}/{albumId}/{yyyy}/{mm}/{mediaId}.{kind}.webp   썸네일 (200/800/1600px WebP)
{TRASH_ROOT}/...                                    소프트 삭제된 원본 (30일 후 영구 삭제)
```

기본값은 프로젝트 루트의 `./data/{media,variants,trash,tmp,db}` 이며, `MEDIA_ROOT` 등을 다른 드라이브 경로로 바꾸면 그쪽에 저장됩니다. 부팅 시 각 경로에 쓰기 권한이 있는지 자동으로 확인하고, 없으면 즉시 실패합니다.

## 구현된 기능

**핵심**
- 이메일 회원가입/로그인 (+ 옵션으로 카카오 로그인)
- 사진첩 생성/멤버/초대 링크 (`/invite/:token`, 만료·횟수 제한)
- 사진/동영상 업로드 (JPEG/PNG/HEIC/WebP/MP4/MOV), 200·800·1600px WebP 썸네일 자동 생성 (동영상은 `ffmpeg-static`으로 프레임 추출 후 동일 파이프라인 적용)
- EXIF `DateTimeOriginal`(사진) / 컨테이너 `creation_time`(동영상)을 촬영일자로 추출해 `takenAt`에 저장 — 타임라인은 업로드일이 아니라 이 촬영일 기준으로 날짜별 그룹핑
- 날짜별 타임라인을 "하루 카드" 피드로 표시: 큰 썸네일 1장 + 작은 썸네일 2장 콜라주, 3장을 넘으면 마지막 칸에 "N장의 사진 + M개의 동영상" 오버레이. 카드 클릭 시 해당 날짜 전체 그리드(`/albums/:id/days/:date`)로 이동
- 사진/동영상별 리액션 4종(좋아요/귀여워/웃겨요/놀라워, 사용자당 1개) — 반응이 있으면 썸네일 우측 하단에 하트 뱃지 표시, 뷰어에서 직접 선택/해제 가능
- 하루 카드에 그날 전체 미디어의 리액션 집계, 댓글(작성/목록), 업로더(`By 닉네임`) 표시
- 미디어 뷰어(다운로드/삭제/커버 지정), 소프트 삭제 → 휴지통 → 30일 후 자동 영구 삭제

**1. 관리자 스토리지 대시보드**
- `getStorageStatus()` : 디스크 실사용(`check-disk-space`) 기준 주의(80%)/경고(90%)/차단(95%) 3단계 판정
- `GET /api/admin/storage`, `GET /api/admin/storage/history`, `POST recalculate`, `POST purge-trash`
- 매시 정각 배치(`STORAGE_CHECK_CRON`): `storage_stats` 적재 → 단계 상승 시 관리자 메일 + 개설자 배너 + (차단 단계면) 업로드 차단 플래그
- 업로드 시작 API에서 캐시된 level 을 매번 확인해 배치 지연(최대 1시간) 없이 즉시 차단
- `/admin/storage` 화면: 게이지, 여유공간/휴지통/일평균증가/소진예상, 30일 추이 차트, 사진첩별 사용량 순위, 임계치 표시

**2. 홈 PC 업로드 환경 구성**
- `.env` 로딩 + zod 기반 검증 모듈 — 필수값 누락 시 부팅 실패 (`src/lib/env.ts`)
- 저장 경로 자동 생성 + 쓰기 권한 확인 (`src/lib/paths.ts`)
- `.env.example` 에 ★ 표시로 반드시 채워야 하는 값 구분

**3. 카카오톡 공유**
- 사진이 아니라 **사진첩/날짜/사진으로 가는 링크**만 공유 (`/albums/:id`, `/albums/:id/days/:date`, `/albums/:id/media/:mediaId`, `/invite/:token`)
- 공유 썸네일은 공개 고정 이미지(`/static/share-cover.png`)만 사용, 비공개 사진 URL은 노출하지 않음
- 딥링크 진입 시 로그인 → 멤버 확인 → 멤버면 해당 화면, 아니면 초대 랜딩(비회원 접근 시 `참여 신청` 화면)
- 카카오 미설정/카카오톡 미설치 환경은 "링크 복사"로 자동 폴백
- 공유 클릭은 `access_logs` 에 `action='share'` 로 기록

## 스케줄러

`src/instrumentation.ts` 가 서버 부팅 시 1회 등록되어 `src/lib/scheduler.ts` 의 두 크론잡을 시작합니다.

- `STORAGE_CHECK_CRON` (기본 매시): 스토리지 상태 재집계 + 알림
- `PURGE_CRON` (기본 매일 새벽 4시): 보관기한 지난 휴지통 파일 영구 삭제, 오래된 `access_logs` 정리

## 알려진 제한 (경량 스택 트레이드오프)

- 동영상은 썸네일용 프레임만 추출하고, 재생용 트랜스코딩(해상도 조정 등)은 하지 않습니다 — 원본 코덱/해상도 그대로 `<video>` 재생.
- 업로드는 파일당 단일 HTTP 요청입니다 (5MB 청크 이어올리기 없음). 대용량 파일은 `UPLOAD_MAX_FILE_BYTES` 이내에서 브라우저·네트워크 안정성에 의존합니다.
- Redis 대신 인메모리 캐시를 쓰므로, 다중 프로세스/서버로 수평 확장하면 스토리지 level 캐시가 프로세스별로 분리됩니다. 단일 홈 서버 운영 전제에서는 문제 없습니다.
