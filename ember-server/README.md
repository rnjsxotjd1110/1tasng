# Ember 서버 (Cloudflare Worker)

Ember 안드로이드 앱의 **"API 키 없이 쓰기"(유료 크레딧)** 백엔드입니다.

- 앱은 Anthropic Java SDK 의 `baseUrl` 을 이 서버 주소로, `apiKey` 를 **기기 토큰**으로 설정합니다.
- 서버는 Anthropic Messages API 와 똑같이 동작하는 **투명 프록시**입니다. 기기 토큰을 확인한 뒤 서버의 진짜 Anthropic 키로 바꿔서 전달합니다. 보내기 **전에** 최악의 비용을 잔액에서 미리 빼 두고(예약), 응답의 `usage`(토큰 수)로 실제 비용을 계산해 남는 만큼 돌려줍니다(정산).
- **크레딧 모드는 Google 로그인(Sign in with Google)이 필수**입니다. 앱이 Android Credential Manager 로 받은 Google ID 토큰을 가입 때 보내면, 서버는 그 안의 `sub`(구글 계정 고유 ID)로 계정을 찾습니다. 앱을 다시 깔거나 폰을 바꿔도 같은 Google 계정으로 로그인하면 **같은 계정(잔액·구매)이 돌아옵니다.** 이메일·이름은 저장하지 않습니다.
- 크레딧은 Google Play 인앱 상품으로 판매하고, 새 계정에는 무료 크레딧(기본 40)을 **Google 계정당 평생 한 번** 줍니다(탈퇴 후 다시 가입해도 다시 받지 못함). **결제한 적 없는 계정은 Opus 요청도 Sonnet 으로 처리**합니다.
- **유료 크레딧과 무료 크레딧을 따로 셉니다**(이용약관 5·6·7장). 유료는 구매 한 건마다 "묶음(lot)" 으로 남은 양과 유효기간(구매 + 5년)을 기록하고, **무료 먼저, 그다음 유료를 오래된 구매부터** 씁니다(1장).
- 청약철회·환불은 운영자가 `GET /ember/admin/refund-quote` 로 금액을 계산하고 `POST /ember/admin/refund` 로 크레딧을 없앤 뒤 **Play Console 에서 돈을 돌려줍니다**(6장 "환불·청약철회 처리").
- 앱에서 **계정 삭제**(`DELETE /ember/account`)를 할 수 있습니다. 구매 기록만 법정 보관을 위해 계정과 연결을 끊은 채 남깁니다(9장 데이터 목록).
- 환불·취소된 구매는 매일 cron 이 Google Play Voided Purchases API 로 찾아 크레딧을 회수합니다(그 구매의 묶음에서 먼저).
- 보관 기간은 개인정보처리방침과 같습니다: 사용 기록·신고 1년, IP 2일, 무료 크레딧만 있는 계정은 마지막 사용 후 1년, 유료가 남은 계정은 마지막 구매 후 5년, 구매·환불 기록 5년, 무료 크레딧 중복 방지 기록은 계정이 없어진 뒤 3년(9장).
- 크레딧 계정이 없는 사용자(내 API 키·체험 모드)도 `POST /ember/report/anon` 으로 AI 결과를 익명 신고할 수 있습니다.
- 가입 때 Play Integrity 로 진짜 Play 설치 앱·정상 기기인지 확인합니다(`wrangler.toml` 의 `INTEGRITY_MODE = "grant"`). **배포 전에 Play Integrity 를 설정해야 합니다(4-5).** 설정하지 않으면 가입은 되지만 새 계정의 무료 크레딧이 0 입니다.
- 데이터는 Cloudflare D1(SQLite)에 저장합니다. 서버 비용은 소규모라면 Cloudflare 무료 플랜 안에서 해결됩니다.

