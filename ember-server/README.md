# Ember 서버 (Cloudflare Worker)

Ember 안드로이드 앱의 **"API 키 없이 쓰기"(유료 크레딧)** 백엔드입니다.

- 앱은 Anthropic Java SDK 의 `baseUrl` 을 이 서버 주소로, `apiKey` 를 **기기 토큰**으로 설정합니다.
- 서버는 Anthropic Messages API 와 똑같이 동작하는 **투명 프록시**입니다. 기기 토큰을 확인한 뒤 서버의 진짜 Anthropic 키로 바꿔서 전달하고, 응답의 `usage`(토큰 수)만큼 크레딧을 차감합니다.
- 크레딧은 Google Play 인앱 상품으로 판매하고, 신규 설치에는 무료 크레딧을 한 번 줍니다.
- 데이터는 Cloudflare D1(SQLite)에 저장합니다. 서버 비용은 소규모라면 Cloudflare 무료 플랜 안에서 해결됩니다.

```
앱 (Anthropic SDK, x-api-key = 기기 토큰)
   │  POST /v1/messages (스트리밍 SSE 포함), GET /v1/models/{id}
   │  POST /ember/register · GET /ember/balance · POST /ember/purchase · POST /ember/report
   ▼
Ember 서버 (Cloudflare Worker + D1)
   │  x-api-key = 서버의 ANTHROPIC_API_KEY
   ▼
api.anthropic.com            androidpublisher.googleapis.com (영수증 확인)
```

---

## 1. 크레딧 단위

- **1 크레딧 = 마크업을 포함한 $0.01** 입니다.
- 요청 한 번의 크레딧 = `올림(원가 USD × 100 × MARKUP)` (MARKUP 기본 1.5). 0 보다 큰 비용이면 최소 1 크레딧.
- 원가(100만 토큰당 USD):

| 모델 | 입력 | 출력 | 캐시 읽기 | 캐시 쓰기 |
|---|---|---|---|---|
| `claude-opus-5-5` | 4.00 | 20.00 | 0.20 | 5분: 입력×1.25 / 1시간: 입력×2 |
| `claude-sonnet-5-5` | 2.00 | 10.00 | 0.20 | 〃 |
| `claude-haiku-5-5` | 0.10 | 0.50 | 0.01 | 〃 (입력 합계 10만 토큰 초과 시 모든 단가 5배) |
| 웹 검색 | 요청 1회당 $0.01 | | | |

- 예) Opus 로 입력 1,000 + 출력 500 토큰 → $0.014 → 0.014×100×1.5 = 2.1 → **3 크레딧**.
- 상품: `ember_credits_500` → 500, `ember_credits_1500` → 1650, `ember_credits_5000` → 5750 크레딧 (`PRODUCTS` 로 변경 가능).
- 잔액이 0 이하이면 새 요청은 402 로 거절됩니다. 차감은 요청이 끝난 뒤 하므로 **마지막 요청에서 잔액이 조금 음수가 될 수 있습니다**(의도된 동작, 다음 구매에서 메워짐).
- 업스트림(Anthropic) 오류 응답은 비용 0 입니다.
- 서버측 거절 대체(`server-side-fallback`)로 다른 모델이 응답하면, 그 모델의 단가표가 있으면 그 단가로(예: `claude-opus-5` $5/$25), 없으면 요청한 모델 단가로 계산합니다.

---

## 2. 앱용 API 계약 요약

모든 오류는 Anthropic 형식입니다: `{"type":"error","error":{"type":"...","message":"..."}}`
인증은 `x-api-key: <토큰>` 또는 `Authorization: Bearer <토큰>`.

