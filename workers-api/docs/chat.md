# 클럽 공용 채팅

클럽당 하나의 텍스트 채팅입니다. 클럽원 전원이 같은 공간을 사용하며 별도 방 생성·선택·초대는 없습니다.
이미지 채팅, 메시지 수정·삭제, 푸시 알림은 이번 초기 구현에 포함하지 않습니다.

## 저장과 권한

- Neon PostgreSQL `club_chat_messages`가 메시지의 최종 저장소입니다.
- `ClubChat` Durable Object는 소문자로 정규화한 클럽 UUID 하나에 대응하며 연결과 실시간 전달을 조정합니다.
- 가입 시 DB 트리거가 현재 메시지 순번을 멤버십의 `chat_visible_after_sequence`에 저장합니다.
- 메시지 순번 증가·저장과 가입은 같은 클럽 행 잠금으로 직렬화합니다. 시간 비교나 전역 BIGSERIAL에 의존하지 않습니다.
- 이력과 실시간 수신 모두 가입 경계 이후만 허용합니다. 재가입은 새 멤버십과 새 경계를 만듭니다.
- 발신자는 인증된 세션과 현재 멤버십으로 결정합니다. 클라이언트의 발신자 지정은 거부합니다.
- DB 커밋 이후에만 `ack`를 전송합니다. `(sender_membership_id, client_message_id)` 고유 제약으로 동시 재시도도 중복 저장하지 않습니다.
- 같은 ID에 다른 내용을 보내면 `MESSAGE_ID_CONFLICT`입니다. 재시도는 원래 ID·내용을 유지합니다.
- 탈퇴·강퇴한 작성자의 기존 대화는 보관합니다. 클럽 폐쇄 후에도 보관하되 조회를 차단합니다.
- 메시지 자동 만료·개별 삭제는 없습니다. 보관 기간 도입 시 백업을 포함한 별도 삭제 정책이 필요합니다.

테이블은 `club_chat_messages`와 읽음·전송 제한을 위한 `club_chat_state`입니다. 별도 채팅방 테이블은 없습니다.
64비트 순번은 JSON에서 문자열, Flutter에서 `BigInt`로 다룹니다.

## 연결 인증과 무효화

1. 운영은 WSS, 로컬만 WS입니다. 접속 URL의 쿼리 파라미터는 허용하지 않습니다.
2. 웹 Origin은 `CHAT_ALLOWED_ORIGINS`의 쉼표 구분 목록과 정확히 비교합니다. 미설정이면 `ADMIN_WEB_ORIGIN`을 사용합니다.
3. Origin 없는 네이티브 연결도 토큰 인증은 필수입니다.
4. 연결 후 5초 안에 첫 `auth` 메시지로 RUNLINE access token을 보냅니다. 토큰을 URL에 넣지 않습니다.
5. 인증 전에는 채팅 데이터를 전달하지 않습니다. 소켓 attachment에는 토큰 해시만 보관합니다.
6. 메시지 전송 때 멤버십·세션을 다시 확인하고, 수신자도 매번 SQL로 검사합니다.
7. 수신자 검사와 `ws.send()`가 끝날 때까지 클럽·세션 공유 잠금을 유지합니다.
   탈퇴·강퇴·폐쇄나 세션 삭제·갱신이 그 사이 커밋되지 않게 합니다.
8. 탈퇴·강퇴·폐쇄·로그아웃·토큰 갱신 API는 커밋 후 해당 클럽의 연결을 즉시 재검사합니다.
9. 무효화 RPC가 실패해도 다음 전달 시 SQL로 차단합니다. 유휴 연결은 alarm으로 최대 30초 주기로 재검사하고, 세션 만료 시각에도 alarm을 예약합니다.
10. DB 확인이 실패하면 연결을 닫고 보호된 데이터를 전달하지 않습니다.

유효한 권한으로 이미 전송한 프레임이나 기기에 도착한 데이터는 회수할 수 없습니다.
Flutter는 로그아웃·계정 전환·권한 상실 시 소켓과 화면의 대화·대기 메시지를 비웁니다.

## 초기 제한

- 일반 텍스트 1–2000자, UTF-8 최대 8000바이트. 바이너리·NUL·임의 발신자 필드는 거부합니다.
- 프레임 최대 16KiB, 접속별 10초당 40프레임, 멤버십별 10초당 새 메시지 20개입니다.
- 멤버십 전송 제한은 DB에 저장하므로 연결 교체·휴면으로 초기화되지 않습니다.
- 사용자당 활성 연결 3개, 클럽당 인증 대기 20개, 같은 IP의 인증 대기 3개로 제한합니다.
- 이력 페이지는 기본 50개, 최대 100개입니다.
- 앱은 대기 메시지 20개로 제한하고 자동 재연결은 지수 백오프와 지터로 최대 5회 시도합니다.
- 로그에 토큰·채팅 원문을 남기지 않습니다. UI는 일반 텍스트로 표시하며 HTML을 실행하지 않습니다.

위 숫자는 앱 정책이며 Cloudflare 플랫폼 한도와 별개입니다.

## HTTP API

