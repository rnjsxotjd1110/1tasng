// 정산과 사용 기록. 요청 전에 예약(reserved)한 크레딧과 실제 비용(credits)의 차이를 한 batch(트랜잭션)로 반영한다.
import type { Usage } from "./usage";

/** accounts.disabled 값: 정산 기록이 계속 실패해 자동으로 막은 계정(운영자가 로그로 정산한 뒤 0 으로 되돌린다). */
export const DISABLED_BILLING_FAILURE = 2;

export interface UsageRecord {
  accountId: number;
  model: string;
  status: number;
  streamed: boolean;
  usage: Usage;
  /** 최종 청구액 */
  credits: number;
  /** 요청 전에 미리 뺀 크레딧(예약 없이 기록만 하면 0) */
  reserved: number;
  /** true = 최종 usage 를 못 받아 예약액 전체를 청구함 */
  estimated: boolean;
  now: number;
}

/**
 * usage_log 에 남기고 잔액을 정산한다: 예약액 - 실제 비용만큼 돌려준다(돌려줄 게 없으면 0).
 * 실제 비용이 예약액보다 크면(입력 추정이 모자랐던 드문 경우) 그 차이를 더 뺀다(잔액이 음수가 될 수 있음).
 * 정산 후 잔액을 돌려준다.
 */
export async function recordUsage(db: D1Database, r: UsageRecord): Promise<number | null> {
  const u = r.usage;
  const log = db
    .prepare(
      `INSERT INTO usage_log (account_id, model, status, streamed, input_tokens, output_tokens,
         cache_read_tokens, cache_write_tokens, web_search_requests, credits, estimated, created_at)
       SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
       WHERE EXISTS (SELECT 1 FROM accounts WHERE id = ?)`,
    )
    .bind(
      r.accountId,
      r.model,
      r.status,
      r.streamed ? 1 : 0,
      u.inputTokens,
      u.outputTokens,
      u.cacheReadTokens,
      u.cacheWrite5mTokens + u.cacheWrite1hTokens,
      u.webSearchRequests,
      r.credits,
      r.estimated ? 1 : 0,
      r.now,
      // 요청 중에 계정이 삭제(DELETE /ember/account)됐으면 기록을 남기지 않는다.
      r.accountId,
    );
  const refund = Math.max(0, r.reserved - r.credits);
  const extra = Math.max(0, r.credits - r.reserved);
  if (extra > 0) {
    console.warn(`실제 비용이 예약액보다 큼: account=${r.accountId} reserved=${r.reserved} actual=${r.credits}`);
  }
  const results = await db.batch([
    log,
    db
      .prepare("UPDATE accounts SET credits = credits + ? - ?, updated_at = ? WHERE id = ?")
      .bind(refund, extra, r.now, r.accountId),
    db.prepare("SELECT credits FROM accounts WHERE id = ?").bind(r.accountId),
  ]);
  const row = results[2]?.results[0] as { credits: number } | undefined;
  return row?.credits ?? null;
}

/**
 * recordUsage 를 한 번 다시 시도하고, 그래도 실패하면 계정을 막는다(disabled = 2).
 * 기록 없이 넘어가면 예약액이 정산되지 않거나 사용이 기록되지 않으므로, 운영자가 로그를 보고 정산할 때까지 쓰지 못하게 한다.
 * 정산 후 잔액(실패하면 null)을 돌려준다. 예외를 던지지 않는다.
 */
export async function settleUsage(db: D1Database, r: UsageRecord): Promise<number | null> {
  let lastErr: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      return await recordUsage(db, r);
    } catch (err) {
      lastErr = err;
    }
  }
  console.error(
    `정산 실패(계정 차단, 수동 정산 필요): account=${r.accountId} reserved=${r.reserved} actual=${r.credits} ` +
      `model=${r.model} status=${r.status} usage=${JSON.stringify(r.usage)}`,
    lastErr,
  );
  try {
    await db
      .prepare("UPDATE accounts SET disabled = ?, updated_at = ? WHERE id = ? AND disabled = 0")
      .bind(DISABLED_BILLING_FAILURE, r.now, r.accountId)
      .run();
  } catch (err) {
    console.error(`정산 실패 후 계정 차단도 실패: account=${r.accountId}`, err);
  }
  return null;
}
