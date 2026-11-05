// Ember 서버 진입점(Cloudflare Worker).
import { loadConfig, type Env } from "./env";
import { purgeExpiredNonces } from "./play/integrity";
import { processVoidedPurchases } from "./play/voided";
import { purgeOldRateLimits } from "./ratelimit";
import { purgeExpired } from "./retention";
import { route } from "./router";

export type { Env } from "./env";

/** 매일 cron: 정리 작업과 환불 회수. 하나가 실패해도 나머지는 돌리고, 끝에 실패를 알린다. */
export async function runDailyJobs(env: Env, nowMs: number = Date.now()): Promise<void> {
  const cfg = loadConfig(env);
  const now = Math.floor(nowMs / 1000);
  const jobs: [string, () => Promise<unknown>][] = [
    ["rate_limits 정리", () => purgeOldRateLimits(env.DB, now)],
    ["nonce 정리", () => purgeExpiredNonces(env.DB, now)],
    ["보관 기간 정리", () => purgeExpired(env.DB, now)],
    ["환불 회수", () => processVoidedPurchases(env, cfg, nowMs)],
  ];
  const failed: string[] = [];
  for (const [name, job] of jobs) {
    try {
      await job();
    } catch (err) {
      console.error(`cron 작업 실패(${name}):`, err);
      failed.push(name);
    }
  }
  if (failed.length > 0) throw new Error(`cron jobs failed: ${failed.join(", ")}`);
}

export default {
  fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return route(req, env, ctx);
  },
  async scheduled(_controller: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    await runDailyJobs(env);
  },
} satisfies ExportedHandler<Env>;
