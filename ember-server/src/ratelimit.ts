// D1 기반 고정 창 요청 제한.
import { ApiError } from "./http";

/** key 의 이번 창 카운터를 1 올리고, limit 을 넘으면 429 를 던진다. */
export async function enforceRateLimit(
  db: D1Database,
  key: string,
  limit: number,
  windowSeconds: number,
  now: number,
): Promise<void> {
  const windowStart = Math.floor(now / windowSeconds) * windowSeconds;
  const row = await db
    .prepare(
      `INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 1)
       ON CONFLICT (key, window_start) DO UPDATE SET count = count + 1
       RETURNING count`,
    )
    .bind(key, windowStart)
    .first<{ count: number }>();
  const count = row?.count ?? 1;
  if (count > limit) {
    const retryAfter = Math.max(1, windowStart + windowSeconds - now);
    throw new ApiError(429, "rate_limit_error", "too many requests, please try again later", {
      "retry-after": String(retryAfter),
    });
  }
}

/** 이틀보다 오래된 카운터 삭제(cron). */
export async function purgeOldRateLimits(db: D1Database, now: number): Promise<void> {
  await db.prepare("DELETE FROM rate_limits WHERE window_start < ?").bind(now - 2 * 86400).run();
}
