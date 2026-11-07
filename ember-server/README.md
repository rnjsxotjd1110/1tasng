# Ember 서버 (Cloudflare Worker)

Ember 안드로이드 앱의 **"API 키 없이 쓰기"(유료 크레딧)** 백엔드입니다.

- 앱은 Anthropic Java SDK 의 `baseUrl` 을 이 서버 주소로, `apiKey` 를 **기기 토큰**으로 설정합니다.
- 서버는 Anthropic Messages API 와 똑같이 동작하는 **투명 프록시**입니다. 기기 토큰을 확인한 뒤 서버의 진짜 Anthropic 키로 바꿔서 전달합니다. 보내기 **전에** 최악의 비용을 잔액에서 미리 빼 두고(예약), 응답의 `usage`(토큰 수)로 실제 비용을 계산해 남는 만큼 돌려줍니다(정산).
- 크레딧은 Google Play 인앱 상품으로 판매하고, 신규 설치에는 무료 크레딧(기본 40)을 한 번 줍니다. **결제한 적 없는 계정은 Opus 요청도 Sonnet 으로 처리**합니다.
- 환불·취소된 구매는 매일 cron 이 Google Play Voided Purchases API 로 찾아 크레딧을 회수합니다.
- 가입 때 Play Integrity 로 진짜 Play 설치 앱·정상 기기인지 확인합니다(`wrangler.toml` 의 `INTEGRITY_MODE = "grant"`). **배포 전에 Play Integrity 를 설정해야 합니다(4-5).** 설정하지 않으면 가입은 되지만 새 계정의 무료 크레딧이 0 입니다.
- 데이터는 Cloudflare D1(SQLite)에 저장합니다. 서버 비용은 소규모라면 Cloudflare 무료 플랜 안에서 해결됩니다.

