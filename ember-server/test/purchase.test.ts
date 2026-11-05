import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { clearGoogleTokenCache } from "../src/play/google-auth";
import { base64Decode, base64UrlEncode } from "../src/util";
import { call, errorBody, makeEnv, register, type TestEnv } from "./helpers/env";

const TOKEN_URI = "https://oauth2.googleapis.com/token";
const PLAY_PREFIX =
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/app.ember.ideas/purchases/products/";

interface FakeGoogle {
  saJson: string;
  tokenRequests: number;
  verifyRequests: string[];
  purchaseState: number;
  quantity?: number;
}

function pem(der: ArrayBuffer): string {
  const b64 = btoa(String.fromCharCode(...new Uint8Array(der)));
  return `-----BEGIN PRIVATE KEY-----\n${b64.match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----\n`;
}

function b64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
  return base64Decode(b64);
}

/** 진짜 RSA 키로 서비스 계정을 만들고, 토큰 엔드포인트는 JWT 서명을 실제로 검증한다. */
async function fakeGoogle(): Promise<FakeGoogle> {
  const keys = (await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
  const g: FakeGoogle = {
    saJson: JSON.stringify({
      type: "service_account",
      client_email: "ember@test-project.iam.gserviceaccount.com",
      private_key: pem(await crypto.subtle.exportKey("pkcs8", keys.privateKey) as ArrayBuffer),
      token_uri: TOKEN_URI,
    }),
    tokenRequests: 0,
    verifyRequests: [],
    purchaseState: 0,
  };

  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const req = new Request(input, init);
      if (req.url === TOKEN_URI) {
        g.tokenRequests++;
        const form = new URLSearchParams(await req.text());
        expect(form.get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:jwt-bearer");
        const [h, c, s] = form.get("assertion")!.split(".");
        const ok = await crypto.subtle.verify(
          "RSASSA-PKCS1-v1_5",
          keys.publicKey,
          b64urlToBytes(s!),
          new TextEncoder().encode(`${h}.${c}`),
        );
        if (!ok) return new Response("{}", { status: 400 });
        const claims = JSON.parse(new TextDecoder().decode(b64urlToBytes(c!))) as Record<string, unknown>;
        expect(claims["scope"]).toBe("https://www.googleapis.com/auth/androidpublisher");
        expect(claims["aud"]).toBe(TOKEN_URI);
        expect(claims["iss"]).toBe("ember@test-project.iam.gserviceaccount.com");
        return Response.json({ access_token: "ya29.fake", expires_in: 3599, token_type: "Bearer" });
      }
      if (req.url.startsWith(PLAY_PREFIX)) {
        expect(req.headers.get("authorization")).toBe("Bearer ya29.fake");
        g.verifyRequests.push(req.url);
        const [productId, , token] = req.url.slice(PLAY_PREFIX.length).split("/");
        if (decodeURIComponent(token!) === "missing-token") {
          return Response.json({ error: { code: 404 } }, { status: 404 });
        }
        return Response.json({
          kind: "androidpublisher#productPurchase",
          purchaseState: g.purchaseState,
          consumptionState: 0,
          orderId: "GPA.1234-5678",
          productId: decodeURIComponent(productId!),
          quantity: g.quantity,
          acknowledgementState: 0,
        });
      }
      throw new Error(`unexpected fetch ${req.url}`);
    }),
  );
  return g;
}

async function buy(env: TestEnv, token: string, productId: string, purchaseToken: string): Promise<Response> {
  const { res } = await call(env, "/ember/purchase", {
    method: "POST",
    json: { productId, purchaseToken },
    headers: { "x-api-key": token },
  });
  return res;
}

beforeEach(() => clearGoogleTokenCache());
afterEach(() => vi.unstubAllGlobals());

