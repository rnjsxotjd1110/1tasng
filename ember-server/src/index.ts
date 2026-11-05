import { purgeExpired } from "./retention";
// Ember 서버 진입점(Cloudflare Worker).
import type { Env } from "./env";
import { purgeOldRateLimits } from "./ratelimit";
import { route } from "./router";
import { nowSeconds } from "./util";

export type { Env } from "./env";

export default {
  fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return route(req, env, ctx);
  },
  async scheduled(_controller: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    await purgeOldRateLimits(env.DB, nowSeconds());
    await purgeExpired(env.DB, nowSeconds());
  },
} satisfies ExportedHandler<Env>;