```
앱 (Anthropic SDK, x-api-key = 기기 토큰)
   │  POST /v1/messages (스트리밍 SSE 포함), GET /v1/models/{id}
   │  GET /ember/nonce · POST /ember/register · GET /ember/balance · POST /ember/purchase · POST /ember/report
   ▼
Ember 서버 (Cloudflare Worker + D1)            매일 cron: 정리 + 환불 회수
   │  x-api-key = 서버의 ANTHROPIC_API_KEY
   ▼
api.anthropic.com      androidpublisher.googleapis.com (영수증 확인·환불 목록)
                       playintegrity.googleapis.com (무결성 토큰 해독, INTEGRITY_MODE 가 켜졌을 때)
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
- **예약과 정산**(잔액을 넘겨 쓰지 못하게):
  1. 업스트림을 부르기 **전에** 최악의 비용을 크레딧으로 계산해 `UPDATE accounts SET credits = credits - 예약액 WHERE id = ? AND credits >= 예약액` 으로 원자적으로 뺍니다.
     - 최악의 비용 = `max_tokens × 출력 단가` + `입력 추정 × 입력 단가` + `웹 검색 max_uses 합 × $0.01`.
     - 입력 추정 = 본문 UTF-8 바이트 ÷ 3 토큰(이미지 base64 는 바이트 대신 장당 5,000 토큰) + 웹 검색 1회당 결과 8,000 토큰. 본문에 `cache_control` 이 있으면 입력 단가 ×1.25(`ttl: "1h"` 가 보이면 ×2), Haiku 는 추정이 10만 토큰을 넘으면 ×5.
     - `fallbacks: "default"` 를 쓰면 응답 모델이 바뀔 수 있으므로 **아는 단가 중 가장 비싼 값**(입력 $5 / 출력 $25)으로 예약합니다.
  2. 잔액이 예약액보다 적으면 `max_tokens` 를 잔액이 감당하는 만큼 **줄여서** 보냅니다(하한 1,024, 요청한 값이 더 작으면 그 값. `thinking.budget_tokens` 가 새 `max_tokens` 이상이면 함께 줄임). 그래도 안 되면 **402**.
  3. 응답이 끝나면 `예약액 − 실제 비용` 을 돌려줍니다(0 미만이면 돌려주지 않음). 입력 추정이 모자라 실제 비용이 예약액보다 큰 드문 경우에는 차이를 더 빼므로 잔액이 조금 음수가 될 수 있습니다(로그에 `실제 비용이 예약액보다 큼`).
  - 그래서 잔액을 넘는 동시 요청·긴 출력으로 크레딧을 넘겨 쓸 수 없습니다. 같은 계정의 동시 처리는 **2개**까지입니다(`MAX_CONCURRENT_REQUESTS`, 넘으면 429).
- 업스트림(Anthropic) 오류 응답·연결 실패는 비용 0(예약액 전부 환불)입니다.
- **최종 usage 를 받지 못한 경우는 예약액 전체를 청구**합니다(환불 없음): 스트리밍 중 앱이 끊음, 업스트림 스트림이 `message_delta` 없이 끝남, 스트림 중간 `error` 이벤트, 비스트리밍 응답의 본문·usage 를 읽지 못함. 화면에 안 보이는 사고 토큰(`display: "omitted"`)·웹 검색도 예약액(`max_tokens`·`max_uses` 기준)에 들어 있어 빠져나가지 못합니다. 단, `message_start` 전에 `error` 이벤트로 끝나면(생성 없음) 0 입니다.
- **무료 계정 모델 제한**: 지급 완료되고 환불되지 않은 구매가 하나도 없는 계정(= 무료 크레딧만 쓰는 계정)이 `claude-opus-5-5` 를 요청하면, 서버가 `model` 을 `claude-sonnet-5-5` 로 바꿔 보내고 **Sonnet 단가로 과금**합니다. Haiku·Sonnet 요청은 그대로입니다. 한 번이라도 구매하면 바로 Opus 를 쓸 수 있고, 그 구매가 환불되면 다시 Sonnet 으로 돌아갑니다. 실제로 보낸 모델은 응답 헤더 `ember-model` 로 알 수 있습니다.
- 서버측 거절 대체(`server-side-fallback`)로 다른 모델이 응답하면, 그 모델의 단가표가 있으면 그 단가로(예: `claude-opus-5` $5/$25), **단가표에 없는 모델이면 아는 단가 중 가장 비싼 값**(입력 $5 / 출력 $25 / 캐시 읽기 $0.5)으로 계산합니다(요청한 모델 단가가 아님).

---

## 2. 앱용 API 계약 요약

모든 오류는 Anthropic 형식입니다: `{"type":"error","error":{"type":"...","message":"..."}}`
인증은 `x-api-key: <토큰>` 또는 `Authorization: Bearer <토큰>`.

| 메서드·경로 | 인증 | 요청 | 응답 |
|---|---|---|---|
| `GET /ember/nonce` | 없음 | – | `{"nonce"}` (Play Integrity 용 일회용 값, 5분 유효) |
| `POST /ember/register` | 없음 | `{"installId": "8~64자 [A-Za-z0-9_-]", "integrityToken"?, "nonce"?}` | `{"token","credits","freeGranted"}` + `INTEGRITY_MODE` 가 켜져 있으면 `"integrity"` |
| `GET /ember/balance` | 토큰 | – | `{"credits"}` |
| `POST /ember/purchase` | 토큰 | `{"productId","purchaseToken"}` | `{"credits","granted"}` (+ 운영에서 테스트 구매면 `"testPurchase": true`) |
| `POST /ember/report` | 토큰 | `{"kind":"question"\|"idea"\|"document"\|"other","reason","content"(≤20000자),"note"(≤2000),"appVersion"(≤64)}` | `{"ok":true,"id"}` |
| `POST /v1/messages` | 토큰 | Anthropic Messages API(허용 필드만) | Anthropic 응답 그대로(스트리밍 포함) + 헤더 `ember-model` |
| `GET /v1/models/{id}` | 토큰 | – | `{"type":"model","id","display_name","created_at"}` 또는 404 |
| `GET /ember/admin/reports?limit=50&before=<id>` | `x-admin-key` | – | `{"reports":[...],"nextBefore"}` |
| `GET /ember/admin/stats` | `x-admin-key` | – | 계정 수, 지급/사용 크레딧, 24시간 요청 수 등 |

그 밖의 경로는 모두 404 `not_found_error`.

**등록**
- 새 installId → 새 계정 + 무료 크레딧(`freeGranted: true`). 줄 무료 크레딧이 0 이면 `freeGranted: false`.
- 이미 있는 installId → 같은 계정에 **새 토큰**을 발급하고 이전 토큰은 무효가 됩니다. 무료 크레딧은 **다시 주지 않습니다**(`freeGranted: false`).
- **하루 무료 크레딧 상한**(`FREE_CREDITS_DAILY_CAP`, 기본 20,000 = 40 크레딧 × 500 계정): 그날(UTC) 새 계정에 준 무료 크레딧 합계가 상한에 닿으면 이후 새 계정은 0(`freeGranted: false`) 으로 가입됩니다. 대량 가입 공격의 피해 상한입니다.
- IP 당 요청 제한(429). IP 는 `CF-Connecting-IP` 기준으로 **IPv4 는 주소 전체, IPv6 는 /64** 단위로 셉니다(한 가입자가 /64 안의 주소를 마음대로 바꿀 수 있으므로).
  - 새 installId(무료 크레딧 대상): 시간당 5회(`REGISTER_LIMIT`).
  - 이미 있는 installId 의 재등록(토큰 재발급): 따로 시간당 30회(`REREGISTER_LIMIT`). 모바일 CGNAT 처럼 많은 사용자가 한 IP 를 쓰는 경우에도 재로그인이 막히지 않게 하기 위함입니다.
  - `GET /ember/nonce`: 재등록과 같은 시간당 30회, 따로 셉니다.
- Play Integrity(`INTEGRITY_MODE`, 4-5 참고):

| `INTEGRITY_MODE` | 토큰 통과 | 토큰 없음·실패 | 응답의 `integrity` |
|---|---|---|---|
| `off`(기본) | 확인 안 함(예전과 같음) | 〃 | 없음 |
| `grant`(wrangler.toml 기본) | 가입 + 무료 크레딧 | 가입은 되지만 **무료 크레딧 0**(`freeGranted: false`) | `"ok"` / `"failed"` / `"missing"` / `"unavailable"` |
| `require` | 가입 + 무료 크레딧 | **403 `integrity_failed`**, 계정을 만들지 않음(재등록도 마찬가지) | `"ok"` / `"unavailable"` |

  - `missing`: `integrityToken` 이나 `nonce` 를 보내지 않음. `failed`: nonce 가 틀림·만료·재사용, Google 이 토큰을 거절, 판정 미달.
  - `unavailable`: 서버에 `GOOGLE_SERVICE_ACCOUNT_JSON` 이 없어 확인할 수 없음. 오류(500)를 주면 앱이 가입을 끝없이 재시도하므로, **가입은 시키되 새 계정의 무료 크레딧은 0** 입니다(`require` 에서도 마찬가지). 로그에 `INTEGRITY_MODE 가 켜져 있지만 GOOGLE_SERVICE_ACCOUNT_JSON 이 없음` 이 남습니다.
  - 통과 조건: 토큰 안의 `requestDetails.nonce` 가 서버가 발급했고 만료(5분) 전이며 아직 안 쓴 nonce 와 같음, `requestPackageName == PACKAGE_NAME`, `appRecognitionVerdict == "PLAY_RECOGNIZED"`, `deviceRecognitionVerdict` 에 `MEETS_DEVICE_INTEGRITY` 포함.
  - nonce 는 Google 을 부르기 **전에** 소비됩니다. 결과와 관계없이 한 번 보낸 nonce 는 다시 못 씁니다.
  - Google 일시 오류(네트워크·5xx·할당량 초과·권한 설정 문제)면 **502 `api_error`** 입니다. 무료 크레딧 지급 여부가 영구히 정해지므로 실패로 처리하지 않고 앱이 처음(nonce 받기)부터 다시 시도하게 합니다.
  - `grant` 에서 첫 가입 때 `failed`/`missing` 이었던 installId 는 나중에 통과해도 무료 크레딧을 받지 못합니다(무료 크레딧은 계정이 처음 만들어질 때만 지급).

**구매**
- Google Play Developer API 로 영수증을 확인하고 `purchaseState == 0`(구매 완료)일 때만 지급합니다(대기·취소는 400).
- 확인 뒤 크레딧을 주기 **전에 서버가 직접 `purchases.products.consume`** 을 부릅니다(소비 = 확인 포함, 3일 뒤 자동 환불 방지). 이미 소비된 구매(`consumptionState == 1` 이거나 Google 이 "이미 소비됨" 400)는 성공으로 봅니다. 소비가 실패하면 **502** 이고 지급하지 않습니다(앱이 다시 보내면 됨).
- 같은 `purchaseToken` 은 **절대 두 번 지급되지 않습니다**(DB UNIQUE + 트랜잭션). 재전송하면 `granted: 0` 과 현재 잔액을 돌려주므로 앱이 안전하게 재시도할 수 있습니다.
- **앱은 더 이상 직접 소비(consume)하지 않아도 됩니다.** 예전 앱처럼 성공 응답 뒤에 앱이 소비를 시도해도 괜찮고, 그 소비가 "이미 소비됨"으로 실패해도 무시하면 됩니다(실패했다고 복원·재전송을 반복하지 마세요).
- **테스트 구매**(라이선스 테스터, `purchaseType == 0`): 운영(`ALLOW_TEST_PURCHASES` 가 `"true"` 가 아님)에서는 소비만 하고 **크레딧을 주지 않으며**(`granted: 0`, `"testPurchase": true`) 결제 계정으로도 치지 않습니다. 기록은 `purchases.credits = 0, purchase_type = 0` 으로 남습니다.
- **결제 계정**(Opus 사용 가능) = 크레딧을 실제로 지급했고 환불되지 않은 구매가 있고, **환불(일부 환불 포함)된 구매가 하나도 없는** 계정.
- 오류: 모르는 상품·없는 영수증·미완료 구매 → 400, Google 일시 오류·소비 실패 → 502(재시도), 소비 후 DB 지급이 두 번 실패 → 500(로그 `소비 후 지급 실패(수동 지급 필요)`).

**메시지**
- 모든 업스트림 응답(성공·스트리밍·업스트림 오류)에 `ember-model: <서버가 실제로 보낸 모델>` 헤더가 붙습니다. 무료 계정이 Opus 를 요청하면 `ember-model: claude-sonnet-5-5`. (서버측 거절 대체로 다른 모델이 답한 경우는 응답 본문의 `model` 을 보세요.)
- 401 `authentication_error`: 토큰이 없거나 틀림. 403 `permission_error`: 차단된 계정(메시지에 `billing reconciliation` 이 있으면 정산 실패로 자동 차단된 것, 6장).
- **402 `insufficient_credits`**: 잔액이 0 이하이거나, `max_tokens` 를 1,024(또는 요청한 값)까지 줄여도 최악의 비용을 예약할 수 없음.
- 429 `rate_limit_error`: 토큰당 10분에 30회 초과, 또는 **같은 계정의 동시 요청이 2개 처리 중**(`retry-after: 5`).
- 400 `invalid_request_error`:
  - 허용 모델(`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`) 이외, `web_search_*` 이외의 도구.
  - **최상위 필드 허용 목록** 밖의 필드: 허용은 `model`, `max_tokens`, `messages`, `system`, `stream`, `tools`, `tool_choice`, `thinking`, `output_config`, `metadata`, `temperature`, `top_p`, `top_k`, `stop_sequences`, `fallbacks`, `cache_control`(앱이 보내는 최상위 자동 캐시) 뿐입니다. `mcp_servers`·`container`·`speed`·`service_tier`·`context_management` 등은 400.
  - `fallbacks` 가 문자열 `"default"` 가 아님. 웹 검색 `max_uses` 가 양의 정수가 아님.
  - `anthropic-version` 이 `2023-06-01` 이 아님(없으면 `2023-06-01`).
- 413 `request_too_large`: 본문이 2 MB 초과(이미지 base64 포함).
- `max_tokens` 가 64000 보다 크면 64000 으로 잘라서 보내고, 잔액이 모자라면 더 줄여서 보냅니다(위 "예약과 정산"). 줄였다면 응답이 `stop_reason: "max_tokens"` 로 끝날 수 있습니다.
- 웹 검색 도구의 `max_uses` 는 **5 이하로 강제**합니다(없거나 5 보다 크면 5).
- `anthropic-beta` 는 **허용 목록에 있는 값만** 전달합니다: `server-side-fallback-2026-07-01`(앱이 보내는 유일한 베타). 다른 값은 조용히 뺍니다.
- 비스트리밍 응답에는 `ember-credits-remaining` 헤더가 붙습니다. **정산 후 DB 에서 다시 읽은 잔액**입니다(정산 기록이 실패하면 헤더가 없음).
- 스트리밍(`"stream": true`)은 바이트를 바꾸지 않고 그대로 흘려보내며, 스트림이 끝나면 정산합니다(최종 usage 가 없으면 예약액 전체 청구).
- 서버의 Anthropic 키가 잘못되어 업스트림이 401/403 을 주면, 앱이 "기기 토큰이 틀렸다"고 오해하지 않도록 **500 `api_error`** 로 바꿔서 돌려줍니다.

### 앱 연동

1. **가입(Play Integrity 를 켤 경우)**
   1. `GET /ember/nonce` → `{"nonce":"..."}`. nonce 는 **24바이트 난수의 base64url(패딩 없음, 32자, `[A-Za-z0-9_-]`)** 입니다.
   2. Play Integrity **classic 요청**에 이 문자열을 **그대로** nonce 로 넣습니다(다시 인코딩하거나 바이트로 바꾸지 않음):
      ```kotlin
      val response = IntegrityManagerFactory.create(context)
          .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).build())
          .await()
      ```
      (클라우드 프로젝트 번호를 `setCloudProjectNumber(...)` 로 넘겨야 할 수 있습니다 — 4-5 참고.)
   3. `POST /ember/register {"installId", "integrityToken": response.token(), "nonce": nonce}`.
      - Google 이 토큰 안에 돌려주는 nonce 는 표준 base64(`+`, `/`, `=` 패딩)로 올 수도 있어, 서버는 base64url·무패딩으로 맞춘 뒤 비교합니다. 앱은 신경 쓸 필요 없습니다.
   - 응답은 예전과 같고(`token`, `credits`, `freeGranted`), `INTEGRITY_MODE` 가 `off` 가 아니면 `"integrity": "ok" | "failed" | "missing"` 이 추가됩니다.
   - 502 를 받으면 1번(새 nonce)부터 다시 시도합니다. Play Integrity 호출 자체가 기기에서 실패하면 토큰 없이 가입을 보내면 됩니다(`grant` 에서는 무료 크레딧 없이 가입, `require` 에서는 403).
   - `INTEGRITY_MODE=off` 인 동안에는 `integrityToken`·`nonce` 를 보내도 무시하므로, 앱을 먼저 배포하고 나중에 서버 설정만 바꿀 수 있습니다.
2. **메시지**: `/v1/messages` 응답 헤더 `ember-model` 이 실제로 쓴 모델입니다. 요청한 모델과 다르면(무료 계정의 Opus → Sonnet) "구매하면 Opus 를 쓸 수 있어요" 같은 안내를 보여 줄 수 있습니다.
   - 잔액이 적으면 서버가 `max_tokens` 를 줄여 보내므로 `stop_reason: "max_tokens"` 로 끝날 수 있습니다. 이 경우 "크레딧이 부족해 답이 잘렸어요" 로 안내하는 것을 권장합니다.
   - 429 중 메시지에 `concurrent` 가 있으면 같은 계정의 요청 2개가 처리 중인 것입니다. 잠시 뒤(`retry-after`) 다시 보내세요(SDK 의 자동 재시도로 충분).
   - 앱이 보내는 베타·필드는 이 서버의 허용 목록과 맞춰 두어야 합니다. 새 베타·최상위 필드를 쓰려면 서버(`src/proxy/validate.ts`)를 먼저 고쳐 배포하세요.
3. **구매**: 서버가 소비까지 하므로 앱의 `consumePurchase` 는 없어도 됩니다(있어도 되고, 실패는 무시). 응답에 `"testPurchase": true` 가 있으면 운영 서버가 테스트 구매에 크레딧을 주지 않은 것입니다.
4. **환불**: 구글에서 환불된 구매의 크레딧은 다음 날 cron 에서 회수되어 잔액이 음수가 될 수 있습니다. 음수면 `/v1/messages` 는 402 이므로 앱은 기존 "크레딧 부족" 화면을 그대로 쓰면 됩니다.
5. **신고**: `POST /ember/report` 는 AI 응답을 한 번이라도 받은 계정만 쓸 수 있습니다(아니면 403).

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
> **이미 운영 중인 DB 를 업그레이드할 때**는 schema.sql 대신 마이그레이션을 실행합니다(6장 "DB 업그레이드" 참고).

> **배포 전에 4-5(Play Integrity)를 끝내세요.** `wrangler.toml` 의 기본값이 `INTEGRITY_MODE = "grant"` 라서, 서비스 계정·Play Integrity 설정이 없으면 새 계정은 무료 크레딧 0 으로 가입됩니다.

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
# → INTEGRITY_MODE=grant(기본)에서는 토큰 없이 보냈으므로 {"token":"...","credits":0,"freeGranted":false,"integrity":"missing"}
#   (서비스 계정이 없으면 "integrity":"unavailable"). off 면 {"token":"...","credits":40,"freeGranted":true}

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
5. 환불 회수(Voided Purchases API)도 같은 서비스 계정·같은 권한(**재무 데이터 보기**)을 씁니다. 추가 설정은 없습니다.
6. 구매 소비(`purchases.products.consume`, 서버가 지급 전에 부름)는 **주문 및 구독 관리** 권한을 씁니다. 이 권한이 없으면 구매가 502 로 실패합니다.

### 4-4. 테스트 구매
- Play Console → 설정 → **라이선스 테스트**에 테스터 Gmail 을 넣으면 실제 결제 없이 구매를 시험할 수 있습니다.
- 운영 서버(`ALLOW_TEST_PURCHASES = "false"`, 기본)는 테스트 구매(`purchaseType == 0`)에 **크레딧을 주지 않고**(소비만 함, 응답 `granted: 0, testPurchase: true`) 결제 계정으로도 치지 않습니다. 라이선스 테스터를 아는 사람이 공짜 크레딧·Opus 를 얻는 것을 막기 위함입니다.
- 테스트 구매로 지급까지 시험하려면 **별도의 테스트용 워커**에서만 `ALLOW_TEST_PURCHASES = "true"` 로 두세요(`purchases.purchase_type = 0` 으로 기록되어 구분 가능).

### 4-5. Play Integrity 설정 (배포 전 필수)
가입 때 "Play 스토어에서 받은 진짜 앱 + 정상 기기"인지 확인해 무료 크레딧 반복 수령을 막습니다. `wrangler.toml` 의 기본값이 `INTEGRITY_MODE = "grant"` 이므로 **배포 전에 아래를 끝내야** 새 사용자가 무료 크레딧을 받습니다(설정 전에는 `integrity: "unavailable"` 또는 `"failed"` 로 무료 크레딧 0).

1. **Google Cloud 에서 API 사용 설정**: <https://console.cloud.google.com> → 4-2 에서 만든 프로젝트(`ember-play`) 선택 → **API 및 서비스 → 라이브러리** → "Google Play Integrity API" 검색 → **사용 설정**.
2. **Play Console 에 클라우드 프로젝트 연결**: Play Console → 앱 선택 → **테스트 및 출시(Release) → 앱 무결성(App integrity)** → **Play Integrity API** 항목에서 **클라우드 프로젝트 연결(Link Cloud project)** → 위 프로젝트 선택.
   - 토큰은 **연결된 프로젝트의 서비스 계정으로만** 해독할 수 있습니다. 다른 프로젝트의 서비스 계정이면 Google 이 거절하고, 서버는 가입을 502 로 돌려줍니다(로그에 `Play Integrity 해독 실패: 403`).
   - 앱이 Play 스토어 밖에서도 배포되거나 연결이 안 된 경우 앱에서 `setCloudProjectNumber(<프로젝트 번호>)` 가 필요합니다(프로젝트 번호는 Cloud 콘솔 대시보드에 표시).
3. **서비스 계정 권한**: 같은 프로젝트의 서비스 계정(`GOOGLE_SERVICE_ACCOUNT_JSON`)이면 Play Console 권한은 따로 필요 없습니다. 서버는 `https://www.googleapis.com/auth/playintegrity` 범위로 토큰을 받아 `decodeIntegrityToken` 을 부릅니다. 해독이 403 이면 API 사용 설정·프로젝트 연결을 다시 확인하세요(반영에 몇 분 걸릴 수 있음).
4. (권장) 같은 화면의 **응답(Responses) 설정**에서 기기 판정 기본값을 유지합니다. 서버는 `PLAY_RECOGNIZED` + `MEETS_DEVICE_INTEGRITY` 를 요구합니다(루팅·에뮬레이터·사이드로드는 통과 못 함).
5. **할당량**: 기본 하루 10,000 회입니다. 가입 수가 많아지면 Play Console 에서 증설을 요청하세요. 할당량을 넘으면 Google 이 429 를 주고 서버는 502 로 돌려줍니다.
6. **모드**: 기본은 `grant` 입니다. 바꾸려면 `wrangler.toml` 의 `INTEGRITY_MODE` 를 고치고 `npx wrangler deploy`.
   - Play Integrity 를 보내지 않는 예전 앱 버전은 `grant` 에서 무료 크레딧 0, `require` 에서 가입 불가가 됩니다.
   - 확인 없이 운영하려면(권장하지 않음) `off` 로 둡니다. 이때도 하루 상한(`FREE_CREDITS_DAILY_CAP`)은 적용됩니다.

