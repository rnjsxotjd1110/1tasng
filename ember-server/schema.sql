-- Ember 서버 D1 스키마. 처음 한 번 실행한다:
--   npx wrangler d1 execute ember --remote --file=./schema.sql
-- 모든 시각은 유닉스 초(INTEGER). 크레딧은 정수(1 크레딧 = 마크업 포함 $0.01).

-- 계정: Google 계정(sub) 하나당 하나(예전 앱이 만든 계정은 설치 ID 하나당 하나, google_sub = NULL).
-- 토큰은 SHA-256 해시(hex)만 저장한다. 이메일·이름은 저장하지 않는다.
-- install_id 의 특수 값: 'expired-<id>'(보관 기간 만료), 'detached:<id>'(다른 Google 계정이 이 설치를 가져감),
--   'deleted:tombstone'(탈퇴한 계정들의 구매 기록이 옮겨 가는 공용 묘비 계정, 로그인 불가).
CREATE TABLE IF NOT EXISTS accounts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id    TEXT    NOT NULL UNIQUE,
  token_hash    TEXT    NOT NULL UNIQUE,
  credits       INTEGER NOT NULL DEFAULT 0,   -- 지금 쓸 수 있는 잔액 = 무료 + 만료 안 된 유료(처리 중 요청의 예약액은 빠짐). 음수 = 빚
  free_credits  INTEGER NOT NULL DEFAULT 0,   -- 가입 때 받은 무료 크레딧(통계용. 남은 무료 크레딧은 credits - 유료 묶음 합계)
  disabled      INTEGER NOT NULL DEFAULT 0,   -- 0 정상, 1 차단(운영자가 SQL 로 설정), 2 정산 실패로 자동 차단(로그 확인·정산 후 0 으로)
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  google_sub    TEXT,                         -- Google ID 토큰의 sub(계정 고유 ID). NULL = 연결 안 된 예전 계정
  last_used_at  INTEGER NOT NULL DEFAULT 0    -- 마지막 사용(가입·로그인·잔액 확인·요청 등 인증된 호출). 보관 기간(1년 미사용) 기준
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_google_sub ON accounts(google_sub);

-- 무료 크레딧을 받은 Google 계정: HMAC-SHA256(sub, SUB_HASH_SECRET) 만 저장한다(원래 sub 는 알 수 없음).
-- 계정을 지워도 남아서, 같은 Google 계정으로 다시 가입하면 무료 크레딧은 0 이다(남용 방지).
-- 개인정보처리방침: 계정이 있는 동안 보관, 계정이 삭제·만료되면 그때부터 3년 뒤 지운다(gone_at 기준, cron).
CREATE TABLE IF NOT EXISTS free_credit_grants (
  sub_hash    TEXT    PRIMARY KEY,
  created_at  INTEGER NOT NULL,
  account_id  INTEGER,                        -- 이 기록이 속한 지금 계정(NULL = 계정 없음 또는 0005 이전 기록, cron 이 연결)
  gone_at     INTEGER                         -- 계정이 삭제·만료된 시각(NULL = 계정이 있음). 3년 뒤 삭제
);
CREATE INDEX IF NOT EXISTS idx_free_grants_account ON free_credit_grants(account_id);

-- 탈퇴(DELETE /ember/account) 시각만 남긴다(통계용, 식별 정보 없음).
CREATE TABLE IF NOT EXISTS account_deletions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  deleted_at  INTEGER NOT NULL
);

-- 구글 플레이 구매: purchase_token 이 UNIQUE 라서 같은 영수증은 두 번 지급되지 않는다.
-- credited = 0 은 지급 대기(소비 전에 기록, 소비 후 지급이 실패하면 같은 계정이 다시 보내 지급받는다).
-- 탈퇴한 계정의 구매는 account_id = 묘비 계정, purchase_token = 'sha256:<원래 토큰의 SHA-256 hex>' 로 바꿔 5년 보관한다.
CREATE TABLE IF NOT EXISTS purchases (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_token  TEXT    NOT NULL UNIQUE,
  account_id      INTEGER NOT NULL REFERENCES accounts(id),
  product_id      TEXT    NOT NULL,
  order_id        TEXT,
  quantity        INTEGER NOT NULL DEFAULT 1,
  credits         INTEGER NOT NULL,
  purchase_type   INTEGER,                    -- 0 = 테스트 구매(라이선스 테스터), NULL = 일반
  credited        INTEGER NOT NULL DEFAULT 0, -- 1 이면 처리 완료(credits 만큼 지급. 운영에서 테스트 구매는 credits = 0)
  created_at      INTEGER NOT NULL,
  voided          INTEGER NOT NULL DEFAULT 0, -- 1 이면 환불·취소(일부 환불 포함)되어 크레딧을 회수함(Voided Purchases API, cron)
  voided_at       INTEGER,                    -- 구글이 알려 준 (마지막) 환불·취소 시각
  voided_quantity INTEGER NOT NULL DEFAULT 0, -- 환불된 수량(quantity 중). 회수 크레딧 = credits × voided_quantity / quantity
  -- 유료 크레딧 묶음(lot): 지급한 구매 하나 = 묶음 하나. 만료 = created_at + 5년(달력 기준).
  remaining          INTEGER NOT NULL DEFAULT 0, -- 이 구매로 받은 유료 크레딧 중 남은 양(무료 먼저, 그다음 오래된 구매부터 쓴다)
  expires_at         INTEGER,                    -- 유효기간 끝(NULL = 묶음 아님: 지급 대기·0 크레딧 테스트 구매)
  lot_closed_at      INTEGER,                    -- 묶음을 닫은 시각(NULL = 열림: 잔액에 들어감)
  lot_closed_reason  TEXT,                       -- expired / refunded / voided / deleted(탈퇴) / account_expired(계정 만료)
  lot_closed_credits INTEGER NOT NULL DEFAULT 0, -- 닫을 때 남아 있던(잃은·환불한) 크레딧
  price_micros       INTEGER,                    -- 결제 금액(전체 수량, 백만분의 1 단위). Play 확인 응답 → 없으면 PRODUCT_PRICES_KRW
  price_currency     TEXT,                       -- 결제 통화(ISO 4217, 예: KRW)
  refunded_at        INTEGER,                    -- 운영자 환불(POST /ember/admin/refund) 시각
  refund_micros      INTEGER,                    -- 운영자 환불 금액(백만분의 1 단위, price_currency)
  refund_credits     INTEGER NOT NULL DEFAULT 0  -- 운영자 환불로 없앤 크레딧
);
CREATE INDEX IF NOT EXISTS idx_purchases_account ON purchases(account_id);
CREATE INDEX IF NOT EXISTS idx_purchases_order ON purchases(order_id);
CREATE INDEX IF NOT EXISTS idx_purchases_expires ON purchases(expires_at);