| 메서드·경로 | 인증 | 요청 | 응답 |
|---|---|---|---|
| `POST /ember/register` | 없음 | `{"installId": "8~64자 [A-Za-z0-9_-]"}` | `{"token","credits","freeGranted"}` |
| `GET /ember/balance` | 토큰 | – | `{"credits"}` |
| `POST /ember/purchase` | 토큰 | `{"productId","purchaseToken"}` | `{"credits","granted"}` |
| `POST /ember/report` | 토큰 | `{"kind":"question"\|"idea"\|"document"\|"other","reason","content"(≤20000자),"note"(≤2000),"appVersion"(≤64)}` | `{"ok":true,"id"}` |
| `POST /v1/messages` | 토큰 | Anthropic Messages API 그대로 | Anthropic 응답 그대로(스트리밍 포함) |
| `GET /v1/models/{id}` | 토큰 | – | `{"type":"model","id","display_name","created_at"}` 또는 404 |
| `GET /ember/admin/reports?limit=50&before=<id>` | `x-admin-key` | – | `{"reports":[...],"nextBefore"}` |
| `GET /ember/admin/stats` | `x-admin-key` | – | 계정 수, 지급/사용 크레딧, 24시간 요청 수 등 |

그 밖의 경로는 모두 404 `not_found_error`.

**등록**
- 새 installId → 새 계정 + 무료 크레딧(`freeGranted: true`).
- 이미 있는 installId → 같은 계정에 **새 토큰**을 발급하고 이전 토큰은 무효가 됩니다. 무료 크레딧은 **다시 주지 않습니다**(`freeGranted: false`).
- IP(`CF-Connecting-IP`)당 시간당 5회로 제한(429).

**구매**
- Google Play Developer API 로 영수증을 확인하고 `purchaseState == 0`(구매 완료)일 때만 지급합니다.
- 같은 `purchaseToken` 은 **절대 두 번 지급되지 않습니다**(DB UNIQUE + 트랜잭션). 재전송하면 `granted: 0` 과 현재 잔액을 돌려주므로 앱이 안전하게 재시도할 수 있습니다.
- 성공 응답을 받은 뒤 앱이 직접 구매를 소비(consume)합니다. 소비 전에 앱이 꺼져도, 다음 실행 때 미소비 구매를 다시 보내면 됩니다(서버는 중복 지급하지 않음).
- 오류: 모르는 상품·없는 영수증·미완료 구매 → 400, Google 일시 오류 → 502(재시도).

**메시지**
- 401 `authentication_error`: 토큰이 없거나 틀림. 403 `permission_error`: 차단된 계정.
- **402 `insufficient_credits`**: 잔액이 0 이하.
- 429 `rate_limit_error`: 토큰당 10분에 30회 초과.
- 400 `invalid_request_error`: 허용 모델(`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`) 이외, `web_search_*` 이외의 도구, `mcp_servers`·`container`·`speed: "fast"` 사용.
- 413 `request_too_large`: 본문이 2 MB 초과(이미지 base64 포함).
- `max_tokens` 가 64000 보다 크면 64000 으로 잘라서 보냅니다.
- `anthropic-version`, `anthropic-beta` 헤더는 그대로 전달됩니다.
- 비스트리밍 응답에는 `ember-credits-remaining` 헤더(차감 후 잔액)가 붙습니다. 정확한 잔액은 `/ember/balance` 로 확인하세요.
- 스트리밍(`"stream": true`)은 바이트를 바꾸지 않고 그대로 흘려보내며, 스트림이 끝나면 차감합니다.
- 서버의 Anthropic 키가 잘못되어 업스트림이 401/403 을 주면, 앱이 "기기 토큰이 틀렸다"고 오해하지 않도록 **500 `api_error`** 로 바꿔서 돌려줍니다.

---

## 3. 배포하기 (처음 하는 분용, 단계별)

### 3-1. 준비물
1. **Node.js 22 이상** 설치: <https://nodejs.org> 에서 LTS 버전을 받아 설치합니다. 터미널(Windows 는 PowerShell)에서 `node -v` 로 확인.
2. **Cloudflare 계정**: <https://dash.cloudflare.com/sign-up> (무료).
3. **Anthropic API 키**: <https://console.anthropic.com> → API Keys. 결제 수단을 등록하고, 지출 한도(Spend limit)를 꼭 설정하세요.

