// Google ID 토큰(Sign in with Google, Android Credential Manager) 검증. 외부 라이브러리 없이 WebCrypto 만 쓴다.
//
// - 공개키: https://www.googleapis.com/oauth2/v3/certs (JWKS). Cache-Control max-age 동안 아이솔레이트에 캐시한다.
//   모르는 kid 가 오면(키 교체 직후) 최소 간격을 두고 한 번 다시 받는다. 다시 받기에 실패하면 캐시가 만료됐더라도
//   이전 키로 검증한다(서명은 여전히 Google 의 개인키가 있어야 만들 수 있으므로 안전).
// - 확인: alg RS256 + 서명, iss(accounts.google.com 또는 https://accounts.google.com),
//   aud ∈ GOOGLE_OAUTH_CLIENT_IDS, exp/iat(시계 오차 60초), email 이 있으면 email_verified == true.
// - 결과로는 sub(구글 계정 고유 ID)만 쓴다. 이메일·이름은 저장하지도 로그에 남기지도 않는다(최소 수집).
import { isRecord } from "../http";
import { base64UrlDecode } from "../util";

export const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
export const GOOGLE_ISSUERS: readonly string[] = ["accounts.google.com", "https://accounts.google.com"];
/** exp/iat 허용 시계 오차(초) */
export const CLOCK_SKEW_SECONDS = 60;
/** ID 토큰 최대 길이(실제는 1~2 KB) */
export const MAX_ID_TOKEN_LENGTH = 8 * 1024;
const MAX_SUB_LENGTH = 255;
/** Cache-Control 이 없을 때 캐시 시간, 그리고 상한 */
const DEFAULT_JWKS_TTL_SECONDS = 3600;
const MAX_JWKS_TTL_SECONDS = 86400;
/** 모르는 kid 때문에 다시 받는 최소 간격(공격자가 가짜 kid 로 Google 을 두드리게 하지 않도록) */
const JWKS_REFETCH_MIN_INTERVAL_MS = 60_000;

/** invalid: 토큰이 틀림(401). unavailable: Google 공개키를 받지 못함(502, 재시도). */
export class GoogleIdTokenError extends Error {
  constructor(
    readonly kind: "invalid" | "unavailable",
    message: string,
  ) {
    super(message);
    this.name = "GoogleIdTokenError";
  }
}

interface JwksCache {
  keys: Map<string, JsonWebKey>;
  imported: Map<string, CryptoKey>;
  expiresAtMs: number;
  fetchedAtMs: number;
}

let jwksCache: JwksCache | null = null;

export function clearGoogleJwksCache(): void {
  jwksCache = null;
}

/** 테스트·운영 도구용: JWKS 를 직접 캐시에 넣는다(네트워크 없이 검증). */
export function primeGoogleJwksCache(jwks: unknown, expiresAtMs: number, nowMs: number = Date.now()): void {
  jwksCache = { keys: parseJwks(jwks), imported: new Map(), expiresAtMs, fetchedAtMs: nowMs };
}

export function parseJwks(data: unknown): Map<string, JsonWebKey> {
  const out = new Map<string, JsonWebKey>();
  const keys = isRecord(data) ? data["keys"] : undefined;
  if (!Array.isArray(keys)) throw new Error("JWKS has no keys array");
  for (const k of keys) {
    if (!isRecord(k)) continue;
    const kid = k["kid"];
    if (typeof kid !== "string" || k["kty"] !== "RSA") continue;
    if (k["alg"] !== undefined && k["alg"] !== "RS256") continue;
    if (k["use"] !== undefined && k["use"] !== "sig") continue;
    if (typeof k["n"] !== "string" || typeof k["e"] !== "string") continue;
    out.set(kid, { kty: "RSA", n: k["n"], e: k["e"], alg: "RS256", ext: true });
  }
  return out;
}

/** Cache-Control 의 max-age(초). 없거나 틀리면 기본값, 상한 1일. */
export function jwksTtlSeconds(cacheControl: string | null): number {
  const m = /(?:^|[,\s])max-age\s*=\s*(\d+)/i.exec(cacheControl ?? "");
  if (!m?.[1]) return DEFAULT_JWKS_TTL_SECONDS;
  return Math.min(MAX_JWKS_TTL_SECONDS, Number(m[1]));
}

async function fetchJwks(nowMs: number): Promise<JwksCache> {
  const res = await fetch(GOOGLE_JWKS_URL, { headers: { accept: "application/json" } });
  if (!res.ok) {
    await res.body?.cancel().catch(() => undefined);
    throw new Error(`JWKS request failed (${res.status})`);
  }
  const keys = parseJwks(await res.json());
  if (keys.size === 0) throw new Error("JWKS has no usable RSA keys");
  const ttl = jwksTtlSeconds(res.headers.get("cache-control"));
  return { keys, imported: new Map(), expiresAtMs: nowMs + ttl * 1000, fetchedAtMs: nowMs };
}

