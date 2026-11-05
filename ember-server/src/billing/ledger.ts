// 크레딧 차감과 사용 기록. 한 batch(트랜잭션)로 원자적으로 처리한다.
import type { Usage } from "./usage";

export interface UsageRecord {
  accountId: number;
  model: string;
  status: number;
  streamed: boolean;
  usage: Usage;
  credits: number;
  estimated: boolean;
  now: number;
}

/**
 * credits 만큼 차감하고 usage_log 에 남긴다.
 * 잔액 확인 없이 차감하므로 마지막 요청에서 잔액이 조금 음수가 될 수 있다(의도된 동작).
 */
export async function recordUsage(db: D1Database, r: UsageRecord): Promise<void> {
  const u = r.usage;
  const log = db
    .prepare(
      `INSERT INTO usage_log (account_id, model, status, streamed, input_tokens, output_tokens,
         cache_read_tokens, cache_write_tokens, web_search_requests, credits, estimated, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
    );
  if (r.credits > 0) {
    const deduct = db
      .prepare("UPDATE accounts SET credits = credits - ?, updated_at = ? WHERE id = ?")
      .bind(r.credits, r.now, r.accountId);
    await db.batch([deduct, log]);
  } else {
    await log.run();
  }
}
