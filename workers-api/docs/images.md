# 공통 이미지 처리

모든 사진은 Flutter의 공통 최적화를 거칩니다. 서버에서는 main의 피드 저장·서명 URL 흐름과 클럽 이미지 변환 흐름을 유지합니다.
[통합 안내](merge-integration.md)에서 두 경로와 저장소를 확인하세요. 아래 서버 변환·썸네일 설명은 프로필·클럽 대표·공지를 기준으로 합니다.

## 처리 흐름

1. Flutter에서 이미지 선택 후 파일 크기와 실제 디코더 헤더를 검사합니다.
2. 40MP 이하 이미지의 첫 프레임을 읽고 EXIF 방향을 보정합니다.
3. 비율을 유지하며 사진은 긴 변 1600px, 프로필·클럽 대표는 512px로 줄입니다. 확대하지 않습니다.
4. 픽셀만 새 이미지로 복사해 EXIF·GPS·XMP를 버립니다. 사진은 JPEG 품질 80부터,
   투명 이미지에는 PNG를 사용합니다. 목표 700KiB, 최대 1MiB가 되도록 품질·크기를 조정합니다.
5. 인증된 multipart 요청으로 최적화된 바이트를 업로드합니다. 원본 파일은 전송하지 않습니다.
6. 서버에서 5MiB 입력 제한, 실제 파일 시그니처와 MIME 일치, 디코딩 가능 여부, 40MP 해상도를 검증합니다.
7. Images 바인딩으로 WebP를 생성합니다. 방향 보정 후 EXIF·XMP 청크를 명시적으로 제거합니다.
   GIF·애니메이션 WebP는 첫 프레임으로 정규화합니다. SVG·임의 파일은 이미지로 허용하지 않습니다.
8. 본문 최대 1MiB, 썸네일 최대 400px·256KiB를 생성해 비공개 R2에 저장합니다.
9. DB에는 저장 키·해상도·크기·연결 대상만 저장합니다. 클럽 공지의 일반 문서는 기존 별도 처리를 유지합니다.
10. 썸네일과 본문 모두 인증 API로 읽습니다. 클럽 공지는 현재 소속 클럽원만 읽을 수 있습니다.

기본값은 사진에 따라 결과가 달라집니다. 글자가 많은 공지나 투명 PNG도 실제 기기에서 가독성을 확인하세요.
Flutter native는 `compute`로 압축을 분리합니다. 웹에서 `compute`는 별도 스레드를 보장하지 않습니다.
지원 입력은 JPEG·PNG·WebP·GIF입니다. HEIC는 현재 클라이언트 디코더에서 지원하지 않아 JPEG로 변환해서 선택해야 합니다.

## API

모든 업로드는 `file` 하나를 가진 `multipart/form-data`와 RUNLINE Bearer 인증을 사용합니다.

| 용도 | 업로드 |
|---|---|
| 프로필 | `POST /api/v1/me/avatar` |
| 클럽 대표 | `POST /api/v1/clubs/:clubId/image` |
| 클럽 공지 | `POST /api/v1/clubs/:clubId/notices/:noticeId/attachments` |
| 피드 게시물 | `POST /api/v1/feed/media` 후 `mediaIds`로 게시글에 첨부 |

프로필과 클럽 대표는 교체하고, 공지는 최대 5개를 추가합니다. main 피드는 최대 4개이며 별도의 서명 URL과 FEED_MEDIA 버킷을 사용합니다.
서버는 변환 전 권한을 검사하고, 저장 직전 트랜잭션에서 권한과 개수를 다시 검사합니다.
저장 실패 시 생성한 R2 객체를 정리합니다.

응답의 `image`:

```json
{
  "id": "이미지 UUID",
  "width": 1600,
  "height": 900,
  "size": 150000,
  "thumbnail_size": 15000,
  "content_type": "image/webp",
  "url": "/api/v1/media/images/이미지-UUID",
  "thumbnail_url": "/api/v1/media/images/이미지-UUID?variant=thumbnail"
}
```

`GET /api/v1/media/images/:imageId`는 본문, `?variant=thumbnail`은 썸네일입니다.
토큰은 URL 쿼리로 받지 않습니다. Flutter 웹도 인증 헤더로 바이트를 받아 `Image.memory`로 표시합니다.
응답은 `private, no-store`이며 공개 R2 URL이나 원본 우회 URL은 반환하지 않습니다.
프로필·클럽 대표는 인증된 사용자에게 공개하고, 클럽 공지는 클럽원만 접근합니다.
삭제·교체된 이미지의 API 접근은 즉시 막고, 일일 작업에서 R2 객체와 DB 메타데이터를 정리합니다.

`DELETE /api/v1/media/images/:imageId`로 이미지를 제거할 수 있습니다.
클럽 이미지는 현재 클럽장, 프로필 이미지는 업로더만 삭제할 수 있습니다. 피드 사진은 main 게시글 수정·삭제 흐름에서 관리합니다.
공지·피드 삭제와 클럽 폐쇄 시 연결된 이미지도 삭제 상태로 변경합니다.

피드는 main의 기존 API를 사용합니다.

- `POST /api/v1/feed/posts`: `{ "body": "내용", "mediaIds": ["업로드 ID"] }`
- `GET /api/v1/feed/recommended`, `GET /api/v1/feed/following`: 추천·팔로잉 피드
- `GET/PATCH/DELETE /api/v1/feed/posts/:postId`: 상세·수정·삭제
- 응답의 `media[].url`은 조회자와 만료 시간에 묶인 서명 URL입니다. 기존 서명 쿼리를 그대로 유지합니다.

## Flutter 연결

- 피드 → 내 프로필 → 사진 변경: 프로필 사진 변경. 홈의 설정 진입은 유지합니다.
- 미가입 클럽 탭의 만들기: 대표 사진을 포함한 클럽 생성
- 클럽장 클럽 탭의 사진 아이콘: 대표 사진 변경
- 클럽 공지의 작성 버튼: 공지 사진 선택·게시
- 피드의 작성 버튼: 사진 게시, 목록의 썸네일 선택으로 본문 이미지 확대

로그인·갱신·로그아웃은 기존 `RunlineAuth` 흐름을 사용합니다. 별도의 세션 공급은 필요하지 않습니다.
서버 주소는 통합 설정의 `RUNLINE_API_ORIGIN`을 사용합니다.
웹 HTTP 허용 Origin은 `RUNLINE_WEB_ORIGIN`, WebSocket은 `CHAT_ALLOWED_ORIGINS`를 설정합니다.
로그인하지 않은 상태에서는 업로드하지 않고 로그인 안내를 표시합니다.

## 실행·검증

`003_images.sql`을 포함한 마이그레이션, 비공개 `runline-media` 버킷, Images 바인딩을 준비합니다.
설정은 [API 실행 안내](../README.md)를 따릅니다. 원격 리소스 생성·마이그레이션·배포는 자동 실행하지 않았습니다.

```powershell
# workers-api
npm run typecheck
npm test -- --run
npm run test:clubs

# runline
flutter test test/image_optimizer_test.dart test/image_upload_test.dart
```

서버 통합 테스트는 Sharp로 실제 파일을 생성하고 Images 변환을 재현해 SQL·R2 저장 및 권한을 확인합니다.
Workers 테스트는 로컬 Images·R2 바인딩으로 실제 PNG→WebP 변환을 별도로 검증합니다.
로컬 Images는 일부 옵션만 지원하는 시뮬레이터이므로 배포 후 실기기에서 EXIF·투명도·품질을 최종 확인해야 합니다.
