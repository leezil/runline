# App1 지도·추천 API 로컬 설정

앱 사용 방법과 Chrome 실행 명령은 [RUNLINE 앱 안내](../README.md)에서 확인하세요.

- Android: `kakao.example.json`을 `kakao.local.json`으로 복사하고 `KAKAO_NATIVE_APP_KEY`를 입력한다.
- Web: `kakao.web.local.json`을 만들고 `KAKAO_JAVASCRIPT_KEY`에 JavaScript 키를 입력한다.
- 추천 API: `route-api.example.json`을 `route-api.local.json`으로 복사하고 현재 HTTPS 서버 주소와 `ROUTE_API_TOKEN`을 입력한다. 임시 ngrok 주소의 유효성은 보장하지 않는다.
- 기존 로컬 파일은 덮어쓰지 않는다. `config/*.local.json`은 Git 제외 대상이며 예제의 키·토큰 값은 비워 둔다.
- Android 패키지 `com.example.runline` 및 각 서명 인증서 키 해시(Base64 SHA-1)를 등록한다. Web은 실제 실행 origin을 카카오 허용 도메인으로 등록한다.
- `--dart-define-from-file`로 빌드 시 주입한다. Flutter asset에 설정 파일을 추가하지 않는다. 빌드 결과에서 설정이 추출될 수 있으므로 운영 비밀은 서버 relay와 사용자 인증으로 처리한다.
- API는 GET `/v1/health`(토큰 없음), POST `/v1/routes`(Bearer)를 사용한다. Web CORS 및 `Retry-After` 노출 설정을 서버에서 확인한다.
- GPS·러닝 측정·실제 코스 선택·로컬 기록은 구현되어 있다. 별도 캔버스 그림 입력이며 지도 위 직접 그리기, 실제 백그라운드 GPS, 교차로 회전 안내는 구현하지 않았다.
- 실제 지도 인증·기기 GPS·실서버 전체 흐름은 자동 테스트/빌드와 별도 검증이 필요하다.

## 피드 API 연결

피드는 Workers API의 `GET /api/v1/feed/posts`와 `POST /api/v1/feed/posts`를 사용합니다. 사진 첨부는 `POST /api/v1/feed/posts/:postId/images`, 사진 조회는 응답의 `/api/v1/media/images/:imageId` 경로를 사용합니다. 목록의 `nextCursor`로 다음 페이지를 요청합니다.

서버 주소는 `--dart-define=RUNLINE_API_BASE_URL=https://<api-host>`로 지정합니다. 기본값은 `http://localhost:8787`이며, 주소에 `/api/v1`을 붙이지 않습니다. 코스 추천용 `ROUTE_API_BASE_URL`과 별도 설정입니다.

모든 피드·사진 요청에는 `RunlineSession`의 RUNLINE 액세스 토큰이 Bearer 헤더로 전달됩니다. 인증 흐름에서 `/api/v1/auth/kakao` 교환 후 받은 RUNLINE 토큰을 `RunlineSession.instance.setAccessToken(token)`에 전달해야 합니다. 카카오 토큰을 피드에 직접 보내지 않습니다. 현재 Flutter에는 로그인 화면이 없어 세션 연결 전에는 로그인 안내가 표시됩니다. 사용자 토큰을 빌드 설정이나 소스에 저장하지 않습니다.

자동 검증: 앱 폴더에서 `flutter test test/feed_screen_test.dart test/image_upload_test.dart`. 이 검증은 HTTP 응답을 대체하며 실제 서버·DB·사진 저장소 연결 검증과는 별개입니다.