describe("POST /ember/purchase", () => {
  it("구매 완료(purchaseState 0)면 상품표만큼 지급한다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    const res = await buy(env, token, "ember_credits_1500", "tok-A");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ credits: 1750, granted: 1650 });
    expect(g.verifyRequests[0]).toBe(PLAY_PREFIX + "ember_credits_1500/tokens/tok-A");
  });

  it("같은 purchaseToken 은 두 번 지급하지 않고 현재 잔액을 돌려준다(멱등)", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    expect(await (await buy(env, token, "ember_credits_500", "tok-B")).json()).toEqual({ credits: 600, granted: 500 });
    env.db.sqlite.prepare("UPDATE accounts SET credits = credits - 50").run();
    expect(await (await buy(env, token, "ember_credits_500", "tok-B")).json()).toEqual({ credits: 550, granted: 0 });
    expect(g.verifyRequests).toHaveLength(1); // 두 번째는 Google 을 부르지 않는다
    expect(g.tokenRequests).toBe(1); // 액세스 토큰은 캐시
    expect(env.db.rows("SELECT purchase_token, credits, credited FROM purchases")).toEqual([
      { purchase_token: "tok-B", credits: 500, credited: 1 },
    ]);
  });

  it("동시에 같은 영수증이 와도 한 번만 지급한다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    const results = await Promise.all([1, 2, 3].map(() => buy(env, token, "ember_credits_5000", "tok-C")));
    const bodies = (await Promise.all(results.map((r) => r.json()))) as { credits: number; granted: number }[];
    expect(bodies.filter((b) => b.granted === 5750)).toHaveLength(1);
    expect(bodies.filter((b) => b.granted === 0)).toHaveLength(2);
    expect(env.db.rows<{ credits: number }>("SELECT credits FROM accounts")[0]!.credits).toBe(5850);
  });

  it("다른 계정이 같은 영수증을 보내도 지급하지 않는다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await register(env);
    const b = await register(env);
    await buy(env, a.token, "ember_credits_500", "tok-D");
    expect(await (await buy(env, b.token, "ember_credits_500", "tok-D")).json()).toEqual({ credits: 100, granted: 0 });
  });

  it("quantity 가 2 면 두 배", async () => {
    const g = await fakeGoogle();
    g.quantity = 2;
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    expect(await (await buy(env, token, "ember_credits_500", "tok-Q")).json()).toEqual({ credits: 1100, granted: 1000 });
  });

  it("취소·대기 상태(purchaseState ≠ 0)는 400 이고 기록하지 않는다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    for (const state of [1, 2]) {
      g.purchaseState = state;
      const res = await buy(env, token, "ember_credits_500", `tok-state-${state}`);
      expect(res.status).toBe(400);
      expect((await errorBody(res)).error.message).toMatch(/not completed/);
    }
    expect(env.db.rows("SELECT * FROM purchases")).toHaveLength(0);
    // 나중에 완료되면 같은 토큰으로 지급 가능
    g.purchaseState = 0;
    expect(await (await buy(env, token, "ember_credits_500", "tok-state-2")).json()).toEqual({ credits: 600, granted: 500 });
  });

  it("모르는 상품·없는 영수증·빈 토큰은 400", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    expect((await buy(env, token, "ember_credits_999", "tok")).status).toBe(400);
    expect((await buy(env, token, "ember_credits_500", "")).status).toBe(400);
    const missing = await buy(env, token, "ember_credits_500", "missing-token");
    expect(missing.status).toBe(400);
    expect((await errorBody(missing)).error.message).toMatch(/not found/);
  });

  it("PRODUCTS 환경 변수로 상품표를 바꿀 수 있다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, PRODUCTS: '{"promo_10":10}' });
    const { token } = await register(env);
    expect((await buy(env, token, "ember_credits_500", "t1")).status).toBe(400);
    expect(await (await buy(env, token, "promo_10", "t2")).json()).toEqual({ credits: 110, granted: 10 });
  });

  it("인증이 없으면 401, 서비스 계정이 없으면 500", async () => {
    const env = makeEnv();
    expect((await buy(env, "bad", "ember_credits_500", "t")).status).toBe(401);
    const { token } = await register(env);
    const res = await buy(env, token, "ember_credits_500", "t");
    expect(res.status).toBe(500);
    expect((await errorBody(res)).error.type).toBe("api_error");
  });
});

describe("base64url", () => {
  it("패딩 없이 URL 안전 문자만", () => {
    expect(base64UrlEncode(new Uint8Array([251, 255, 191]))).toBe("-_-_");
  });
});
