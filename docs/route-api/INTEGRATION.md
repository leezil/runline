# Runline 경로 생성 API 연동 설명서


## 1. 접속 정보와 확인된 범위

- 테스트 기본 주소: `https://01b0-61-98-40-101.ngrok-free.app`
- 검증일: 2026-11-05 (한국 시간)
- 서버 PC에서 위 공개 HTTPS 주소를 경유한 `GET /v1/health` 성공.
- 토큰 없는 `POST /v1/routes`가 HTTP 401로 차단되는 것 확인.
- 공개 주소를 통한 **Bearer 인증 및 실제 한국 OSM 경로 생성에 성공**했습니다(2026-11-05 17:48 한국 시간). 후보 2개 중 추천 가능 1개, 추천 코스 1,690.9m, 접근 거리 271.2m, 좌표 99개, 서버 처리 시간 6.19초입니다.
- 검증은 서버 PC에서 공개 ngrok HTTPS 주소를 경유했습니다. 다른 기기·네트워크의 클라이언트에서 직접 호출한 테스트는 아닙니다.
- [실제 공개 API 응답 전체](response.external.osm.json), [검증 기록](external-verification.json), [검증 요청 JSON](request.osm.json)을 함께 제공합니다. 계산 시간 제한에 따라 후보 수·결과가 달라질 수 있습니다.
- PC·Python 서버·ngrok이 실행 중이어야 합니다. 재시작 시 주소가 달라질 수 있으므로 기본 주소를 설정값으로 관리하세요.

## 2. 먼저 상태 확인

`GET {BASE_URL}/v1/health` — 토큰 없이 호출합니다.

```json
{"ok": true, "version": "v1", "local_only": false}
```

ngrok 안내 화면이 나오면 `ngrok-skip-browser-warning: 1` 헤더를 추가합니다. 이 헤더는 API 인증을 대신하지 않습니다.

## 3. 그림을 보내기

`POST {BASE_URL}/v1/routes`

```http
Authorization: Bearer <별도로 전달받은 API 토큰>
Content-Type: application/json
ngrok-skip-browser-warning: 1
```

```json
{
  "drawing": [[100, 80], [100, 320], [400, 320]],
  "location": [127.0374, 37.5445],
  "distance_m": 2000,
  "candidate_limit": 5,
  "data_source": "osm",
  "radius_m": 1500,
  "search_seconds": 8
}
```

- `drawing`: 사용자가 그린 순서대로 캔버스의 `[x, y]` 좌표. x는 오른쪽, y는 아래로 증가합니다. GPS 좌표가 아닙니다.
- `location`: 경로를 찾을 기준 위치 `[경도, 위도]`.
- `distance_m`: 목표 러닝 거리(미터). 기본 허용 오차는 ±20%입니다.
- `candidate_limit`: 후보 개수의 상한입니다. 항상 이 개수만큼 나오지는 않습니다.
- `data_source: osm`: 서버 PC에 저장된 대한민국 OSM 도로로 계산합니다. `demo`는 가상 도로 테스트입니다.
- `radius_m`: 도로 조회 반경. `search_seconds`: 계산 시간 예산이며 전체 HTTP 응답 시간과 같지는 않습니다.

전체 필드의 범위·기본값은 [상세 명세](README.md)를 확인하세요. 응답은 같은 POST 요청에서 반환됩니다. 작업 ID를 받아 별도로 조회하는 방식이 아닙니다. 클라이언트 타임아웃은 120초를 권장합니다.

## 4. 응답 사용 순서

1. HTTP 상태를 확인합니다. 200이 아니면 아래 오류 처리를 적용합니다.
2. JSON을 파싱합니다. HTTP 200이어도 추천할 경로가 없을 수 있습니다.
3. `candidates` 중 `acceptable == true`인 후보만 추천 목록으로 사용합니다.
4. 후보의 `distance_m`을 코스 거리로 표시합니다. `approach_m`은 기준 위치에서 코스 시작점까지의 접근 거리 추정값으로 별도 표시합니다.
5. 선택한 후보의 `geometry.coordinates` 전체를 순서대로 연결해 지도에 선을 표시합니다.
6. GeoJSON 좌표는 `[경도, 위도]`입니다. 지도 SDK의 `LatLng(위도, 경도)`에 넣을 때 순서를 바꿉니다.