---

## 5. 환경 변수

`wrangler.toml` 의 `[vars]` 는 공개 설정, 비밀값은 `wrangler secret put` 으로 넣습니다.

| 이름 | 종류 | 기본값 | 설명 |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | 비밀 | – | Anthropic API 키(필수) |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | 비밀 | – | 서비스 계정 JSON 전체(구매·환불 회수·Play Integrity 에 필수). 없으면 환불 회수는 건너뜀 |
| `ADMIN_KEY` | 비밀 | – | 관리자 API 키. 없으면 관리자 API 전부 401 |
| `PACKAGE_NAME` | 변수 | `app.ember.ideas` | 앱 패키지 이름 |
| `FREE_CREDITS` | 변수 | `40` | 신규 설치 무료 크레딧(결제 전에는 Opus 요청이 Sonnet 으로 처리됨) |
| `FREE_CREDITS_DAILY_CAP` | 변수 | `20000` | 하루(UTC) 새 계정 무료 크레딧 합계 상한. 넘으면 새 계정은 0 |
| `INTEGRITY_MODE` | 변수 | `grant`(wrangler.toml) / 코드 기본 `off` | 가입 시 Play Integrity: `off` / `grant`(통과해야 무료 크레딧) / `require`(통과해야 가입). 모르는 값이면 `off`. 서비스 계정이 없으면 무료 크레딧 0 |
| `ALLOW_TEST_PURCHASES` | 변수 | `false` | `true` 면 라이선스 테스트 구매에도 크레딧 지급(테스트용 워커에서만) |
| `MARKUP` | 변수 | `1.5` | 원가 대비 배수(1 이상) |
| `MAX_OUTPUT_TOKENS` | 변수 | `64000` | `max_tokens` 상한 |
| `MAX_BODY_BYTES` | 변수 | `2097152` | 요청 본문 최대 크기(2 MB) |
| `PRODUCTS` | 변수 | `{"ember_credits_500":500,"ember_credits_1500":1650,"ember_credits_5000":5750}` | 상품 ID → 크레딧(JSON). 형식이 틀리면 기본값 사용 |
| `REGISTER_LIMIT` / `REGISTER_WINDOW_SECONDS` | 변수 | `5` / `3600` | IP(IPv4 주소 / IPv6 /64)당 새 가입 제한 |
| `REREGISTER_LIMIT` | 변수 | `30` | IP 당 재등록(토큰 재발급)·`/ember/nonce` 제한(창은 `REGISTER_WINDOW_SECONDS`) |
| `MESSAGES_LIMIT` / `MESSAGES_WINDOW_SECONDS` | 변수 | `30` / `600` | 토큰 당 `/v1/messages` 제한 |
| `MAX_CONCURRENT_REQUESTS` | 변수 | `2` | 계정당 동시 처리 중인 `/v1/messages` 수 |
| `INFLIGHT_STALE_SECONDS` | 변수 | `1800` | 이보다 오래된 처리 중 표시는 죽은 요청으로 보고 무시(최소 60) |
| `REPORTS_DAILY_CAP` | 변수 | `500` | 하루(UTC) 전체 신고 수 상한 |
| `ANTHROPIC_BASE_URL` | 변수 | `https://api.anthropic.com` | 업스트림 주소(테스트용으로만 변경) |

