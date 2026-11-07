-- 0003 까지 적용된 운영 D1 에 한 번만 실행한다(Google 로그인 버전을 배포하기 전에):
--   npx wrangler d1 execute ember --remote --file=./migrations/0004_google_signin.sql
-- 새로 만드는 DB 는 schema.sql 에 이미 들어 있으므로 실행하지 않는다(컬럼 중복 오류가 난다).
-- 0002·0003 도 적용하지 않은 DB 라면 그것들을 먼저 순서대로 실행한다.

-- 1) 계정 ↔ Google 계정(sub) 연결. 기존 계정은 NULL(연결 안 된 예전 계정)로 남는다.
ALTER TABLE accounts ADD COLUMN google_sub TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_google_sub ON accounts(google_sub);

-- 2) 무료 크레딧을 받은 Google 계정(sub 의 HMAC). 계정을 지워도 남는다.
CREATE TABLE IF NOT EXISTS free_credit_grants (
  sub_hash    TEXT    PRIMARY KEY,
  created_at  INTEGER NOT NULL
);

-- 3) 탈퇴 시각(통계용)
CREATE TABLE IF NOT EXISTS account_deletions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  deleted_at  INTEGER NOT NULL
);
