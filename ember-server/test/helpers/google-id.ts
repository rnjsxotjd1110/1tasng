// 가짜 Google ID 토큰: 진짜 RSA 키로 서명하고, 그 공개키(JWKS)를 검증기 캐시에 넣는다(네트워크 없음).
import { primeGoogleJwksCache } from "../../src/google/id-token";
import { base64UrlEncode, base64UrlEncodeString } from "../../src/util";

export const TEST_CLIENT_ID = "123456789-test.apps.googleusercontent.com";
export const TEST_KID = "test-kid-1";

let keyPair: Promise<CryptoKeyPair> | null = null;
export function googleKeys(): Promise<CryptoKeyPair> {
  keyPair ??= crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  ) as Promise<CryptoKeyPair>;
  return keyPair;
}

/** 테스트 키의 JWKS(Google 형식) */
export async function testJwks(kid = TEST_KID): Promise<{ keys: Record<string, unknown>[] }> {
  const { publicKey } = await googleKeys();
  const jwk = (await crypto.subtle.exportKey("jwk", publicKey)) as JsonWebKey;
  return { keys: [{ kty: "RSA", alg: "RS256", use: "sig", kid, n: jwk.n, e: jwk.e }] };
}

/** 검증기 캐시에 테스트 JWKS 를 넣는다(1시간 유효). */
export async function primeTestJwks(): Promise<void> {
  primeGoogleJwksCache(await testJwks(), Date.now() + 3600_000);
}

export interface IdTokenOptions {
  claims?: Record<string, unknown>;
  header?: Record<string, unknown>;
  /** 다른 키로 서명(위조) */
  signWith?: CryptoKey;
}

/** sub 의 유효한 ID 토큰. claims 로 덮어쓰거나(undefined 면 그 클레임을 뺀다) 다른 키로 서명할 수 있다. */
export async function makeIdToken(sub: string, opts: IdTokenOptions = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claims: Record<string, unknown> = {
    iss: "https://accounts.google.com",
    azp: "android-client.apps.googleusercontent.com",
    aud: TEST_CLIENT_ID,
    sub,
    email: "someone@example.com",
    email_verified: true,
    name: "Some One",
    iat: now,
    exp: now + 3600,
    ...opts.claims,
  };
  for (const [k, v] of Object.entries(claims)) if (v === undefined) delete claims[k];
  const header = { alg: "RS256", kid: TEST_KID, typ: "JWT", ...opts.header };
  const input = `${base64UrlEncodeString(JSON.stringify(header))}.${base64UrlEncodeString(JSON.stringify(claims))}`;
  const key = opts.signWith ?? (await googleKeys()).privateKey;
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
  return `${input}.${base64UrlEncode(new Uint8Array(sig))}`;
}

/** 캐시를 채우고 sub 의 ID 토큰을 만든다(가입·연결 테스트용). */
export async function idTokenFor(sub: string, opts: IdTokenOptions = {}): Promise<string> {
  await primeTestJwks();
  return makeIdToken(sub, opts);
}
