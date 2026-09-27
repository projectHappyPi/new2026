# 튼튼이 동기화 서버

엄마·아빠 폰의 기록(분유·수면·기저귀…)과 달력 일정을 맞춰 주는 작은 서버. 의존성 없는 Node 22 + 내장 SQLite.

## 실행 (Docker + Cloudflare Tunnel)

```bash
cp .env.example .env      # FAMILY_CODE, TUNNEL_TOKEN 입력
docker compose up -d
```

Cloudflare 터널의 Public Hostname(예: `tunteuni.example.com`) 서비스는 `http://sync:8787`.
앱 **설정 > 가족 공유**에 `https://tunteuni.example.com` 과 FAMILY_CODE를 두 폰 모두 입력하면 끝.

## 동작

- `POST /v1/sync` (`Authorization: Bearer <FAMILY_CODE>`): `{cursor, activities[], events[]}`를 보내면 반영하고, cursor 이후 바뀐 행과 새 cursor를 돌려준다.
- 같은 id는 `updatedAt`이 더 큰 쪽이 이김. 삭제는 `deletedAt`(soft delete)로 전파.
- 앱은 30초마다, 그리고 기록 직후 동기화한다.
- 데이터: `./data/tunteuni.sqlite` (백업은 이 파일만 복사).

## 테스트

```bash
npm test
```
