-- 0004 까지 적용된 운영 D1 에 한 번만 실행한다(유료/무료 크레딧 분리·보관 기간 버전을 배포하기 직전에):
--   npx wrangler d1 execute ember --remote --file=./migrations/0005_credit_lots_retention.sql
-- 새로 만드는 DB 는 schema.sql 에 이미 들어 있으므로 실행하지 않는다(컬럼 중복 오류가 난다).
-- 0002~0004 도 적용하지 않은 DB 라면 그것들을 먼저 순서대로 실행한다.
-- SQLite 3.35 이상(UPDATE … FROM, WITH … MATERIALIZED, 창 함수)이 필요하다. D1 은 해당한다.

-- 1) 계정의 마지막 사용 시각(보관 기간 1년 미사용 기준). 지금까지의 updated_at 으로 채운다.
ALTER TABLE accounts ADD COLUMN last_used_at INTEGER NOT NULL DEFAULT 0;
UPDATE accounts SET last_used_at = updated_at;

-- 2) 유료 크레딧 묶음(구매 한 건 = 묶음 하나), 결제 금액, 운영자 환불 기록
ALTER TABLE purchases ADD COLUMN remaining INTEGER NOT NULL DEFAULT 0;
ALTER TABLE purchases ADD COLUMN expires_at INTEGER;
ALTER TABLE purchases ADD COLUMN lot_closed_at INTEGER;
ALTER TABLE purchases ADD COLUMN lot_closed_reason TEXT;
ALTER TABLE purchases ADD COLUMN lot_closed_credits INTEGER NOT NULL DEFAULT 0;
ALTER TABLE purchases ADD COLUMN price_micros INTEGER;
ALTER TABLE purchases ADD COLUMN price_currency TEXT;
ALTER TABLE purchases ADD COLUMN refunded_at INTEGER;
ALTER TABLE purchases ADD COLUMN refund_micros INTEGER;
ALTER TABLE purchases ADD COLUMN refund_credits INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_purchases_order ON purchases(order_id);
CREATE INDEX IF NOT EXISTS idx_purchases_expires ON purchases(expires_at);

-- 3) 무료 크레딧 1회 기록(HMAC)과 계정의 연결. 기존 기록은 계정을 모르므로 NULL 로 두고,
--    배포 후 첫 cron 이 SUB_HASH_SECRET 으로 지금 계정과 연결한다(맞는 계정이 없으면 그때를 '계정 없어진 시각'으로 둔다).
ALTER TABLE free_credit_grants ADD COLUMN account_id INTEGER;
ALTER TABLE free_credit_grants ADD COLUMN gone_at INTEGER;
CREATE INDEX IF NOT EXISTS idx_free_grants_account ON free_credit_grants(account_id);

-- 4) 신고: 크레딧 계정 없는 익명 신고(account_id NULL)를 받도록 표를 다시 만든다(NOT NULL 은 ALTER 로 못 바꾼다).
CREATE TABLE reports_new (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id   INTEGER,
  kind         TEXT    NOT NULL,
  reason       TEXT    NOT NULL,
  content      TEXT    NOT NULL,
  note         TEXT    NOT NULL DEFAULT '',
  app_version  TEXT    NOT NULL DEFAULT '',
  created_at   INTEGER NOT NULL
);
INSERT INTO reports_new (id, account_id, kind, reason, content, note, app_version, created_at)
  SELECT id, account_id, kind, reason, content, note, app_version, created_at FROM reports;
DROP TABLE reports;
ALTER TABLE reports_new RENAME TO reports;

-- 5) 기존 잔액을 유료/무료로 나눈다.
--    지급 완료(credited = 1, credits > 0) 구매마다 묶음을 만들고(만료 = 구매 + 5년),
--    환불(일부 포함)된 구매와 탈퇴·만료 계정의 구매는 묶음을 닫는다(남은 양 0).
--    남은 묶음에는 계정 잔액(0 미만이면 0)을 최신 구매부터 채운다(쓰는 순서가 오래된 것부터이므로 최신 것이 남아 있다).
--    즉 유료 = min(잔액, 환불 안 된 지급 구매 크레딧 합계), 무료 = 잔액 - 유료.
UPDATE purchases SET expires_at = CAST(strftime('%s', created_at, 'unixepoch', '+5 years') AS INTEGER)
  WHERE credited = 1 AND credits > 0;
UPDATE purchases SET lot_closed_at = COALESCE(voided_at, CAST(strftime('%s', 'now') AS INTEGER)), lot_closed_reason = 'voided'
  WHERE expires_at IS NOT NULL AND voided = 1;
UPDATE purchases SET lot_closed_at = CAST(strftime('%s', 'now') AS INTEGER), lot_closed_reason = 'deleted'
  WHERE expires_at IS NOT NULL AND lot_closed_at IS NULL
    AND account_id IN (SELECT id FROM accounts WHERE install_id = 'deleted:tombstone');
UPDATE purchases SET lot_closed_at = CAST(strftime('%s', 'now') AS INTEGER), lot_closed_reason = 'account_expired'
  WHERE expires_at IS NOT NULL AND lot_closed_at IS NULL
    AND account_id IN (SELECT id FROM accounts WHERE install_id LIKE 'expired-%');
WITH lots AS MATERIALIZED (
  SELECT p.id, p.credits, MAX(0, a.credits) AS balance,
    COALESCE(SUM(p.credits) OVER (
      PARTITION BY p.account_id ORDER BY p.created_at DESC, p.id DESC ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS newer
  FROM purchases p JOIN accounts a ON a.id = p.account_id
  WHERE p.credited = 1 AND p.expires_at IS NOT NULL AND p.lot_closed_at IS NULL
)
UPDATE purchases SET remaining = MIN(lots.credits, MAX(0, lots.balance - lots.newer))
FROM lots WHERE purchases.id = lots.id;
