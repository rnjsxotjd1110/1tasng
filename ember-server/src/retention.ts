// 개인정보처리방침·이용약관의 보관 기간을 지킨다. 매일 cron 에서 부른다(index.ts).
//
// - 유료 크레딧 묶음: 구매 + 5년(달력)이 지나면 닫고 잔액에서 뺀다(billing/lots.ts expireLots).
// - 크레딧 사용 기록(usage_log)·신고(reports): 1년이 지나면 지운다(익명 신고 포함).
// - 계정: 마지막 사용(last_used_at) 후 1년이 지났고 만료 안 된 유료 크레딧이 남아 있지 않으면 만료시킨다
//   (남은 무료 크레딧은 사라진다). 유료 크레딧이 남아 있는 계정은 묶음이 만료될 때까지(= 마지막 구매 + 5년) 남는다.
//   · 구매 기록이 없으면 계정 행을 지운다.
//   · 구매 기록이 있으면(5년 보관 의무) 토큰·설치 ID·Google 연결을 지우고 잔액을 0 으로 만든 자리 표시('expired-<id>')만 남긴다.
//     자리 표시는 구매 기록이 모두 지워진 뒤 지운다.
// - 구매·환불 기록(purchases, voided_events): 구매 + 5년(달력)이 지나면 계정 상태와 관계없이 지운다(닫힌 묶음만).
// - 무료 크레딧 1회 기록(free_credit_grants, sub 의 HMAC): 계정이 있는 동안 보관하고,
//   계정이 삭제·만료된 때(gone_at)부터 3년(달력)이 지나면 지운다. 0005 이전 기록은 linkLegacyFreeGrants 가 계정과 연결한다.
// - IP 가 들어간 요청 제한 카운터는 ratelimit.ts purgeOldRateLimits(2일 안).
// - account_deletions(탈퇴 시각, 식별 정보 없음)는 지우지 않는다.
import { addYears, expireLots, openLot } from "./billing/lots";
import type { Env } from "./env";
import { hmacSha256Hex } from "./util";

export const RETENTION_SECONDS = 365 * 86400;
/** 구매·환불 기록 보관(년, 전자상거래법) */
export const PURCHASE_RETENTION_YEARS = 5;
/** 무료 크레딧 1회 기록: 계정이 삭제·만료된 뒤 보관(년) */
export const FREE_GRANT_RETENTION_YEARS = 3;

/**
 * 만료 대상 계정 조건: 1년 동안 쓰지 않음 + 만료 안 된 유료 크레딧이 남아 있지 않음 + 묘비 계정 아님.
 * 무료 크레딧·빚(음수 잔액)은 남아 있어도 대상이다.
 */
const EXPIRABLE = `last_used_at < ? AND install_id <> 'deleted:tombstone'
  AND NOT EXISTS (SELECT 1 FROM purchases p WHERE p.account_id = accounts.id AND ${openLot("p")} AND p.remaining > 0)`;

