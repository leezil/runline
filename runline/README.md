# runline

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## App1 개발 담당 기능

Flutter 기반 Android/Web 지도 및 GPS 러닝을 담당한다. 아래 내용은 이 브랜치에 반영된 코드 기준이며 다른 팀원의 서비스 구현 설명을 복사하지 않았다.

### 구현 기능과 사용 흐름

1. 홈 START 또는 자유 러닝에서 위치 권한을 확인하고 측정을 시작한다. 거리/시간 목표를 사용할 수 있다.
2. 그림 검색에서는 **지도와 별도의 캔버스**에 자유 그림을 입력하거나 별·하트·초승달 외곽선을 선택한다. 캔버스 좌표를 실제 위도·경도로 간주하지 않는다.
3. 목표 거리와 기준 경도·위도를 직접 입력하고 서버 상태 확인 및 경로 생성을 요청한다. 기준 위치는 GPS로 자동 입력하지 않는다. v1은 하나로 이어진 stroke를 요구하며 여러 stroke를 임의로 연결하지 않는다.
4. 실제 OSM API 응답의 허용된 후보만 코스 러닝에 사용할 수 있다. mock 미리보기·synthetic·비교 후보는 실제 코스 러닝으로 시작하지 않는다. 오류·빈 결과를 가짜 추천으로 대체하지 않는다.
5. 러닝 중 GPS 거리·활동 시간·평균 페이스와 현재 위치·이동 궤적을 표시하고 일시정지·재개·종료를 지원한다. 부정확·오래된 위치, 순간 점프 등을 걸러내며 중단 후 궤적을 직선으로 연결하지 않는다.
6. 추천 코스는 미통과 파랑, 통과 확인 초록, 실제 GPS 궤적 보라로 표시한다. 자유 러닝 궤적은 초록이다. 현재 위치 마커와 추적/재중심 기능을 제공한다.
7. 코스 좌표에 GPS를 투영해 실제 통과 범위를 계산한다. 진행률·남은 거리, 이탈·복귀 상태와 다음 구간 방향을 표시한다. 방향 화살표는 교차로 회전 지시가 아니다.
8. 로컬 체크포인트를 저장하고 미완료 세션을 일시정지 상태로 복구한다. 종료 후 상세 및 홈의 러닝 기록 목록에서 날짜·거리·페이스·코스·저장 궤적을 조회한다. Activity 탭의 목록 UI를 완성한 것으로 설명하지 않는다.

### 기술과 구조

- Flutter/Dart(Material), `kakao_map_sdk 1.3.1` 및 Web JavaScript interop
- `http`: 추천 API, `geolocator`: 위치 권한·스트림
- `sembast`/`sembast_web`/`path_provider`: Android 파일 DB 및 Web IndexedDB
- `lib/features/route_drawing/`: 캔버스·프리셋·생성 화면
- `lib/features/route_generation/`: API 계약·요청 검증·검색 설정
- `lib/features/route_recommendation/`: 추천 모델·선택 화면
- `lib/features/running/`: 측정·GPS·타이머·생명주기·코스 진행
- `lib/features/running/history/`: 저장·복구·목록·상세
- `lib/shared/widgets/`: Android/Web 지도와 러닝 오버레이
- `test/`: 엔진·위젯·API 대역·저장 호환/복구 테스트

### 실행 준비와 지도 설정

이 README의 명령은 Flutter 프로젝트 폴더 `runline`에서 실행한다. Dart SDK 요구사항은 `pubspec.yaml`의 `^3.13.5`다. Android SDK/JDK 및 Flutter Android 도구도 준비해야 한다.

```powershell
cd runline
flutter pub get
Copy-Item config/kakao.example.json config/kakao.local.json
Copy-Item config/kakao.web.example.json config/kakao.web.local.json
Copy-Item config/route-api.example.json config/route-api.local.json
```

이미 로컬 설정 파일이 있으면 덮어쓰지 않는다. 개인 키와 토큰은 로컬 파일에만 입력하고 출력·공유·커밋하지 않는다. `config/*.local.json`은 기존 Git ignore 대상이다.

- Android: `kakao.local.json`의 `KAKAO_NATIVE_APP_KEY`를 설정한다. Kakao Developers에서 지도 사용을 설정하고 Android 패키지 `com.example.runline`과 각 개발자/릴리스 서명 인증서의 키 해시를 등록한다. 네이티브 지도는 ARM/ARM64를 대상으로 하며 x86/x64는 지원 안내를 표시한다.
- Web: `kakao.web.local.json`의 `KAKAO_JAVASCRIPT_KEY`를 설정하고 실행 origin(예: `http://localhost:5000`)을 카카오 허용 도메인으로 등록한다. GPS에는 HTTPS 또는 브라우저가 신뢰하는 localhost와 위치 권한이 필요하다.
- 지도 키가 없거나 인증/플랫폼 조건이 맞지 않으면 안내 화면을 표시한다. 키 없는 빌드 성공은 실제 지도 인증 성공을 의미하지 않는다.

```powershell
flutter run -d chrome --web-port 5000 --dart-define-from-file=config/kakao.web.local.json --dart-define-from-file=config/route-api.local.json
flutter devices
# 아래 기기 ID를 flutter devices 결과로 교체한다.
flutter run -d YOUR_ANDROID_DEVICE_ID --dart-define-from-file=config/kakao.local.json --dart-define-from-file=config/route-api.local.json
```

### 추천 API 설정

`route-api.local.json`에 서버 담당자가 제공하는 현재 HTTPS 주소를 `ROUTE_API_BASE_URL`, 개발용 토큰을 `ROUTE_API_TOKEN`으로 입력한다. 코드/예제의 임시 ngrok 주소가 현재 살아 있다고 보장하지 않는다. 실제 키·토큰은 이 문서에 포함하지 않는다.