```
앱 (Anthropic SDK, x-api-key = 기기 토큰)
   │  POST /v1/messages (스트리밍 SSE 포함), GET /v1/models/{id}
   │  GET /ember/nonce · POST /ember/register · POST /ember/link-google · DELETE /ember/account
   │  GET /ember/balance · POST /ember/purchase · POST /ember/report · POST /ember/report/anon(인증 없음)
   ▼
Ember 서버 (Cloudflare Worker + D1)            매일 cron: 정리·유효기간·보관 기간 + 환불 회수
   │  (운영자) GET /ember/admin/refund-quote · POST /ember/admin/refund · GET /ember/admin/stats·reports
   │  x-api-key = 서버의 ANTHROPIC_API_KEY
   ▼
api.anthropic.com      androidpublisher.googleapis.com (영수증 확인·환불 목록)
                       playintegrity.googleapis.com (무결성 토큰 해독, INTEGRITY_MODE 가 켜졌을 때)
                       www.googleapis.com/oauth2/v3/certs (Google ID 토큰 공개키, 캐시)
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
  1. 업스트림을 부르기 **전에** 최악의 비용을 크레딧으로 계산해 `UPDATE accounts SET credits = credits - 예약액 WHERE id = ? AND credits >= 예약액` 으로 원자적으로 뺍니다. 같은 트랜잭션에서 무료로 모자라는 만큼은 오래된 유료 묶음에서 잠시 빼 둡니다(아래 "유료 크레딧과 무료 크레딧").
     - 최악의 비용 = `max_tokens × 출력 단가` + `입력 추정 × 입력 단가` + `웹 검색 max_uses 합 × $0.01`.
     - 입력 추정 = 본문 UTF-8 바이트 ÷ 3 토큰(이미지 base64 는 바이트 대신 장당 5,000 토큰) + 웹 검색 1회당 결과 8,000 토큰. 본문에 `cache_control` 이 있으면 입력 단가 ×1.25(`ttl: "1h"` 가 보이면 ×2), Haiku 는 추정이 10만 토큰을 넘으면 ×5.
     - `fallbacks: "default"` 를 쓰면 응답 모델이 바뀔 수 있으므로 **아는 단가 중 가장 비싼 값**(입력 $5 / 출력 $25)으로 예약합니다.
  2. 잔액이 예약액보다 적으면 `max_tokens` 를 잔액이 감당하는 만큼 **줄여서** 보냅니다(하한 1,024, 요청한 값이 더 작으면 그 값. `thinking.budget_tokens` 가 새 `max_tokens` 이상이면 함께 줄임). 그래도 안 되면 **402**.
  3. 응답이 끝나면 `예약액 − 실제 비용` 을 돌려줍니다(0 미만이면 돌려주지 않음). 예약 때 유료 묶음에서 뺐던 양까지는 유료 묶음(최신 구매부터)으로 되돌리고, 나머지는 무료로 돌아갑니다. 입력 추정이 모자라 실제 비용이 예약액보다 큰 드문 경우에는 차이를 더 빼므로(무료 → 오래된 유료 순) 잔액이 조금 음수가 될 수 있습니다(로그에 `실제 비용이 예약액보다 큼`).
  - 그래서 잔액을 넘는 동시 요청·긴 출력으로 크레딧을 넘겨 쓸 수 없습니다. 같은 계정의 동시 처리는 **2개**까지입니다(`MAX_CONCURRENT_REQUESTS`, 넘으면 429).
- 업스트림(Anthropic) 오류 응답·연결 실패는 비용 0(예약액 전부 환불)입니다.
- **끝까지 받지 못한 요청**(최종 usage = `message_delta` 를 받기 전에 끝남, 이용약관 5장, 운영자 결정, `src/billing/interrupted.ts`). 모두 `usage_log.estimated = 1` 로 남고, **예약액을 넘지 않습니다**.

  | 상황 | 청구 |
  |---|---|
  | 앱이 '중지'를 누르거나 연결이 끊김(스트리밍) | **입력 토큰**(`message_start` 의 usage: 입력·캐시 읽기·캐시 쓰기) **+ 출력 추정 = 올림(받은 출력 문자 수 ÷ 3) × 2 토큰**. 출력 문자 = `content_block_delta` 의 `text`·`thinking`·`partial_json` 문자 수. ×2 는 화면에 보이지 않는 생각(thinking) 분량을 덮기 위한 것. 웹 검색은 청구하지 않음 |
  | Anthropic 쪽 오류: 스트림 중간 `error` 이벤트, 업스트림 연결이 끊김, `message_delta` 없이 스트림이 끝남 | **입력 토큰만** |
  | 이 서버 쪽 오류(스트림 처리 중 예외) | **입력 토큰만** |
  | 비스트리밍 응답의 본문·usage 를 읽지 못함(업스트림 쪽 문제) | **입력 토큰만**. 비스트리밍은 `message_start` 가 없으므로 본문 크기로 추정한 입력 토큰(바이트 ÷ 3, 이미지 장당 5,000)을 씀 |
  | `message_start` 를 받기 전에 끝남(생성 시작 전) | 0 |
  | 업스트림 오류 응답(HTTP 4xx·5xx)·연결 실패 | 0 |

  - 예) Sonnet, 입력 10,000 토큰, 사고 1,200자 + 본문 1,800자를 받은 뒤 중지 → 출력 추정 = 3,000 ÷ 3 × 2 = 2,000 토큰 → $0.02 + $0.02 = $0.04 × 1.5 = **6 크레딧**.
  - 워커가 중간에 죽어 정산하지 못한 요청(처리 중 표시가 30분 넘게 남음)만 예전처럼 예약액이 그대로 청구된 상태로 남습니다(6장).
- **유료 크레딧과 무료 크레딧**(`src/billing/lots.ts`):
  - `accounts.credits` 는 지금 쓸 수 있는 잔액 전체(무료 + 만료 안 된 유료, 처리 중 요청의 예약액은 빠진 값, 음수 = 빚)입니다. 예전 앱이 보는 `credits` 도 이 값입니다.
  - **유료 크레딧** = 지급한 구매마다 하나씩인 "묶음"(`purchases.remaining`, `expires_at`, `lot_closed_*`)의 남은 양 합계. **무료 크레딧** = `credits − 유료`. 무료 크레딧은 가입 때 받은 것(그리고 정산 때 묶음으로 돌아가지 못한 소량)입니다.
  - **쓰는 순서**: 무료 먼저, 그다음 유료를 오래된 구매부터. 서버는 잔액이 줄어드는 모든 곳(예약·정산·환불 회수)에서 "유료 합계 ≤ max(0, credits)" 가 되도록 오래된 묶음부터 깎습니다. 그래서 유료가 남아 있는 동안 무료는 0 이상이고, 빚(음수)은 유료가 0 일 때만 생깁니다. 빚이 있는 계정이 사면 새 묶음에서 빚을 먼저 갚습니다.
  - **유효기간**: 구매 기록 시각 + 달력 5년(2월 29일 구매는 5년 뒤 3월 1일). 지나면 그 계정의 다음 요청(잔액 확인 포함) 때 또는 매일 cron 이 묶음을 닫고(`lot_closed_reason = 'expired'`) 남은 양을 잔액에서 뺍니다. 30일 안에 만료되는 양은 `GET /ember/balance` 의 `expiringSoon` 으로 알려 주므로 앱이 안내합니다(약관 6장).
  - **환불 회수**(Google 환불·취소): 그 구매의 묶음에 남은 양에서 먼저 빼고, 모자라면 나머지 잔액(무료 → 다른 오래된 묶음)에서 빼며, 그래도 모자라면 음수가 됩니다(예전과 같음). 전체 환불이면 묶음을 닫습니다(`voided`).
  - **운영자 환불**(`POST /ember/admin/refund`)은 그 묶음의 남은 양을 0 으로 만들고 잔액에서 뺍니다. 그 뒤 Google 이 알려 주는 같은 구매의 환불은 다시 빼지 않습니다.
  - **탈퇴**하면 남은 묶음을 닫습니다(`deleted`, 크레딧 소멸, 약관 12장). **계정 만료**(1년 미사용 + 유료 없음) 때 남은 무료 크레딧도 사라집니다.
  - 기존 잔액(0005 이전)은 마이그레이션이 나눕니다: 유료 = min(잔액, 환불 안 된 지급 구매 크레딧 합계)를 **최신 구매부터** 채우고(오래된 것부터 썼다고 보므로), 나머지는 무료. 환불(일부 포함)된 구매·탈퇴·만료 계정의 구매는 닫힌 묶음(남은 양 0)이 됩니다. 0 이하 잔액이면 유료 0.
- **무료 계정 모델 제한**: 지급 완료되고 환불되지 않은 구매가 하나도 없는 계정(= 무료 크레딧만 쓰는 계정)이 `claude-opus-5-5` 를 요청하면, 서버가 `model` 을 `claude-sonnet-5-5` 로 바꿔 보내고 **Sonnet 단가로 과금**합니다. Haiku·Sonnet 요청은 그대로입니다. 한 번이라도 구매하면 바로 Opus 를 쓸 수 있고, 그 구매가 환불되면 다시 Sonnet 으로 돌아갑니다. 실제로 보낸 모델은 응답 헤더 `ember-model` 로 알 수 있습니다.
- 서버측 거절 대체(`server-side-fallback`)로 다른 모델이 응답하면, 그 모델의 단가표가 있으면 그 단가로(예: `claude-opus-5` $5/$25), **단가표에 없는 모델이면 아는 단가 중 가장 비싼 값**(입력 $5 / 출력 $25 / 캐시 읽기 $0.5)으로 계산합니다(요청한 모델 단가가 아님).

---

## 2. 앱용 API 계약 요약

모든 오류는 Anthropic 형식입니다: `{"type":"error","error":{"type":"...","message":"..."}}`
인증은 `x-api-key: <토큰>` 또는 `Authorization: Bearer <토큰>`.

| 메서드·경로 | 인증 | 요청 | 응답 |
|---|---|---|---|
| `GET /ember/nonce` | 없음 | – | `{"nonce"}` (Play Integrity 용 일회용 값, 5분 유효) |
| `POST /ember/register` | 없음 | `{"installId": "8~64자 [A-Za-z0-9_-]", "idToken": "<Google ID 토큰>", "integrityToken"?, "nonce"?}` | `{"token","credits","freeGranted","restored"}` + `INTEGRITY_MODE` 가 켜져 있으면 `"integrity"` |
| `POST /ember/link-google` | 토큰 | `{"idToken"}` | `{"linked":true,"credits"}` |
| `DELETE /ember/account` | 토큰 | – | `{"deleted":true}` |
| `GET /ember/balance` | 토큰 | – | `{"credits","freeCredits","paidCredits","expiringSoon"}` (아래 "잔액") |
| `POST /ember/purchase` | 토큰 | `{"productId","purchaseToken"}` | `{"credits","granted"}` (+ 운영에서 테스트 구매면 `"testPurchase": true`) |
| `POST /ember/report` | 토큰 | `{"kind":"question"\|"idea"\|"document"\|"other","reason","content"(≤20000자),"note"(≤2000),"appVersion"(≤64)}` | `{"ok":true,"id"}` |
| `POST /ember/report/anon` | **없음** | `/ember/report` 와 같음 | `{"ok":true,"id"}` (크레딧 계정 없는 사용자의 익명 신고, 아래 "신고") |
| `POST /v1/messages` | 토큰 | Anthropic Messages API(허용 필드만) | Anthropic 응답 그대로(스트리밍 포함) + 헤더 `ember-model` |
| `GET /v1/models/{id}` | 토큰 | – | `{"type":"model","id","display_name","created_at"}` 또는 404 |
| `GET /ember/admin/reports?limit=50&before=<id>` | `x-admin-key` | – | `{"reports":[...],"nextBefore"}` |
| `GET /ember/admin/stats` | `x-admin-key` | – | 계정 수, Google 연결 계정 수, 탈퇴 수, 지급/사용 크레딧, 유료 잔액, 24시간 요청 수 등 |
| `GET /ember/admin/refund-quote?orderId=GPA...[&waiveFee=1][&paid=5900&currency=KRW]` | `x-admin-key` | – | 환불 견적(금액·비율·묶음 상태, 바꾸는 것 없음). 6장 |
| `POST /ember/admin/refund` | `x-admin-key` | `{"orderId", "waiveFee"?, "paid"?, "currency"?}` | `{"refunded":true,"orderId","credits","amountMicros","amount","currency","quote"}`. 6장 |

그 밖의 경로는 모두 404 `not_found_error`.

**오류 코드 한눈에 보기**(Google 로그인·계정 관련)

| HTTP | `error.type` | 언제 | 앱이 할 일 |
|---|---|---|---|
| 400 | `google_required` | 가입에 `idToken` 이 없음(`REQUIRE_GOOGLE_SIGNIN` 기본). 또는 `REQUIRE_GOOGLE_SIGNIN=false` 에서 Google 에 연결된 계정의 installId 로 `idToken` 없이 가입 | Google 로그인 후 `idToken` 을 넣어 다시 |
| 403 | `google_required` | `LEGACY_UNLINKED_UNTIL` 이 지났는데 Google 에 연결 안 된 계정의 토큰으로 요청(연결·탈퇴 제외), 또는 그 뒤 `idToken` 없는 가입 | Google 로그인 → `POST /ember/link-google` |
| 401 | `invalid_google_token` | ID 토큰 검증 실패(서명·발급자·aud·만료·이메일 미인증·형식) | Credential Manager 로 새 ID 토큰을 받아 다시(토큰은 약 1시간 유효) |
| 409 | `google_in_use` | link-google: 그 Google 계정이 이미 다른 Ember 계정의 것 | 안내("이 Google 계정은 이미 다른 Ember 계정에 연결되어 있어요"). 계정 합치기는 없음 |
| 409 | `already_linked` | link-google: 이 계정이 이미 **다른** Google 계정에 연결됨 | 안내. 같은 Google 계정이면 200(멱등) |
| 502 | `api_error` | Google 공개키(JWKS)를 받지 못함 | 잠시 뒤 다시 |
| 500 | `api_error` | 서버 설정 누락(`GOOGLE_OAUTH_CLIENT_IDS`·`SUB_HASH_SECRET`), 메시지 `Google sign-in is not configured` | 운영자 설정 확인 |
| 401 | `authentication_error` | 토큰이 없거나 틀림(탈퇴한 계정의 토큰 포함) | 다시 가입(Google 로그인) |

**잔액**(`GET /ember/balance`, 응답 형식이 바뀜 — 예전 앱은 `credits` 만 읽으면 그대로 동작)
```json
{"credits": 2050, "freeCredits": 100, "paidCredits": 1950, "expiringSoon": {"credits": 200, "at": 1893456000}}
```
- `credits`: 지금 쓸 수 있는 잔액 전체(무료 + 만료 안 된 유료). **예전 앱 호환을 위해 그대로 둡니다.** 음수면 빚(환불 회수 등).
- `freeCredits`: 무료 크레딧(= `credits − paidCredits`). 빚이 있으면 음수(그때 `paidCredits` 는 0).
- `paidCredits`: 만료 안 된 유료 크레딧(구매별 남은 양의 합).
- `expiringSoon`: 30일 안에 만료되는 유료 크레딧이 있으면 `{"credits": 그 합계, "at": 가장 이른 만료 시각(유닉스 초, UTC)}`, 없으면 `null`. 앱은 "N 크레딧이 YYYY-MM-DD 에 만료돼요" 로 안내합니다(약관 6장: 만료 30일 전 안내).
- 처리 중인 요청이 있으면 예약액만큼 줄어든 값입니다(끝나면 정산되어 돌아옴).
- 잔액 확인도 "마지막 사용" 으로 칩니다(계정 보관 기간 1년 기준, 9장).

**신고**
- `POST /ember/report`(토큰): AI 응답을 한 번이라도 받은 계정만(아니면 403). 계정당·IP(/64)당 시간당 30회.
- `POST /ember/report/anon`(**인증 없음**): 크레딧 계정이 없는 사용자(내 API 키·체험 모드)용. 본문·응답·검증은 `/ember/report` 와 같고, `account_id = NULL` 로 저장합니다(토큰을 보내도 계정과 연결하지 않음). **IP(IPv4 주소 / IPv6 /64)당 시간당 10회**(넘으면 429 `rate_limit_error`).
- 하루 전체 상한 `REPORTS_DAILY_CAP`(기본 500)은 두 경로를 **합쳐서** 셉니다(넘으면 429, 메시지에 `today`).
- 신고는 1년 보관합니다. IP 는 요청 제한 카운터에만 쓰고(2일) 신고에는 저장하지 않습니다.

**등록(Google 로그인, 기본)**
- 요청: `{"installId", "idToken", "integrityToken"?, "nonce"?}`. `idToken` 은 Credential Manager 가 준 Google ID 토큰(JWT) 문자열 그대로.
- 응답: `{"token": "<기기 토큰>", "credits": 123, "freeGranted": true|false, "restored": true|false}` (+ `"integrity"`).
  - `restored: true` = 이미 있던 계정을 돌려받음(새 토큰 발급, 이전 기기의 토큰은 무효). `false` = 새 계정.
- 서버는 ID 토큰을 검증(4-6)하고 **`sub` 만** 씁니다. 이메일·이름은 저장하지 않습니다(앱이 보여 주고 싶으면 앱이 가진 값을 쓰세요).
- **그 Google 계정의 계정이 있으면 → 복원**: 같은 계정에 새 토큰을 주고, 계정의 installId 를 이번 installId 로 바꿉니다. 무료 크레딧은 없습니다(`freeGranted: false`). 새 폰·재설치는 이렇게 계정을 돌려받습니다.
- **없고, 이 installId 가 Google 에 연결 안 된 예전 계정의 것이면 → 그 계정을 이 Google 계정에 연결**(`restored: true`, 잔액 유지, 무료 크레딧 다시 없음). 예전 앱에서 업데이트한 사용자는 따로 연결하지 않아도 됩니다(토큰이 있으면 `POST /ember/link-google` 이 더 확실합니다).
- **둘 다 아니면 → 새 계정**. 무료 크레딧은 **Google 계정당 평생 한 번**입니다: 무료 크레딧을 준 Google 계정은 `HMAC-SHA256(sub, SUB_HASH_SECRET)` 를 `free_credit_grants` 에 남기고(탈퇴해도 남음), 이 기록이 있으면 새 계정은 0(`freeGranted: false`).
  - 같은 기기(installId)에서 **다른** Google 계정으로 로그인하면 그 Google 계정의 새 계정이 만들어지고, 이전 Google 계정의 계정은 installId 만 떼어 냅니다(그 Google 계정으로 다시 로그인하면 그대로 복원).
- 동시에 같은 Google 계정으로 여러 번 가입해도 계정은 하나, 무료 크레딧도 한 번입니다.

**Google 계정 연결**(`POST /ember/link-google`, 예전 앱 버전이 만든 계정용)
- 요청: 헤더 `x-api-key: <기존 토큰>`, 본문 `{"idToken"}`. 응답 `{"linked": true, "credits"}`.
- 이 계정을 그 Google 계정에 연결합니다. 이후 새 기기에서 그 Google 계정으로 가입하면 이 계정이 복원됩니다. 토큰은 바뀌지 않습니다.
- 그 Google 계정이 이미 다른 계정의 것이면 **409 `google_in_use`**(아무것도 바뀌지 않음, 합치기 없음). 이 계정이 이미 다른 Google 계정에 연결돼 있으면 **409 `already_linked`**. 같은 Google 계정으로 다시 부르면 200(멱등).
- 예전 계정이 받았던 무료 크레딧도 그 Google 계정의 "받음" 으로 기록합니다.
- 계정당 시간당 30회(`REREGISTER_LIMIT`). `LEGACY_UNLINKED_UNTIL` 이 지난 뒤에도 쓸 수 있습니다.

**계정 삭제**(`DELETE /ember/account`)
- 헤더 `x-api-key: <토큰>`, 본문 없음. 응답 `{"deleted": true}`. 되돌릴 수 없습니다. 남은 크레딧은 사라집니다(앱에서 미리 경고하세요).
- 지우는 것: 계정(토큰 해시·installId·Google sub·잔액), 요청 기록, 처리 중 표시, 이 계정이 보낸 신고, 계정 단위 요청 제한 카운터.
- 남기는 것: 구매 기록(5년, 계정과 연결을 끊고 영수증 토큰은 해시로), 무료 크레딧 지급 기록(sub 의 HMAC), 탈퇴 시각(통계). 9장 참고.
- 지운 뒤 같은 Google 계정으로 다시 가입할 수 있지만 **새 계정이고 무료 크레딧은 0** 입니다. 탈퇴한 계정의 영수증을 새 계정에서 다시 보내도 지급되지 않습니다.
- 차단된 계정(`disabled`)은 403 이라 앱에서 지울 수 없습니다(운영자에게 요청 → 6장).
- `LEGACY_UNLINKED_UNTIL` 이 지난 뒤에도 연결 안 된 계정이 쓸 수 있습니다.

**예전 방식(`REQUIRE_GOOGLE_SIGNIN = "false"` 일 때만)**: `idToken` 없이 `{"installId"}` 만 보내면 예전처럼 동작합니다.
- 새 installId → 새 계정 + 무료 크레딧(`freeGranted: true`). 줄 무료 크레딧이 0 이면 `freeGranted: false`.
- 이미 있는 installId → 같은 계정에 **새 토큰**을 발급하고 이전 토큰은 무효가 됩니다. 무료 크레딧은 **다시 주지 않습니다**(`freeGranted: false`, `restored: true`).
- Google 에 연결된 계정의 installId 는 `idToken` 없이 쓸 수 없습니다(400 `google_required`). `LEGACY_UNLINKED_UNTIL` 이 지나면 `idToken` 없는 가입은 403 `google_required`.
- `idToken` 을 보내면 Google 로그인으로 처리합니다(앱을 먼저 배포하고 서버 설정을 나중에 바꿀 수 있음).

**예전 계정(Google 에 연결 안 된 계정)**: `LEGACY_UNLINKED_UNTIL` 을 설정하지 않으면 계속 쓸 수 있습니다. 설정한 시각이 지나면 그 계정의 토큰으로 오는 요청은 **403 `google_required`** 이고, `POST /ember/link-google`(연결)과 `DELETE /ember/account`(탈퇴)만 됩니다.

**공통(무료 크레딧·요청 제한)**
- **하루 무료 크레딧 상한**(`FREE_CREDITS_DAILY_CAP`, 기본 20,000 = 40 크레딧 × 500 계정): 그날(UTC) 새 계정에 준 무료 크레딧 합계가 상한에 닿으면 이후 새 계정은 0(`freeGranted: false`) 으로 가입됩니다. 대량 가입 공격의 피해 상한입니다.
- IP 당 요청 제한(429). IP 는 `CF-Connecting-IP` 기준으로 **IPv4 는 주소 전체, IPv6 는 /64** 단위로 셉니다(한 가입자가 /64 안의 주소를 마음대로 바꿀 수 있으므로).
  - 새 계정(무료 크레딧 대상): 시간당 5회(`REGISTER_LIMIT`).
  - 이미 있는 계정의 재로그인(Google 복원, 예전 계정 연결, 예전 방식의 같은 installId 재등록): 따로 시간당 30회(`REREGISTER_LIMIT`). 모바일 CGNAT 처럼 많은 사용자가 한 IP 를 쓰는 경우에도 재로그인이 막히지 않게 하기 위함입니다.
  - ID 토큰 검증이 실패한 요청(401)은 세지 않습니다.
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
  - `grant` 에서 첫 가입 때 `failed`/`missing` 이었던 계정은 나중에 통과해도 무료 크레딧을 받지 못합니다(무료 크레딧은 계정이 처음 만들어질 때만 지급).
  - Google 로그인과 함께 동작합니다: 복원(재로그인)도 `require` 에서는 무결성 통과가 필요하고, 무료 크레딧은 "무결성 통과 + 그 Google 계정이 받은 적 없음 + 하루 상한 안" 일 때만 줍니다.

**구매**
- Google Play Developer API 로 영수증을 확인하고 `purchaseState == 0`(구매 완료)일 때만 지급합니다(대기·취소는 400).
- 확인 뒤 크레딧을 주기 **전에 서버가 직접 `purchases.products.consume`** 을 부릅니다(소비 = 확인 포함, 3일 뒤 자동 환불 방지). 이미 소비된 구매(`consumptionState == 1` 이거나 Google 이 "이미 소비됨" 400)는 성공으로 봅니다. 소비가 실패하면 **502** 이고 지급하지 않습니다(앱이 다시 보내면 됨).
- 같은 `purchaseToken` 은 **절대 두 번 지급되지 않습니다**(DB UNIQUE + 트랜잭션). 재전송하면 `granted: 0` 과 현재 잔액을 돌려주므로 앱이 안전하게 재시도할 수 있습니다.
- **지급 복구**: 서버는 소비(consume) **전에** 이 계정의 "지급 대기" 기록(`credited = 0`)을 남깁니다. 소비 뒤 지급(DB)이 실패해 500 을 받았더라도, **같은 계정이 같은 `purchaseToken` 을 다시 보내면** Google 이 "이미 소비됨" 으로 알려 주고 서버가 대기 기록을 보고 지급합니다(`granted` > 0). 지급은 대기 → 완료 전환으로 한 번만 일어납니다. 다른 계정이 그 영수증을 보내면 `granted: 0`, 상품 ID 가 다르면 400.
  - 앱은 500/502 를 받은 구매를 기억해 두었다가(또는 Play 의 구매 기록·미소비 목록으로) 나중에 다시 보내면 됩니다. Google 로그인 덕분에 재설치 후에도 같은 계정이라 복구됩니다.
- 탈퇴한 계정의 영수증(해시로 보관)은 새 계정이 보내도 지급하지 않고 Google 도 부르지 않습니다(`granted: 0`).
- **앱은 더 이상 직접 소비(consume)하지 않아도 됩니다.** 예전 앱처럼 성공 응답 뒤에 앱이 소비를 시도해도 괜찮고, 그 소비가 "이미 소비됨"으로 실패해도 무시하면 됩니다(실패했다고 복원·재전송을 반복하지 마세요).
- **테스트 구매**(라이선스 테스터, `purchaseType == 0`): 운영(`ALLOW_TEST_PURCHASES` 가 `"true"` 가 아님)에서는 소비만 하고 **크레딧을 주지 않으며**(`granted: 0`, `"testPurchase": true`) 결제 계정으로도 치지 않습니다. 기록은 `purchases.credits = 0, purchase_type = 0` 으로 남습니다.
- **결제 계정**(Opus 사용 가능) = 크레딧을 실제로 지급했고 환불되지 않은 구매가 있고, **환불(일부 환불 포함)된 구매가 하나도 없는** 계정.
- 오류: 모르는 상품·없는 영수증·미완료 구매 → 400, Google 일시 오류·소비 실패 → 502(재시도), 소비 후 DB 지급이 두 번 실패 → 500(로그 `소비 후 지급 실패(수동 지급 필요)`, **같은 계정이 다시 보내면 지급됨**).

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
- 스트리밍(`"stream": true`)은 바이트를 바꾸지 않고 그대로 흘려보내며, 스트림이 끝나면 정산합니다(최종 usage 가 없으면 1장 "끝까지 받지 못한 요청" 규칙: 중지는 입력 + 받은 출력 × 2 추정, 오류는 입력만).
- 서버의 Anthropic 키가 잘못되어 업스트림이 401/403 을 주면, 앱이 "기기 토큰이 틀렸다"고 오해하지 않도록 **500 `api_error`** 로 바꿔서 돌려줍니다.

### 앱 연동

0. **Google 로그인(크레딧 모드 필수)** — 가입 전에 ID 토큰을 받습니다(Android Credential Manager + `googleid` 라이브러리).
   ```kotlin
   // serverClientId = 서버의 GOOGLE_OAUTH_CLIENT_IDS 에 넣은 "웹 애플리케이션" OAuth 클라이언트 ID (Android 클라이언트 ID 아님)
   val option = GetSignInWithGoogleOption.Builder(serverClientId = WEB_CLIENT_ID).build()
   // (자동 선택 UI 를 원하면 GetGoogleIdOption.Builder().setServerClientId(WEB_CLIENT_ID).setFilterByAuthorizedAccounts(false) )
   val result = CredentialManager.create(context).getCredential(context, GetCredentialRequest(listOf(option)))
   val cred = result.credential
   if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
       val idToken = GoogleIdTokenCredential.createFrom(cred.data).idToken   // 이것을 서버로
   }
   ```
   - 같은 Google 계정의 Android OAuth 클라이언트(패키지 이름 + 서명 SHA-1)도 같은 Cloud 프로젝트에 있어야 Credential Manager 가 토큰을 줍니다(4-6).
   - ID 토큰은 약 1시간 유효합니다. 가입 직전에 받고, 401 `invalid_google_token` 이면 새로 받아 다시 보내세요.
   - 사용자에게 이메일을 보여 주고 싶으면 `GoogleIdTokenCredential.id`(이메일) 등을 **앱이 직접** 쓰세요. 서버는 저장하지 않습니다.
   - **앱 시작 시 흐름**: 저장된 기기 토큰이 없으면(새 설치·새 폰) Google 로그인 → `POST /ember/register`. `restored: true` 면 "이전 계정을 불러왔어요" 안내.
   - **예전 버전에서 업데이트한 앱**(토큰은 있는데 Google 연결 여부를 모름): Google 로그인 → `POST /ember/link-google`. 200 이면 연결됨(이미 같은 계정이어도 200), 409 `google_in_use`/`already_linked` 면 안내만 하고 기존 토큰을 계속 씁니다.
   - 어떤 요청이든 403 `google_required` 를 받으면 Google 로그인 → `link-google` 을 안내합니다.
   - **계정 삭제**: 설정 화면에서 경고(남은 크레딧 소멸, 되돌릴 수 없음) 후 `DELETE /ember/account` → `{"deleted":true}` 면 기기 토큰을 지우고 처음 화면으로. Credential Manager 의 `clearCredentialState()` 로 로그인 상태도 지우는 것을 권장합니다.
1. **가입(Play Integrity 를 켤 경우)**
   1. `GET /ember/nonce` → `{"nonce":"..."}`. nonce 는 **24바이트 난수의 base64url(패딩 없음, 32자, `[A-Za-z0-9_-]`)** 입니다.
   2. Play Integrity **classic 요청**에 이 문자열을 **그대로** nonce 로 넣습니다(다시 인코딩하거나 바이트로 바꾸지 않음):
      ```kotlin
      val response = IntegrityManagerFactory.create(context)
          .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).build())
          .await()
      ```
      (클라우드 프로젝트 번호를 `setCloudProjectNumber(...)` 로 넘겨야 할 수 있습니다 — 4-5 참고.)
   3. `POST /ember/register {"installId", "idToken", "integrityToken": response.token(), "nonce": nonce}`.
      - Google 이 토큰 안에 돌려주는 nonce 는 표준 base64(`+`, `/`, `=` 패딩)로 올 수도 있어, 서버는 base64url·무패딩으로 맞춘 뒤 비교합니다. 앱은 신경 쓸 필요 없습니다.
   - 응답은 `token`, `credits`, `freeGranted`, `restored` 이고, `INTEGRITY_MODE` 가 `off` 가 아니면 `"integrity": "ok" | "failed" | "missing"` 이 추가됩니다.
   - 502 를 받으면 1번(새 nonce)부터 다시 시도합니다. Play Integrity 호출 자체가 기기에서 실패하면 토큰 없이 가입을 보내면 됩니다(`grant` 에서는 무료 크레딧 없이 가입, `require` 에서는 403).
   - `INTEGRITY_MODE=off` 인 동안에는 `integrityToken`·`nonce` 를 보내도 무시하므로, 앱을 먼저 배포하고 나중에 서버 설정만 바꿀 수 있습니다.
2. **메시지**: `/v1/messages` 응답 헤더 `ember-model` 이 실제로 쓴 모델입니다. 요청한 모델과 다르면(무료 계정의 Opus → Sonnet) "구매하면 Opus 를 쓸 수 있어요" 같은 안내를 보여 줄 수 있습니다.
   - 잔액이 적으면 서버가 `max_tokens` 를 줄여 보내므로 `stop_reason: "max_tokens"` 로 끝날 수 있습니다. 이 경우 "크레딧이 부족해 답이 잘렸어요" 로 안내하는 것을 권장합니다.
   - 429 중 메시지에 `concurrent` 가 있으면 같은 계정의 요청 2개가 처리 중인 것입니다. 잠시 뒤(`retry-after`) 다시 보내세요(SDK 의 자동 재시도로 충분).
   - 앱이 보내는 베타·필드는 이 서버의 허용 목록과 맞춰 두어야 합니다. 새 베타·최상위 필드를 쓰려면 서버(`src/proxy/validate.ts`)를 먼저 고쳐 배포하세요.
3. **구매**: 서버가 소비까지 하므로 앱의 `consumePurchase` 는 없어도 됩니다(있어도 되고, 실패는 무시). 응답에 `"testPurchase": true` 가 있으면 운영 서버가 테스트 구매에 크레딧을 주지 않은 것입니다. 500/502 를 받은 구매는 같은 `productId`·`purchaseToken` 으로 나중에 다시 보내면 지급됩니다(지급 복구).
4. **환불**: 구글에서 환불된 구매의 크레딧은 다음 날 cron 에서 회수되어 잔액이 음수가 될 수 있습니다. 음수면 `/v1/messages` 는 402 이므로 앱은 기존 "크레딧 부족" 화면을 그대로 쓰면 됩니다. 7일 지난 환불·부분 환불은 앱이 아니라 이메일(주문번호 GPA.…)로 받아 운영자가 처리합니다(6장).
5. **잔액 화면**: `GET /ember/balance` 의 `freeCredits`·`paidCredits` 를 나눠 보여 주고, `expiringSoon` 이 있으면 만료 안내를 띄웁니다. 예전 앱은 `credits` 만 읽어도 됩니다.
6. **신고**: 크레딧 계정이 있으면 `POST /ember/report`(AI 응답을 한 번이라도 받은 계정만, 아니면 403), 없으면(내 API 키·체험 모드) `POST /ember/report/anon`(인증 헤더 없이). 429 면 잠시 뒤 다시.
7. **중지 버튼**: 스트리밍 중 연결을 끊으면 서버가 입력 + 받은 출력(× 2) 만큼만 청구하고 나머지 예약액을 돌려줍니다. 끊은 뒤 `GET /ember/balance` 로 잔액을 다시 읽으세요(정산은 끊은 직후 끝납니다).

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

> **배포 전에 4-6(Google 로그인 OAuth 클라이언트)을 끝내고 `wrangler.toml` 의 `GOOGLE_OAUTH_CLIENT_IDS` 를 채우세요.** 비어 있으면 가입이 모두 500 입니다.

> **배포 전에 4-5(Play Integrity)를 끝내세요.** `wrangler.toml` 의 기본값이 `INTEGRITY_MODE = "grant"` 라서, 서비스 계정·Play Integrity 설정이 없으면 새 계정은 무료 크레딧 0 으로 가입됩니다.

### 3-4. 비밀값 넣기
비밀값은 파일에 쓰지 말고 아래 명령으로만 넣습니다(입력하라는 프롬프트에 값을 붙여 넣기).
```bash
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ADMIN_KEY            # 관리자용 긴 무작위 문자열(예: 비밀번호 생성기로 40자)
npx wrangler secret put SUB_HASH_SECRET      # Google 계정 무료 크레딧 기록용 긴 무작위 문자열(40자 이상). 한 번 정하면 바꾸지 않기
```
> `SUB_HASH_SECRET` 은 잃어버리거나 바꾸면 "이 Google 계정은 무료 크레딧을 이미 받음" 기록이 맞지 않게 되어, 탈퇴한 사용자가 무료 크레딧을 다시 받을 수 있습니다. 비밀번호 관리자에 보관하세요. 무작위 값 만들기 예: `openssl rand -base64 48`
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
# → Google 로그인 필수(기본)이므로 400 {"type":"error","error":{"type":"google_required",...}}
#   (진짜 가입은 앱에서 Google 로그인으로 받은 idToken 이 있어야 합니다.)
#   서버에 GOOGLE_OAUTH_CLIENT_IDS 가 비어 있으면 idToken 을 보냈을 때 500 "Google sign-in is not configured".

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

### 4-6. Google 로그인(OAuth 클라이언트) 설정 (배포 전 필수)
크레딧 모드는 Sign in with Google 이 필수입니다. 서버는 Google ID 토큰의 `aud` 가 **웹 애플리케이션 OAuth 클라이언트 ID** 인지 확인합니다.

1. <https://console.cloud.google.com> → 4-2 의 프로젝트(`ember-play`) 선택 → **API 및 서비스 → OAuth 동의 화면**: 앱 이름·지원 이메일·개인정보처리방침 URL 을 넣고 **게시(프로덕션)** 합니다. 범위는 기본(`openid`, `email`, `profile`)만 씁니다(민감 범위 없음 → 검수 불필요).
2. **사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID → 웹 애플리케이션**: 이름 예 `ember-server`. 리디렉션 URI 는 필요 없습니다. 만들어진 **클라이언트 ID**(`xxxx.apps.googleusercontent.com`)를 `wrangler.toml` 의 `GOOGLE_OAUTH_CLIENT_IDS` 에 넣습니다(비밀값 아님). 앱의 `serverClientId` 에도 같은 값을 씁니다.
3. 같은 화면에서 **OAuth 클라이언트 ID → Android** 도 만듭니다: 패키지 이름 `app.ember.ideas` + 서명 인증서 SHA-1. **Play 앱 서명 키의 SHA-1**(Play Console → 앱 무결성 → 앱 서명)과 업로드/디버그 키의 SHA-1 을 각각 등록해야 출시 빌드·개발 빌드 모두 로그인이 됩니다. 이 Android 클라이언트 ID 는 서버에 넣지 않습니다.
4. 클라이언트 ID 를 바꾸거나 둘 이상 허용하려면 쉼표로 나열합니다: `GOOGLE_OAUTH_CLIENT_IDS = "id1.apps.googleusercontent.com,id2.apps.googleusercontent.com"`.
5. `npx wrangler secret put SUB_HASH_SECRET` 을 했는지 확인합니다(3-4).
6. 검증 내용(서버): Google 공개키(<https://www.googleapis.com/oauth2/v3/certs>, `Cache-Control: max-age` 동안 캐시, 모르는 `kid` 면 최소 1분 간격으로 다시 받음, 받기 실패 시 이전 키 사용)로 **RS256 서명**, `iss` = `accounts.google.com` 또는 `https://accounts.google.com`, `aud` ∈ `GOOGLE_OAUTH_CLIENT_IDS`, `exp`/`iat`(시계 오차 60초), `email` 이 있으면 `email_verified == true`. 외부 라이브러리 없이 WebCrypto 로 합니다.

