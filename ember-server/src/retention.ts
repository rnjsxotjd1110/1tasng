// 개인정보처리방침의 보관 기간을 지킨다. 매일 cron 에서 부른다.
// - 요청 기록·신고: 1년이 지나면 지운다.
// - 1년 동안 쓰지 않은 계정: 결제한 적이 없으면 지운다.
//   결제 기록은 전자상거래법에 따라 5년 보관해야 하므로, 결제한 계정은 토큰만 무효로 만들고 남겨 둔다.
export const RETENTION_SECONDS = 365 * 86400;
export const PURCHASE_RETENTION_SECONDS = 5 * 365 * 86400;

export async function purgeExpired(db: D1Database, now: number): Promise<void> {
  const cutoff = now - RETENTION_SECONDS;
  await db.batch([
    db.prepare("DELETE FROM usage_log WHERE created_at < ?").bind(cutoff),
    db.prepare("DELETE FROM reports WHERE created_at < ?").bind(cutoff),
    db.prepare(
      `DELETE FROM accounts WHERE updated_at < ?
         AND NOT EXISTS (SELECT 1 FROM purchases p WHERE p.account_id = accounts.id)`,
    ).bind(cutoff),
    // 결제한 계정은 더 이상 쓸 수 없게 토큰을 바꾸고 설치 ID 를 지운다.
    db.prepare(
      `UPDATE accounts SET token_hash = 'expired-' || id, install_id = 'expired-' || id, updated_at = ?
         WHERE updated_at < ? AND install_id NOT LIKE 'expired-%'`,
    ).bind(now, cutoff),
    db.prepare(
      `DELETE FROM purchases WHERE created_at < ?`,
    ).bind(now - PURCHASE_RETENTION_SECONDS),
  ]);
}
