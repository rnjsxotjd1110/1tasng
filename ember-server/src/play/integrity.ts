// Play Integrity: GET /ember/nonce 로 일회용 nonce 를 주고, 가입 때 받은 무결성 토큰을 Google 에서 해독해 확인한다.
//
// nonce 형식: 24바이트 난수의 base64url(패딩 없음, 32자, [A-Za-z0-9_-]).
// 앱은 이 문자열을 그대로 IntegrityTokenRequest.setNonce(nonce) 에 넣는다(다시 인코딩하지 않는다).
// Google 이 토큰 안에 되돌려 주는 requestDetails.nonce 도 base64 이지만, 표준 알파벳(+ /)이나
// '=' 패딩이 붙어 올 수 있으므로 normalizeNonce 로 base64url·무패딩 형태로 맞춘 뒤 비교한다.
import type { Config, Env } from "../env";
import { ApiError, isRecord, jsonResponse } from "../http";
import { enforceRateLimit } from "../ratelimit";
import { base64UrlEncode, nowSeconds } from "../util";
import { googleFetch, PLAY_INTEGRITY_SCOPE } from "./google-auth";

export const NONCE_BYTES = 24;
export const NONCE_TTL_SECONDS = 300;
const NONCE_RE = /^[A-Za-z0-9_-]{16,128}$/;
/** 무결성 토큰 최대 길이(실제는 수 KB) */
export const MAX_INTEGRITY_TOKEN_LENGTH = 16 * 1024;

export const REQUIRED_APP_VERDICT = "PLAY_RECOGNIZED";
export const REQUIRED_DEVICE_VERDICT = "MEETS_DEVICE_INTEGRITY";

/** ok: 통과, failed: 토큰·nonce·판정이 틀림, missing: 토큰이나 nonce 를 보내지 않음 */
export type IntegrityOutcome = "ok" | "failed" | "missing";

export function randomNonce(): string {
  const bytes = new Uint8Array(NONCE_BYTES);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

/** base64/base64url, 패딩 유무와 관계없이 base64url·무패딩 형태로 맞춘다. */
export function normalizeNonce(s: string): string {
  return s.replace(/\s+/g, "").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

export async function handleNonce(req: Request, env: Env, cfg: Config): Promise<Response> {
  const now = nowSeconds();
  const ip = req.headers.get("cf-connecting-ip") ?? "unknown";
  await enforceRateLimit(env.DB, `nonce:${ip}`, cfg.registerLimit, cfg.registerWindowSeconds, now);
  const nonce = randomNonce();
  await env.DB.prepare("INSERT INTO nonces (nonce, expires_at) VALUES (?, ?)")
    .bind(nonce, now + NONCE_TTL_SECONDS)
    .run();
  return jsonResponse({ nonce });
}

/** 만료 전이고 아직 안 쓴 nonce 면 지우고(한 번만 쓰도록) true. */
export async function consumeNonce(db: D1Database, nonce: string, now: number): Promise<boolean> {
  const row = await db
    .prepare("DELETE FROM nonces WHERE nonce = ? AND expires_at > ? RETURNING nonce")
    .bind(nonce, now)
    .first<{ nonce: string }>();
  return row !== null;
}

export async function purgeExpiredNonces(db: D1Database, now: number): Promise<void> {
  await db.prepare("DELETE FROM nonces WHERE expires_at <= ?").bind(now).run();
}

export function decodeTokenUrl(packageName: string): string {
  return `https://playintegrity.googleapis.com/v1/${encodeURIComponent(packageName)}:decodeIntegrityToken`;
}

export type DecodeResult =
  | { kind: "ok"; payload: unknown }
  /** Google 이 토큰을 거절함(형식 오류·다른 앱의 토큰 등) */
  | { kind: "invalid"; status: number }
  /** 일시 오류(네트워크·5xx·할당량·권한 설정 문제) */
  | { kind: "error"; status: number };

export async function decodeIntegrityToken(
  serviceAccountJson: string,
  packageName: string,
  integrityToken: string,
): Promise<DecodeResult> {
  const res = await googleFetch(serviceAccountJson, PLAY_INTEGRITY_SCOPE, decodeTokenUrl(packageName), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ integrity_token: integrityToken }),
  });
  if (res.status === 400) {
    console.warn("Play Integrity 토큰 거절:", await res.text().catch(() => ""));
    return { kind: "invalid", status: res.status };
  }
  if (!res.ok) {
    console.error("Play Integrity 해독 실패:", res.status, await res.text().catch(() => ""));
    return { kind: "error", status: res.status };
  }
  const data: unknown = await res.json().catch(() => null);
  if (!isRecord(data)) return { kind: "error", status: 502 };
  return { kind: "ok", payload: data["tokenPayloadExternal"] };
}

