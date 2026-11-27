# RUNLINE 클럽 API

클럽 탐색·즉시 가입·생성, 멤버 관리, 공지·첨부파일,
클럽 러닝, 홈 통합 피드와 공통 이미지 업로드를 제공합니다. Flutter 사진 선택·압축·게시·조회도 연결했습니다.
기존 로그인·피드 기능을 유지하며 클럽·채팅도 Flutter `RunlineAuth` 세션을 공유합니다.
[main 통합과 DB 적용 안내](docs/merge-integration.md)를 먼저 확인하세요.
클럽 공용 채팅의 저장·인증·재접속 정책과 실행 방법은 [채팅 안내](docs/chat.md)를 참고하세요.

## 실행 및 DB 반영

```powershell
cd workers-api
npm ci
npm run db:migrate -- --plan
```

`--plan`은 로컬 SQL 목록만 출력하고 DB에 접속하지 않습니다.
실제 마이그레이션은 `NEON_DIRECT_URL` 환경 변수 또는 `.env.neon.local`의 같은 변수를 사용합니다.
연결 문자열을 명령 인자나 소스에 넣지 마세요.

새 DB에는 다음을 실행합니다.

```powershell
npm run db:migrate
```

기존 DB에 `001_auth.sql`을 **이미 수동 적용한 경우** 최초 한 번 다음을 실행합니다.
기존 인증 테이블의 필수 컬럼을 확인한 뒤 001을 적용 이력으로 기록하고 002를 실행합니다.

```powershell
npm run db:migrate -- --baseline-auth
```

이후에는 `npm run db:migrate`를 사용합니다. 적용 이력·SQL 체크섬을 보관하고,
동시 실행은 DB 잠금으로 방지합니다. 실패 시 해당 실행 전체를 롤백합니다.
각 SQL 파일은 독립적으로 직접 실행할 수도 있지만, 추후 이력 관리를 위해 스크립트를 권장합니다.
이 구현 작업에서는 원격 DB 마이그레이션이나 배포를 실행하지 않았습니다.
`003_images.sql`은 클럽 이미지, `004_chat.sql`은 클럽 채팅, `007_club_profiles.sql`은 프로필 통합에 필요합니다. main의 프로필·피드·팔로우·러닝 SQL도 모두 적용해야 합니다.

운영 이미지 저장에는 비공개 R2 버킷 `runline-media`와 Images 바인딩이 필요합니다.
`wrangler.jsonc`에 `MEDIA_BUCKET`, `IMAGES`와 삭제된 이미지의 일일 정리 트리거를 설정했습니다.
배포 전 계정에서 Images 사용을 설정하고 버킷을 준비하세요.

```powershell
npx wrangler r2 bucket create runline-media
```

이 명령은 이번 작업에서 실행하지 않았습니다. 버킷의 공개 URL은 활성화하지 않습니다.
로컬 `wrangler dev`는 로컬 R2와 Images 변환 시뮬레이터를 사용합니다.

```powershell
npm run dev:neon
```

## 정책

- 모든 API는 RUNLINE Bearer 인증이 필요합니다. 사용자 ID·권한은 서버가 결정합니다.
- 사용자당 활성 클럽 멤버십은 최대 하나입니다. 가입은 즉시 완료됩니다.
- 추천·검색·가입 전 공개 정보는 미가입자에게만 제공합니다.
- 클럽 생성자는 자동으로 클럽장이 됩니다. 가입 방식 선택 필드는 없습니다.
- 홈·공지·첨부파일·멤버·러닝·피드는 현재 소속 클럽원만 이용합니다.
- 공지 작성·수정·삭제·고정은 현재 클럽장만 가능합니다. 위임 후 새 클럽장이 기존 공지도 관리합니다.
- 러닝은 모든 클럽원이 생성하며, 수정·취소는 해당 러닝 생성자만 가능합니다.
- 러닝 생성자는 자동 참가하며 정원에 포함됩니다. 생성자는 참가 취소 대신 러닝을 취소합니다.
- 참가 취소는 시작 전까지 가능하며, 재참가는 모집 중일 때 가능합니다.
- 러닝 정원은 이미 참가한 인원보다 작게 변경할 수 없습니다.
- 생성자 탈퇴·강퇴 시 시작 전 러닝은 취소하고, 떠나는 멤버의 시작 전 참가도 취소합니다.
- 시작한 러닝의 기록과 탈퇴한 작성자의 과거 게시물은 유지합니다.
- 재가입은 새로운 멤버십 ID·가입 시각·채팅 열람 경계를 만듭니다.
- 클럽장은 위임 후 탈퇴하거나 클럽을 폐쇄합니다. 폐쇄하면 모든 멤버십을 종료하고 남은 러닝을 취소합니다.
- 초기 추천은 운영 중인 클럽을 최신 생성순으로 제공합니다. `region`으로 지역을 좁힐 수 있습니다.
- 투표, 앱 알림, 푸시는 포함하지 않습니다. 클럽 채팅은 텍스트부터 지원합니다.