async function refresh(nowMs: number): Promise<void> {
  try {
    jwksCache = await fetchJwks(nowMs);
  } catch (err) {
    console.error("Google 공개키(JWKS) 받기 실패:", err);
    if (!jwksCache) throw new GoogleIdTokenError("unavailable", "could not fetch Google signing keys");
    // 이전 키로 계속 검증하되, Google 이 안 될 때 요청마다 두드리지 않도록 1분 뒤에 다시 시도한다.
    jwksCache.fetchedAtMs = nowMs;
    jwksCache.expiresAtMs = nowMs + JWKS_REFETCH_MIN_INTERVAL_MS;
  }
}

async function publicKeyFor(kid: string, nowMs: number): Promise<CryptoKey | null> {
  if (!jwksCache || jwksCache.expiresAtMs <= nowMs) await refresh(nowMs);
  let cache = jwksCache!;
  if (!cache.keys.has(kid) && nowMs - cache.fetchedAtMs >= JWKS_REFETCH_MIN_INTERVAL_MS) {
    await refresh(nowMs);
    cache = jwksCache!;
  }
  const cached = cache.imported.get(kid);
  if (cached) return cached;
  const jwk = cache.keys.get(kid);
  if (!jwk) return null;
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  cache.imported.set(kid, key);
  return key;
}

function decodeJson(part: string): Record<string, unknown> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(base64UrlDecode(part)));
  } catch {
    throw new GoogleIdTokenError("invalid", "malformed token");
  }
  if (!isRecord(parsed)) throw new GoogleIdTokenError("invalid", "malformed token");
  return parsed;
}

/**
 * ID 토큰을 검증하고 sub 를 돌려준다. 틀리면 GoogleIdTokenError("invalid"), 공개키를 못 받으면 ("unavailable").
 * clientIds 가 비어 있으면 호출하지 않는다(호출하는 쪽에서 500 으로 처리).
 */
export async function verifyGoogleIdToken(
  idToken: string,
  clientIds: readonly string[],
  nowMs: number = Date.now(),
): Promise<{ sub: string }> {
  if (idToken.length === 0 || idToken.length > MAX_ID_TOKEN_LENGTH) throw new GoogleIdTokenError("invalid", "bad token length");
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new GoogleIdTokenError("invalid", "malformed token");
  const [h, p, s] = parts as [string, string, string];
  const header = decodeJson(h);
  if (header["alg"] !== "RS256") throw new GoogleIdTokenError("invalid", "unsupported alg");
  const kid = header["kid"];
  if (typeof kid !== "string" || kid === "") throw new GoogleIdTokenError("invalid", "missing kid");
  const claims = decodeJson(p);

  let signature: Uint8Array;
  try {
    signature = base64UrlDecode(s);
  } catch {
    throw new GoogleIdTokenError("invalid", "malformed signature");
  }
  const key = await publicKeyFor(kid, nowMs);
  if (!key) throw new GoogleIdTokenError("invalid", "unknown signing key");
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, signature, new TextEncoder().encode(`${h}.${p}`));
  if (!ok) throw new GoogleIdTokenError("invalid", "bad signature");

  const iss = claims["iss"];
  if (typeof iss !== "string" || !GOOGLE_ISSUERS.includes(iss)) throw new GoogleIdTokenError("invalid", "bad issuer");
  const aud = claims["aud"];
  if (typeof aud !== "string" || !clientIds.includes(aud)) throw new GoogleIdTokenError("invalid", "bad audience");
  const now = Math.floor(nowMs / 1000);
  const exp = claims["exp"];
  if (typeof exp !== "number" || !Number.isFinite(exp) || exp + CLOCK_SKEW_SECONDS <= now) {
    throw new GoogleIdTokenError("invalid", "token expired");
  }
  const iat = claims["iat"];
  if (typeof iat !== "number" || !Number.isFinite(iat) || iat - CLOCK_SKEW_SECONDS > now) {
    throw new GoogleIdTokenError("invalid", "token issued in the future");
  }
  if (claims["email"] !== undefined) {
    const verified = claims["email_verified"];
    if (verified !== true && verified !== "true") throw new GoogleIdTokenError("invalid", "email not verified");
  }
  const sub = claims["sub"];
  if (typeof sub !== "string" || sub === "" || sub.length > MAX_SUB_LENGTH) throw new GoogleIdTokenError("invalid", "missing sub");
  return { sub };
}
