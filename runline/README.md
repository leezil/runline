# RUNLINE 앱

자유 러닝을 시작하거나 거리·시간 목표를 정해 달릴 수 있습니다. 직접 그린 모양과 비슷한 러닝 코스를 찾아 지도에서 따라 달릴 수도 있습니다.

## 기능 사용 방법

| 기능 | 사용 방법 |
| --- | --- |
| 자유 러닝 | **홈 → START**를 누르고 위치 권한을 허용합니다. 러닝 중 지도에서 이동 경로를 보고 거리, 시간, 평균 페이스를 확인할 수 있습니다. |
| 거리·시간 목표 러닝 | **홈 → 목표 설정**에서 **거리** 또는 **시간**을 고릅니다. 슬라이더나 ＋·－ 버튼으로 목표를 조절하고 **시작**을 누르면 현재 수치와 목표 진행률이 표시됩니다. |
| 그림으로 코스 찾기 | **홈 → 루트 그리기**에서 한 획으로 모양을 그리거나 별·하트·달을 선택합니다. 거리 범위를 정하고 **그림 찾기**를 누른 뒤 목표 거리와 시작 기준 위치를 입력합니다. **현재 위치에서 코스 찾기**를 누르면 GPS 위치를 사용할 수 있습니다. **경로 생성**을 누르면 조건에 맞는 코스를 검색합니다. |
| 추천 코스 따라 달리기 | 추천 결과에서 코스를 고르면 지도에 경로가 표시됩니다. **이 코스로 달리기**를 누르면 GPS를 바탕으로 통과한 구간과 남은 구간을 표시하고 경로 이탈을 알려줍니다. |
| 러닝 기록 | **홈 → 러닝 기록**에서 목록을, **활동**에서 주·월·년 통계와 러닝 달력을 확인합니다. 완료 기록을 열면 이동 거리, 시간, 평균 페이스, 실제 이동 경로를 볼 수 있습니다. 추천 코스로 달린 기록에는 코스 통과 정보도 표시됩니다. |

목표 러닝 화면에서 옆으로 넘기거나 **구간**을 선택하면, 완료한 1km마다 페이스와 직전 구간 대비 편차를 확인할 수 있습니다. 잰 시간을 멈추려면 **일시정지**, 계속 달리려면 **재개**를 누릅니다. 기록을 마치려면 **종료**를 길게 누릅니다.

그림은 도로 모양을 찾기 위한 기준으로 사용됩니다. 주변 도로와 설정한 거리에 따라 결과가 달라지거나 추천 코스가 없을 수 있습니다. 칼로리·고도·심박수처럼 앱에서 수집하지 않는 값은 `—`로 표시합니다.

## Chrome에서 실행하기

Flutter SDK와 Chrome이 필요합니다. PR의 원형 **START**, **루트 그리기**, **목표 설정** 화면을 확인하려면 `feat/home-start-layout` 브랜치의 앱을 실행하세요.

앱 폴더의 `config/kakao.web.local.json`에 카카오 JavaScript 키를 설정하고, 카카오 JavaScript SDK의 허용 도메인에 `http://localhost:5000`을 등록합니다. 실제 경로 추천을 사용하려면 같은 앱 폴더의 `config/route-api.local.json`에 추천 서버 주소와 개발용 토큰을 설정합니다. [지도 및 추천 API 설정](config/README.md)

**별도 통합 작업 폴더를 만든 경우** 아래 블록 전체를 원래 작업 폴더의 PowerShell에 붙여 넣으세요. 통합 폴더가 없거나 브랜치가 다르면 실행 전에 멈춥니다.

```powershell
& {
  Set-Location -LiteralPath .integration-main-app1/runline -ErrorAction Stop
  if ((git branch --show-current) -ne 'feat/home-start-layout') {
    throw 'feat/home-start-layout 브랜치로 이동한 뒤 실행하세요.'
  }

  $runArgs = @(
    'run', '-d', 'chrome',
    '--web-hostname', 'localhost',
    '--web-port', '5000',
    '--dart-define-from-file=config/kakao.web.local.json'
  )
  if (Test-Path -LiteralPath config/route-api.local.json) {
    $runArgs += '--dart-define-from-file=config/route-api.local.json'
  }
  flutter @runArgs
}
```

**저장소를 일반 폴더에 체크아웃한 경우** 해당 저장소의 `runline` 앱 폴더에서 아래 명령을 실행합니다. PR을 확인하는 중이라면 먼저 `git branch --show-current`로 브랜치가 맞는지 확인하세요.

```powershell
flutter run -d chrome --web-hostname localhost --web-port 5000 --dart-define-from-file=config/kakao.web.local.json
```

일반 폴더에서 그림 코스 추천도 사용하려면 실행 명령 끝에 `--dart-define-from-file=config/route-api.local.json`을 붙입니다. 로컬 설정 파일을 변경했거나 5000번 포트에 앱이 이미 떠 있으면 기존 Flutter 실행을 종료한 뒤 다시 실행하세요.

웹 러닝을 시작하려면 브라우저의 위치 권한을 허용해야 합니다. 기록은 현재 브라우저 프로필과 실행 주소의 IndexedDB에 저장되므로, 이전 기록을 보려면 같은 프로필과 주소로 접속합니다.
