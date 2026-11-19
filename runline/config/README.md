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

## 러닝 지도 시설 표시

`facilities.example.json`을 `facilities.local.json`으로 복사해 다음 값을 입력한다.

- `PLACES_API_BASE_URL`에는 `runline-api` 실행 창에 표시되는 HTTPS 기본 주소를 입력한다. `/v1/places`는 코드가 붙인다.
- `PLACES_API_TOKEN`에는 `runline-api` 서버의 `.api-token` 값 또는 서버에 설정한 `DRAWRUN_API_TOKEN` 값을 입력한다.
- 시설 설정을 별도로 주입하지 않으면 `ROUTE_API_BASE_URL`, `ROUTE_API_TOKEN` 설정을 사용한다.

Chrome에서는 `kakao.web.example.json`을 `kakao.web.local.json`으로 복사해 `KAKAO_JAVASCRIPT_KEY`에 카카오 JavaScript 키를 입력한다. 카카오 Web 도메인에 `http://localhost:5000`과 `http://127.0.0.1:5000`을 등록한다. Flutter 프로젝트 폴더에서 실행한다.

```powershell
flutter run -d chrome --web-port 5000 --dart-define-from-file=config/kakao.web.local.json --dart-define-from-file=config/facilities.local.json
```

그림 경로 생성까지 테스트할 때는 기존 `--dart-define-from-file=config/route-api.local.json`도 추가한다. Android에서는 Web 키 대신 `config/kakao.local.json`의 Native App Key를 주입한다.

시설 수집에 쓰는 공공데이터 인증키는 `runline-api/.env`의 `PUBLIC_DATA_SERVICE_KEY`에 입력한다. 화장실 주소 변환 설정은 같은 파일의 `JUSO_SEARCH_KEY`, `JUSO_COORD_KEY`, `JUSO_STORAGE_APPROVED`이며 자세한 발급 조건은 서버의 `.env.example`과 좌표 변환 안내를 따른다. 실제 서버는 이미 수집·주소 변환 기능을 제공하며 앱은 `/v1/places`의 저장된 결과를 조회한다.

시설 표시 버튼은 기본 꺼짐이다. 켠 상태에서 지도 이동이 600ms 동안 멈추면 조회한다. 최근 조회 영역에 15% 여유를 두고 2분간 메모리 캐시를 재사용한다. 요청은 한 번에 하나, 최소 5초 간격이며 캐시는 최대 12영역이다. 10km에 가까운 넓은 범위는 확대를 안내한다. 최대 200건에서 결과가 잘렸다면 확대 후 재조회한다. 백그라운드에서는 대기 요청을 취소하고, 늦은 응답은 화면에 적용하지 않는다. 오류 시 자동 반복 호출을 멈추며 429 응답은 Retry-After를 따른다. 수집 지역 밖의 빈 결과는 실제 시설 부재를 보장하지 않는다.
