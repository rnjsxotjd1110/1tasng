-- 이미 운영 중인 D1(예전 schema.sql 로 만든 DB)에 한 번만 실행한다:
--   npx wrangler d1 execute ember --remote --file=./migrations/0002_voided_integrity.sql
-- 새로 만드는 DB 는 schema.sql 에 이미 들어 있으므로 실행하지 않는다(컬럼 중복 오류가 난다).

-- 1) 환불 회수: 구매에 환불 표시
ALTER TABLE purchases ADD COLUMN voided INTEGER NOT NULL DEFAULT 0;
ALTER TABLE purchases ADD COLUMN voided_at INTEGER;

-- 2) 환불 목록 처리 위치 등을 저장하는 키-값 표
CREATE TABLE IF NOT EXISTS meta (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);

-- 3) Play Integrity 일회용 nonce
CREATE TABLE IF NOT EXISTS nonces (
  nonce       TEXT    PRIMARY KEY,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_nonces_expires ON nonces(expires_at);