## 응답 규칙

기본 경로는 `/api/v1`입니다. JSON 응답은 `ok: true`와 리소스를 포함합니다.
DB 리소스 필드는 `snake_case`, JSON 입력은 아래 표의 `camelCase`를 사용합니다.
시간 입력은 시간대를 포함한 ISO 8601 형식이며 응답은 UTC ISO 형식입니다.
ID는 UUID입니다. 성공한 삭제·탈퇴·위임·취소는 본문 없는 `204`를 반환합니다.

목록은 다음 구조입니다.

```json
{ "ok": true, "items": [], "nextCursor": null }
```

`limit`은 기본 20, 최대 100입니다. 다음 페이지에는 `nextCursor` 값을 URL 인코딩해
`cursor`로 전달합니다. 커서는 API·클럽·필터별로 구분하며 동일 필터에서만 사용할 수 있습니다.
정렬은 날짜 내림차순, UUID 내림차순이며 공지는 고정 여부가 우선입니다.
DB 시간 정밀도를 밀리초로 통일해 JavaScript 변환 시 페이지 경계가 달라지지 않게 했습니다.

## 내 상태 및 프로필

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/me/club` | `{ club: null, membership: null }` 또는 가입된 클럽과 멤버십 |
| GET | `/me/profile` | 내 `id`, `nickname`, `avatar_url` |
| PATCH | `/me/profile` | `nickname`(1–30자) 수정, `avatarUrl: null`로 사진 제거 |
| POST | `/me/avatar` | 공통 파이프라인을 거쳐 프로필 사진 업로드·교체 |

앱은 `/me/club`의 `club`이 null이면 추천·검색·생성 화면, 값이 있으면 해당 클럽 홈을 표시합니다.
기존 사용자의 기본 닉네임은 `러너`입니다.

## 클럽 탐색·가입·관리

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/clubs/recommended` | 추천 목록. 선택 쿼리: `region`, `limit`, `cursor` |
| GET | `/clubs` | 클럽명 부분 검색. 선택 쿼리: `query`, `region`, `limit`, `cursor` |
| GET | `/clubs/:clubId` | 미가입자의 가입 전 공개 정보 조회 |
| POST | `/clubs` | 클럽 생성. 응답 `201`, `{ club, membership }` |
| POST | `/clubs/:clubId/join` | 즉시 가입. 본문 없음, 응답 `201`, `{ club, membership }` |
| GET | `/clubs/:clubId/home` | 소속 클럽 기본 정보와 내 멤버십 |
| PATCH | `/clubs/:clubId` | 클럽장 전용 클럽 정보 수정 |
| POST | `/clubs/:clubId/leave` | 일반 멤버 탈퇴 |
| POST | `/clubs/:clubId/ownership` | 클럽장 위임. 본문 `{ "membershipId": "대상 멤버십 UUID" }` |
| DELETE | `/clubs/:clubId` | 클럽장 전용 클럽 폐쇄 |

생성 입력은 `name`(1–50자), `region`(1–100자), 선택 `description`(최대 2000자),
`imageUrl`(null만 허용)입니다. 수정은 같은 필드 중 하나 이상입니다.
대표 이미지는 클럽 생성 이후 `POST /clubs/:clubId/image`로 업로드합니다.
외부 이미지 URL 직접 입력은 최적화 우회를 막기 위해 차단했습니다.
공개 정보에는 이름·소개·대표 이미지·활동 지역·멤버 수가 포함되며 멤버 명단이나 내부 콘텐츠는 제외합니다.