-- 환불 이벤트(회수 1건 = 1행). 같은 이벤트를 여러 번 받아도 한 번만 회수하도록 (purchase_token, event_key) 가 키다.
-- event_key: 전체 환불 'full', 수량 일부 환불 'q:<voidedTimeMillis>:<voidedQuantity>', 마이그레이션 이전 회수분 'legacy'.
CREATE TABLE IF NOT EXISTS voided_events (
  purchase_token  TEXT    NOT NULL,
  event_key       TEXT    NOT NULL,
  quantity        INTEGER NOT NULL DEFAULT 0, -- 이 이벤트로 환불 처리한 수량
  credits         INTEGER NOT NULL DEFAULT 0, -- 이 이벤트로 회수한 크레딧
  applied         INTEGER NOT NULL DEFAULT 0, -- 1 이면 잔액에 반영함
  voided_at       INTEGER,
  PRIMARY KEY (purchase_token, event_key)
);

-- 처리 중인 /v1/messages(계정당 동시 요청 수 제한). 끝나면 지운다. 오래된(INFLIGHT_STALE_SECONDS) 행은 무시·정리.
CREATE TABLE IF NOT EXISTS inflight (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id  INTEGER NOT NULL,
  reserved    INTEGER NOT NULL DEFAULT 0,     -- 이 요청을 위해 미리 뺀(예약한) 크레딧
  started_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inflight_account ON inflight(account_id, started_at);

-- 작은 키-값 저장소. 예: 'voided_purchases_end_ms' = 환불 목록을 마지막으로 처리한 시각(ms).
CREATE TABLE IF NOT EXISTS meta (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

-- Play Integrity 용 일회용 nonce(GET /ember/nonce). 5분 뒤 만료, 한 번 쓰면 지운다.
CREATE TABLE IF NOT EXISTS nonces (
  nonce       TEXT    PRIMARY KEY,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_nonces_expires ON nonces(expires_at);

-- 요청 기록(성공·실패 모두). 실패한 요청은 credits = 0. credits 는 최종 청구액(예약 후 정산한 값).
CREATE TABLE IF NOT EXISTS usage_log (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id            INTEGER NOT NULL,
  model                 TEXT    NOT NULL,
  status                INTEGER NOT NULL,
  streamed              INTEGER NOT NULL DEFAULT 0,
  input_tokens          INTEGER NOT NULL DEFAULT 0,
  output_tokens         INTEGER NOT NULL DEFAULT 0,
  cache_read_tokens     INTEGER NOT NULL DEFAULT 0,
  cache_write_tokens    INTEGER NOT NULL DEFAULT 0,
  web_search_requests   INTEGER NOT NULL DEFAULT 0,
  credits               INTEGER NOT NULL DEFAULT 0,
  estimated             INTEGER NOT NULL DEFAULT 0, -- 1 = 최종 usage 를 못 받아(중단·오류) 추정으로 청구함(README 1장 "끝까지 받지 못한 요청")
  created_at            INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_usage_created ON usage_log(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_account ON usage_log(account_id, created_at);

-- AI 생성 콘텐츠 신고(구글 플레이 정책 요구사항). account_id NULL = 크레딧 계정 없는 익명 신고(POST /ember/report/anon).
CREATE TABLE IF NOT EXISTS reports (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id   INTEGER,
  kind         TEXT    NOT NULL,
  reason       TEXT    NOT NULL,
  content      TEXT    NOT NULL,
  note         TEXT    NOT NULL DEFAULT '',
  app_version  TEXT    NOT NULL DEFAULT '',
  created_at   INTEGER NOT NULL
);

-- 고정 창(fixed window) 요청 제한 카운터. key 예: 'reg:1.2.3.4', 'reg:2001:db8:0:1::/64', 'msg:42', 'link:42'
-- IP 가 들어간 키(reg·rereg·nonce·repip·repanon)는 2일 안에 지운다(cron 이 창 시작 1일 지난 행을 매일 삭제).
-- 하루 합계 카운터도 여기에 둔다: 'free:day'(무료 크레딧 지급 합계), 'rep:day'(신고 수), window_start = UTC 0시.
CREATE TABLE IF NOT EXISTS rate_limits (
  key           TEXT    NOT NULL,
  window_start  INTEGER NOT NULL,
  count         INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (key, window_start)
);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window ON rate_limits(window_start);