---

## 6. 운영

- **통계**: `GET /ember/admin/stats` (헤더 `x-admin-key`).
- **신고 목록**: `GET /ember/admin/reports?limit=50`, 다음 페이지는 응답의 `nextBefore` 를 `before=` 로.
- **계정 차단**:
  ```bash
  npx wrangler d1 execute ember --remote --command "UPDATE accounts SET disabled = 1 WHERE id = 42"
  ```
- **정산 실패로 자동 차단된 계정(`disabled = 2`)**: 응답 후 사용 기록·정산(usage_log + 잔액 반영)이 재시도까지 실패하면, 공짜로 쓰이지 않도록 계정을 `disabled = 2` 로 막습니다. 이때 예약액은 이미 빠진 상태라 사용자가 덜 낸 것은 없습니다(보통 더 낸 상태).
  1. `npx wrangler tail` 또는 로그에서 `정산 실패(계정 차단, 수동 정산 필요): account=… reserved=… actual=…` 을 찾습니다.
  2. 돌려줄 크레딧(`reserved − actual`)을 더하고 차단을 풉니다:
     ```bash
     npx wrangler d1 execute ember --remote --command "UPDATE accounts SET credits = credits + <reserved-actual>, disabled = 0 WHERE id = 42 AND disabled = 2"
     ```
  - `GET /ember/admin/stats` 의 `billingDisabledAccounts` 로 개수를, `inflightRequests` 로 처리 중(예약 중) 요청 수를 볼 수 있습니다.