## 멤버

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/clubs/:clubId/members` | 멤버십 ID, 사용자 ID, 닉네임, 이미지, 역할, 가입 시각 |
| DELETE | `/clubs/:clubId/members/:membershipId` | 클럽장 전용 강퇴. 클럽장 자신은 강퇴 불가 |

멤버 목록은 `query`로 닉네임 부분 검색, `limit`·`cursor`로 페이지 조회합니다.
강퇴와 위임에 쓰는 ID는 사용자 ID가 아닌 **멤버십 ID**입니다.

## 공지·첨부파일

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/clubs/:clubId/notices` | 공지 목록. `limit`, `cursor` 지원 |
| POST | `/clubs/:clubId/notices` | 공지 작성, 응답 `201`, `{ notice }` |
| GET | `/clubs/:clubId/notices/:noticeId` | 공지 본문과 첨부파일 메타데이터 |
| PATCH | `/clubs/:clubId/notices/:noticeId` | 공지 수정·고정 |
| DELETE | `/clubs/:clubId/notices/:noticeId` | 공지 삭제 및 첨부파일 정리 |
| POST | `/clubs/:clubId/notices/:noticeId/attachments` | 파일 업로드, 응답 `201`, `{ attachment }` |
| GET | `/clubs/:clubId/notices/:noticeId/attachments/:attachmentId` | 인증 후 파일 다운로드 |
| DELETE | `/clubs/:clubId/notices/:noticeId/attachments/:attachmentId` | 첨부파일 삭제 |

공지 생성 입력은 `title`(1–100자), `content`(1–10000자), 선택 `pinned`(기본 false)입니다.
수정은 같은 필드 중 하나 이상입니다.

업로드는 `multipart/form-data`의 `file` 필드 하나를 사용합니다. 공지당 최대 5개,
파일당 1바이트–5MiB입니다. JPEG·PNG·WebP·GIF·PDF·일반 텍스트·DOCX·XLSX를 지원합니다.
이미지는 공통 처리 후 R2에 저장하고, DB에는 크기·해상도·객체 키만 저장합니다.
PDF·텍스트·문서 등 일반 첨부파일은 압축하지 않고 기존 PostgreSQL `bytea` 저장을 유지합니다.
다운로드는 인증·현재 클럽 소속·공지와 파일의 일치 여부를 검사하고 `no-store`, `nosniff`,
일반 파일에는 `Content-Disposition: attachment`, 정규화된 WebP에는 `inline` 헤더를 적용합니다.
이미지도 항상 인증 API로 제공하며 공개 파일 URL은 발급하지 않습니다.
003 적용 전에 저장된 기존 이미지 바이트는 호환성을 위해 기존 다운로드 경로로 유지합니다.

