// 암호·인코딩·시간 도우미(WebCrypto 만 사용).

export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

export function base64UrlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64UrlEncodeString(s: string): string {
  return base64UrlEncode(new TextEncoder().encode(s));
}

export function base64Decode(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** 32바이트 난수 토큰(base64url, 43자). */
export function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

export async function sha256Bytes(s: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
}

export function toHex(bytes: Uint8Array): string {
  let hex = "";
  for (const b of bytes) hex += b.toString(16).padStart(2, "0");
  return hex;
}

export async function sha256Hex(s: string): Promise<string> {
  return toHex(await sha256Bytes(s));
}

/** HMAC-SHA256(key, message) 의 hex. */
export async function hmacSha256Hex(key: string, message: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(key), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  return toHex(new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(message))));
}

/** base64url(패딩 유무 무관)을 바이트로. 형식이 틀리면 예외. */
export function base64UrlDecode(s: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*={0,2}$/.test(s)) throw new Error("invalid base64url");
  const b64 = s.replace(/=+$/, "").replace(/-/g, "+").replace(/_/g, "/");
  return base64Decode(b64 + "=".repeat((4 - (b64.length % 4)) % 4));
}

/** 길이와 무관하게 일정 시간 비교: 양쪽을 SHA-256 으로 고정 길이로 만든 뒤 XOR 누적. */
export async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const [ha, hb] = await Promise.all([sha256Bytes(a), sha256Bytes(b)]);
  let diff = 0;
  for (let i = 0; i < ha.length; i++) diff |= (ha[i] ?? 0) ^ (hb[i] ?? 0);
  return diff === 0;
}