- **처리 중 표시(`inflight`)**: 요청이 끝나면 지워집니다. 워커가 중간에 죽어 남은 행은 `INFLIGHT_STALE_SECONDS`(30분) 뒤 무시되고 cron 이 로그(`정산되지 않은 요청 정리`)를 남기고 지웁니다. 이 경우 예약액은 그대로 청구된 상태입니다.
- **크레딧 수동 지급(환불·보상)**:
  ```bash
  npx wrangler d1 execute ember --remote --command "UPDATE accounts SET credits = credits + 500 WHERE id = 42"
  ```
- 매일 03:17(UTC) cron 이 하는 일(하나가 실패해도 나머지는 계속하고, 마지막에 실패로 기록):
  1. 오래된 요청 제한 카운터·만료된 nonce·오래된 처리 중 표시 삭제, 보관 기간 지난 기록 정리
     - 보관 정리: 1년 지난 `usage_log`·`reports` 삭제. 1년 동안 쓰지 않은 계정 중 **잔액이 0 이하이고 환불되지 않은 구매가 없는 계정만** 정리합니다(구매 기록이 없으면 삭제, 환불된 구매 기록만 있으면 토큰·installId 만 무효로 하고 남김). **잔액이 남아 있거나 환불되지 않은 구매가 있는 계정은 절대 만료하지 않습니다.** 5년 지난 구매 기록은 이미 만료된 계정 것만 지웁니다.
  2. **환불 회수**: Voided Purchases API(`type=0` 일회성 상품, `includeQuantityBasedPartialRefund=true`, 1000개씩 페이지 넘김)로 환불·취소 목록을 받아, 지급한 구매면 환불된 수량만큼 잔액에서 빼고(**음수 가능 → 402 로 사용 차단**) `purchases.voided = 1, voided_quantity, voided_at = 환불 시각` 으로 표시합니다.
     - **수량 일부 환불**(`voidedQuantity` 가 있음): `credits × voidedQuantity / quantity` 만 회수합니다(누적 기준으로 나눠, 전부 환불되면 정확히 전액). `voidedQuantity` 가 없으면 전체 환불로 보고 아직 회수하지 않은 나머지 수량을 전부 회수합니다.
     - 같은 환불 이벤트(전체 환불 / 일부 환불은 시각·수량)는 `voided_events` 표로 **한 번만** 뺍니다.
     - 일부 환불만 있어도 그 계정은 결제 계정에서 빠집니다(Opus → Sonnet).
     - 처리 위치는 `meta` 표의 `voided_purchases_end_ms` 에 저장합니다. 첫 실행은 30일 전부터(구글이 허용하는 최대), 이후에는 지난 실행 시각 **1일 전**부터 다시 봅니다(늦게 올라오는 환불 대비). cron 이 30일 넘게 멈췄다면 그 사이 환불 일부는 놓칠 수 있습니다.
     - Google 오류로 중간에 실패하면 처리 위치를 올리지 않으므로 다음 날 다시 봅니다. `npx wrangler tail` 로그에 `환불 회수:` / `환불 목록 N건 확인` 이 남습니다.