다음은 응답 필드 설명용 축약 예시입니다. 좌표 2개만 기재했으므로 실제 코스 재현용으로 사용하지 마세요.

```json
{
  "api_version": "v1",
  "source": "osm",
  "found": true,
  "recommended_count": 1,
  "candidates": [{
    "acceptable": true,
    "distance_m": 1690.9,
    "approach_m": 271.2,
    "geometry": {
      "type": "LineString",
      "coordinates": [[127.03498525, 37.54452825], [127.0352379, 37.5444403]]
    }
  }]
}
```

[공개 HTTPS API에서 실제 수신한 전체 응답](response.external.osm.json)을 파싱 샘플로 사용할 수 있습니다. 추천 후보가 없으면 위치·그림·거리 조건을 변경하도록 안내하세요. `acceptable: false` 후보를 정상 추천으로 취급하지 마세요.

## 5. 호출 코드 예시 — JavaScript 백엔드 / Node.js

브라우저용 코드가 아닙니다. 환경 변수 `RUNLINE_API_BASE_URL`, `RUNLINE_API_TOKEN`을 설정한 백엔드에서 실행합니다. 최신 Node.js의 내장 fetch를 사용합니다.

```js
async function generateRoutes(drawing, location) {
  const base = process.env.RUNLINE_API_BASE_URL?.replace(/\/$/, '');
  const token = process.env.RUNLINE_API_TOKEN;
  if (!base || !token) throw new Error('API 주소와 토큰을 설정하세요.');
  const response = await fetch(`${base}/v1/routes`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': '1',
    },
    body: JSON.stringify({
      drawing, location, distance_m: 2000,
      candidate_limit: 5, data_source: 'osm',
    }),
    signal: AbortSignal.timeout(120000),
  });
  const raw = await response.text();
  let data;
  try { data = JSON.parse(raw); }
  catch { throw new Error(`JSON이 아닌 응답: HTTP ${response.status}. 서버/터널 상태를 확인하세요.`); }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${data.error?.code ?? 'UNKNOWN'} / ${data.error?.message ?? '요청 실패'}`);
  }
  return {
    raw: data,
    recommended: (data.candidates ?? []).filter(c => c.acceptable === true),
  };
}
```

앱에서는 `recommended`를 목록으로 보여주고, 선택된 경로를 지도에 표시하세요. 요청 중에는 중복 제출을 막습니다. 요청 취소나 타임아웃이 서버 계산 중단을 보장하지는 않으므로 즉시 반복 호출하지 마세요.

## 6. 오류 처리와 실행 환경

- 400/422: JSON 구조, 좌표·거리 범위 또는 데이터 오류. `error.code`, `error.message`를 확인합니다.
- 401: API 토큰 누락 또는 불일치. ngrok 계정 authtoken과 API 토큰은 서로 다릅니다.
- 403: 외부 브라우저 Origin 차단. 현재 Flutter Web/일반 웹사이트의 직접 호출은 지원하지 않습니다. 해당 웹앱의 백엔드를 통해 호출하세요.
- 413/415: 요청 크기 또는 Content-Type 오류.
- 429: 동시 계산 또는 요청 수 제한. `Retry-After`만큼 대기한 뒤 제한된 횟수로 재시도합니다. 현재 동시 계산 1개, 분당 12회 제한입니다.
- 500/502 또는 HTML 응답: 서버/데이터/터널 상태 확인. 실제 원인은 응답 본문과 서버 로그로 구분합니다.

Flutter Android/iOS, Postman, 서버 프로그램은 호출 대상입니다. 배포 앱에 공용 테스트 토큰을 하드코딩하지 말고, 서비스 운영 시 자체 백엔드에서 토큰을 관리하세요.

OSM 도로와 카카오 지도 표시는 별개입니다. 경로 데이터를 표시할 때 `© OpenStreetMap contributors` 출처 표기를 유지하세요.

## 7. 서버 담당자: 다시 실행하는 명령

첫 번째 PowerShell:

```powershell
cd C:\Users\tmddb\Desktop\running
python api_server.py --port 8082 --enable-tunnel --tunnel-port 8083
```

두 번째 PowerShell (업데이트한 프로젝트 전용 ngrok):

```powershell
& 'C:\Users\tmddb\Desktop\runline\.tools\ngrok\ngrok.exe' http 127.0.0.1:8083
```

이미 실행 중이면 중복 실행하지 마세요. 현재 공개 주소와 API 토큰을 호출 담당자에게 각각 전달합니다. `.api-token`이나 ngrok 계정 인증 정보는 Git 및 공유 문서에 포함하지 않습니다.

## 8. API 토큰 발급·확인·교체

현재는 회원별 토큰 발급 서비스가 아니라 **서버에 하나의 공유 테스트 토큰을 설정하는 방식**입니다. 별도의 토큰 발급 API나 자동 만료 기능은 없습니다.

### 최초 발급

`--enable-tunnel` 옵션으로 서버를 처음 실행할 때 다음 순서로 토큰을 결정합니다.

1. 서버 프로세스의 `DRAWRUN_API_TOKEN` 환경 변수가 있으면 그 값을 사용합니다.
2. 환경 변수가 없으면 `C:\Users\tmddb\Desktop\running\.api-token` 파일의 값을 사용합니다.
3. 파일도 없으면 Python `secrets.token_urlsafe(32)`로 무작위 토큰을 생성하여 해당 파일에 저장합니다.

따라서 지금은 이미 발급되어 있으며, ngrok 사이트에서 API 토큰을 새로 받을 필요가 없습니다. 서버를 재시작해도 파일이 같으면 토큰은 유지됩니다. ngrok 주소 변경과 API 토큰 변경은 별개입니다.

### 기존 토큰을 호출 담당자에게 전달

서버 담당자가 자신의 PowerShell에서 아래 명령으로 토큰을 클립보드에 복사하고, 신뢰하는 담당자에게 비공개로 전달합니다. 현재 공개 API 테스트에서는 이 파일의 토큰으로 인증에 성공했습니다.

```powershell
Get-Content -Raw 'C:\Users\tmddb\Desktop\running\.api-token' | ForEach-Object { $_.Trim() } | Set-Clipboard
```

호출 담당자는 받은 값을 본인 백엔드의 비밀 환경 변수 등에 보관하고 `Authorization: Bearer <토큰>`으로 전송합니다. 이 문서의 Node.js 예시는 호출 측 `RUNLINE_API_TOKEN` 환경 변수를 사용합니다. 서버 측 `DRAWRUN_API_TOKEN`과 이름은 다르지만 **값은 같아야 합니다**.

### 필요할 때 새 토큰으로 교체

이 작업은 기존 호출자의 인증을 무효화하므로 교체 시에만 수행합니다. 이번 검증에서는 토큰을 교체하지 않았습니다.

1. 경로 API 서버를 중지합니다.
2. 서버에 `DRAWRUN_API_TOKEN`을 설정해 사용하는 경우 그 설정을 새 값으로 바꿉니다. 환경 변수가 파일보다 우선하므로 파일만 바꿔서는 적용되지 않습니다.
3. 기본 파일 방식으로 사용하는 경우 아래 명령으로 파일에 새 토큰을 저장합니다(화면에 토큰을 출력하지 않음).

```powershell
cd C:\Users\tmddb\Desktop\running
python -c "import secrets; from pathlib import Path; Path('.api-token').write_text(secrets.token_urlsafe(32) + '\n', encoding='utf-8')"
```

4. 서버를 다시 실행하고 새 토큰을 호출 담당자에게 전달합니다. 실행 중인 서버는 파일 변경을 자동으로 읽지 않습니다.

ngrok 계정의 `authtoken`은 터널을 여는 서버 담당자용 자격증명입니다. API 호출자에게 전달하는 위 토큰과는 다른 것이며 전달하지 않습니다.
