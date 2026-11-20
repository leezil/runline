# 앱 API 통합 설정

실제 설정은 `app.local.json`, 커밋용 빈 예제는 `app.local.example.json`입니다. 기존 설정이 있다면 덮어쓰지 마세요. 예제를 복사한 뒤 아래 항목을 입력합니다.

- `KAKAO_NATIVE_APP_KEY`: Android 앱에 사용할 카카오 Native App Key.
- `KAKAO_JAVASCRIPT_KEY`: Web 지도에 사용할 카카오 JavaScript 키.
- `API_BASE_URL`: 경로·시설 요청에 함께 사용할 서버의 HTTPS 기본 주소. `/v1/routes`, `/v1/places`는 각각 코드가 붙입니다.
- `API_TOKEN`: 경로·시설 요청에 함께 사용할 Bearer 토큰. `Bearer ` 접두사 없이 값만 입력합니다.

서버 실행 창의 현재 HTTPS 주소와 해당 서버의 `.api-token` 값을 사용하세요. 서버에서 `DRAWRUN_API_TOKEN`을 설정했다면 그 값이 우선입니다. ngrok 주소가 바뀌면 `API_BASE_URL`만 수정합니다. 두 API 클라이언트는 `lib/shared/config/api_config.dart`의 공통 설정을 읽습니다.

모든 설정은 아래처럼 빌드 시 주입합니다. Flutter 프로젝트 폴더(`pubspec.yaml`이 있는 폴더)에서 실행하세요.

```powershell
flutter run -d chrome --web-hostname localhost --web-port 5000 --dart-define-from-file=config/app.local.json
```

Android에서는 기기를 선택하고 같은 파일을 사용합니다.

```powershell
flutter run -d <android-device-id> --dart-define-from-file=config/app.local.json
```

설정을 변경한 뒤에는 실행 중인 Flutter 앱을 종료하고 다시 실행해야 합니다. 저장소 루트의 `start-chrome.ps1`도 이 파일을 읽으며 파일이 없으면 생성 방법을 안내하고 중단합니다.

카카오 Web 허용 도메인에는 실제 실행 주소인 `http://localhost:5000` 또는 `http://127.0.0.1:5000`을 등록합니다. Android 패키지는 `com.example.runline`이며 서명 인증서 키 해시도 등록해야 합니다.

`*.local.json`은 Git에서 제외하고 `app.local.example.json`은 빈 값으로 커밋합니다. 설정 파일을 Flutter assets에 추가하지 않습니다. 빌드 시 주입한 값도 클라이언트에서 추출될 수 있으므로 운영 인증은 서버와 사용자 인증으로 처리해야 합니다.

공공데이터 수집용 인증키와 Juso 주소·좌표 검색 키는 앱 설정에 넣지 않습니다. 이 키는 runline-api 서버의 `.env`에서 관리하며 앱은 서버에 저장된 시설 결과를 조회합니다.

시설 표시 버튼은 기본 꺼짐입니다. 켠 상태에서 지도 이동이 600ms 동안 멈추면 조회하며, 최근 조회 영역에 15% 여유를 두고 2분간 메모리 캐시를 재사용합니다. 요청은 한 번에 하나, 최소 5초 간격이며 캐시는 최대 12영역입니다. 조회 범위가 너무 넓거나 결과 200건이 잘렸다면 지도를 확대하세요. 오류 시 자동 반복 호출을 멈추며 429 응답은 Retry-After를 따릅니다. 빈 결과는 실제 시설 부재를 보장하지 않습니다.