### 3-2. 설치와 로그인
```bash
cd ember-server
npm install
npx wrangler login          # 브라우저가 열리면 Cloudflare 계정으로 허용
```

### 3-3. 데이터베이스 만들기
```bash
npx wrangler d1 create ember
```
출력에 나오는 `database_id = "xxxxxxxx-...."` 값을 복사해서 `wrangler.toml` 의 `database_id` 자리에 붙여 넣습니다.

그다음 표를 만듭니다:
```bash
npx wrangler d1 execute ember --remote --file=./schema.sql
```

### 3-4. 비밀값 넣기
비밀값은 파일에 쓰지 말고 아래 명령으로만 넣습니다(입력하라는 프롬프트에 값을 붙여 넣기).
```bash
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ADMIN_KEY            # 관리자용 긴 무작위 문자열(예: 비밀번호 생성기로 40자)
```
서비스 계정 JSON 파일(4장 참고)은 파일 내용을 통째로 넣습니다:
```bash
# macOS / Linux
npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON < service-account.json
# Windows PowerShell
Get-Content service-account.json -Raw | npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON
```
> JSON 키 파일은 넣은 뒤 안전한 곳에 보관하거나 지우세요. 깃에 절대 커밋하지 마세요.

### 3-5. 배포
```bash
npx wrangler deploy
```
출력에 `https://ember-server.<계정>.workers.dev` 주소가 나옵니다. 이것이 **SERVER_URL** 입니다.

### 3-6. 확인
```bash
curl -X POST https://ember-server.<계정>.workers.dev/ember/register \
  -H 'content-type: application/json' -d '{"installId":"test-install-0001"}'
# → {"token":"...","credits":100,"freeGranted":true}

curl https://ember-server.<계정>.workers.dev/ember/admin/stats -H 'x-admin-key: <ADMIN_KEY>'
```

### 3-7. 앱에 연결
앱의 `BuildConfig.EMBER_SERVER_URL`(`app/build.gradle.kts`)에 위 주소를 넣고 다시 빌드합니다(끝에 `/` 없이).

### 3-8. 로그 보기·수정 반영
```bash
npx wrangler tail            # 실시간 로그
npx wrangler deploy          # 코드나 wrangler.toml 을 고친 뒤 다시 배포
```

---

## 4. Google Play 설정

### 4-1. 인앱 상품 만들기 (Play Console)
1. 결제 프로필(판매자 계정)이 연결되어 있어야 하고, 앱이 **결제 라이브러리를 포함한 빌드**로 최소 내부 테스트 트랙에 올라가 있어야 상품 메뉴가 열립니다.
2. Play Console → 앱 선택 → **수익 창출(Monetize with Play) → 제품 → 인앱 상품** → **상품 만들기**.
3. 아래 세 개를 **ID 를 정확히 똑같이** 만듭니다(나중에 바꿀 수 없음).

| 상품 ID | 지급 크레딧 | 비고 |
|---|---|---|
| `ember_credits_500` | 500 | 원가 약 $3.33 어치(마크업 1.5 기준). 가격은 그 이상으로 |
| `ember_credits_1500` | 1650 | 10% 보너스 |
| `ember_credits_5000` | 5750 | 15% 보너스 |

4. 이름·설명·가격을 넣고 저장한 뒤 **활성화**합니다.
5. 가격을 정할 때: 1 크레딧 = 고객에게 $0.01 의 사용 가치. 구글 수수료(15~30%)와 세금을 감안해 정합니다.

### 4-2. 서비스 계정 만들기 (Google Cloud)
1. <https://console.cloud.google.com> → 새 프로젝트 만들기(이름 예: `ember-play`).
2. **API 및 서비스 → 라이브러리** → "Google Play Android Developer API" 검색 → **사용 설정**.
3. **IAM 및 관리자 → 서비스 계정 → 서비스 계정 만들기**. 이름 예: `ember-server`. 역할은 주지 않아도 됩니다.
4. 만든 서비스 계정 → **키 → 키 추가 → 새 키 만들기 → JSON** → 파일이 내려받아집니다. 이 파일 내용이 `GOOGLE_SERVICE_ACCOUNT_JSON` 입니다.

