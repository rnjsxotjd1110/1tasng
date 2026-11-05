// 서비스 계정 JSON 으로 Google OAuth 액세스 토큰을 발급받는다(RS256 JWT, WebCrypto).
import { isRecord } from "../http";
import { base64Decode, base64UrlEncode, base64UrlEncodeString } from "../util";

export const ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";
const JWT_LIFETIME_SECONDS = 3600;
/** 만료 이 시간(ms) 전에 미리 새로 받는다. */
const REFRESH_MARGIN_MS = 60_000;

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
}

export function parseServiceAccount(json: string): ServiceAccount {
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON is not valid JSON");
  }
  if (!isRecord(parsed)) throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON must be an object");
  const email = parsed["client_email"];
  const key = parsed["private_key"];
  const tokenUri = parsed["token_uri"];
  if (typeof email !== "string" || typeof key !== "string") {
    throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON is missing client_email or private_key");
  }
  return { client_email: email, private_key: key, token_uri: typeof tokenUri === "string" ? tokenUri : DEFAULT_TOKEN_URI };
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  return crypto.subtle.importKey(
    "pkcs8",
    base64Decode(b64),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** 서명된 JWT(assertion)를 만든다. */
export async function signServiceAccountJwt(sa: ServiceAccount, scope: string, nowSec: number): Promise<string> {
  const header = base64UrlEncodeString(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64UrlEncodeString(
    JSON.stringify({
      iss: sa.client_email,
      scope,
      aud: sa.token_uri,
      iat: nowSec,
      exp: nowSec + JWT_LIFETIME_SECONDS,
    }),
  );
  const input = `${header}.${claims}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
  return `${input}.${base64UrlEncode(new Uint8Array(sig))}`;
}

interface CachedToken {
  email: string;
  token: string;
  expiresAtMs: number;
}

// 아이솔레이트 단위 캐시(요청 사이에 재사용된다).
let cached: CachedToken | null = null;

export function clearGoogleTokenCache(): void {
  cached = null;
}

export async function getGoogleAccessToken(saJson: string, nowMs: number = Date.now()): Promise<string> {
  const sa = parseServiceAccount(saJson);
  if (cached && cached.email === sa.client_email && cached.expiresAtMs - REFRESH_MARGIN_MS > nowMs) {
    return cached.token;
  }
  const assertion = await signServiceAccountJwt(sa, ANDROID_PUBLISHER_SCOPE, Math.floor(nowMs / 1000));
  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }).toString(),
  });
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok || !isRecord(data) || typeof data["access_token"] !== "string") {
    throw new Error(`Google OAuth token request failed (${res.status})`);
  }
  const expiresIn = typeof data["expires_in"] === "number" ? data["expires_in"] : JWT_LIFETIME_SECONDS;
  cached = { email: sa.client_email, token: data["access_token"], expiresAtMs: nowMs + expiresIn * 1000 };
  return cached.token;
}