---

## 5. 환경 변수

`wrangler.toml` 의 `[vars]` 는 공개 설정, 비밀값은 `wrangler secret put` 으로 넣습니다.

| 이름 | 종류 | 기본값 | 설명 |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | 비밀 | – | Anthropic API 키(필수) |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | 비밀 | – | 서비스 계정 JSON 전체(구매·환불 회수·Play Integrity 에 필수). 없으면 환불 회수는 건너뜀 |
| `ADMIN_KEY` | 비밀 | – | 관리자 API 키. 없으면 관리자 API 전부 401 |
| `SUB_HASH_SECRET` | 비밀 | – | Google sub 의 HMAC-SHA256 키(무료 크레딧 1회 기록). **필수**(없으면 Google 로그인 500). 바꾸지 말 것 |
| `GOOGLE_OAUTH_CLIENT_IDS` | 변수 | 비어 있음 | ID 토큰 `aud` 로 허용할 **웹** OAuth 클라이언트 ID(쉼표 구분). **필수**(비면 Google 로그인 500) |
| `REQUIRE_GOOGLE_SIGNIN` | 변수 | 필수(`"false"` 가 아니면 모두 필수) | `"false"` 면 `idToken` 없는 예전 방식 가입도 받음 |
| `LEGACY_UNLINKED_UNTIL` | 변수 | 비어 있음(제한 없음) | ISO 날짜/시각(예 `2027-07-01`, 날짜만이면 00:00 UTC). 이 시각부터 Google 에 연결 안 된 계정은 403 `google_required`(연결·탈퇴만 허용). 형식이 틀리면 무시(로그) |
| `PACKAGE_NAME` | 변수 | `app.ember.ideas` | 앱 패키지 이름 |
| `FREE_CREDITS` | 변수 | `40` | 신규 설치 무료 크레딧(결제 전에는 Opus 요청이 Sonnet 으로 처리됨) |
| `FREE_CREDITS_DAILY_CAP` | 변수 | `20000` | 하루(UTC) 새 계정 무료 크레딧 합계 상한. 넘으면 새 계정은 0 |
| `INTEGRITY_MODE` | 변수 | `grant`(wrangler.toml) / 코드 기본 `off` | 가입 시 Play Integrity: `off` / `grant`(통과해야 무료 크레딧) / `require`(통과해야 가입). 모르는 값이면 `off`. 서비스 계정이 없으면 무료 크레딧 0 |
| `ALLOW_TEST_PURCHASES` | 변수 | `false` | `true` 면 라이선스 테스트 구매에도 크레딧 지급(테스트용 워커에서만) |
| `MARKUP` | 변수 | `1.5` | 원가 대비 배수(1 이상) |
| `MAX_OUTPUT_TOKENS` | 변수 | `64000` | `max_tokens` 상한 |
| `MAX_BODY_BYTES` | 변수 | `2097152` | 요청 본문 최대 크기(2 MB) |
| `PRODUCTS` | 변수 | `{"ember_credits_500":500,"ember_credits_1500":1650,"ember_credits_5000":5750}` | 상품 ID → 크레딧(JSON). 형식이 틀리면 기본값 사용 |
| `PRODUCT_PRICES_KRW` | 변수 | 비어 있음 | 상품 ID → **1개 가격(원)** JSON(예 `{"ember_credits_500":5900}`). Play 확인 응답에 결제 금액이 없으면(보통 없음) 구매 기록에 `가격 × 수량` 을 남기고, 금액이 기록되지 않은 구매의 환불 견적에도 씀. Play Console 의 실제 판매가와 같게 유지. 형식이 틀리면 무시(로그) |
| `REGISTER_LIMIT` / `REGISTER_WINDOW_SECONDS` | 변수 | `5` / `3600` | IP(IPv4 주소 / IPv6 /64)당 새 가입 제한. 창은 **하루 이하**로(IP 카운터를 2일 안에 지우기 위해) |
| `REREGISTER_LIMIT` | 변수 | `30` | IP 당 재등록(토큰 재발급)·`/ember/nonce` 제한(창은 `REGISTER_WINDOW_SECONDS`) |
| `MESSAGES_LIMIT` / `MESSAGES_WINDOW_SECONDS` | 변수 | `30` / `600` | 토큰 당 `/v1/messages` 제한 |
| `MAX_CONCURRENT_REQUESTS` | 변수 | `2` | 계정당 동시 처리 중인 `/v1/messages` 수 |
| `INFLIGHT_STALE_SECONDS` | 변수 | `1800` | 이보다 오래된 처리 중 표시는 죽은 요청으로 보고 무시(최소 60) |
| `REPORTS_DAILY_CAP` | 변수 | `500` | 하루(UTC) 전체 신고 수 상한 |
| `ANTHROPIC_BASE_URL` | 변수 | `https://api.anthropic.com` | 업스트림 주소(테스트용으로만 변경) |

