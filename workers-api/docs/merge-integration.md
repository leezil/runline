# main 로그인·피드와 클럽 통합

- Flutter 로그인·갱신·로그아웃은 기존 `RunlineAuth`가 담당합니다. 클럽·공지·채팅·이미지 클라이언트도 같은 세션을 사용합니다.
- API 주소는 `config/app.local.json`의 `RUNLINE_API_ORIGIN`입니다. 클럽 전용 서버 주소나 별도 세션 주입은 없습니다.
- 기존 홈의 설정 진입과 로그아웃을 유지합니다. 프로필 사진 변경은 피드의 내 프로필에서 사용할 수 있습니다.
- 피드 화면과 작성 흐름은 main을 기준으로 유지합니다. 클럽 생성·공지·대표 사진 작성은 별도 `ClubImageComposeScreen`을 사용합니다.

## API와 저장소

- 피드: `POST /api/v1/feed/media` 업로드 → `POST /api/v1/feed/posts`에 `{ body, mediaIds }` 전달. 추천·팔로잉·상세·수정·삭제 API와 조회자별 서명 URL을 유지합니다.
- 클럽 홈 통합 피드: `GET /api/v1/clubs/:clubId/feed`. 일반 피드와 별개입니다.
- 프로필의 기준은 `runline_user_profiles`입니다. 피드 작성자, 클럽 멤버·공지·러닝 작성자와 채팅 발신자가 같은 닉네임·프로필 사진을 조회합니다.
- 기존 피드 저장소 `FEED_MEDIA`와 클럽 이미지 저장소 `MEDIA_BUCKET`을 모두 바인딩합니다. Images 및 `CLUB_CHAT` 바인딩도 필요합니다.
- 피드 정리는 `15 * * * *`, 클럽 이미지 정리는 `17 3 * * *`에 각각 실행합니다.
- 기존 피드 프로토타입의 `{ title, content }` API는 등록하지 않습니다. 이전 SQL과 데이터는 삭제하지 않습니다.

## DB 적용

기존 SQL 파일의 이름·내용·체크섬을 유지했습니다. 클럽 마이그레이션뿐 아니라 main의 프로필·피드·팔로우·러닝 마이그레이션도 필요합니다. 전체 로컬 순서는 `npm run db:migrate -- --plan`으로 확인할 수 있습니다.

`007_club_profiles.sql`은 기존 클럽 프로필을 main 프로필 테이블로 옮깁니다. 이미 있는 main 프로필은 덮어쓰지 않으며 이전 컬럼·피드 테이블을 삭제하지 않습니다.

기존 DB는 적용 이력을 먼저 확인해야 합니다. `--baseline-auth`는 인증 SQL만 수동 적용한 경우에 사용합니다. main의 다른 SQL도 수동 적용했다면 해당 스키마와 적용 이력을 먼저 대조·등록해야 합니다. 스크립트는 테이블 존재만으로 SQL을 자동 생략하지 않습니다.

이 통합 작업은 운영 DB 변경이나 배포를 실행하지 않습니다. 새 코드 배포 전에 필요한 SQL을 적용하고 R2·Images·Durable Object·Origin 설정을 확인합니다.

## 검증

```powershell
npm run typecheck
npx tsc --noEmit -p test/tsconfig.json
npm test -- --run
npm run test:clubs
npm run test:chat
npx wrangler deploy --dry-run
# runline 디렉터리
flutter test
flutter analyze
flutter build web
```

클럽 SQL 테스트는 모든 마이그레이션을 적용한 임시 PGlite에서 실행합니다. 채팅 동시성 테스트는 별도의 임시 PostgreSQL을 사용하고 Neon에 접속하지 않습니다.

### 통합 검증 결과

`main`의 `4a51d60`을 기준으로 확인했습니다.

| 항목 | 결과 |
|---|---|
| Flutter 전체 테스트 | 185개 통과 |
| Workers 인증·피드·이미지·채팅·정기 작업 테스트 | 58개 통과 |
| 전체 SQL 적용 후 클럽·프로필·피드 통합 테스트 | 23개 통과 |
| 임시 PostgreSQL 채팅·동시성 테스트 | 9개 통과 |
| TypeScript 소스·테스트 타입 검사 | 통과 |
| 수정 영역 Dart 분석 | 통과 |
| Flutter 웹 빌드·Workers 배포 전 빌드 검사 | 통과 |

별도 `CLUB_TEST_DATABASE_URL`을 요구하는 기존 선택적 동시성 테스트 3개는 생략했습니다. 전체 Flutter 분석에는 main에 있던 lint 경고가 남아 있으며, 웹 빌드에서는 기존 Kakao SDK의 Wasm 호환성 경고가 출력됩니다. 기본 웹 빌드는 성공했습니다.
