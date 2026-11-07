// POST /ember/register, GET /ember/balance
import { authenticate } from "./auth";
import type { Config, Env } from "./env";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { verifyRegistrationIntegrity, type IntegrityOutcome } from "./play/integrity";
import { clientIpKey, enforceRateLimit, subtractDaily, tryAddDaily } from "./ratelimit";
import { nowSeconds, randomToken, sha256Hex } from "./util";

// 무결성 토큰(수 KB)이 들어갈 수 있게 넉넉히 둔다.
const REGISTER_BODY_MAX = 32 * 1024;
const INSTALL_ID_RE = /^[A-Za-z0-9_-]{8,64}$/;

export interface RegisterResult {
  token: string;
  credits: number;
  freeGranted: boolean;
}

/** 하루 무료 크레딧 지급 합계 카운터(rate_limits 표, window_start = UTC 0시) */
export const FREE_CREDITS_DAILY_KEY = "free:day";

export async function handleRegister(req: Request, env: Env, cfg: Config): Promise<Response> {
  const now = nowSeconds();
  const body = await readJsonObject(req, REGISTER_BODY_MAX);
  const installId = body["installId"];
  if (typeof installId !== "string" || !INSTALL_ID_RE.test(installId)) {
    throw new ApiError(400, "invalid_request_error", "installId must be 8-64 characters of [A-Za-z0-9_-]");
  }

  // IP(IPv4 주소 / IPv6 /64)당 제한. 새 계정(무료 크레딧 대상)은 엄격하게, 이미 있는 installId 의 토큰 재발급은
  // 따로 느슨하게 센다(모바일 CGNAT 로 많은 사용자가 한 IP 를 쓰는 경우 재로그인이 막히지 않도록).
  const ip = clientIpKey(req);
  const exists = await env.DB.prepare("SELECT 1 AS x FROM accounts WHERE install_id = ?").bind(installId).first();
  if (exists) {
    await enforceRateLimit(env.DB, `rereg:${ip}`, cfg.reregisterLimit, cfg.registerWindowSeconds, now);
  } else {
    await enforceRateLimit(env.DB, `reg:${ip}`, cfg.registerLimit, cfg.registerWindowSeconds, now);
  }

  // INTEGRITY_MODE: off 면 예전과 같고, grant 면 통과한 새 설치만 무료 크레딧, require 면 통과해야 가입.
  // 서비스 계정이 없으면(unavailable) 오류 대신 무료 크레딧 0 으로 가입시킨다.
  let integrity: IntegrityOutcome | undefined;
  if (cfg.integrityMode !== "off") {
    integrity = await verifyRegistrationIntegrity(env, cfg, body, now);
    if (cfg.integrityMode === "require" && integrity !== "ok" && integrity !== "unavailable") {
      throw new ApiError(403, "integrity_failed", `device integrity check ${integrity}`);
    }
  }
  let freeCredits = integrity === undefined || integrity === "ok" ? cfg.freeCredits : 0;

  // 하루 전체 무료 크레딧 상한. 새 계정일 때만 미리 잡아 두고, 계정이 이미 있었으면 되돌린다.
  let heldDaily = 0;
  if (freeCredits > 0 && !exists) {
    if (await tryAddDaily(env.DB, FREE_CREDITS_DAILY_KEY, freeCredits, cfg.freeCreditsDailyCap, now)) {
      heldDaily = freeCredits;
    } else {
      console.warn("오늘의 무료 크레딧 상한(FREE_CREDITS_DAILY_CAP)에 도달, 새 계정에 0 지급");
      freeCredits = 0;
    }
  } else if (exists) {
    freeCredits = 0;
  }

  let result: RegisterResult;
  try {
    result = await registerInstall(env.DB, installId, freeCredits, now);
  } catch (err) {
    await subtractDaily(env.DB, FREE_CREDITS_DAILY_KEY, heldDaily, now).catch(() => undefined);
    throw err;
  }
  if (heldDaily > 0 && !result.freeGranted) await subtractDaily(env.DB, FREE_CREDITS_DAILY_KEY, heldDaily, now);
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