---

## 6. 운영

- **통계**: `GET /ember/admin/stats` (헤더 `x-admin-key`). Google 관련 항목:
  - `accounts`: 계정 수(탈퇴 계정의 구매가 옮겨 간 묘비 계정 제외, 만료 계정 포함), `googleLinkedAccounts`: Google 에 연결된 계정 수
  - `deletedAccounts`: `{"total", "last30d"}` 탈퇴 수
  - `pendingPurchases`: 지급 대기 구매(소비 후 지급 실패 등). 오래 남아 있으면 아래 "지급 대기 구매" 참고
  - `paidCreditsOutstanding`: 만료 안 된 유료 크레딧 합계(`creditsOutstanding` 중 유료), `paidCreditsExpired`: 유효기간이 지나 사라진 유료 크레딧, `adminRefunds`: 운영자 환불 `{"purchases","credits"}`
- **지급 대기 구매**: 같은 계정이 다시 보내면 자동 지급됩니다. 사용자가 다시 보내지 않으면 운영자가 수동 지급할 수 있습니다:
  ```bash
  npx wrangler d1 execute ember --remote --command "SELECT id, account_id, product_id, order_id, credits, datetime(created_at,'unixepoch') FROM purchases WHERE credited = 0"
  # Play Console 에서 주문(order_id)이 결제 완료·환불 안 됨인지 확인한 뒤:
  npx wrangler d1 execute ember --remote --command "UPDATE accounts SET credits = credits + 500 WHERE id = 42; UPDATE purchases SET credited = 1, remaining = credits, expires_at = CAST(strftime('%s', created_at, 'unixepoch', '+5 years') AS INTEGER) WHERE id = 7 AND credited = 0"
  ```
  (`remaining`·`expires_at` 을 함께 넣어야 유료 크레딧 묶음이 됩니다. 빼면 그 500 은 무료 크레딧으로 잡힙니다.)
