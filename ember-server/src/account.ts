// POST /ember/register, GET /ember/balance
//
// 가입은 두 가지다.
// - Google 로그인(idToken 있음, REQUIRE_GOOGLE_SIGNIN 기본): 계정은 Google sub 로 찾는다.
//   · sub 에 연결된 계정이 있으면 그 계정에 새 토큰을 준다(복원: 앱 재설치·기기 변경). installId 는 새 값으로 바꾼다.
//   · 없고, 이 installId 가 Google 에 연결 안 된 예전 계정의 것이면 그 계정을 이 sub 에 연결한다(앱 업데이트).
//   · 둘 다 아니면 새 계정을 만든다. 무료 크레딧은 Google 계정당 평생 한 번(free_credit_grants, 탈퇴해도 남음).
// - 예전 방식(idToken 없음, REQUIRE_GOOGLE_SIGNIN = "false" 일 때만): installId 로 찾거나 만든다.
import { authenticate, googleRequiredError, legacyUnlinkedExpired } from "./auth";
import type { Config, Env } from "./env";
import { balanceBreakdown } from "./billing/lots";
import { detachInstallStmt, linkFreeGrantStmt, recordFreeGrantStmt, subHashOf, verifyGoogleSignIn } from "./google/identity";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { verifyRegistrationIntegrity, type IntegrityOutcome } from "./play/integrity";
import { clientIpKey, enforceRateLimit, subtractDaily, tryAddDaily } from "./ratelimit";
import { nowSeconds, randomToken, sha256Hex } from "./util";

// 무결성 토큰(수 KB)과 ID 토큰(1~2 KB)이 들어갈 수 있게 넉넉히 둔다.
const REGISTER_BODY_MAX = 32 * 1024;
const INSTALL_ID_RE = /^[A-Za-z0-9_-]{8,64}$/;
/** 보관 정리(retention.ts)가 만료 계정에 쓰는 installId 접두사. 가입에 쓰지 못하게 막는다. */
const RESERVED_INSTALL_PREFIX = "expired-";

export interface RegisterResult {
  token: string;
  credits: number;
  freeGranted: boolean;
  /** 이미 있던 계정에 새 토큰을 준 경우 true(Google 복원, 예전 계정 연결, 같은 installId 재등록) */
  restored: boolean;
}

/** 하루 무료 크레딧 지급 합계 카운터(rate_limits 표, window_start = UTC 0시) */
export const FREE_CREDITS_DAILY_KEY = "free:day";

interface InstallOwner {
  id: number;
  google_sub: string | null;
  disabled: number;
}

export async function handleRegister(req: Request, env: Env, cfg: Config): Promise<Response> {
  const now = nowSeconds();
  const body = await readJsonObject(req, REGISTER_BODY_MAX);
  const installId = body["installId"];
  if (typeof installId !== "string" || !INSTALL_ID_RE.test(installId) || installId.startsWith(RESERVED_INSTALL_PREFIX)) {
    throw new ApiError(400, "invalid_request_error", "installId must be 8-64 characters of [A-Za-z0-9_-]");
  }
  const idToken = body["idToken"];
  if (idToken === undefined || idToken === null || idToken === "") {
    if (cfg.requireGoogleSignin) {
      throw new ApiError(400, "google_required", "idToken is required: sign in with Google");
    }
    return legacyRegister(req, env, cfg, body, installId, now);
  }
  return googleRegister(req, env, cfg, body, installId, idToken, now);
}

/** INTEGRITY_MODE 확인(off 면 undefined). require 에서 통과 못 하면 403. */
async function checkIntegrity(env: Env, cfg: Config, body: Record<string, unknown>, now: number): Promise<IntegrityOutcome | undefined> {
  if (cfg.integrityMode === "off") return undefined;
  const integrity = await verifyRegistrationIntegrity(env, cfg, body, now);
  if (cfg.integrityMode === "require" && integrity !== "ok" && integrity !== "unavailable") {
    throw new ApiError(403, "integrity_failed", `device integrity check ${integrity}`);
  }
  return integrity;
}

function withIntegrity(result: RegisterResult, integrity: IntegrityOutcome | undefined): Response {
  return jsonResponse(integrity === undefined ? result : { ...result, integrity });
}

