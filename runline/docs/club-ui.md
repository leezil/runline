# Flutter 클럽 화면 연결

## 이용 흐름

로그인 후 하단 클럽 탭에서 이용합니다. 기존 RunlineAuth와 RUNLINE_API_ORIGIN 설정을 공유합니다.

- 미가입: 추천 목록 → 바로 가입 또는 클럽 소개 → 즉시 가입. 돋보기로 이름·지역을 검색하고, 만들기 버튼으로 대표 사진을 포함한 클럽을 생성합니다.
- 가입 후: 소속 클럽 홈에 공지·멤버·클럽 러닝·채팅 버튼과 통합 피드를 표시합니다. 추천·검색·생성 버튼은 숨깁니다.
- 홈의 내 프로필 편집: 닉네임, 프로필 사진 변경·삭제.
- 홈의 클럽 설정: 클럽 소개 조회, 클럽장 정보·대표 사진 관리, 멤버 관리·위임, 멤버 탈퇴, 클럽장 폐쇄.
- 공지: 목록·상단 고정·상세·사진 확대·첨부 저장. 클럽장은 작성·수정·고정·삭제·사진/문서 추가·첨부 삭제.
- 멤버: 닉네임 검색·페이지네이션·프로필 조회. 클럽장은 다른 멤버 강퇴·클럽장 위임.
- 클럽 러닝: 모집 중·전체·예정·진행 중·지난 러닝·취소 목록. 모든 멤버가 생성·상세·참가자 조회·참가·참가 취소. 생성자는 시작 전 수정·취소.
- 통합 피드의 공지·러닝 글을 누르면 해당 상세로 이동합니다. 목록으로 돌아오면 최신 정보를 다시 조회합니다.
- 채팅: 기존 공용 텍스트 채팅, 읽음·미확인 수·재접속·전송 재시도를 사용합니다. 미확인 수 조회 실패가 클럽 피드를 막지 않습니다.

## 연결한 API

| 기능 | 주요 API |
|---|---|
| 가입 상태·추천·검색·소개·가입·생성 | GET /me/club, GET /clubs/recommended, GET /clubs, GET /clubs/:id, POST /clubs/:id/join, POST /clubs |
| 홈·통합 피드 | GET /clubs/:id/home, GET /clubs/:id/feed |
| 프로필 | GET/PATCH /me/profile, POST /me/avatar |
| 클럽 관리 | PATCH/DELETE /clubs/:id, POST /clubs/:id/leave, POST /clubs/:id/ownership |
| 대표 사진 | POST /clubs/:id/image, PATCH /clubs/:id의 imageUrl:null |
| 멤버 | GET /clubs/:id/members, DELETE /clubs/:id/members/:membershipId |
| 공지 | GET/POST /clubs/:id/notices, GET/PATCH/DELETE /clubs/:id/notices/:noticeId |
| 공지 첨부 | POST /clubs/:id/notices/:noticeId/attachments, GET/DELETE /clubs/:id/notices/:noticeId/attachments/:attachmentId |
| 러닝 | GET/POST /clubs/:id/runs, GET/PATCH /clubs/:id/runs/:runId, POST /clubs/:id/runs/:runId/cancel |
| 참가 | GET/POST /clubs/:id/runs/:runId/participants, DELETE /clubs/:id/runs/:runId/participants/me |
| 채팅 | 기존 chat 상태·이력·읽음 HTTP API 및 WebSocket |

모든 경로 앞에 /api/v1이 붙습니다. 이미지·첨부는 공개 R2 주소 대신 인증 헤더가 있는 API 요청으로 읽습니다.

범용 DELETE /media/images/:id를 직접 호출하는 별도 화면은 없습니다. 같은 사용자 동작을 프로필/대표 사진의 삭제 API와 공지 첨부 삭제 API로 제공합니다.

## 입력·권한·재시도

- 멤버의 공지 관리와 클럽장 전용 관리 버튼은 숨기고, 최종 권한은 서버에서 검사합니다.
- 위임·강퇴·탈퇴·폐쇄·공지/첨부 삭제·러닝/참가 취소는 확인 후 실행합니다.
- 생성자는 러닝 생성 시 자동 참가하므로 참가 취소 대신 러닝 취소를 사용합니다.
- 러닝 시간을 로컬 시간으로 표시하고 전송할 때 UTC로 변환합니다. 수정 시 바뀐 필드만 PATCH하여 이미 지난 모집 마감 시간이 수정 요청에 다시 실리지 않도록 합니다.
- 사진은 기존 최적화 파이프라인을 거칩니다. 공지 첨부는 사진·문서를 합쳐 최대 5개, 문서는 PDF·TXT·DOCX·XLSX, 파일당 최대 5MiB입니다.
- 공지 본문 저장 후 사진 업로드가 일부 실패하면 저장한 공지 ID와 성공한 업로드 위치를 유지하여 나머지만 다시 전송합니다.
- 페이지 추가 조회 실패 시 기존 목록과 커서를 유지합니다. 검색·필터가 바뀌면 이전 응답을 버립니다.
- 로그아웃 시 화면·대기 중 요청 결과를 폐기하고, 계정이 바뀐 상세·편집 화면과 확인 창은 가립니다. 이전 계정에서 시작한 요청에 새 계정의 인증 헤더를 붙이지 않습니다.

## 남은 부분과 검증 범위

기존 백엔드의 주요 클럽 사용자 기능은 위 화면에 연결했습니다.

- 문서(PDF·DOCX·XLSX 등)는 선택·업로드·기기 저장을 지원합니다. 문서 내용을 앱 내부에서 미리 보는 뷰어는 없습니다.
- 채팅은 기존 텍스트 범위입니다. 사진 전송·메시지 수정/삭제·대화 검색은 백엔드 기능이 없어 제공하지 않습니다.
- 공지 투표와 앱 알림은 초기 범위에서 제외되어 있습니다.
- 운영 Worker와 R2·Images·Durable Object 바인딩은 2026-11-27 승인 후 배포했습니다. DB 스키마 변경은 없으며, [배포 결과](../../workers-api/docs/club-deploy.md)를 참고하세요. 실제 로그인 계정을 이용한 권한·재접속·업로드 확인은 별도 검증이 필요합니다.
- 이 환경에는 Android SDK가 없어 APK 빌드와 Android 실기기 파일 선택·저장 검증을 완료하지 못했습니다. iOS 실행 대상 프로젝트도 현재 저장소에 없습니다.

테스트는 Mock HTTP 응답을 이용해 실제 화면의 API 경로·요청 본문·역할별 버튼·페이지 복구·파일 처리·계정 전환을 검증합니다. 네이티브 선택/저장 창은 테스트에서 메모리 어댑터로 대체합니다.

검증 명령:

- Flutter 전체 테스트: 209개 통과. 이 중 클럽 화면·연동 회귀 테스트 24개를 추가했습니다.
- 변경 영역 Dart 정적 분석: 문제 없음.
- Flutter 기본 웹 빌드: 성공. 기존 Kakao SDK의 Wasm 호환성 경고는 남아 있습니다.
- Android APK 빌드: Android SDK를 찾지 못해 실행 단계에서 중단되었습니다.

~~~powershell
flutter test
dart analyze lib/features/club lib/shared/media/runline_api.dart test/club_screens_test.dart
flutter build web
~~~