- **계정 삭제 요청(앱 밖, 예: 이메일·차단된 계정)**: 계정 id 를 확인한 뒤(예: 사용자가 알려 준 주문번호로 `SELECT account_id FROM purchases WHERE order_id = 'GPA....'`) 아래를 **한 번에** 실행합니다. 앱의 삭제와 같지만, SQL 로는 SHA-256 을 계산할 수 없어 구매의 `purchase_token` 은 원문 그대로 묘비 계정으로 옮깁니다(같은 영수증 재지급 방지는 그대로 됨). 차단을 잠시 풀어(`disabled = 0`) 사용자가 앱에서 지우게 하면 토큰까지 해시됩니다.
  ```bash
  npx wrangler d1 execute ember --remote --command "UPDATE purchases SET lot_closed_at = unixepoch(), lot_closed_reason = 'deleted', lot_closed_credits = remaining, remaining = 0 WHERE account_id = 42 AND expires_at IS NOT NULL AND lot_closed_at IS NULL; UPDATE free_credit_grants SET account_id = NULL, gone_at = unixepoch() WHERE account_id = 42; INSERT INTO accounts (install_id, token_hash, credits, free_credits, disabled, created_at, updated_at) VALUES ('deleted:tombstone', 'deleted:tombstone', 0, 0, 1, unixepoch(), unixepoch()) ON CONFLICT (install_id) DO NOTHING; UPDATE purchases SET account_id = (SELECT id FROM accounts WHERE install_id = 'deleted:tombstone') WHERE account_id = 42; DELETE FROM usage_log WHERE account_id = 42; DELETE FROM inflight WHERE account_id = 42; DELETE FROM reports WHERE account_id = 42; DELETE FROM rate_limits WHERE key IN ('msg:42','rep:42','link:42'); DELETE FROM accounts WHERE id = 42; INSERT INTO account_deletions (deleted_at) VALUES (unixepoch())"
  ```
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
- **처리 중 표시(`inflight`)**: 요청이 끝나면 지워집니다. 워커가 중간에 죽어 남은 행은 `INFLIGHT_STALE_SECONDS`(30분) 뒤 무시되고 cron 이 로그(`정산되지 않은 요청 정리`)를 남기고 지웁니다. 이 경우 예약액은 그대로 청구된 상태입니다(필요하면 아래 "크레딧 수동 지급" 으로 돌려줌).
- **크레딧 수동 지급(보상)**: 아래처럼 잔액만 올리면 **무료 크레딧**으로 잡힙니다(유효기간 없음, 1년 미사용 시 계정과 함께 소멸, 환불 대상 아님).
  ```bash
  npx wrangler d1 execute ember --remote --command "UPDATE accounts SET credits = credits + 500 WHERE id = 42"
  ```