/** 하루 무료 크레딧 상한을 미리 잡는다. 잡은 양(못 잡으면 0)을 돌려준다. */
async function holdDaily(env: Env, cfg: Config, amount: number, now: number): Promise<number> {
  if (amount <= 0) return 0;
  if (await tryAddDaily(env.DB, FREE_CREDITS_DAILY_KEY, amount, cfg.freeCreditsDailyCap, now)) return amount;
  console.warn("오늘의 무료 크레딧 상한(FREE_CREDITS_DAILY_CAP)에 도달, 새 계정에 0 지급");
  return 0;
}

async function googleRegister(
  req: Request,
  env: Env,
  cfg: Config,
  body: Record<string, unknown>,
  installId: string,
  idToken: unknown,
  now: number,
): Promise<Response> {
  const sub = await verifyGoogleSignIn(env, cfg, idToken);
  const subHash = await subHashOf(env, sub);

  const bySub = await env.DB.prepare("SELECT id, disabled FROM accounts WHERE google_sub = ?")
    .bind(sub)
    .first<{ id: number; disabled: number }>();
  const byInstall = await env.DB.prepare("SELECT id, google_sub, disabled FROM accounts WHERE install_id = ?")
    .bind(installId)
    .first<InstallOwner>();
  const linkLegacy = !bySub && byInstall !== null && byInstall.google_sub === null;
  const existing = bySub !== null || linkLegacy;

  // IP 당 제한: 새 계정(무료 크레딧 대상)은 엄격하게, 복원·연결은 느슨하게(모바일 CGNAT).
  const ip = clientIpKey(req);
  if (existing) await enforceRateLimit(env.DB, `rereg:${ip}`, cfg.reregisterLimit, cfg.registerWindowSeconds, now);
  else await enforceRateLimit(env.DB, `reg:${ip}`, cfg.registerLimit, cfg.registerWindowSeconds, now);

  const integrity = await checkIntegrity(env, cfg, body, now);

  if (bySub) {
    if (bySub.disabled) throw new ApiError(403, "permission_error", "this account has been disabled");
    return withIntegrity(await restoreBySub(env.DB, sub, subHash, installId, now), integrity);
  }
  if (linkLegacy) {
    if (byInstall!.disabled) throw new ApiError(403, "permission_error", "this account has been disabled");
    return withIntegrity(await linkLegacyByInstall(env.DB, installId, sub, subHash, now), integrity);
  }

  // 새 계정. 무료 크레딧: 무결성 통과(또는 off) + 이 Google 계정이 받은 적 없음 + 하루 상한 안.
  let freeCredits = integrity === undefined || integrity === "ok" ? cfg.freeCredits : 0;
  if (freeCredits > 0) {
    const used = await env.DB.prepare("SELECT 1 AS x FROM free_credit_grants WHERE sub_hash = ?").bind(subHash).first();
    if (used) {
      console.log("이미 무료 크레딧을 받은 Google 계정의 새 계정: 무료 크레딧 0");
      freeCredits = 0;
    }
  }
  const held = await holdDaily(env, cfg, freeCredits, now);
  if (held === 0) freeCredits = 0;

  let result: RegisterResult;
  try {
    result = await createGoogleAccount(env.DB, installId, sub, subHash, freeCredits, now);
  } catch (err) {
    await subtractDaily(env.DB, FREE_CREDITS_DAILY_KEY, held, now).catch(() => undefined);
    throw err;
  }
  if (held > 0 && !result.freeGranted) await subtractDaily(env.DB, FREE_CREDITS_DAILY_KEY, held, now);
  return withIntegrity(result, integrity);
}

