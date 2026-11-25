> 이 문서는 2026-11-07 개발 이력이다. 아래의 108개 테스트 및 내비게이션·기록 UI 미구현 설명은 당시 상태다. 현재 구현과 새 검증 결과는 [App1 README](../README.md) 및 [코스 진행 문서](running-navigation.md)를 따른다.

# App1 러닝 구현 및 검증 메모

기준일: 2026-11-07 (KST). 작업 브랜치: `feature/app1-map-drawing-running`.

## GPS와 상태 관리

- `RunningLocation`이 플랫폼 권한/위치 스트림을 제공하고 `RunningController`가 타이머와 생명주기를 관리한다. 위치 데이터는 테스트에서만 명시적으로 주입한다.
- 시작/재개는 서비스와 전경 위치 권한을 확인한 후 진행한다. 준비 중 중복 요청을 막으며, 권한 확인의 30초 제한 타이머도 일시정지/종료/dispose 시 취소한다. 플랫폼 권한 대화상자 자체를 강제 종료하지는 않는다.
- `hidden`/`paused`에서 자동 일시정지하고, 다시 돌아와도 사용자가 재개해야 한다. `inactive`는 권한 대화상자에서도 발생하므로 중지 신호로 사용하지 않는다.
- 신호가 없는 15초 동안은 연결/약한 신호 상태이며 정상 측정 상태로 표시하지 않는다. 위치 오류를 사용자 메시지로 바꾸고, 회복한 스트림의 첫 유효 좌표는 새 구간의 기준점으로 삼는다. 스트림이 완전히 끝나면 일시정지 후 재개로 재구독할 수 있다.
- 실제 GPS 스트림은 Android/Web에서만 사용한다. Web은 HTTPS 또는 브라우저가 신뢰하는 localhost 및 위치 API가 필요하다. 브라우저/OS의 위치 제공 여부에 따른 오류는 측정 불가 상태로 표시한다. [Geolocator 공식 설명](https://pub.dev/packages/geolocator/versions/14.1.2)

## 거리·페이스 및 필터 기준

`RunningMeasurement`의 `GpsFilterSettings`가 실기기 조정 지점이다.

| 설정 | 기본값 | 동작 |
| --- | --- | --- |
| 최대 정확도 반경 | 25m | 초과 시 제외하고 구간을 끊음 |
| 최소 이동 | 5m | 이보다 작은 변위는 앵커를 유지하며 누적하지 않음 |
| 정확도 이동 계수 | 0.5 | 최소 이동량과 양쪽 정확도 반경의 최댓값 × 계수 중 큰 값 적용 |
| 최대 속도 | 10m/s | 초과하는 점프 제외, 기존 앵커 유지 |
| 최대 GPS 간격/위치 나이 | 15초 | 장기 단절·오래된 좌표는 연결하지 않음 |
| 허용 미래 시각 | 5초 | 그 이상 미래인 위치는 제외 |
| 페이스 표시 최소 거리 | 20m | 미만이면 `--'--"` |

위도/경도 범위, 유한수, 정확도, 시간순서를 검증한다. Haversine과 평균 지구 반경 6,371,000m로 지표면 거리를 구해 내부적으로 미터 단위로 누적한다. 페이스는 활동 시간(초) / 거리(km)를 초 단위 반올림해 분·초로 표시한다. 고도/경사 보정은 하지 않는다. 목표 진행률은 거리 또는 활동 시간으로 계산하고 0~1로 제한하며 자동 종료하지 않는다.

GPS만으로 모든 정지 드리프트를 구별할 수는 없다. 도심·실내·개방 공간에서 정지, 걷기, 느린 달리기를 비교해 과소/과대 측정을 확인해야 한다.

## 추천 경로 연결

- 기존 API 결과의 선택 객체를 그대로 전달한다. 시작 시 경로 API를 다시 호출하지 않는다.
- `source=api`이며 유효한 2개 이상의 좌표와 양의 거리가 있는 경로만 시작 가능하다. Mock/synthetic/비교 후보/빈 결과는 시작하지 못한다.
- 서버 `[경도, 위도]`는 기존 파서에서 `LatLng(위도, 경도)`로 변환한다. 러닝 화면은 변환된 동일 좌표 목록을 기존 Kakao Map에 전달한다.
- 추천 코스 거리는 목표이며 실제 측정 거리는 GPS로만 증가한다. 자유 러닝과 추천 경로 러닝을 구분해 표시한다. 길 안내와 이탈 감지는 구현하지 않는다.

## 로컬 기록 저장과 조회 인터페이스

기존 영속 저장 계층이 없어 Sembast를 선택했다. 별도 네이티브 SQLite/웹 SQLite 구성을 추가하지 않고 트랜잭션과 메모리 테스트를 공유할 수 있다. Android는 `path_provider` 앱 지원 디렉터리의 `runline-running-v1.db`, Web은 `runline-running-v1` IndexedDB를 사용한다. [Sembast 저장 방식](https://github.com/tekartik/sembast.dart), [Web 구현](https://pub.dev/packages/sembast_web)

- `RunningRecord`: 세션 ID, 시작/갱신 시각, revision, 상태, 활동 시간, 거리, 필터링된 GPS 좌표, 구간 시작 인덱스, 목표, 선택 코스 스냅샷. 원시 GPS 오류나 API 토큰은 저장하지 않는다.
- `RunningSessionRecorder`: 활동 시간 5초마다 및 상태 변경 시 체크포인트를 직렬 저장한다. 종료 후 flush를 기다린다. 화면 이탈은 일시정지 체크포인트로 남기며 완료 기록으로 바꾸지 않는다.
- 저장소는 세션 ID로 upsert하고, 같은/오래된 revision 및 확정된 완료 기록의 덮어쓰기를 트랜잭션으로 막는다. 위치 권한을 얻지 못한 준비 상태는 기록하지 않는다.
- 재진입하면 가장 최근의 미완료 세션에 대해 새 러닝/이어서 진행을 선택할 수 있다. 복구는 같은 세션 ID, 목표/코스/누적값을 유지하며 일시정지로 시작한다. 프로세스가 없던 시간과 복구 전후의 공간 이동은 합산하지 않는다.
- 저장 실패는 화면에 표시하고 재시도를 제공하며 GPS 자체는 계속 사용할 수 있다. 종료 시 확인 버튼은 현재 저장 시도와 구독 해제를 기다린다.
- Activity 담당자는 `RunningHistory.open()` 후 `list(finished: true)`, `list(finished: false)`, `read(id)`를 사용할 수 있다. 앱 공용 저장소이므로 화면 단위에서 `close()`하지 않는다. ActivityScreen과 다른 탭은 변경하지 않았다.

제약: 강제 종료 직전 아직 커밋하지 못한 체크포인트는 복구할 수 없다(정상 처리 중 최대 약 5초 및 저장 지연). Web 기록은 origin/port에 종속되고 브라우저 데이터 삭제/축출의 영향을 받는다. 별도 암호화/서버 동기화는 없다. Sembast는 데이터를 메모리에 적재하므로 장기·대량 기록에는 페이지 조회 및 저장 백엔드 교체를 검토해야 한다. 여러 탭/프로세스에서 동일 세션을 동시에 복구하는 사용 흐름은 아직 지원 범위로 검증하지 않았다.

## Android 백그라운드 GPS 도입 계획 — 이번에는 활성화하지 않음

현재 foreground notification 설정은 전달하지 않으며 `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`를 앱 Manifest에 추가하지 않았다. 잠금/앱 숨김은 현재 기능에서 일시정지로 처리한다.

설치된 `geolocator_android 5.2.1` 소스 확인 결과 플러그인 Manifest에는 `location` 타입의 비공개 서비스가 선언되어 있고, `AndroidSettings.foregroundNotificationConfig`를 제공할 때 foreground 모드를 활성화한다. 이 설정만으로 Activity 파괴/프로세스 종료 이후까지 추적하는 별도 Flutter 엔진을 보장하지 않는다. 패키지 최신 문서와 실제 고정 버전 Manifest의 권한 선언이 다를 수 있으므로 최종 merged Manifest로 확인해야 한다. [AndroidSettings API](https://pub.dev/documentation/geolocator_android/5.2.1/geolocator_android/AndroidSettings-class.html)

| Android | 도입 시 확인할 제약 |
| --- | --- |
| 8~9 | 알림 채널과 foreground service 알림, 9 이상 `FOREGROUND_SERVICE` 선언 |
| 10~11 | `location` 서비스 타입, 백그라운드 위치 권한이 필요한 사용 흐름의 구분 및 전경/백그라운드 단계별 요청 |
| 12 | 백그라운드에서 FGS 시작 제한, 대략적 위치만 허용된 경우의 정확도 처리 |
| 13 | `POST_NOTIFICATIONS` UX. 알림 권한 없이 FGS를 시작할 수 있어도 서비스 알림 자체는 필요하며 거부 시 표시 위치가 달라짐 |
| 14 이상 | `FOREGROUND_SERVICE_LOCATION`과 위치 런타임 권한/서비스 활성화 선행. 보이는 Activity에서 시작해야 하며 while-in-use 조건 위반 시 `SecurityException` 가능 |
| 15~16 | 최신 시작 제한 재검증. 15의 6시간 제한은 현재 `dataSync`/`mediaProcessing`에 적용되므로 `location`에 그대로 적용하지 않음. WorkManager를 지속 GPS 소유자로 대체하지 않음 |

근거: [FGS 타입 및 전제 조건](https://developer.android.com/develop/background-work/services/fgs/service-types#location), [백그라운드 시작/while-in-use 제한](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [알림 런타임 권한](https://developer.android.com/develop/ui/compose/notifications/notification-permission), [타입별 시간 제한](https://developer.android.com/develop/background-work/services/fgs/timeout).

제안 순서:

1. 사용자가 화면에서 시작한 러닝을 잠금 중에도 계속할 범위를 먼저 확정한다. 보이는 화면에서 시작한 location FGS를 유지하는 흐름과 백그라운드에서 새 서비스를 시작/재시작하는 흐름을 구분한다. 후자는 더 강한 권한/예외 조건이 필요할 수 있다.
2. `RunningLocation` 경계와 거리·페이스 엔진은 재사용하고, 추적 소유권을 Screen 밖의 앱 세션 서비스로 옮긴다. 현재 자동 일시정지는 정책 객체로 분리하되 기능 플래그 기본값은 전경 전용으로 둔다.
3. 단일 추적 스트림/단일 저장 작성자, 알림의 일시정지·종료 액션, Android service 종료, UI 재접속을 구현한다. process-death 복구가 필요하면 geolocator 설정만으로 보장하지 말고 네이티브 서비스/별도 엔진 대안을 검증한다. Sembast IO는 다중 isolate 동시 작성에 사용하지 않는다.
4. visible Activity에서 권한 선행 확인 후 location FGS를 시작한다. `ACCESS_BACKGROUND_LOCATION`은 실제로 요구되는 사용 흐름일 때만 별도 단계로 검토한다. 재부팅/강제 종료 시 자동 시작은 기본 기능으로 넣지 않는다.
5. Pixel/Samsung ARM64에서 Android 12~16, 화면 잠금, 절전, 알림 권한 거부, 정밀/대략적 위치, OS 서비스 중지, 프로세스 종료를 검증하고 merged Manifest 및 Play Console 선언을 확인한 후 활성화한다. [Play 위치 정책](https://support.google.com/googleplay/android-developer/answer/9799150)

## 기기·서버 검증 체크리스트

- Android ARM64: 최초 권한 허용/거부/영구 거부, 설정 복귀, 위치 서비스 도중 끄기/켜기, 잠금 시 일시정지, 재개 첫 좌표 연결 방지, 뒤로 가기와 재진입 복구, 종료 뒤 스트림 없음.
- GPS: 개방 공간 실제 코스 거리 비교, 정지 3~5분 드리프트, 느린 이동, 순간 점프/신호 단절, 분/km와 목표 진행률, 앱 강제 종료 후 마지막 체크포인트 복구.
- 로컬: 앱 재시작/완료 기록 보존, 저장 공간 부족·Web IndexedDB 제한, 저장 오류 후 재시도, 동일 origin/port의 Web 새로고침 복구.
- Web: HTTPS/localhost에서 허용·거부, API 미지원/비보안 환경에서 안전한 메시지, 숨김 후 명시적 재개, Kakao 허용 도메인과 SDK 키가 있는 실제 지도 오버레이.
- 서버 필요: 최신 OSM 응답의 추천 후보 선택부터 러닝 시작까지 실응답 확인, 정확한 좌표·거리·Kakao 오버레이. 이미 받은 스냅샷 기반 시작/측정/저장/복구에는 서버가 필요하지 않다.

서버 업로드, Activity 목록 UI, 기록 삭제/보존 정책, 내비게이션, 경로 이탈 감지, 실제 백그라운드 추적은 후속 작업이다.

## 이번 러닝 작업의 파일 목록

중단 전부터 있던 그림/프리셋/API/지도 관련 미커밋 변경은 그대로 유지했다. 이번 작업 범위의 파일은 다음과 같다.

- 수정: `lib/features/running/running_screen.dart`, `running_timer.dart`.
- 추가: `lib/features/running/running_location.dart`, `running_measurement.dart`, `running_controller.dart`.
- 추가: `lib/features/running/history/running_record.dart`, `running_history_repository.dart`, `running_history_database_io.dart`, `running_history_database_web.dart`, `running_history_database_stub.dart`, `running_session_recorder.dart`.
- 경로 연결 보완: 기존 미커밋 파일 `lib/features/route_recommendation/recommended_route.dart`, `route_recommendation_screen.dart`.
- 설정: `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, `pubspec.lock`.
- 기존 테스트 수정: `test/running_screen_test.dart`, `home_screen_test.dart`, `route_drawing_screen_test.dart`.
- 테스트 추가: `test/fake_running_location.dart`, `fake_running_history.dart`, `flutter_test_config.dart`, `running_gps_test.dart`, `running_location_test.dart`, `running_history_test.dart`, `running_connection_test.dart`.
- 문서: `docs/app1-running.md`.

테스트 설정 파일은 위젯 테스트에만 명시적인 저장소 대역을 주입한다. 실제 영속성 검증은 Sembast 메모리 트랜잭션과 파일 DB close/reopen 테스트로 별도 수행하며, GPS 좌표는 명시적인 테스트 제공자만 사용한다.

## 최종 자동 검증 결과

- `flutter test --no-pub`: 108개 통과, 0개 실패.
- `flutter analyze --no-pub`: No issues found.
- `git diff --check`: 오류 없음.
- `flutter build web --no-pub`: 기본 JavaScript Web 빌드 성공. Wasm 사전 검사에서는 기존 `kakao_map_sdk 1.3.1`의 external interop 매개변수 기본값 관련 경고가 출력됐다. Wasm 빌드 성공이나 실제 브라우저 GPS 동작을 검증한 것은 아니다.
- Android 빌드/실기기 GPS, 브라우저 실제 권한/IndexedDB/지도, 실제 서버와의 종단 흐름은 수행하지 않았다.

기존 목표 화면 테스트 실패는 Fake 위치를 이미 주입한 상태에서 구독 취소/재개 비동기 처리가 끝나기 전에 확인하던 문제였다. 실제 기능을 무조건 running으로 바꾸지 않고 테스트에서 취소 완료 및 화면 갱신을 기다리도록 수정했다. 추가 검증 중 발견된 실제 코드 문제(권한 준비 timeout 생명주기, 스트림 종료 시 서비스 오류 설명 유실)도 수정하고 회귀 테스트를 추가했다.