export async function purgeExpired(db: D1Database, now: number): Promise<void> {
  // 유효기간 지난 유료 크레딧을 먼저 닫는다(아래 계정 만료·구매 기록 삭제가 그 결과를 본다).
  await expireLots(db, now);

  const cutoff = now - RETENTION_SECONDS;
  const purchaseCutoff = addYears(now, -PURCHASE_RETENTION_YEARS);
  await db.batch([
    db.prepare("DELETE FROM usage_log WHERE created_at < ?").bind(cutoff),
    db.prepare("DELETE FROM reports WHERE created_at < ?").bind(cutoff),

    // 구매·환불 기록: 5년 지난 것은 계정 상태와 관계없이 지운다. 열린 묶음(만료 처리 전)은 남겨 다음 실행에서.
    db
      .prepare(
        `DELETE FROM purchases WHERE created_at < ?
           AND (expires_at IS NULL OR lot_closed_at IS NOT NULL OR credited = 0)`,
      )
      .bind(purchaseCutoff),
    db.prepare("DELETE FROM voided_events WHERE purchase_token NOT IN (SELECT purchase_token FROM purchases)"),

    // 만료되는 계정의 무료 크레딧 기록: 연결을 끊고 3년 보관 시계를 시작한다.
    db
      .prepare(
        `UPDATE free_credit_grants SET account_id = NULL, gone_at = ?
         WHERE account_id IN (SELECT id FROM accounts WHERE ${EXPIRABLE})`,
      )
      .bind(now, cutoff),
    // 남은 양이 0 인 열린 묶음도 닫아 둔다(자리 표시 계정에 열린 묶음이 남지 않게).
    db
      .prepare(
        `UPDATE purchases SET lot_closed_at = ?, lot_closed_reason = 'account_expired', lot_closed_credits = remaining, remaining = 0
         WHERE expires_at IS NOT NULL AND lot_closed_at IS NULL
           AND account_id IN (SELECT id FROM accounts WHERE ${EXPIRABLE})`,
      )
      .bind(now, cutoff),
    db
      .prepare(
        `DELETE FROM accounts WHERE ${EXPIRABLE}
           AND NOT EXISTS (SELECT 1 FROM purchases p WHERE p.account_id = accounts.id)`,
      )
      .bind(cutoff),
    // 구매 기록이 남은 계정은 더 이상 쓸 수 없게 토큰을 바꾸고 설치 ID·Google 연결·잔액(무료 크레딧·빚)을 지운다.
    db
      .prepare(
        `UPDATE accounts SET token_hash = 'expired-' || id, install_id = 'expired-' || id, google_sub = NULL,
           credits = 0, updated_at = ?
         WHERE ${EXPIRABLE} AND install_id NOT LIKE 'expired-%'`,
      )
      .bind(now, cutoff),

    // 무료 크레딧 1회 기록: 계정이 없어진 지 3년 지난 것.
    db
      .prepare("DELETE FROM free_credit_grants WHERE gone_at IS NOT NULL AND gone_at < ?")
      .bind(addYears(now, -FREE_GRANT_RETENTION_YEARS)),
  ]);
}

/** 한 번에 보내는 문장 수(D1 batch 크기 제한 대비) */
const LINK_BATCH = 100;

/**
 * 0005 이전의 무료 크레딧 기록(account_id·gone_at 모두 NULL)을 지금 계정과 연결한다(cron).
 * 계정의 Google sub 로 HMAC 을 다시 계산해 맞으면 연결하고, 맞는 계정이 없으면(이미 탈퇴·만료) 지금을 gone_at 으로 둔다
 * (실제로 없어진 때보다 늦으므로 3년 보관을 줄이지 않는다). SUB_HASH_SECRET 이 없으면 건너뛴다(null).
 * 연결할 기록이 없으면 계정을 읽지 않는다(배포 후 첫 실행 뒤로는 거의 일이 없다).
 */
export async function linkLegacyFreeGrants(env: Env, now: number): Promise<{ linked: number; gone: number } | null> {
  if (!env.SUB_HASH_SECRET) return null;
  const db = env.DB;
  const { results: pending } = await db
    .prepare("SELECT sub_hash FROM free_credit_grants WHERE account_id IS NULL AND gone_at IS NULL")
    .all<{ sub_hash: string }>();
  if (pending.length === 0) return { linked: 0, gone: 0 };

  const wanted = new Set(pending.map((r) => r.sub_hash));
  const owner = new Map<string, number>();
  const { results: accounts } = await db
    .prepare("SELECT id, google_sub FROM accounts WHERE google_sub IS NOT NULL")
    .all<{ id: number; google_sub: string }>();
  for (const a of accounts) {
    const h = await hmacSha256Hex(env.SUB_HASH_SECRET, a.google_sub);
    if (wanted.has(h)) owner.set(h, a.id);
  }

  const stmts = pending.map((r) => {
    const id = owner.get(r.sub_hash);
    return id !== undefined
      ? db
          .prepare("UPDATE free_credit_grants SET account_id = ? WHERE sub_hash = ? AND account_id IS NULL AND gone_at IS NULL")
          .bind(id, r.sub_hash)
      : db
          .prepare("UPDATE free_credit_grants SET gone_at = ? WHERE sub_hash = ? AND account_id IS NULL AND gone_at IS NULL")
          .bind(now, r.sub_hash);
  });
  for (let i = 0; i < stmts.length; i += LINK_BATCH) await db.batch(stmts.slice(i, i + LINK_BATCH));
  return { linked: owner.size, gone: pending.length - owner.size };
}