/** sub 에 연결된 계정에 새 토큰을 준다. installId 는 다른 예전 계정이 쓰고 있지 않으면 새 값으로 바꾼다. */
async function restoreBySub(
  db: D1Database,
  sub: string,
  subHash: string,
  installId: string,
  now: number,
): Promise<RegisterResult> {
  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const results = await db.batch([
    detachInstallStmt(db, installId, sub),
    db
      .prepare(
        `UPDATE accounts SET token_hash = ?, updated_at = ?, last_used_at = ?,
           install_id = CASE WHEN EXISTS (SELECT 1 FROM accounts o WHERE o.install_id = ? AND o.id <> accounts.id)
                             THEN install_id ELSE ? END
         WHERE google_sub = ? AND disabled = 0
         RETURNING credits`,
      )
      .bind(tokenHash, now, now, installId, installId, sub),
    linkFreeGrantStmt(db, subHash, sub),
  ]);
  const row = results[1]?.results[0] as { credits: number } | undefined;
  if (!row) throw new ApiError(403, "permission_error", "this account has been disabled");
  return { token, credits: row.credits, freeGranted: false, restored: true };
}

/** 이 installId 의 연결 안 된 예전 계정을 sub 에 연결하고 새 토큰을 준다(무료 크레딧은 다시 주지 않는다). */
async function linkLegacyByInstall(
  db: D1Database,
  installId: string,
  sub: string,
  subHash: string,
  now: number,
): Promise<RegisterResult> {
  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const results = await db.batch([
    db
      .prepare(
        `UPDATE accounts SET google_sub = ?, token_hash = ?, updated_at = ?, last_used_at = ?
         WHERE install_id = ? AND google_sub IS NULL AND disabled = 0
           AND NOT EXISTS (SELECT 1 FROM accounts o WHERE o.google_sub = ?)
         RETURNING credits`,
      )
      .bind(sub, tokenHash, now, now, installId, sub),
    recordFreeGrantStmt(db, subHash, sub, now),
    linkFreeGrantStmt(db, subHash, sub),
  ]);
  const row = results[0]?.results[0] as { credits: number } | undefined;
  if (!row) throw new ApiError(500, "api_error", "could not register this install, please retry");
  return { token, credits: row.credits, freeGranted: false, restored: true };
}

/**
 * sub 에 연결된 새 계정을 만든다. 무료 크레딧은 한 트랜잭션 안에서 free_credit_grants 를 다시 확인해 정하고,
 * 지급했으면 해시를 기록한다(동시 요청이 와도 Google 계정당 한 번). 동시에 같은 sub 로 계정이 생겼으면 그 계정을 복원한다.
 */
async function createGoogleAccount(
  db: D1Database,
  installId: string,
  sub: string,
  subHash: string,
  freeCredits: number,
  now: number,
): Promise<RegisterResult> {
  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const results = await db.batch([
    detachInstallStmt(db, installId, sub),
    db
      .prepare(
        `INSERT INTO accounts (install_id, token_hash, credits, free_credits, google_sub, created_at, updated_at, last_used_at)
         SELECT ?, ?, c, c, ?, ?, ?, ?
         FROM (SELECT CASE WHEN EXISTS (SELECT 1 FROM free_credit_grants WHERE sub_hash = ?) THEN 0 ELSE ? END AS c)
         WHERE 1
         ON CONFLICT DO NOTHING
         RETURNING credits, free_credits`,
      )
      .bind(installId, tokenHash, sub, now, now, now, subHash, freeCredits),
    recordFreeGrantStmt(db, subHash, sub, now),
    linkFreeGrantStmt(db, subHash, sub),
  ]);
  const row = results[1]?.results[0] as { credits: number; free_credits: number } | undefined;
  if (row) return { token, credits: row.credits, freeGranted: row.free_credits > 0, restored: false };

  // 동시에 같은 sub(또는 installId)로 계정이 생겼다. sub 의 계정이면 복원한다.
  const again = await db.prepare("SELECT disabled FROM accounts WHERE google_sub = ?").bind(sub).first<{ disabled: number }>();
  if (again && !again.disabled) return restoreBySub(db, sub, subHash, installId, now);
  throw new ApiError(500, "api_error", "could not register this install, please retry");
}