/** 해독된 판정(tokenPayloadExternal)을 확인한다. 통과면 null, 아니면 실패 이유. */
export function checkIntegrityPayload(payload: unknown, expectedNonce: string, packageName: string): string | null {
  if (!isRecord(payload)) return "missing tokenPayloadExternal";
  const request = payload["requestDetails"];
  if (!isRecord(request)) return "missing requestDetails";
  const nonce = request["nonce"];
  if (typeof nonce !== "string" || normalizeNonce(nonce) !== expectedNonce) return "nonce mismatch";
  if (request["requestPackageName"] !== packageName) return "package name mismatch";

  const app = payload["appIntegrity"];
  if (!isRecord(app) || app["appRecognitionVerdict"] !== REQUIRED_APP_VERDICT) return "app not recognized by Play";

  const device = payload["deviceIntegrity"];
  const verdicts = isRecord(device) ? device["deviceRecognitionVerdict"] : undefined;
  if (!Array.isArray(verdicts) || !verdicts.includes(REQUIRED_DEVICE_VERDICT)) return "device integrity not met";
  return null;
}

/**
 * 가입 본문의 integrityToken·nonce 를 확인한다.
 * nonce 는 Google 을 부르기 전에 먼저 소비하므로, 한 번 보낸 nonce 는 결과와 관계없이 다시 쓸 수 없다.
 * Google 일시 오류는 502 를 던진다(무료 크레딧 지급 여부가 영구히 정해지므로 앱이 다시 시도하게 한다).
 */
export async function verifyRegistrationIntegrity(
  env: Env,
  cfg: Config,
  body: Record<string, unknown>,
  now: number,
): Promise<IntegrityOutcome> {
  const token = body["integrityToken"];
  const rawNonce = body["nonce"];
  if (typeof token !== "string" || token === "" || typeof rawNonce !== "string" || rawNonce === "") return "missing";
  if (token.length > MAX_INTEGRITY_TOKEN_LENGTH) return "failed";
  const nonce = normalizeNonce(rawNonce);
  if (!NONCE_RE.test(nonce)) return "failed";

  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    console.error("INTEGRITY_MODE 가 켜져 있지만 GOOGLE_SERVICE_ACCOUNT_JSON 이 없음");
    throw new ApiError(500, "api_error", "integrity verification is not configured");
  }

  if (!(await consumeNonce(env.DB, nonce, now))) {
    console.warn("Play Integrity: 모르는·만료된·이미 쓴 nonce");
    return "failed";
  }

  let decoded: DecodeResult;
  try {
    decoded = await decodeIntegrityToken(env.GOOGLE_SERVICE_ACCOUNT_JSON, cfg.packageName, token);
  } catch (err) {
    console.error("Play Integrity 호출 오류:", err);
    decoded = { kind: "error", status: 502 };
  }
  if (decoded.kind === "error") {
    throw new ApiError(502, "api_error", "could not verify device integrity, please retry");
  }
  if (decoded.kind === "invalid") return "failed";

  const reason = checkIntegrityPayload(decoded.payload, nonce, cfg.packageName);
  if (reason !== null) {
    console.warn("Play Integrity 불통과:", reason);
    return "failed";
  }
  return "ok";
}