- **환불 현황**:
  ```bash
  npx wrangler d1 execute ember --remote --command "SELECT account_id, product_id, credits, datetime(voided_at,'unixepoch') FROM purchases WHERE voided = 1 ORDER BY voided_at DESC LIMIT 50"
  ```
  `GET /ember/admin/stats` 의 `voided.purchases`·`voided.creditsClawedBack` 에도 나옵니다.
- **환불 회수 다시 처음부터(30일)**: `npx wrangler d1 execute ember --remote --command "DELETE FROM meta WHERE key = 'voided_purchases_end_ms'"`

### DB 업그레이드
운영 중인 DB 에는 **새 코드를 배포하기 전에** 아직 적용하지 않은 마이그레이션을 순서대로 한 번씩 실행합니다(새 표·컬럼 없이 새 코드를 배포하면 쿼리가 실패합니다).

**이번 버전(0003: 예약 과금·동시 요청 제한·일부 환불)** — 0002 까지 적용된 DB:
```bash
npx wrangler d1 execute ember --remote --file=./migrations/0003_billing_guards.sql
```
내용: `purchases.voided_quantity` 컬럼 추가, `voided_events`·`inflight` 표 생성, 이미 회수한 구매(`voided = 1`)를 전체 수량 환불 + `legacy` 이벤트로 옮김.