## 클럽 러닝

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/clubs/:clubId/runs` | `filter`, `limit`, `cursor`로 목록 조회 |
| POST | `/clubs/:clubId/runs` | 러닝 생성 및 생성자 자동 참가, 응답 `201`, `{ run }` |
| GET | `/clubs/:clubId/runs/:runId` | 상세와 참가 인원·내 참가 여부 |
| PATCH | `/clubs/:clubId/runs/:runId` | 생성자 전용 일정 수정 |
| POST | `/clubs/:clubId/runs/:runId/cancel` | 생성자 전용 취소. 반복 취소는 성공 처리 |
| POST | `/clubs/:clubId/runs/:runId/participants` | 참가, 응답 `201`, `{ run }` |
| DELETE | `/clubs/:clubId/runs/:runId/participants/me` | 내 참가 취소 |
| GET | `/clubs/:clubId/runs/:runId/participants` | 참가자 목록. `limit`, `cursor` 지원 |

생성 입력 예시:

```json
{
  "title": "주말 한강 5km",
  "description": "천천히 함께 달려요",
  "location": "여의도 한강공원",
  "startsAt": "2030-05-11T08:00:00+09:00",
  "endsAt": "2030-05-11T09:00:00+09:00",
  "registrationClosesAt": "2030-05-10T23:00:00+09:00",
  "capacity": 10
}
```

제목 1–100자, 설명 최대 5000자, 장소 1–300자, 정원 1–10000명입니다.
생성 시 시작·모집 마감은 미래이고, 종료는 시작 이후, 모집 마감은 시작 이전 또는 같은 시각이어야 합니다.
시작 전 러닝만 수정·취소할 수 있습니다. 모집 마감 후에도 제목·장소 등은 수정할 수 있습니다.
시간 판단은 DB 시계를 사용합니다.

`filter`는 `all`(기본), `recruiting`, `upcoming`, `in_progress`, `past`, `cancelled`입니다.
`upcoming`은 모집 마감 여부와 관계없는 시작 전 일정이며, `past`는 취소되지 않고 종료 시각이 지난 일정입니다.
응답 `state`는 `recruiting`, `closed`, `in_progress`, `ended`, `cancelled` 중 하나입니다.
별도 스케줄러 없이 조회 시 시간·정원에 따라 상태를 계산합니다.

## 홈 통합 피드

`GET /clubs/:clubId/feed?limit=20&cursor=...`

`type`은 `notice_created`, `run_created`, `run_updated`, `run_cancelled`입니다.
각 항목은 `id`, `type`, `title`, `created_at`, `target_type`(`notice`/`run`), `target_id`를 포함합니다.
`title`은 이벤트 발생 당시 제목이고, `current_notice_title`·`current_run_title`은 현재 제목입니다.
공지 고정 여부, 러닝 시작·취소 시각도 반환합니다. 삭제된 공지의 피드는 숨깁니다.
피드 생성은 원본 데이터 변경과 같은 트랜잭션에서 실행하므로 한쪽만 저장되지 않습니다.
이 API는 홈 게시물 목록이며 앱 알림 기능은 아닙니다.

## 권한·동시성

클럽 읽기는 해당 클럽 행을 공유 잠금하고 현재 멤버십을 다시 검사합니다.
변경은 클럽 행을 배타 잠금해 탈퇴·강퇴·폐쇄·위임·참가 처리를 직렬화합니다.
가입·생성은 사용자 행도 잠그며 활성 멤버십 부분 고유 인덱스가 최종 중복 가입을 차단합니다.
집계는 잠금을 획득한 뒤 별도 문장에서 읽어 대기 중 커밋된 참가·가입을 반영합니다.
클럽 변경을 직렬화하는 방식은 초기 규모를 위한 선택이며 규모가 커지면 러닝별 잠금으로 세분화할 수 있습니다.
클럽 조회와 권한 검사는 트랜잭션 안에서 실행해 가입·탈퇴 직후 오래된 조회 결과를 사용하지 않도록 합니다.

주요 오류 형식:

```json
{ "ok": false, "error": { "code": "ALREADY_IN_CLUB", "message": "You already belong to a club" } }
```

| HTTP | 대표 코드 |
|---|---|
| 400 | `INVALID_REQUEST` |
| 401 | `AUTH_REQUIRED` |
| 403 | `CLUB_MEMBERSHIP_REQUIRED`, `CLUB_OWNER_REQUIRED`, `RUN_CREATOR_REQUIRED` |
| 404 | `NOT_FOUND` |
| 409 | `ALREADY_IN_CLUB`, `OWNER_MUST_TRANSFER_OR_CLOSE`, `RUN_NOT_RECRUITING`, `ALREADY_PARTICIPATING`, `CAPACITY_BELOW_ATTENDANCE`, `ATTACHMENT_LIMIT` |
| 413 | `PAYLOAD_TOO_LARGE`, `ATTACHMENT_TOO_LARGE` |

## 검증

```powershell
npm run typecheck
npx tsc --noEmit -p test/tsconfig.json
npm test -- --run
npm run test:clubs
```

기존 인증 테스트는 Workers 런타임, 클럽 통합 테스트는 메모리 PGlite의 실제 PostgreSQL SQL로 실행합니다.
PGlite는 단일 연결이므로 여러 DB 연결 사이의 잠금 경쟁은 검증하지 않습니다.
별도 PostgreSQL 테스트 DB를 준비하면 아래 명령으로 다중 연결 경쟁 테스트도 실행합니다.
테스트는 임의의 전용 스키마를 생성·삭제하므로 운영 DB를 사용하지 마세요.

```powershell
$env:CLUB_TEST_DATABASE_URL = 'postgresql://test:test@localhost:5432/runline_test'
npm run test:clubs
```

다중 연결 테스트는 같은 사용자의 동시 가입, 가입과 생성의 경쟁, 러닝 마지막 자리의 동시 참가를 확인합니다.
변수가 없으면 해당 세 테스트만 건너뜁니다. 로컬 통합 테스트는 외부 DB에 접속하지 않습니다.
