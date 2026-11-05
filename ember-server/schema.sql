-- Ember 서버 D1 스키마. 처음 한 번 실행한다:
--   npx wrangler d1 execute ember --remote --file=./schema.sql
-- 모든 시각은 유닉스 초(INTEGER). 크레딧은 정수(1 크레딧 = 마크업 포함 $0.01).

-- 계정: 설치 ID 하나당 하나. 토큰은 SHA-256 해시(hex)만 저장한다.
CREATE TABLE IF NOT EXISTS accounts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id    TEXT    NOT NULL UNIQUE,
  token_hash    TEXT    NOT NULL UNIQUE,
  credits       INTEGER NOT NULL DEFAULT 0,
  free_credits  INTEGER NOT NULL DEFAULT 0,   -- 가입 때 받은 무료 크레딧(통계용)
  disabled      INTEGER NOT NULL DEFAULT 0,   -- 1 이면 차단(운영자가 SQL 로 설정)
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);

-- 구글 플레이 구매: purchase_token 이 UNIQUE 라서 같은 영수증은 두 번 지급되지 않는다.
CREATE TABLE IF NOT EXISTS purchases (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_token  TEXT    NOT NULL UNIQUE,
  account_id      INTEGER NOT NULL REFERENCES accounts(id),
  product_id      TEXT    NOT NULL,
  order_id        TEXT,
  quantity        INTEGER NOT NULL DEFAULT 1,
  credits         INTEGER NOT NULL,
  purchase_type   INTEGER,                    -- 0 = 테스트 구매(라이선스 테스터), NULL = 일반
  credited        INTEGER NOT NULL DEFAULT 0, -- 1 이면 크레딧 지급 완료
  created_at      INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_purchases_account ON purchases(account_id);

-- 요청 기록(성공·실패 모두). 실패한 요청은 credits = 0.
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
  estimated             INTEGER NOT NULL DEFAULT 0, -- 1 = 스트림이 중간에 끊겨 출력 토큰을 추정함
  created_at            INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_usage_created ON usage_log(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_account ON usage_log(account_id, created_at);

-- AI 생성 콘텐츠 신고(구글 플레이 정책 요구사항).
CREATE TABLE IF NOT EXISTS reports (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id   INTEGER NOT NULL,
  kind         TEXT    NOT NULL,
  reason       TEXT    NOT NULL,
  content      TEXT    NOT NULL,
  note         TEXT    NOT NULL DEFAULT '',
  app_version  TEXT    NOT NULL DEFAULT '',
  created_at   INTEGER NOT NULL
);

-- 고정 창(fixed window) 요청 제한 카운터. key 예: 'reg:1.2.3.4', 'msg:42'
CREATE TABLE IF NOT EXISTS rate_limits (
  key           TEXT    NOT NULL,
  window_start  INTEGER NOT NULL,
  count         INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (key, window_start)
);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window ON rate_limits(window_start);