### 환불·청약철회 처리(운영자)
이용약관 7장: 구매 후 **7일 이내**면 그 구매의 남은 유료 크레딧 비율만큼 **수수료 없이**(쓰지 않았으면 전액 = 청약철회), **7일이 지나면** 같은 금액에서 **10% 를 빼고** 환불합니다. 금액 = `결제 금액 × (그 구매의 남은 유료 크레딧 ÷ 그 구매로 받은 크레딧)`(내림). 무료 크레딧은 환불하지 않습니다. 회사는 요청을 받은 날부터 3영업일 안에 처리합니다.

- 사용자가 **구매 후 48시간 안에 Google Play 에서** 환불을 요청해 Google 이 환불하면 이 절차는 필요 없습니다(다음 날 cron 이 회수: 그 구매의 묶음 먼저, 모자라면 나머지 잔액, 음수 가능).
- 그 밖의 요청(이메일로 주문번호 `GPA.…`)은 아래 순서로 처리합니다.
  1. **견적**(아무것도 바꾸지 않음):
     ```bash
     curl -s "https://<워커 주소>/ember/admin/refund-quote?orderId=GPA.1234-5678-9012-34567" -H "x-admin-key: $ADMIN_KEY"
     ```
     응답 예:
     ```json
     {"orderId":"GPA.1234-5678-9012-34567","productId":"ember_credits_500","quantity":1,
      "purchasedAt":1762500000,"expiresAt":1920266400,"daysSincePurchase":2,
      "lot":{"state":"open","credits":500,"remaining":300,"closedAt":null,"closedCredits":0},
      "price":{"amountMicros":5900000000,"amount":5900,"currency":"KRW","source":"purchase"},
      "withinWithdrawalPeriod":true,"feeRate":0,"ratio":0.6,
      "refundable":{"amountMicros":3540000000,"amount":3540,"currency":"KRW"},
      "refundableNow":true,"refunded":null}
     ```
     - `lot.state`: `open`(환불 가능) / `expired`(유효기간 지남) / `refunded`(이미 운영자 환불) / `voided`(Google 환불) / `deleted`(탈퇴, 약관 12장: 삭제 전에 요청해야 함) / `account_expired` / `pending`(지급 전) / `no_credits`(크레딧 0 인 테스트 구매).
     - `price.source`: `purchase`(구매 때 기록한 금액) / `config`(`PRODUCT_PRICES_KRW`) / `override`(요청의 `paid`). 금액을 모르면 `price`·`refundable` 이 `null` 이고 `refundableNow: false` 입니다. 그때는 Play Console 주문 화면의 결제 금액을 `&paid=5900&currency=KRW` 로 넘깁니다.
     - 서비스 종료(약관 11장)처럼 수수료 없이 돌려줄 때는 `&waiveFee=1`.
     - Google 이 수량 일부를 이미 환불한 구매는 남은 수량 기준으로 크레딧·금액을 계산합니다.
  2. **크레딧 없애기·기록**(견적과 같은 계산, 같은 옵션):
     ```bash
     curl -s -X POST "https://<워커 주소>/ember/admin/refund" -H "x-admin-key: $ADMIN_KEY" \
       -H "content-type: application/json" -d '{"orderId":"GPA.1234-5678-9012-34567"}'
     ```
     그 구매의 남은 유료 크레딧을 0 으로 만들고(잔액에서 빼고, 묶음 `refunded` 로 닫음) `refunded_at`·`refund_micros`·`refund_credits` 를 기록합니다. 그 사이 사용자가 크레딧을 써서 묶음이 바뀌었으면 **409**(다시 견적), 이미 환불했거나 환불할 크레딧이 없으면 **409**, 모르는 주문은 404.
  3. **돈 돌려주기**: Play Console → 주문 관리 → 그 주문 → **환불** 에서 응답의 `amount`(통화 `currency`)만큼 **부분 환불**합니다(전액이면 전체 환불). 소비형 상품이므로 "권한 취소(revoke)" 는 의미가 없습니다.
  - Google 이 이 환불을 Voided Purchases 로 알려 줘도 cron 은 **크레딧을 다시 빼지 않습니다**(이미 2번에서 없앰, 이벤트만 기록).
  - 순서를 지키세요: 2번(크레딧 없애기) 전에 3번(돈)을 하면, 그 사이 사용자가 크레딧을 쓸 수 있고 cron 이 구매 전체를 회수해 잔액이 음수가 될 수 있습니다.
  - 미성년자 취소처럼 결제 전액을 돌려줘야 하면 2번을 한 뒤 Play Console 에서 **전체 금액**을 환불합니다(이미 쓴 크레딧은 회수할 수 없으므로 서버 쪽은 2번으로 충분).
  - 기록 조회: `SELECT order_id, refund_credits, refund_micros, price_currency, datetime(refunded_at,'unixepoch') FROM purchases WHERE refunded_at IS NOT NULL`.
- 매일 03:17(UTC) cron 이 하는 일(하나가 실패해도 나머지는 계속하고, 마지막에 실패로 기록):
  1. 요청 제한 카운터(창 시작 1일 지난 것 → IP 는 2일 안에 삭제)·만료된 nonce·오래된 처리 중 표시 삭제
  2. **무료 크레딧 기록 연결**(0005 이전 기록이 있을 때만): `SUB_HASH_SECRET` 으로 지금 계정의 Google sub 의 HMAC 을 계산해 `free_credit_grants.account_id` 를 채우고, 맞는 계정이 없으면 그날을 `gone_at`(계정 없어진 시각)으로 둡니다. 배포 후 첫 실행에서 끝나고 그 뒤로는 할 일이 없습니다.
  3. **보관 기간 정리**(`src/retention.ts`, 9장 표와 같음):
     - 유효기간(구매 + 5년) 지난 유료 묶음을 닫고 잔액에서 뺌.
     - 1년 지난 `usage_log`·`reports`(익명 포함) 삭제.
     - 구매 + 5년 지난 구매·환불 기록(`purchases`·`voided_events`)은 **계정 상태와 관계없이** 삭제(닫힌 묶음만).
     - **마지막 사용(`last_used_at`) 후 1년** 지났고 **만료 안 된 유료 크레딧이 없는** 계정을 만료: 남은 무료 크레딧·빚은 사라짐. 구매 기록이 없으면 계정 행 삭제, 있으면 토큰·installId·Google 연결·잔액을 지운 자리 표시(`expired-<id>`)만 남기고 구매 기록이 지워진 뒤 삭제. **유료 크레딧이 남은 계정은 묶음이 만료될 때까지(= 마지막 구매 + 5년) 남습니다.** 마지막 사용은 가입·로그인·잔액 확인·요청·구매·신고 등 인증된 모든 호출(1시간 단위로 기록).
     - `free_credit_grants`: 그 기록의 계정이 삭제·만료된 때(`gone_at`)부터 **3년** 지나면 삭제. 계정이 있는 동안은 남습니다. 탈퇴 뒤 같은 Google 계정으로 다시 가입하면 기록이 새 계정에 다시 묶입니다(3년은 새 계정이 없어진 때부터).
     - `account_deletions` 는 지우지 않습니다(식별 정보 없음).
  4. **환불 회수**: Voided Purchases API(`type=0` 일회성 상품, `includeQuantityBasedPartialRefund=true`, 1000개씩 페이지 넘김)로 환불·취소 목록을 받아, 지급한 구매면 환불된 수량만큼 잔액에서 빼고(그 구매의 유료 묶음 먼저, 모자라면 나머지 잔액. **음수 가능 → 402 로 사용 차단**) `purchases.voided = 1, voided_quantity, voided_at = 환불 시각` 으로 표시합니다. 운영자가 이미 `POST /ember/admin/refund` 로 처리한 구매는 크레딧을 다시 빼지 않습니다.
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

