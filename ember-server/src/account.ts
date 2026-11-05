// POST /ember/register, GET /ember/balance
import { authenticate } from "./auth";
import type { Config, Env } from "./env";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { verifyRegistrationIntegrity, type IntegrityOutcome } from "./play/integrity";
import { enforceRateLimit } from "./ratelimit";
import { nowSeconds, randomToken, sha256Hex } from "./util";

// 무결성 토큰(수 KB)이 들어갈 수 있게 넉넉히 둔다.
const REGISTER_BODY_MAX = 32 * 1024;
const INSTALL_ID_RE = /^[A-Za-z0-9_-]{8,64}$/;

export interface RegisterResult {
  token: string;
  credits: number;
  freeGranted: boolean;
}

export async function handleRegister(req: Request, env: Env, cfg: Config): Promise<Response> {
  const now = nowSeconds();
  const ip = req.headers.get("cf-connecting-ip") ?? "unknown";
  await enforceRateLimit(env.DB, `reg:${ip}`, cfg.registerLimit, cfg.registerWindowSeconds, now);

  const body = await readJsonObject(req, REGISTER_BODY_MAX);
  const installId = body["installId"];
  if (typeof installId !== "string" || !INSTALL_ID_RE.test(installId)) {
    throw new ApiError(400, "invalid_request_error", "installId must be 8-64 characters of [A-Za-z0-9_-]");
  }

  // INTEGRITY_MODE: off 면 예전과 같고, grant 면 통과한 새 설치만 무료 크레딧, require 면 통과해야 가입.
  let integrity: IntegrityOutcome | undefined;
  if (cfg.integrityMode !== "off") {
    integrity = await verifyRegistrationIntegrity(env, cfg, body, now);
    if (cfg.integrityMode === "require" && integrity !== "ok") {
      throw new ApiError(403, "integrity_failed", `device integrity check ${integrity}`);
    }
  }
  const freeCredits = integrity === undefined || integrity === "ok" ? cfg.freeCredits : 0;

  const result = await registerInstall(env.DB, installId, freeCredits, now);
  return jsonResponse(integrity === undefined ? result : { ...result, integrity });
}

/**
 * 설치 ID 로 계정을 만들거나 찾는다. 새 토큰을 발급해 이전 토큰은 무효가 된다.
 * 무료 크레딧은 계정이 처음 만들어질 때(INSERT 성공)만 지급된다. freeCredits 가 0 이면 freeGranted 는 false.
 */
export async function registerInstall(
  db: D1Database,
  installId: string,
  freeCredits: number,
  now: number,
): Promise<RegisterResult> {
  const token = randomToken();
  const tokenHash = await sha256Hex(token);

  const inserted = await db
    .prepare(
      `INSERT INTO accounts (install_id, token_hash, credits, free_credits, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (install_id) DO NOTHING
       RETURNING credits`,
    )
    .bind(installId, tokenHash, freeCredits, freeCredits, now, now)
    .first<{ credits: number }>();
  if (inserted) return { token, credits: inserted.credits, freeGranted: freeCredits > 0 };

  const updated = await db
    .prepare(
      `UPDATE accounts SET token_hash = ?, updated_at = ? WHERE install_id = ?
       RETURNING credits, disabled`,
    )
    .bind(tokenHash, now, installId)
    .first<{ credits: number; disabled: number }>();
  if (!updated) throw new ApiError(500, "api_error", "could not register this install");
  if (updated.disabled) throw new ApiError(403, "permission_error", "this account has been disabled");
  return { token, credits: updated.credits, freeGranted: false };
}

export async function handleBalance(req: Request, env: Env): Promise<Response> {
  const account = await authenticate(env, req);
  return jsonResponse({ credits: account.credits });
}
