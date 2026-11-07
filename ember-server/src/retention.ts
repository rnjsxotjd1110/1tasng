// 개인정보처리방침의 보관 기간을 지킨다. 매일 cron 에서 부른다.
// - 요청 기록·신고: 1년이 지나면 지운다.
// - 1년 동안 쓰지 않은 계정: 잔액이 남아 있거나(> 0) 환불되지 않은 구매가 하나라도 있으면 **절대 건드리지 않는다**
//   (산 크레딧·남은 크레딧이 사라지면 안 된다).
//   그 밖의 계정은 구매 기록이 전혀 없으면 지우고, 환불된 구매 기록만 있으면(전자상거래법상 5년 보관)
//   토큰만 무효로 만들고 남겨 둔다.
// - 구매 기록은 5년이 지났고 계정이 이미 만료(expired-)된 경우에만 지운다.
export const RETENTION_SECONDS = 365 * 86400;
export const PURCHASE_RETENTION_SECONDS = 5 * 365 * 86400;

/** 만료 대상 계정 조건(잔액 0 이하 + 환불되지 않은 구매 없음 + 1년 미사용). */
const EXPIRABLE = `updated_at < ? AND credits <= 0
  AND NOT EXISTS (SELECT 1 FROM purchases p WHERE p.account_id = accounts.id AND p.voided = 0)`;

export async function purgeExpired(db: D1Database, now: number): Promise<void> {
  const cutoff = now - RETENTION_SECONDS;
  await db.batch([
    db.prepare("DELETE FROM usage_log WHERE created_at < ?").bind(cutoff),
    db.prepare("DELETE FROM reports WHERE created_at < ?").bind(cutoff),
    db.prepare(
      `DELETE FROM accounts WHERE ${EXPIRABLE}
         AND NOT EXISTS (SELECT 1 FROM purchases p WHERE p.account_id = accounts.id)`,
    ).bind(cutoff),
    // 환불된 구매 기록만 있는 계정은 더 이상 쓸 수 없게 토큰을 바꾸고 설치 ID 를 지운다.
    db.prepare(
      `UPDATE accounts SET token_hash = 'expired-' || id, install_id = 'expired-' || id, updated_at = ?
         WHERE ${EXPIRABLE} AND install_id NOT LIKE 'expired-%'`,
    ).bind(now, cutoff),
    db.prepare(
      `DELETE FROM purchases WHERE created_at < ?
         AND account_id IN (SELECT id FROM accounts WHERE install_id LIKE 'expired-%')`,
    ).bind(now - PURCHASE_RETENTION_SECONDS),
  ]);
}
