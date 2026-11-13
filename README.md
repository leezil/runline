# runline

## 백엔드 데이터베이스: Neon + PostGIS

Workers API는 Cloudflare Hyperdrive를 통해 Neon PostgreSQL에 연결합니다. Neon 데이터베이스에는 공간 데이터 처리를 위한 PostGIS 확장이 활성화되어 있습니다.

```text
Workers API (pg) → Cloudflare Hyperdrive (HYPERDRIVE) → Neon PostgreSQL + PostGIS
```

### Cloudflare 설정

- Hyperdrive 구성 이름: `runline-neon`
- Hyperdrive ID: `c83c7b825bcd4017ab1e872a76ec2b03`
- Worker 바인딩: `HYPERDRIVE`. `workers-api/wrangler.jsonc`에서 설정합니다.
- Worker는 `env.HYPERDRIVE.connectionString`을 사용합니다. Neon 연결 URL은 애플리케이션 소스 코드에 저장하지 않습니다.

### 로컬 연결

Neon의 직접 연결 URL(연결 풀링 사용 안 함)을 `workers-api/.env.neon.local`에 저장합니다.

```dotenv
NEON_DIRECT_URL=postgresql://<role>:<password>@<direct-endpoint>.neon.tech/<database>?sslmode=require
```

이 파일을 Git에 커밋하거나 내용을 공유하지 마세요. `workers-api/.gitignore` 규칙에 따라 Git에서 무시됩니다. 호스트 이름에 `-pooler`가 포함된 URL은 Neon 풀링 연결이므로 사용하지 않습니다. 배포된 Worker의 연결 풀링은 Hyperdrive가 처리합니다.

`workers-api` 디렉터리에서 다음 명령으로 API를 로컬 실행합니다.

```bash
npm run dev:neon
```

이 로컬 실행 방식은 Neon에 직접 연결하며 Hyperdrive의 원격 연결 풀링이나 쿼리 캐시는 사용하지 않습니다. 배포된 Worker는 설정된 Hyperdrive 바인딩을 사용합니다.

### PostGIS 설정 및 연결 확인

PostGIS는 다음 SQL 명령으로 활성화했습니다.

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

API 헬스 체크 엔드포인트에서 데이터베이스 연결과 PostGIS 사용 가능 여부를 확인합니다.

```text
GET /api/v1/health/db
```

연결이 정상일 때 반환되는 응답은 다음과 같습니다.

```json
{
  "ok": true,
  "service": "runline-api",
  "database": "connected",
  "postgis": true
}
```

Neon 연결 설정 후 로컬 헬스 체크에서 위 응답을 확인했습니다.

### 배포 상태

Hyperdrive 리소스와 Wrangler 바인딩은 설정했지만 Worker는 아직 배포하지 않았습니다. Cloudflare 계정에 `workers.dev` 서브도메인이 설정되어 있지 않아 `wrangler dev --remote`를 실행할 수 없었습니다.