**이전 버전(0002: 환불 회수·Play Integrity)** — 그보다 예전 schema.sql 로 만든 DB 라면 0003 전에 먼저:
```bash
npx wrangler d1 execute ember --remote --file=./migrations/0002_voided_integrity.sql
```
내용: `purchases` 에 `voided INTEGER NOT NULL DEFAULT 0`, `voided_at INTEGER` 컬럼 추가(`ALTER TABLE ... ADD COLUMN`), `meta`·`nonces` 표 생성.
- 새로 만드는 DB 는 schema.sql 에 이미 들어 있으므로 실행하지 마세요(컬럼 중복 오류).
- `wrangler d1 migrations apply` 가 아니라 위의 `d1 execute --file` 로 실행합니다.
- Anthropic 콘솔의 **지출 한도**를 반드시 걸어 두세요. 서버 버그나 남용이 있어도 피해가 한도 안에서 멈춥니다.

---

## 7. 남용 위험과 한계 (꼭 읽어 주세요)

1. **무료 크레딧 반복 수령**: installId 는 앱을 지웠다 다시 깔거나 데이터를 지우면 바뀝니다. 그러면 새 계정으로 무료 크레딧을 또 받을 수 있습니다.
   - **IP(IPv4 주소 / IPv6 /64)당 시간당 5회 새 가입 제한**으로 속도를 늦추고(모바일 데이터·VPN 으로 우회 가능), 무료 크레딧은 40 으로 작고 Sonnet 으로만 쓰입니다. 재로그인(이미 있는 installId)은 따로 느슨하게 셉니다.
   - **하루 무료 크레딧 상한**(`FREE_CREDITS_DAILY_CAP`, 기본 20,000 크레딧 ≈ 원가 $133)으로 하루 피해에 상한이 있습니다. 상한에 닿으면 그날 정상 신규 사용자도 무료 크레딧을 못 받으니, `admin/stats` 의 `creditsGranted.free` 를 보며 조정하세요.
   - `INTEGRITY_MODE=grant`(기본)/`require` 의 **Play Integrity** 로 진짜 Play 설치 앱 + 정상 기기에서만 무료 크레딧을 줍니다(4-5). 다만 정상 기기에서 앱을 지웠다 다시 까는 반복은 여전히 막지 못합니다(기기 단위로 묶으려면 기기 식별이 필요하지만, 개인정보 문제로 하지 않음). 피해가 커지면 `FREE_CREDITS` 를 줄이거나 0 으로 바꿀 수 있습니다.
