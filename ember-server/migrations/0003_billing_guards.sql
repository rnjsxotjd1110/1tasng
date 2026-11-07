-- 0002 까지 적용된 운영 D1 에 한 번만 실행한다(배포 전에):
--   npx wrangler d1 execute ember --remote --file=./migrations/0003_billing_guards.sql
-- 새로 만드는 DB 는 schema.sql 에 이미 들어 있으므로 실행하지 않는다(컬럼 중복 오류가 난다).
-- 0002 도 적용하지 않은 DB 라면 0002 를 먼저 실행한다.

-- 1) 수량 일부 환불: 환불된 수량
ALTER TABLE purchases ADD COLUMN voided_quantity INTEGER NOT NULL DEFAULT 0;

-- 2) 환불 이벤트(같은 이벤트 중복 회수 방지)
CREATE TABLE IF NOT EXISTS voided_events (
  purchase_token  TEXT    NOT NULL,
  event_key       TEXT    NOT NULL,
  quantity        INTEGER NOT NULL DEFAULT 0,
  credits         INTEGER NOT NULL DEFAULT 0,
  applied         INTEGER NOT NULL DEFAULT 0,
  voided_at       INTEGER,
  PRIMARY KEY (purchase_token, event_key)
);

-- 3) 이미 전체 회수한 구매(0002 의 voided = 1)를 새 방식으로 옮긴다: 전체 수량 환불 + 'legacy' 이벤트
UPDATE purchases SET voided_quantity = quantity WHERE voided = 1;
INSERT OR IGNORE INTO voided_events (purchase_token, event_key, quantity, credits, applied, voided_at)
  SELECT purchase_token, 'legacy', quantity, credits, 1, voided_at FROM purchases WHERE voided = 1 AND credited = 1;

-- 4) 처리 중인 요청(계정당 동시 요청 수 제한·크레딧 예약)
CREATE TABLE IF NOT EXISTS inflight (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id  INTEGER NOT NULL,
  reserved    INTEGER NOT NULL DEFAULT 0,
  started_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inflight_account ON inflight(account_id, started_at);