### 4-3. Play Console 에 서비스 계정 권한 주기
1. Play Console(개발자 계정 화면) → **사용자 및 권한 → 새 사용자 초대**.
2. 이메일 칸에 서비스 계정 이메일(`ember-server@<프로젝트>.iam.gserviceaccount.com`)을 넣습니다.
3. **앱 권한 → 앱 추가 → Ember** 를 선택하고 다음 권한을 켭니다:
   - **재무 데이터 보기**(View financial data, orders, and cancellation survey responses)
   - **주문 및 구독 관리**(Manage orders and subscriptions)
4. **사용자 초대**를 누릅니다. 권한이 적용되기까지 **최대 24시간** 걸릴 수 있습니다. 그 전에는 구매 확인이 401/403 → 앱에 502 로 실패합니다.

### 4-4. 테스트 구매
- Play Console → 설정 → **라이선스 테스트**에 테스터 Gmail 을 넣으면 실제 결제 없이 구매를 시험할 수 있습니다.
- 테스트 구매도 서버는 정상 구매처럼 크레딧을 지급합니다(`purchases.purchase_type = 0` 으로 기록되어 구분 가능).

---

## 5. 환경 변수

`wrangler.toml` 의 `[vars]` 는 공개 설정, 비밀값은 `wrangler secret put` 으로 넣습니다.

| 이름 | 종류 | 기본값 | 설명 |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | 비밀 | – | Anthropic API 키(필수) |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | 비밀 | – | 서비스 계정 JSON 전체(구매에 필수) |
| `ADMIN_KEY` | 비밀 | – | 관리자 API 키. 없으면 관리자 API 전부 401 |
| `PACKAGE_NAME` | 변수 | `app.ember.ideas` | 앱 패키지 이름 |
| `FREE_CREDITS` | 변수 | `150` | 신규 설치 무료 크레딧 |
| `MARKUP` | 변수 | `1.5` | 원가 대비 배수(1 이상) |
| `MAX_OUTPUT_TOKENS` | 변수 | `64000` | `max_tokens` 상한 |
| `MAX_BODY_BYTES` | 변수 | `2097152` | 요청 본문 최대 크기(2 MB) |
| `PRODUCTS` | 변수 | `{"ember_credits_500":500,"ember_credits_1500":1650,"ember_credits_5000":5750}` | 상품 ID → 크레딧(JSON). 형식이 틀리면 기본값 사용 |
| `REGISTER_LIMIT` / `REGISTER_WINDOW_SECONDS` | 변수 | `5` / `3600` | IP 당 가입 제한 |
| `MESSAGES_LIMIT` / `MESSAGES_WINDOW_SECONDS` | 변수 | `30` / `600` | 토큰 당 `/v1/messages` 제한 |
| `ANTHROPIC_BASE_URL` | 변수 | `https://api.anthropic.com` | 업스트림 주소(테스트용으로만 변경) |

---

## 6. 운영

- **통계**: `GET /ember/admin/stats` (헤더 `x-admin-key`).
- **신고 목록**: `GET /ember/admin/reports?limit=50`, 다음 페이지는 응답의 `nextBefore` 를 `before=` 로.
- **계정 차단**:
  ```bash
  npx wrangler d1 execute ember --remote --command "UPDATE accounts SET disabled = 1 WHERE id = 42"
  ```
- **크레딧 수동 지급(환불·보상)**:
  ```bash
  npx wrangler d1 execute ember --remote --command "UPDATE accounts SET credits = credits + 500 WHERE id = 42"
  ```
- 매일 03:17(UTC) cron 이 오래된 요청 제한 카운터를 지웁니다.
- Anthropic 콘솔의 **지출 한도**를 반드시 걸어 두세요. 서버 버그나 남용이 있어도 피해가 한도 안에서 멈춥니다.

---