- `GET /v1/health`: 상태 확인(토큰 미전송)
- `POST /v1/routes`: Bearer 인증, 캔버스 크기·점·거리·기준 위치·탐색 조건 전송
- 목표 거리: 300–8000m와 사용자가 선택한 범위를 함께 만족해야 한다. 기준/집중 위치는 국내 경도 124–132, 위도 32–39 범위로 검증한다.
- `세부 탐색 설정`에서 탐색 반경·후보 수·회전 등 조건을 변경한다. local 탐색에는 별도 집중 위치가 필요하다. 중복 요청을 차단하고 HTTP 제한 시간은 120초다.
- Web 서버는 CORS 및 필요한 헤더를 허용해야 한다. `Retry-After`를 읽으려면 `Access-Control-Expose-Headers`에 노출해야 한다.
- build-time 주입은 소스 커밋을 피하는 방법이며 비밀을 숨기는 보안 저장소가 아니다. Web 코드/네트워크와 앱 바이너리에서 설정이 노출될 수 있다. 운영용 비밀 토큰은 서버 relay와 사용자 인증으로 처리해야 한다.

### 저장·진행 판정과 제한 사항

Android는 앱 지원 디렉터리 `runline-running-v1.db`, Web은 origin/port별 IndexedDB `runline-running-v1`을 사용한다. 활동 시간 약 5초 간격 및 상태 변경 시 저장하고, 복구 시 프로세스가 없던 시간과 위치 이동을 합산하지 않는다. 마지막 미저장 체크포인트는 강제 종료 시 유실될 수 있다. 브라우저 데이터 삭제/축출, 저장 실패·권한 제한의 영향을 받으며 별도 암호화·서버 동기화는 없다.

GPS 측정 필터와 코스 통과 기준은 별개다. 기본 통과 판정은 정확도 반경 12m 이하, 코스 허용 거리 10m를 사용한다. 이탈 30m/정확한 위치 3회, 복귀 18m 기준이며 교차·반복 구간에서는 순서를 보수적으로 확인한다. 건너뛴 구간을 자동 완료하지 않는다. 진행률/남은 거리는 코스 좌표의 기하학적 길이 기준이라 서버 표시 거리와 다를 수 있다. 완주/목표 달성 시 자동 종료하지 않는다.

전경 러닝만 지원하며 앱 숨김/잠금 시 일시정지하고 사용자가 명시적으로 재개한다. 백그라운드 GPS, 음성 안내, 교차로별 회전 지시, 자동 재탐색, 기록 삭제 정책·서버 동기화는 구현하지 않았다. GPS만으로 평행/다층 도로와 정지 드리프트를 완벽히 구분하지 못한다.

### 자동 검증 결과

검증일: 2026-11-12(KST), main 미병합 App1 전용 feature 작업본. Flutter 3.47.8 / Dart 3.13.7.

| 항목 | 이번 실행 결과 |
| --- | --- |
| `flutter pub get` | 성공 |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | 130개 통과, 실패 0개(VM) |
| `flutter build web --no-pub` | JavaScript 빌드 성공 |
| `flutter build apk --debug --target-platform android-arm64 --no-pub` | ARM64 debug APK 빌드 성공 |
| 변경 범위·비밀정보 | 승인된 53개 경로만 변경, 키·토큰 패턴/추적 로컬 설정 없음 |

지도 키·API 토큰을 주입하지 않은 빌드다. Kakao SDK 1.3.1의 Wasm 사전 검사 호환성 경고와 Android SDK XML 버전/Geolocator deprecated API 경고가 있었으나 위 빌드는 성공했다. Wasm 빌드는 검증하지 않았다.

복사된 원본 코드의 CRLF 바이트는 보존했다. 공백 검사는 저장소 설정을 바꾸지 않고 CR을 줄끝으로 인정하는 `git -c core.whitespace=trailing-space,space-before-tab,cr-at-eol diff --check` 및 동일 옵션의 staged 검사로 수행했다. 기본 옵션의 staged 검사는 CRLF 신규 파일을 줄끝 공백으로 보고할 수 있다. 실제 스페이스/탭 줄끝 공백은 별도로 검사했다. 이번 변경에는 main의 workers-api 파일을 포함하지 않으므로 이전 main 통합본의 공백 5곳 예외는 적용하지 않는다.

재현 명령(지도 키·토큰 없이 수행하는 빌드 검증):

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
flutter build apk --debug --target-platform android-arm64 --no-pub
```

`git diff --check`와 허용 파일 목록·비밀정보 검사도 수행한다. VM 테스트에는 브라우저 전용 테스트가 포함되지 않는다. Web JavaScript 빌드 성공을 Wasm 지원이나 브라우저 실행 검증으로 해석하지 않는다.

### 실제 환경에서 남은 검증

- Android ARM64 실기기 GPS: 권한 허용/거부, 정지·이동·신호 단절, 실제 거리/배터리, 잠금/재개
- 카카오 실제 키·도메인·키 해시 인증과 지도·마커·카메라·색상 표시
- 실제 추천 서버의 인증·CORS·추천부터 러닝 종료까지 전체 흐름
- 브라우저 실제 GPS·IndexedDB 재실행 복구 및 다중 탭
- 장시간 러닝 성능과 평행 도로/교차/반복 구간 오탐

11월 9일 개발 사본의 130개 테스트 통과는 과거 참고 결과다. main 통합본의 132개는 이번 App1 전용 브랜치 검증 결과로 사용하지 않는다. 상세 알고리즘은 [코스 진행 문서](docs/running-navigation.md), 11월 7일 측정·저장 개발 이력은 [러닝 개발 메모](docs/app1-running.md)를 참고한다.