**이번 버전(0005: 유료/무료 크레딧 분리·환불 계산·익명 신고·보관 기간)** — 0004 까지 적용된 DB, **새 코드를 배포하기 직전에**:
```bash
npx wrangler d1 execute ember --remote --file=./migrations/0005_credit_lots_retention.sql
```
내용:
- `accounts.last_used_at`(마지막 사용, 기존 `updated_at` 으로 채움).
- `purchases` 에 유료 묶음(`remaining`, `expires_at`, `lot_closed_at`, `lot_closed_reason`, `lot_closed_credits`), 결제 금액(`price_micros`, `price_currency`), 운영자 환불(`refunded_at`, `refund_micros`, `refund_credits`) 컬럼과 `idx_purchases_order`·`idx_purchases_expires` 인덱스.
- `free_credit_grants.account_id`·`gone_at`(+ 인덱스). 기존 기록은 배포 후 첫 cron 이 계정과 연결합니다(6장 cron 2번, `SUB_HASH_SECRET` 필요).
- `reports` 를 다시 만들어 `account_id` 를 NULL 허용으로(익명 신고). 기존 행·번호는 그대로.
- **기존 잔액 나누기**: 지급 완료 구매마다 묶음(만료 = 구매 + 5년)을 만들고, 유료 = min(잔액, 환불 안 된 지급 구매 크레딧 합계)를 최신 구매부터 채웁니다. 나머지 잔액은 무료. 환불(일부 포함)된 구매와 탈퇴·만료 계정의 구매는 닫힌 묶음(남은 양 0). 기존 구매에는 결제 금액이 없으므로, 환불 견적은 `PRODUCT_PRICES_KRW`(또는 `paid` 지정)를 씁니다.
- SQLite 3.35 이상 기능(`UPDATE … FROM`, `WITH … MATERIALIZED`, 창 함수)을 씁니다. D1 은 해당합니다.

배포 순서: ① 0005 실행 → ② `wrangler.toml` 의 `PRODUCT_PRICES_KRW` 를 Play Console 판매가로 채우기 → ③ `npx wrangler deploy`. 0005 를 실행했는데 예전 코드가 도는 짧은 사이에는 새 구매가 묶음 없이(= 무료로) 잡힐 수 있으므로 ①과 ③ 사이를 짧게 두세요. 그 사이 구매가 있었다면 배포 뒤 아래로 묶음을 열어 줍니다(그 구매만큼 유료로 옮김):
```bash
npx wrangler d1 execute ember --remote --command "UPDATE purchases SET remaining = credits, expires_at = CAST(strftime('%s', created_at, 'unixepoch', '+5 years') AS INTEGER) WHERE credited = 1 AND credits > 0 AND expires_at IS NULL AND voided = 0"
```
새 앱은 `GET /ember/balance` 의 새 필드와 `POST /ember/report/anon` 을 쓰고, 예전 앱은 그대로 동작합니다(`credits` 유지).

**이전 버전(0004: Google 로그인·계정 삭제·지급 복구)** — 0003 까지 적용된 DB, **새 코드를 배포하기 전에**:
```bash
npx wrangler d1 execute ember --remote --file=./migrations/0004_google_signin.sql
```
내용: `accounts.google_sub` 컬럼 + 유일 인덱스 `idx_accounts_google_sub`, `free_credit_grants`·`account_deletions` 표 생성. 기존 계정은 모두 "연결 안 된 예전 계정"(`google_sub = NULL`)으로 남습니다.
배포 순서: ① 0004 실행 → ② `wrangler.toml` 의 `GOOGLE_OAUTH_CLIENT_IDS` 채우기, `wrangler secret put SUB_HASH_SECRET` → ③ `npx wrangler deploy` → ④ Google 로그인을 넣은 앱 출시. **기본값(`REQUIRE_GOOGLE_SIGNIN` 필수)이면 ③ 직후부터 예전 앱의 새 가입은 400 `google_required`** 입니다(이미 토큰이 있는 예전 앱은 계속 동작). 새 앱이 퍼질 때까지 새 가입을 받으려면 ③ 전에 `REQUIRE_GOOGLE_SIGNIN = "false"` 로 두었다가 나중에 되돌리세요.

**이전 버전(0003: 예약 과금·동시 요청 제한·일부 환불)** — 0002 까지 적용된 DB:
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

1. **무료 크레딧 반복 수령**: Google 로그인이 필수(기본)이므로 무료 크레딧은 **Google 계정당 평생 한 번**입니다(재설치·탈퇴 후 재가입도 0). 다만 Google 계정을 여러 개 만들면 계정마다 받을 수 있으므로 아래 장치를 함께 씁니다. (`REQUIRE_GOOGLE_SIGNIN=false` 로 두면 예전처럼 installId 단위입니다: 앱을 지웠다 다시 깔면 installId 가 바뀌어 또 받을 수 있습니다.)
   - **IP(IPv4 주소 / IPv6 /64)당 시간당 5회 새 가입 제한**으로 속도를 늦추고(모바일 데이터·VPN 으로 우회 가능), 무료 크레딧은 40 으로 작고 Sonnet 으로만 쓰입니다. 재로그인(이미 있는 installId)은 따로 느슨하게 셉니다.
   - **하루 무료 크레딧 상한**(`FREE_CREDITS_DAILY_CAP`, 기본 20,000 크레딧 ≈ 원가 $133)으로 하루 피해에 상한이 있습니다. 상한에 닿으면 그날 정상 신규 사용자도 무료 크레딧을 못 받으니, `admin/stats` 의 `creditsGranted.free` 를 보며 조정하세요.
   - `INTEGRITY_MODE=grant`(기본)/`require` 의 **Play Integrity** 로 진짜 Play 설치 앱 + 정상 기기에서만 무료 크레딧을 줍니다(4-5). 다만 정상 기기에서 앱을 지웠다 다시 까는 반복은 여전히 막지 못합니다(기기 단위로 묶으려면 기기 식별이 필요하지만, 개인정보 문제로 하지 않음). 피해가 커지면 `FREE_CREDITS` 를 줄이거나 0 으로 바꿀 수 있습니다.
2. **Google 에 연결된 계정은 installId 로 토큰을 받을 수 없습니다**(그 Google 계정의 유효한 ID 토큰이 있어야 함). **연결 안 된 예전 계정은 installId 가 사실상 비밀번호**입니다: installId 를 아는 사람은 재등록으로 새 토큰을 받거나, 자기 Google 계정으로 가입하면서 그 계정을 자기 Google 계정에 연결할 수 있습니다. 앱은 installId 를 외부에 노출하지 마세요. 예전 계정을 없애려면 새 앱 보급 후 `LEGACY_UNLINKED_UNTIL` 을 설정하세요.
   - 같은 기기(installId)에서 Google 계정을 바꿔 로그인하면 새 계정이 생깁니다(무료 크레딧은 그 Google 계정이 처음일 때만). 이전 계정은 그 Google 계정으로 다시 로그인하면 돌아옵니다.
3. **환불 후 사용**: 매일 cron 이 **Voided Purchases API** 로 환불된 구매의 크레딧을 회수합니다(잔액 음수 → 402, 수량 일부 환불은 비율만큼). 다만 환불 직후부터 다음 cron 까지(최대 약 하루)는 남은 크레딧을 쓸 수 있고, 이미 써 버린 만큼은 음수 잔액으로만 남습니다(다음 구매에서 메워짐).
4. **중단 시 과금**(이용약관 5장): 앱이 중지하면 입력 + 받은 출력 문자 ÷ 3 × 2 토큰, 업스트림·서버 오류면 입력만 청구합니다(1장). 추정이므로 실제 원가와 다를 수 있습니다: 화면에 보이지 않는 사고(`display: "omitted"`)가 길거나 웹 검색 도중에 끊으면 원가보다 적게 받고(검색 비용은 청구하지 않음), 반대로 짧은 사고면 더 받습니다. 사용자가 일부러 "사고·검색만 시키고 끊기" 를 반복하면 원가를 다 받지 못하므로, `usage_log.estimated = 1` 비율을 SQL 로 지켜보세요. `message_start` 를 받기 전에 끊으면 0 입니다.
5. **예약 추정의 한계**: 입력 토큰은 본문 크기로, 웹 검색 결과는 1회 8,000 토큰으로 추정합니다. 실제가 더 크면 정산 때 차이를 더 빼므로 잔액이 조금 음수가 될 수 있습니다(그 뒤 402). 서버측 거절 대체(`fallbacks`)가 두 모델의 출력을 합쳐 청구하는 경우도 같은 방식으로 처리됩니다.
6. **요청 제한은 D1 고정 창 방식**이라 창 경계에서 잠깐 두 배까지 허용될 수 있습니다. 엄격한 제한이 필요하면 Durable Objects 로 바꾸세요. 동시 요청 제한(계정당 2개)과 하루 상한은 한 SQL 문으로 처리해 정확합니다.
7. 도구는 `web_search_*` 만 허용하고, 도구마다 `max_uses` 를 5 이하로 강제합니다. 웹 검색은 1회당 $0.01 이 추가됩니다.
8. **신고 남용**: `POST /ember/report` 는 AI 응답 기록이 있는 계정만, 계정당·IP(/64)당 시간당 30회. 인증 없는 `POST /ember/report/anon` 은 IP(/64)당 시간당 10회. 하루 전체 `REPORTS_DAILY_CAP`(500)회는 둘을 합쳐 세므로, 익명 신고로 상한을 채우면 그날 로그인 신고도 막힙니다(피해 상한은 하루 500행 × 최대 약 22 KB).

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
  account.ts          /ember/register(Google 로그인·복원·예전 계정 연결, 예전 방식), /ember/balance
  account-link.ts     /ember/link-google (예전 계정 → Google 계정 연결)
  account-delete.ts   DELETE /ember/account (계정 삭제, 구매 기록 비식별 보관)
  google/id-token.ts  Google ID 토큰 검증(JWKS 캐시, RS256, iss/aud/exp/iat/email_verified)
  google/identity.ts  Google 로그인 설정 확인·sub HMAC·무료 크레딧 기록
  models.ts           허용 모델, /v1/models/:id
  purchase.ts         /ember/purchase (지급 대기 기록 → 서버 소비 → 멱등 지급, 지급 복구, 테스트 구매 처리)
  retention.ts        보관 기간 지난 기록·계정 정리, 0005 이전 무료 크레딧 기록 연결(cron)
  refund.ts           환불 계산(7일 이내 무수수료 / 이후 10%), /ember/admin/refund-quote, /ember/admin/refund
  play/google-auth.ts 서비스 계정 RS256 JWT → OAuth 토큰(범위별 캐시), googleFetch(401 재시도)
  play/verify.ts      Play Developer API 영수증 확인·소비(consume), Google 오류 종류만 뽑기(로그용)
  play/voided.ts      Voided Purchases API → 환불 크레딧 회수(일부 환불 포함, cron)
  play/integrity.ts   /ember/nonce, Play Integrity 토큰 해독·판정
  proxy/validate.ts   최상위 필드·모델·도구·max_tokens 검증, anthropic-version/beta 허용 목록
  proxy/reserve.ts    최악 비용 예약(max_tokens 줄이기), 계정당 동시 요청 칸(inflight)
  proxy/sse.ts        SSE usage 증분 파서
  proxy/messages.ts   /v1/messages 프록시(비스트리밍·스트리밍), 무료 계정 Opus→Sonnet, ember-model 헤더
  billing/usage.ts    usage 정규화
  billing/pricing.ts  단가표·크레딧 계산·예약 계산
  billing/ledger.ts   정산(예약 − 실제 환불, 유료 묶음으로 되돌림) + usage_log, 실패 시 재시도·계정 차단
  billing/lots.ts     유료 크레딧 묶음: 쓰는 순서(오래된 것부터 깎기), 되돌리기, 5년 만료, 잔액 내역
  billing/interrupted.ts 끝까지 받지 못한 요청의 과금(중지: 입력 + 출력 추정 ×2, 오류: 입력만)
  reports.ts          /ember/report, /ember/report/anon(익명)
  admin.ts            관리자 API
