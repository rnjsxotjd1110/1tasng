// 가짜 Google(OAuth 토큰, Voided Purchases API, Play Integrity decodeIntegrityToken).
// 진짜 RSA 키로 서비스 계정을 만들고, 토큰 엔드포인트는 JWT 서명을 실제로 검증한다.
// 액세스 토큰은 scope 마다 다르게 주고, 각 API 는 자기 scope 의 토큰만 받는다.
import { vi } from "vitest";
import { ANDROID_PUBLISHER_SCOPE, PLAY_INTEGRITY_SCOPE } from "../../src/play/google-auth";
import { base64Decode } from "../../src/util";

export const TOKEN_URI = "https://oauth2.googleapis.com/token";
export const PACKAGE = "app.ember.ideas";
export const VOIDED_URL = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/voidedpurchases`;
export const DECODE_URL = `https://playintegrity.googleapis.com/v1/${PACKAGE}:decodeIntegrityToken`;

const ACCESS_TOKENS: Record<string, string> = {
  [ANDROID_PUBLISHER_SCOPE]: "ya29.publisher",
  [PLAY_INTEGRITY_SCOPE]: "ya29.integrity",
};

export interface FakeVoided {
  purchaseToken: string;
  orderId?: string;
  voidedTimeMillis?: string;
  voidedSource?: number;
  voidedReason?: number;
  voidedQuantity?: number;
}

export interface FakeGoogle {
  saJson: string;
  /** scope → 토큰 발급 횟수 */
  tokenRequests: Record<string, number>;
  voidedRequests: URL[];
  /** 페이지별 환불 목록. 다음 페이지가 있으면 nextPageToken = "page<i+1>" */
  voidedPages: FakeVoided[][];
  /** 0 이 아니면 환불 목록 요청에 이 상태 코드로 실패 */
  voidedFailStatus: number;
  decodeRequests: { body: unknown }[];
  /** 무결성 토큰 → tokenPayloadExternal. 없는 토큰은 400 */
  integrityPayloads: Map<string, unknown>;
  /** 0 이 아니면 decode 요청에 이 상태 코드로 실패 */
  decodeFailStatus: number;
}

function pem(der: ArrayBuffer): string {
  const b64 = btoa(String.fromCharCode(...new Uint8Array(der)));
  return `-----BEGIN PRIVATE KEY-----\n${b64.match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----\n`;
}

function b64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
  return base64Decode(b64);
}

let keyPair: Promise<CryptoKeyPair> | null = null;
function keys(): Promise<CryptoKeyPair> {
  keyPair ??= crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  ) as Promise<CryptoKeyPair>;
  return keyPair;
}

/** 통과하는 판정. overrides 로 일부를 바꾼다. */
export function passingPayload(nonce: string, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    requestDetails: { requestPackageName: PACKAGE, nonce, timestampMillis: String(Date.now()) },
    appIntegrity: {
      appRecognitionVerdict: "PLAY_RECOGNIZED",
      packageName: PACKAGE,
      certificateSha256Digest: ["abc"],
      versionCode: "42",
    },
    deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY", "MEETS_DEVICE_INTEGRITY"] },
    accountDetails: { appLicensingVerdict: "LICENSED" },
    ...overrides,
  };
}

/** fetch 를 가짜 Google 로 바꾼다. 다른 주소는 passthrough(없으면 오류). */
export async function installFakeGoogle(passthrough?: (req: Request) => Promise<Response>): Promise<FakeGoogle> {
  const { privateKey, publicKey } = await keys();
  const g: FakeGoogle = {
    saJson: JSON.stringify({
      type: "service_account",
      client_email: "ember@test-project.iam.gserviceaccount.com",
      private_key: pem((await crypto.subtle.exportKey("pkcs8", privateKey)) as ArrayBuffer),
      token_uri: TOKEN_URI,
    }),
    tokenRequests: {},
    voidedRequests: [],
    voidedPages: [[]],
    voidedFailStatus: 0,
    decodeRequests: [],
    integrityPayloads: new Map(),
    decodeFailStatus: 0,
  };

  const requireToken = (req: Request, scope: string): Response | null =>
    req.headers.get("authorization") === `Bearer ${ACCESS_TOKENS[scope]}`
      ? null
      : Response.json({ error: { code: 401, status: "UNAUTHENTICATED" } }, { status: 401 });

  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const req = new Request(input, init);
      const url = new URL(req.url);

      if (req.url === TOKEN_URI) {
        const form = new URLSearchParams(await req.text());
        if (form.get("grant_type") !== "urn:ietf:params:oauth:grant-type:jwt-bearer") return new Response("{}", { status: 400 });
        const [h, c, s] = form.get("assertion")!.split(".");
        const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey, b64urlToBytes(s!), new TextEncoder().encode(`${h}.${c}`));
        if (!ok) return new Response("{}", { status: 400 });
        const claims = JSON.parse(new TextDecoder().decode(b64urlToBytes(c!))) as Record<string, unknown>;
        const scope = String(claims["scope"]);
        const accessToken = ACCESS_TOKENS[scope];
        if (!accessToken || claims["aud"] !== TOKEN_URI) return new Response("{}", { status: 400 });
        g.tokenRequests[scope] = (g.tokenRequests[scope] ?? 0) + 1;
        return Response.json({ access_token: accessToken, expires_in: 3599, token_type: "Bearer" });
      }

      if (`${url.origin}${url.pathname}` === VOIDED_URL && req.method === "GET") {
        const denied = requireToken(req, ANDROID_PUBLISHER_SCOPE);
        if (denied) return denied;
        g.voidedRequests.push(url);
        if (g.voidedFailStatus) return Response.json({ error: { code: g.voidedFailStatus } }, { status: g.voidedFailStatus });
        const token = url.searchParams.get("token");
        const page = token ? Number(token.replace("page", "")) : 0;
        const items = g.voidedPages[page] ?? [];
        const next = page + 1 < g.voidedPages.length ? `page${page + 1}` : undefined;
        return Response.json({
          ...(next ? { tokenPagination: { nextPageToken: next } } : {}),
          ...(items.length ? { voidedPurchases: items.map((v) => ({ kind: "androidpublisher#voidedPurchase", ...v })) } : {}),
        });
      }

      if (req.url === DECODE_URL && req.method === "POST") {
        const denied = requireToken(req, PLAY_INTEGRITY_SCOPE);
        if (denied) return denied;
        const body = (await req.json()) as Record<string, unknown>;
        g.decodeRequests.push({ body });
        if (g.decodeFailStatus) return Response.json({ error: { code: g.decodeFailStatus } }, { status: g.decodeFailStatus });
        const payload = g.integrityPayloads.get(String(body["integrity_token"]));
        if (payload === undefined) {
          return Response.json({ error: { code: 400, status: "INVALID_ARGUMENT", message: "Invalid integrity token" } }, { status: 400 });
        }
        return Response.json({ tokenPayloadExternal: payload });
      }

      if (passthrough) return passthrough(req);
      throw new Error(`unexpected fetch ${req.method} ${req.url}`);
    }),
  );
  return g;
}