기존 RUNLINE Bearer 인증을 사용합니다.

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/api/v1/clubs/:clubId/chat` | 내 가입 경계·읽음 위치·마지막 순번·미확인 개수 |
| GET | `/api/v1/clubs/:clubId/chat/messages` | 최신 메시지, 순번 내림차순 |
| GET | `/api/v1/clubs/:clubId/chat/messages?before=150` | 150 이전의 허용된 이력, 내림차순 |
| GET | `/api/v1/clubs/:clubId/chat/messages?after=150` | 150 이후의 허용된 이력, 오름차순 |
| POST | `/api/v1/clubs/:clubId/chat/read` | `{ "sequence": "150" }`; 읽음 위치 단조 증가 |
| GET/Upgrade | `/api/v1/clubs/:clubId/chat/socket` | WebSocket; 첫 프레임으로 인증 |

`before`와 `after`는 동시에 사용할 수 없습니다. 가입 전 범위를 요청해도 서버가 잘라냅니다.
읽음 위치는 가입 경계부터 현재 마지막 순번까지만 허용합니다. 미확인 개수는 본인 메시지를 제외합니다.
이력 응답은 `{ ok, items, hasMore, nextSequence, state }`입니다.
`state`는 `membership_id`, `user_id`, `visible_after_sequence`, `last_read_sequence`, `last_sequence`, `unread_count`입니다.

## WebSocket 프로토콜

클라이언트 첫 프레임:

```json
{ "type": "auth", "accessToken": "RUNLINE access token" }
```

인증 성공: `{ "type": "ready", "state": { ... }, "expiresAt": 1234567890000 }`

access token은 기존 정책대로 15분 유효합니다. 만료된 연결은 종료합니다.
로그인·갱신 흐름에서 새 토큰을 `RunlineSession.instance.setAccessToken(...)`에 공급하면 재연결합니다.
refresh token은 소켓으로 보내지 않습니다. 기존 앱에 로그인 화면이 없는 점은 동일합니다.

메시지 전송:

```json
{ "type": "send", "clientMessageId": "UUID", "content": "함께 달려요" }
```

- 발신자: `{ "type": "ack", "message": { ... } }`
- 나머지 클럽원: `{ "type": "message", "message": { ... } }`
- 오류: `{ "type": "error", "code": "CHAT_RATE_LIMIT", "clientMessageId": "UUID" }`
- 연결 확인: `{ "type": "ping" }` → `{ "type": "pong" }`

메시지 필드는 `id`, `club_id`, `sequence`, `sender_membership_id`, `sender_user_id`, `client_message_id`,
`content`, `created_at`, `nickname`, `avatar_url`입니다. 프로필은 현재 사용자 정보, 작성자는 과거 멤버십을 참조합니다.

종료 코드: `4001` 인증 만료·실패, `4003` 멤버십 상실·클럽 이용 불가,
`4008` 연결·전송 제한, `1008` 형식 오류, `1009` 프레임 초과, `1011` 일시 장애.

## 앱 동작과 복구

저장된 메시지와 전송 대기를 분리해 저장 확인 전에는 성공으로 표시하지 않습니다.
재시도는 같은 메시지 ID를 사용합니다. 서버 순번으로 정렬하고 중복 표시를 제거합니다.
초기 최신 이력의 기준 순번을 보관하고 재접속 시 `after` 이력을 오름차순으로 복구합니다.
더 큰 실시간 순번을 받더라도 누락 구간을 건너뛰지 않습니다.
25초 heartbeat 후에도 이력을 확인해 저장 후 실시간 전달 실패를 복구합니다.
DB와 실시간 전달 사이의 분산 트랜잭션 없이 최종 이력을 복구하는 방식입니다.

백그라운드에서는 연결을 종료하고 복귀하면 재연결합니다.
화면 하단을 보고 있을 때만 읽음 위치를 갱신합니다. 클럽 홈 채팅 버튼에 미확인 개수를 표시합니다.

## 적용 및 검증

```powershell
cd workers-api
npm run db:migrate -- --plan
npm run db:migrate
npm run cf-typegen
npm run dev:neon
```

`004_chat.sql`이 필요합니다. 기존 수동 적용 DB의 이력 등록은 [실행 안내](../README.md)를 따릅니다.
진입점 `src/worker.ts`는 `ClubChat` 클래스를 export합니다.
Wrangler에 Durable Object 바인딩과 `v1-club-chat` 마이그레이션을 추가했습니다.
원격 SQL 마이그레이션·배포는 이번 구현에서 실행하지 않았습니다.

웹 실행 origin은 `CHAT_ALLOWED_ORIGINS`와 HTTP API의 `ADMIN_WEB_ORIGIN` 모두에 맞춰야 합니다.
Flutter 개발 서버가 `http://localhost:5000`이면 두 설정에 해당 origin을 사용합니다. 운영은 실제 HTTPS 앱 origin을 사용합니다.

```powershell
npm test -- --run
npm run test:chat
npm run test:clubs
# runline 폴더
flutter test test/club_chat_test.dart
```

Workers 테스트는 실제 WebSocket·Durable Object의 인증·수신 차단·휴면 복구를 확인합니다.
`test:chat`는 native PostgreSQL을 임시 디렉터리에서 실행하고 종료 후 정리합니다.
Neon URL과 `CLUB_TEST_DATABASE_URL`을 읽지 않습니다. 개발 의존성은 Worker 번들에 포함되지 않습니다.
Windows 한글 경로의 bootstrap 문제를 피하려고 테스트 바이너리를 임시 ASCII 경로에 복사합니다.