## 7. 남용 위험과 한계 (꼭 읽어 주세요)

1. **무료 크레딧 반복 수령**: installId 는 앱을 지웠다 다시 깔거나 데이터를 지우면 바뀝니다. 그러면 새 계정으로 무료 크레딧을 또 받을 수 있습니다.
   - 지금은 **IP 당 시간당 5회 가입 제한**으로 속도만 늦춥니다(모바일 데이터·VPN 으로 IP 를 바꾸면 우회 가능).
   - 권장: 나중에 **Play Integrity API** 로 진짜 Play 설치 앱인지 확인하고, 기기 단위로 무료 지급을 묶으세요. 피해가 커지면 `FREE_CREDITS` 를 줄이거나 0 으로 바꿀 수 있습니다.
2. **installId 는 사실상 비밀번호**입니다. installId 를 아는 사람은 재등록으로 같은 계정의 새 토큰을 받을 수 있고, 그러면 원래 기기의 토큰은 무효가 됩니다. 앱은 installId 를 외부에 노출하지 마세요.
3. **환불 후 사용**: 구매 → 크레딧 사용 → 구글에 환불 요청하는 경우를 지금은 막지 않습니다. 필요하면 Google Play **Voided Purchases API** 로 주기적으로 환불 목록을 받아 크레딧을 회수하는 기능을 추가하세요.
4. **스트리밍 중단 시 추정 과금**: 앱이 스트리밍 도중 연결을 끊으면 서버는 업스트림도 취소하고, 마지막 사용량 이벤트(`message_delta`)를 못 받았으므로 출력 토큰을 **받은 글자 수 ÷ 3** 으로 추정해 차감합니다. 화면에 표시되지 않는 사고(thinking) 토큰은 이 추정에 잡히지 않아 실제보다 적게 청구될 수 있습니다.
5. **요청 제한은 D1 고정 창 방식**이라 창 경계에서 잠깐 두 배까지 허용될 수 있습니다. 엄격한 제한이 필요하면 Durable Objects 로 바꾸세요.
6. 도구는 `web_search_*` 만 허용합니다. 웹 검색은 1회당 $0.01 이 추가되며, 앱이 `max_uses` 로 횟수를 제한하는 것을 권장합니다.

---

## 8. 개발·테스트

```bash
npm install
npx tsc --noEmit        # 타입 검사
npx vitest run          # 단위·통합 테스트(실제 schema.sql 을 node:sqlite 로 실행)

# 로컬 실행(로컬 D1)
npx wrangler d1 execute ember --local --file=./schema.sql
npx wrangler dev --var ANTHROPIC_API_KEY:sk-ant-... --var ADMIN_KEY:local
```

### 파일 구조
```
src/
  index.ts            진입점(fetch, scheduled)
  router.ts           경로 → 핸들러, 오류 처리
  env.ts              환경 변수·기본값
  http.ts             Anthropic 형식 오류, 본문 크기 제한 읽기
  util.ts             토큰 생성, SHA-256, 일정 시간 비교, base64url
  auth.ts             기기 토큰 인증
  ratelimit.ts        D1 고정 창 요청 제한
  account.ts          /ember/register, /ember/balance
  models.ts           허용 모델, /v1/models/:id
  purchase.ts         /ember/purchase (멱등 지급)
  play/google-auth.ts 서비스 계정 RS256 JWT → OAuth 토큰(캐시)
  play/verify.ts      Play Developer API 영수증 확인
  proxy/validate.ts   모델·도구·max_tokens 검증
  proxy/sse.ts        SSE usage 증분 파서
  proxy/messages.ts   /v1/messages 프록시(비스트리밍·스트리밍)
  billing/usage.ts    usage 정규화
  billing/pricing.ts  단가표·크레딧 계산
  billing/ledger.ts   원자적 차감 + usage_log
  reports.ts          /ember/report
  admin.ts            관리자 API
test/                 vitest 테스트(가짜 D1 = node:sqlite, 가짜 fetch)
schema.sql            D1 스키마
```