2. **installId 는 사실상 비밀번호**입니다. installId 를 아는 사람은 재등록으로 같은 계정의 새 토큰을 받을 수 있고, 그러면 원래 기기의 토큰은 무효가 됩니다. 앱은 installId 를 외부에 노출하지 마세요.
3. **환불 후 사용**: 매일 cron 이 **Voided Purchases API** 로 환불된 구매의 크레딧을 회수합니다(잔액 음수 → 402, 수량 일부 환불은 비율만큼). 다만 환불 직후부터 다음 cron 까지(최대 약 하루)는 남은 크레딧을 쓸 수 있고, 이미 써 버린 만큼은 음수 잔액으로만 남습니다(다음 구매에서 메워짐).
4. **중단 시 과금**: 앱이 스트리밍 도중 연결을 끊거나 최종 사용량(`message_delta`)을 받지 못하면 서버는 업스트림을 취소하고 **예약액 전체**(최악의 비용)를 청구합니다. 사용자에게는 불리할 수 있지만, 화면에 안 보이는 사고 토큰·웹 검색으로 과금을 피하는 것을 막습니다.
5. **예약 추정의 한계**: 입력 토큰은 본문 크기로, 웹 검색 결과는 1회 8,000 토큰으로 추정합니다. 실제가 더 크면 정산 때 차이를 더 빼므로 잔액이 조금 음수가 될 수 있습니다(그 뒤 402). 서버측 거절 대체(`fallbacks`)가 두 모델의 출력을 합쳐 청구하는 경우도 같은 방식으로 처리됩니다.
6. **요청 제한은 D1 고정 창 방식**이라 창 경계에서 잠깐 두 배까지 허용될 수 있습니다. 엄격한 제한이 필요하면 Durable Objects 로 바꾸세요. 동시 요청 제한(계정당 2개)과 하루 상한은 한 SQL 문으로 처리해 정확합니다.
7. 도구는 `web_search_*` 만 허용하고, 도구마다 `max_uses` 를 5 이하로 강제합니다. 웹 검색은 1회당 $0.01 이 추가됩니다.
8. **신고 남용**: `POST /ember/report` 는 AI 응답 기록이 있는 계정만, 계정당·IP(/64)당 시간당 30회, 하루 전체 `REPORTS_DAILY_CAP`(500)회로 제한합니다.

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
  index.ts            진입점(fetch, scheduled → runDailyJobs: 정리 + 환불 회수)
  router.ts           경로 → 핸들러, 오류 처리
  env.ts              환경 변수·기본값
  http.ts             Anthropic 형식 오류, 본문 크기 제한 읽기
  util.ts             토큰 생성, SHA-256, 일정 시간 비교, base64url
  auth.ts             기기 토큰 인증
  ratelimit.ts        D1 고정 창 요청 제한, 하루 합계 상한, IP 키(IPv4 / IPv6 /64)
  account.ts          /ember/register, /ember/balance
  models.ts           허용 모델, /v1/models/:id
  purchase.ts         /ember/purchase (서버 소비 후 멱등 지급, 테스트 구매 처리)
  retention.ts        보관 기간 지난 기록·계정 정리(cron)
  play/google-auth.ts 서비스 계정 RS256 JWT → OAuth 토큰(범위별 캐시), googleFetch(401 재시도)
  play/verify.ts      Play Developer API 영수증 확인·소비(consume)
  play/voided.ts      Voided Purchases API → 환불 크레딧 회수(일부 환불 포함, cron)
  play/integrity.ts   /ember/nonce, Play Integrity 토큰 해독·판정
  proxy/validate.ts   최상위 필드·모델·도구·max_tokens 검증, anthropic-version/beta 허용 목록
  proxy/reserve.ts    최악 비용 예약(max_tokens 줄이기), 계정당 동시 요청 칸(inflight)
  proxy/sse.ts        SSE usage 증분 파서
  proxy/messages.ts   /v1/messages 프록시(비스트리밍·스트리밍), 무료 계정 Opus→Sonnet, ember-model 헤더
  billing/usage.ts    usage 정규화
  billing/pricing.ts  단가표·크레딧 계산·예약 계산
  billing/ledger.ts   정산(예약 − 실제 환불) + usage_log, 실패 시 재시도·계정 차단
  reports.ts          /ember/report
  admin.ts            관리자 API
test/                 vitest 테스트(가짜 D1 = node:sqlite, 가짜 fetch, 가짜 Google = test/helpers/google.ts)
schema.sql            D1 스키마(새 DB 용)
migrations/           이미 운영 중인 DB 용 변경 SQL
```
