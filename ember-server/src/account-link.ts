// POST /ember/link-google: Google 에 연결 안 된 예전 계정(예전 앱 버전이 만든 계정)을 Google 계정(sub)에 연결한다.
// - 이 sub 가 이미 다른 계정의 것이면 409 google_in_use(아무것도 바꾸지 않는다, 계정 합치기 없음).
// - 이 계정이 이미 다른 sub 에 연결돼 있으면 409 already_linked. 같은 sub 면 그대로 성공(멱등).
// - LEGACY_UNLINKED_UNTIL 이 지난 뒤에도 쓸 수 있다(예전 계정이 빠져나갈 길).
import { authenticate } from "./auth";
import type { Config, Env } from "./env";
import { linkFreeGrantStmt, recordFreeGrantStmt, subHashOf, verifyGoogleSignIn } from "./google/identity";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { enforceRateLimit } from "./ratelimit";
import { nowSeconds } from "./util";

const LINK_BODY_MAX = 16 * 1024;

export interface LinkResult {
  linked: true;
  credits: number;
}

function inUse(): ApiError {
  return new ApiError(409, "google_in_use", "this Google account is already used by another Ember account");
}

function alreadyLinked(): ApiError {
  return new ApiError(409, "already_linked", "this account is already linked to a different Google account");
}

export async function handleLinkGoogle(req: Request, env: Env, cfg: Config): Promise<Response> {
  const account = await authenticate(env, req, { allowUnlinked: true });
  const now = nowSeconds();
  await enforceRateLimit(env.DB, `link:${account.id}`, cfg.reregisterLimit, cfg.registerWindowSeconds, now);
  const body = await readJsonObject(req, LINK_BODY_MAX);
  const sub = await verifyGoogleSignIn(env, cfg, body["idToken"]);

  if (account.googleSub === sub) return jsonResponse({ linked: true, credits: account.credits } satisfies LinkResult);
  if (account.googleSub !== null) throw alreadyLinked();
  const owner = await env.DB.prepare("SELECT id FROM accounts WHERE google_sub = ?").bind(sub).first<{ id: number }>();
  if (owner) throw inUse();

  const subHash = await subHashOf(env, sub);
  const results = await env.DB.batch([
    env.DB
      .prepare(
        `UPDATE accounts SET google_sub = ?, updated_at = ?
         WHERE id = ? AND google_sub IS NULL AND NOT EXISTS (SELECT 1 FROM accounts o WHERE o.google_sub = ?)
         RETURNING credits`,
      )
      .bind(sub, now, account.id, sub),
    // 예전 계정이 받은 무료 크레딧도 이 Google 계정의 '받음'으로 기록한다(탈퇴 후 다시 받지 못하게).
    recordFreeGrantStmt(env.DB, subHash, sub, now),
    linkFreeGrantStmt(env.DB, subHash, sub),
  ]);
  const row = results[0]?.results[0] as { credits: number } | undefined;
  if (row) return jsonResponse({ linked: true, credits: row.credits } satisfies LinkResult);

  // 그 사이 다른 요청이 연결했다.
  const now2 = await env.DB.prepare("SELECT google_sub, credits FROM accounts WHERE id = ?")
    .bind(account.id)
    .first<{ google_sub: string | null; credits: number }>();
  if (now2?.google_sub === sub) return jsonResponse({ linked: true, credits: now2.credits } satisfies LinkResult);
  if (now2?.google_sub) throw alreadyLinked();
  throw inUse();
}