test/                 vitest 테스트(가짜 D1 = node:sqlite, 가짜 fetch, 가짜 Google = test/helpers/google.ts,
                      가짜 Google ID 토큰·JWKS = test/helpers/google-id.ts)
schema.sql            D1 스키마(새 DB 용)
migrations/           이미 운영 중인 DB 용 변경 SQL
```

---

## 9. 개인정보·데이터 목록 (개인정보처리방침용)

서버(Cloudflare D1)에 저장하는 모든 항목입니다. **이메일·이름·전화번호·광고 ID·기기 식별자는 저장하지 않습니다.** 대화 내용(프롬프트·AI 응답)은 Anthropic 으로 전달만 하고 저장하지 않습니다(사용자가 신고할 때 보낸 내용만 `reports` 에 저장). 보관 정리는 매일 cron(`src/retention.ts`)이 합니다.

| 표 | 항목(컬럼) | 왜 | 보관 기간 |
|---|---|---|---|
| `accounts` | `id` | 내부 계정 번호(다른 표와 연결) | 탈퇴 시 즉시 삭제. **무료 크레딧만 있는 계정은 마지막 사용 후 1년**, **유료 크레딧이 남은 계정은 유료가 모두 만료될 때까지(= 마지막 구매 + 5년)**, 그 뒤 1년 미사용이면 자동 삭제(구매 기록이 남아 있으면 아래 값을 지운 자리 표시 행만 구매 기록이 지워질 때까지 남음) |
| | `google_sub` | Google 계정 고유 ID(ID 토큰의 `sub`). 재설치·기기 변경 시 같은 계정 복원 | 〃(만료 시 NULL 로 지움) |
| | `install_id` | 앱 설치마다 앱이 만든 무작위 ID. 예전 계정 식별·Google 계정 전환 처리 | 〃(만료 시 `expired-<id>`) |
| | `token_hash` | 기기 토큰의 SHA-256(원문 저장 안 함). 요청 인증 | 〃 |
| | `credits`, `free_credits` | 잔액(무료 + 유료), 가입 때 받은 무료 크레딧(통계) | 〃(만료 시 0) |
| | `disabled` | 차단 여부(남용·정산 실패) | 〃 |
| | `created_at`, `updated_at`, `last_used_at` | 가입·마지막 변경·**마지막 사용**(가입·로그인·잔액 확인·요청 등, 1년 미사용 판단) | 〃 |
| `purchases` | `purchase_token` | Google Play 영수증 토큰. 영수증 확인·중복 지급 방지·환불 회수 | 결제일로부터 **5년**(전자상거래법: 대금결제 및 재화 공급 기록), 계정 상태(탈퇴·만료)와 관계없이 5년 뒤 삭제. 탈퇴 시 `sha256:<해시>` 로 바꿈 |
| | `account_id` | 구매한 계정 | 탈퇴 시 공용 묘비 계정(`deleted:tombstone`)으로 바꿔 계정과의 연결을 끊음 |
| | `product_id`, `order_id`, `quantity`, `credits`, `purchase_type` | 상품·주문번호(GPA.…)·수량·지급 크레딧·테스트 구매 여부. 법정 거래 기록·환불 문의 대응 | 5년(탈퇴해도 유지) |
| | `credited`, `created_at`, `voided`, `voided_at`, `voided_quantity` | 지급 상태·결제 시각·환불 여부/시각/수량 | 5년 |
| | `remaining`, `expires_at`, `lot_closed_at`, `lot_closed_reason`, `lot_closed_credits` | 유료 크레딧 묶음: 남은 양·유효기간(구매 + 5년)·닫힘(만료·환불·탈퇴) | 5년 |
| | `price_micros`, `price_currency`, `refunded_at`, `refund_micros`, `refund_credits` | 결제 금액(환불 계산), 운영자 환불 기록(청약철회·환불 처리) | 5년 |
| `voided_events` | `purchase_token`(탈퇴 시 해시), `event_key`, `quantity`, `credits`, `applied`, `voided_at` | 환불 회수를 한 번만 하기 위한 기록 | 해당 구매 기록과 같음(구매 기록이 지워지면 함께 삭제) |
| `usage_log` | `account_id`, `model`, `status`, `streamed`, 토큰 수(입력·출력·캐시), `web_search_requests`, `credits`, `estimated`, `created_at` | 과금 근거·잔액 문의 대응·남용 탐지. **내용은 저장 안 함** | **1년**, 탈퇴 시 즉시 삭제 |
| `reports` | `account_id`(익명 신고는 NULL), `kind`, `reason`, `content`(신고한 AI 응답 원문), `note`, `app_version`, `created_at` | 생성형 AI 콘텐츠 신고 처리(구글 플레이 정책) | **1년**, 탈퇴 시 그 계정의 신고는 즉시 삭제. 익명 신고에는 IP 를 저장하지 않음 |
| `inflight` | `account_id`, `reserved`, `started_at` | 처리 중인 요청(동시 요청 제한·예약) | 요청이 끝나면 삭제(늦어도 30분 + 하루) |
| `rate_limits` | `key`(**IP 주소**: IPv4 전체 또는 IPv6 /64 접두사 — `reg:`·`rereg:`·`nonce:`·`repip:`·`repanon:`, 또는 계정 번호), `window_start`, `count` | 가입·신고·익명 신고·요청 횟수 제한(남용 방지) | **2일 안**(창 시작 1일 지난 행을 매일 cron 이 삭제). 계정 번호 키는 탈퇴 시 즉시 삭제 |
| `nonces` | `nonce`, `expires_at` | Play Integrity 일회용 값(사람과 연결 안 됨) | 5분(하루 1회 정리) |
| `free_credit_grants` | `sub_hash` = HMAC-SHA256(Google sub, 서버 비밀키), `created_at`, `account_id`(지금 계정), `gone_at`(계정이 삭제·만료된 시각) | 무료 크레딧을 Google 계정당 한 번만 주기 위함(남용 방지). 비밀키 없이는 원래 sub 를 알 수 없음 | 계정이 있는 동안 + **계정 삭제·만료 후 3년**(그 뒤 cron 이 삭제). 같은 Google 계정으로 다시 가입하면 새 계정에 다시 묶임 |
| `account_deletions` | `deleted_at` | 탈퇴 수 통계. 식별 정보 없음 | 제한 없음 |
| `meta` | `voided_purchases_end_ms` 등 | 서버 작업 위치. 개인정보 아님 | – |

처리 위탁·제3자 제공(개인정보처리방침에 적을 것):
- **Cloudflare**(서버·DB 호스팅, 접속 IP 처리), **Anthropic**(AI 요청 내용 처리, 서버는 저장 안 함), **Google**(로그인 ID 토큰 발급·검증용 공개키, Play 결제 확인·환불 목록, Play Integrity 판정).
- Cloudflare Workers 로그(`wrangler tail`, 대시보드)에는 계정 번호·주문번호·오류가 남을 수 있습니다. **기기 토큰·구매 토큰·무결성 토큰·ID 토큰·Google sub·IP 주소·이메일은 콘솔에 남기지 않고**, Google API(영수증 확인·소비·무결성·환불 목록) 오류는 **상태 코드와 오류 종류**(예 `403 PERMISSION_DENIED`)만 남깁니다(응답 본문 없음). Cloudflare 자체의 요청 로그(대시보드의 Workers 관찰 기능)는 이 코드와 별개이므로 켜려면 개인정보처리방침과 맞는지 확인하세요.
- Play Integrity 판정은 가입 때 확인만 하고 저장하지 않습니다.
