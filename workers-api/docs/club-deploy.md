# 클럽 API 404 배포 점검

2026-11-27 배포 전 점검 결과입니다.

- 운영 API: https://runline-api.yujin20021129.workers.dev
- 운영 배포본: cbc69c97-767a-4f12-a924-06d1e11ba5cd, 한국시간 2026-11-25 01:50.
- 로컬에는 /api/v1/me/club, /api/v1/me/profile 및 /api/v1/clubs 라우트가 등록돼 있습니다.
- 운영 /api/v1/clubs/recommended는 인증 검사 없이 NOT_FOUND 404를 반환합니다. 기존 /me/* 인증 미들웨어 때문에 /me/club의 비로그인 401 응답만으로 클럽 라우트 존재를 판단할 수는 없습니다.
- 현재 운영 버전에는 FEED_MEDIA와 HYPERDRIVE만 있고, 클럽용 MEDIA_BUCKET·IMAGES·CLUB_CHAT 바인딩이 없습니다.
- R2에는 runline-feed-media만 존재하고 runline-media는 없습니다.
- 운영 Hyperdrive와 로컬 Neon 설정의 호스트·DB가 일치합니다. 읽기 전용으로 확인한 클럽·이미지·채팅·프로필 테이블과 채팅 가입 경계·순번 컬럼은 준비돼 있습니다.
- DB 적용 이력 테이블은 없습니다. 현재 스키마에 db:migrate를 무조건 재실행하지 않습니다. 이번 해결에는 DB 변경이 필요하지 않습니다.

## 준비한 코드

기존 HTTP 로그인 설정 RUNLINE_WEB_ORIGIN을 채팅 Origin 허용 목록의 기본값에서도 재사용하도록 보완했습니다. 명시한 CHAT_ALLOWED_ORIGINS가 있으면 해당 설정만 사용하며, 빈 문자열은 브라우저 Origin을 허용하지 않습니다.

TypeScript 소스·테스트 타입 검사, Workers 테스트 60개, 운영 배포 전 빌드 검사를 통과했습니다.

## 적용한 작업

1. 비공개 클럽 이미지 버킷 runline-media 생성. 이미 생성됐다면 생략합니다.
2. 현재 runline-api Worker에 검증한 코드를 배포합니다. MEDIA_BUCKET·IMAGES·CLUB_CHAT 및 v1-club-chat Durable Object 마이그레이션을 포함합니다.
3. 기존 로그인·피드 환경변수와 시크릿을 유지합니다. keep-vars 동작은 [Cloudflare 배포 문서](https://developers.cloudflare.com/workers/wrangler/commands/workers/#deploy)를 참고합니다.
4. 배포 버전·리소스 바인딩·health를 확인하고, 클럽 추천 API가 미인증 요청에 401을 반환하는지 확인합니다. 브라우저에서는 기존 로그인 계정으로 /me/club과 /me/profile이 정상 응답하는지 확인합니다.

workers-api 디렉터리에서:

~~~powershell
npx wrangler r2 bucket create runline-media
npx wrangler deploy --keep-vars --message "Enable club APIs and club chat"
~~~

## 배포 결과

2026-11-27 사용자 승인 후 운영 배포를 완료했습니다.

- 현재 버전: afbb8860-c4c7-4c21-ab2e-353b7ecd1ace.
- runline-media 버킷 생성 완료. r2.dev 공개 접근 비활성 및 연결된 공개 도메인 없음 확인.
- MEDIA_BUCKET·IMAGES·CLUB_CHAT 바인딩과 두 정기 작업 일정 배포 완료.
- 기존 로그인·피드 바인딩과 시크릿 항목 모두 유지됨.
- 운영 Hyperdrive·Neon 연결 및 DB 스키마 변경 없음.

| 확인 | 결과 |
|---|---|
| GET /api/v1/health | 200 |
| GET /api/v1/me/club (미인증) | 401 AUTH_REQUIRED |
| GET /api/v1/me/profile (미인증) | 401 AUTH_REQUIRED |
| GET /api/v1/clubs/recommended (미인증) | 기존 404에서 401 AUTH_REQUIRED로 변경 |
| 기존 피드·인증 API (미인증) | 401 AUTH_REQUIRED |
| localhost:5000의 /me/club CORS 사전 요청 | 204, Origin 및 Authorization 허용 |

브라우저 자동 확인 도구는 작업 경로 오류(os error 267)로 시작되지 않았습니다. 로그인된 브라우저의 200 응답과 사용자 화면은 직접 새로고침하여 최종 확인해야 합니다.

