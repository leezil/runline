# App1 지도·추천 API 로컬 설정

최신 실행 절차와 구현/미검증 범위는 [App1 README](../README.md)를 기준으로 한다. 이 파일은 GPS 개발 이전의 설정 설명을 현재 구현에 맞춰 정리한 것이다.

- Android: `kakao.example.json`을 `kakao.local.json`으로 복사하고 `KAKAO_NATIVE_APP_KEY`를 입력한다.
- Web: `kakao.web.example.json`을 `kakao.web.local.json`으로 복사하고 `KAKAO_JAVASCRIPT_KEY`를 입력한다.
- 추천 API: `route-api.example.json`을 `route-api.local.json`으로 복사하고 현재 HTTPS 서버 주소와 `ROUTE_API_TOKEN`을 입력한다. 임시 ngrok 주소의 유효성은 보장하지 않는다.
- 기존 로컬 파일은 덮어쓰지 않는다. `config/*.local.json`은 Git 제외 대상이며 예제의 키·토큰 값은 비워 둔다.
- Android 패키지 `com.example.runline` 및 각 서명 인증서 키 해시(Base64 SHA-1)를 등록한다. Web은 실제 실행 origin을 카카오 허용 도메인으로 등록한다.
- `--dart-define-from-file`로 빌드 시 주입한다. Flutter asset에 설정 파일을 추가하지 않는다. 빌드 결과에서 설정이 추출될 수 있으므로 운영 비밀은 서버 relay와 사용자 인증으로 처리한다.
- API는 GET `/v1/health`(토큰 없음), POST `/v1/routes`(Bearer)를 사용한다. Web CORS 및 `Retry-After` 노출 설정을 서버에서 확인한다.
- GPS·러닝 측정·실제 코스 선택·로컬 기록은 구현되어 있다. 별도 캔버스 그림 입력이며 지도 위 직접 그리기, 실제 백그라운드 GPS, 교차로 회전 안내는 구현하지 않았다.
- 실제 지도 인증·기기 GPS·실서버 전체 흐름은 자동 테스트/빌드와 별도 검증이 필요하다.