/** 예전 방식(idToken 없음). REQUIRE_GOOGLE_SIGNIN = "false" 일 때만 온다. */
async function legacyRegister(
  req: Request,
  env: Env,
  cfg: Config,
  body: Record<string, unknown>,
  installId: string,
  now: number,
): Promise<Response> {
  if (legacyUnlinkedExpired(env, now)) throw googleRequiredError();
  const owner = await env.DB.prepare("SELECT id, google_sub, disabled FROM accounts WHERE install_id = ?")
    .bind(installId)
    .first<InstallOwner>();
  if (owner && owner.google_sub !== null) {
    // Google 에 연결된 계정은 installId 만으로 토큰을 받을 수 없다.
    throw new ApiError(400, "google_required", "this account is linked to Google: idToken is required");
  }

  // IP(IPv4 주소 / IPv6 /64)당 제한. 새 계정(무료 크레딧 대상)은 엄격하게, 이미 있는 installId 의 토큰 재발급은
  // 따로 느슨하게 센다(모바일 CGNAT 로 많은 사용자가 한 IP 를 쓰는 경우 재로그인이 막히지 않도록).
  const ip = clientIpKey(req);
  if (owner) {
    await enforceRateLimit(env.DB, `rereg:${ip}`, cfg.reregisterLimit, cfg.registerWindowSeconds, now);
  } else {
    await enforceRateLimit(env.DB, `reg:${ip}`, cfg.registerLimit, cfg.registerWindowSeconds, now);
  }

  // INTEGRITY_MODE: off 면 예전과 같고, grant 면 통과한 새 설치만 무료 크레딧, require 면 통과해야 가입.
  // 서비스 계정이 없으면(unavailable) 오류 대신 무료 크레딧 0 으로 가입시킨다.
  const integrity = await checkIntegrity(env, cfg, body, now);
  let freeCredits = owner ? 0 : integrity === undefined || integrity === "ok" ? cfg.freeCredits : 0;

  // 하루 전체 무료 크레딧 상한. 새 계정일 때만 미리 잡아 두고, 계정이 이미 있었으면 되돌린다.
  const held = await holdDaily(env, cfg, freeCredits, now);
  if (held === 0) freeCredits = 0;

  let result: RegisterResult;
  try {
    result = await registerInstall(env.DB, installId, freeCredits, now);
  } catch (err) {
    await subtractDaily(env.DB, FREE_CREDITS_DAILY_KEY, held, now).catch(() => undefined);
    throw err;
  }
  if (held > 0 && !result.freeGranted) await subtractDaily(env.DB, FREE_CREDITS_DAILY_KEY, held, now);
  return withIntegrity(result, integrity);
}

/**
 * (예전 방식) 설치 ID 로 계정을 만들거나 찾는다. 새 토큰을 발급해 이전 토큰은 무효가 된다.
 * 무료 크레딧은 계정이 처음 만들어질 때(INSERT 성공)만 지급된다. freeCredits 가 0 이면 freeGranted 는 false.
 * Google 에 연결된 계정은 installId 로 토큰을 주지 않는다.
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
      `INSERT INTO accounts (install_id, token_hash, credits, free_credits, created_at, updated_at, last_used_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (install_id) DO NOTHING
       RETURNING credits`,
    )
    .bind(installId, tokenHash, freeCredits, freeCredits, now, now, now)
    .first<{ credits: number }>();
  if (inserted) return { token, credits: inserted.credits, freeGranted: freeCredits > 0, restored: false };

  const updated = await db
    .prepare(
      `UPDATE accounts SET token_hash = ?, updated_at = ?, last_used_at = ? WHERE install_id = ? AND google_sub IS NULL
       RETURNING credits, disabled`,
    )
    .bind(tokenHash, now, now, installId)
    .first<{ credits: number; disabled: number }>();
  if (!updated) throw new ApiError(400, "google_required", "this account is linked to Google: idToken is required");
  if (updated.disabled) throw new ApiError(403, "permission_error", "this account has been disabled");
  return { token, credits: updated.credits, freeGranted: false, restored: true };
}

/**
 * GET /ember/balance → { credits, freeCredits, paidCredits, expiringSoon: { credits, at } | null }
 * credits(전체)는 예전 앱 호환용으로 그대로 둔다. at 은 유닉스 초. 인증하면서 마지막 사용 시각이 갱신된다.
 */
export async function handleBalance(req: Request, env: Env): Promise<Response> {
  const account = await authenticate(env, req);
  return jsonResponse(await balanceBreakdown(env.DB, account.id, nowSeconds()));
}
