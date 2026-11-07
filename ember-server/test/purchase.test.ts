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
  consumeRequests: string[];
  purchaseState: number;
  quantity?: number;
  purchaseType?: number;
  consumptionState: number;
  /** 0 이 아니면 consume 이 이 상태 코드와 consumeBody 로 실패 */
  consumeFailStatus: number;
  consumeFailBody: string;
  /** 소비된 purchaseToken */
  consumed: Set<string>;
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
    consumeRequests: [],
    purchaseState: 0,
    consumptionState: 0,
    consumeFailStatus: 0,
    consumeFailBody: "",
    consumed: new Set(),
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
      if (req.url.startsWith(PLAY_PREFIX) && req.method === "POST" && req.url.endsWith(":consume")) {
        expect(req.headers.get("authorization")).toBe("Bearer ya29.fake");
        g.consumeRequests.push(req.url);
        if (g.consumeFailStatus) {
          return new Response(g.consumeFailBody || JSON.stringify({ error: { code: g.consumeFailStatus } }), { status: g.consumeFailStatus });
        }
        const tok = decodeURIComponent(req.url.slice(PLAY_PREFIX.length).split("/")[2]!.replace(/:consume$/, ""));
        if (g.consumed.has(tok)) {
          return Response.json({ error: { code: 400, message: "The purchase has already been consumed.", errors: [{ reason: "purchaseAlreadyConsumed" }] } }, { status: 400 });
        }
        g.consumed.add(tok);
        return new Response("", { status: 200 });
      }
      if (req.url.startsWith(PLAY_PREFIX)) {
        expect(req.headers.get("authorization")).toBe("Bearer ya29.fake");
        expect(req.method).toBe("GET");
        g.verifyRequests.push(req.url);
        const [productId, , token] = req.url.slice(PLAY_PREFIX.length).split("/");
        if (decodeURIComponent(token!) === "missing-token") {
          return Response.json({ error: { code: 404 } }, { status: 404 });
        }
        return Response.json({
          kind: "androidpublisher#productPurchase",
          purchaseState: g.purchaseState,
          consumptionState: g.consumed.has(decodeURIComponent(token!)) ? 1 : g.consumptionState,
          ...(g.purchaseType !== undefined ? { purchaseType: g.purchaseType } : {}),
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

describe("구매: 서버 소비(consume)·테스트 구매", () => {
  it("검증 후 지급 전에 서버가 consume 을 부른다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    const fetchMock = globalThis.fetch as unknown as { mock: { calls: [RequestInfo | URL, RequestInit?][] } };
    expect(await (await buy(env, token, "ember_credits_500", "tok-cons")).json()).toEqual({ credits: 600, granted: 500 });
    expect(g.consumeRequests).toEqual([PLAY_PREFIX + "ember_credits_500/tokens/tok-cons:consume"]);
    // 순서: (토큰) → 검증 GET → consume POST
    const urls = fetchMock.mock.calls.map(([u]) => String(u instanceof Request ? u.url : u));
    expect(urls.indexOf(PLAY_PREFIX + "ember_credits_500/tokens/tok-cons")).toBeLessThan(urls.indexOf(PLAY_PREFIX + "ember_credits_500/tokens/tok-cons:consume"));
  });

  it("consume 이 실패하면 502 이고 지급하지 않는다(지급 대기 기록만 남음). 다시 보내면 지급된다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    g.consumeFailStatus = 503;
    const res = await buy(env, token, "ember_credits_500", "tok-cf");
    expect(res.status).toBe(502);
    expect(env.db.rows("SELECT purchase_token, credited FROM purchases")).toEqual([{ purchase_token: "tok-cf", credited: 0 }]);
    expect(env.db.rows<{ credits: number }>("SELECT credits FROM accounts")[0]!.credits).toBe(100);
    g.consumeFailStatus = 0;
    expect(await (await buy(env, token, "ember_credits_500", "tok-cf")).json()).toEqual({ credits: 600, granted: 500 });
  });

  it("이미 소비된 구매(Google 의 '이미 소비됨' 400 또는 consumptionState 1)도 지급한다(멱등)", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    g.consumeFailStatus = 400;
    g.consumeFailBody = JSON.stringify({ error: { code: 400, message: "The purchase has already been consumed.", errors: [{ reason: "purchaseAlreadyConsumed" }] } });
    expect(await (await buy(env, token, "ember_credits_500", "tok-ac")).json()).toEqual({ credits: 600, granted: 500 });
    // 다른 400(예: 잘못된 요청)은 실패
    g.consumeFailBody = JSON.stringify({ error: { code: 400, message: "Invalid value" } });
    expect((await buy(env, token, "ember_credits_500", "tok-ac2")).status).toBe(502);
    // consumptionState 1 이면 consume 을 부르지 않는다
    g.consumeFailStatus = 0;
    g.consumptionState = 1;
    const before = g.consumeRequests.length;
    expect(await (await buy(env, token, "ember_credits_500", "tok-ac3")).json()).toEqual({ credits: 1100, granted: 500 });
    expect(g.consumeRequests).toHaveLength(before);
  });

  it("운영(ALLOW_TEST_PURCHASES 아님)에서는 테스트 구매(purchaseType 0)에 크레딧을 주지 않고 결제 계정으로도 보지 않는다", async () => {
    const g = await fakeGoogle();
    g.purchaseType = 0;
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    const res = await buy(env, token, "ember_credits_500", "tok-test");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ credits: 100, granted: 0, testPurchase: true });
    expect(g.consumeRequests).toHaveLength(1); // 테스트 구매도 소비해 다시 살 수 있게 한다
    expect(env.db.rows("SELECT credits, credited, purchase_type FROM purchases")).toEqual([{ credits: 0, credited: 1, purchase_type: 0 }]);
    // 다시 보내도 0, Google 을 다시 부르지 않음
    expect(await (await buy(env, token, "ember_credits_500", "tok-test")).json()).toEqual({ credits: 100, granted: 0 });
    expect(g.verifyRequests).toHaveLength(1);
    // 결제 계정이 아니므로 Opus 요청은 Sonnet 으로
    const { authenticate } = await import("../src/auth");
    const acc = await authenticate(env, new Request("https://x", { headers: { "x-api-key": token } }));
    expect(acc.paid).toBe(false);
  });

  it("ALLOW_TEST_PURCHASES=true 면 테스트 구매도 지급하고 결제 계정이 된다", async () => {
    const g = await fakeGoogle();
    g.purchaseType = 0;
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, ALLOW_TEST_PURCHASES: "true" });
    const { token } = await register(env);
    expect(await (await buy(env, token, "ember_credits_500", "tok-test-ok")).json()).toEqual({ credits: 600, granted: 500 });
    const { authenticate } = await import("../src/auth");
    expect((await authenticate(env, new Request("https://x", { headers: { "x-api-key": token } }))).paid).toBe(true);
  });

  it("환불된 구매가 하나라도 있으면 다른 지급 구매가 있어도 결제 계정이 아니다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    await buy(env, token, "ember_credits_500", "tok-p1");
    await buy(env, token, "ember_credits_500", "tok-p2");
    const { authenticate } = await import("../src/auth");
    const paid = async () => (await authenticate(env, new Request("https://x", { headers: { "x-api-key": token } }))).paid;
    expect(await paid()).toBe(true);
    env.db.sqlite.exec("UPDATE purchases SET voided = 1 WHERE purchase_token = 'tok-p1'");
    expect(await paid()).toBe(false);
  });
});

describe("구매: 지급 복구·탈퇴 계정 영수증", () => {
  /** env.DB.batch 를 times 번 실패하게 한다(지급 batch 실패 흉내). */
  function failBatches(env: TestEnv, times: number): void {
    const db = env.db as unknown as { batch: (...a: unknown[]) => Promise<unknown> };
    const orig = db.batch.bind(env.db);
    let left = times;
    db.batch = async (...a: unknown[]) => {
      if (left > 0) {
        left--;
        throw new Error("D1_ERROR: simulated outage");
      }
      return orig(...a);
    };
  }

  it("소비 후 지급이 실패한 구매는 같은 계정이 다시 보내면 지급된다(Google 은 '이미 소비됨'). 두 번 지급하지 않는다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const { token } = await register(env);
    failBatches(env, 2); // 지급 + 재시도 모두 실패
    const res = await buy(env, token, "ember_credits_500", "tok-rec");
    expect(res.status).toBe(500);
    expect(g.consumed.has("tok-rec")).toBe(true); // 소비는 끝남
    expect(env.db.rows("SELECT account_id, credits, credited FROM purchases")).toEqual([{ account_id: 1, credits: 500, credited: 0 }]);
    expect(env.db.rows("SELECT credits FROM accounts")).toEqual([{ credits: 100 }]);

    // 다시 보내면: Google 이 consumptionState 1 → consume 은 부르지 않고 지급
    const consumesBefore = g.consumeRequests.length;
    expect(await (await buy(env, token, "ember_credits_500", "tok-rec")).json()).toEqual({ credits: 600, granted: 500 });
    expect(g.consumeRequests).toHaveLength(consumesBefore);
    expect(env.db.rows("SELECT credited FROM purchases")).toEqual([{ credited: 1 }]);
    // 또 보내면 0(Google 도 부르지 않음)
    const verifies = g.verifyRequests.length;
    expect(await (await buy(env, token, "ember_credits_500", "tok-rec")).json()).toEqual({ credits: 600, granted: 0 });
    expect(g.verifyRequests).toHaveLength(verifies);
    // 동시에 여러 번 와도 한 번만
    failBatches(env, 2);
    await buy(env, token, "ember_credits_500", "tok-rec2");
    const results = await Promise.all([1, 2, 3].map(() => buy(env, token, "ember_credits_500", "tok-rec2")));
    const bodies = (await Promise.all(results.map((r) => r.json()))) as { granted: number }[];
    expect(bodies.map((b) => b.granted).sort()).toEqual([0, 0, 500]);
    expect(env.db.rows("SELECT credits FROM accounts")).toEqual([{ credits: 1100 }]);
  });

  it("다른 계정의 지급 대기 영수증은 지급하지 않는다. 다른 상품 ID 로 보내면 400", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await register(env);
    const b = await register(env);
    g.consumeFailStatus = 503;
    expect((await buy(env, a.token, "ember_credits_500", "tok-pend")).status).toBe(502);
    g.consumeFailStatus = 0;
    expect(await (await buy(env, b.token, "ember_credits_500", "tok-pend")).json()).toEqual({ credits: 100, granted: 0 });
    expect((await buy(env, a.token, "ember_credits_1500", "tok-pend")).status).toBe(400);
    expect(await (await buy(env, a.token, "ember_credits_500", "tok-pend")).json()).toEqual({ credits: 600, granted: 500 });
    expect(env.db.rows("SELECT account_id, credited FROM purchases")).toEqual([{ account_id: 1, credited: 1 }]);
  });

  it("탈퇴한 계정의 영수증(해시로 보관)을 새 계정이 보내도 지급하지 않고 Google 도 부르지 않는다", async () => {
    const g = await fakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const first = await register(env, "install-del-buyer-1", "google-sub-buyer");
    expect(await (await buy(env, first.token, "ember_credits_500", "tok-del")).json()).toEqual({ credits: 600, granted: 500 });
    const del = await call(env, "/ember/account", { method: "DELETE", headers: { "x-api-key": first.token } });
    expect(del.res.status).toBe(200);

    const again = await register(env, "install-del-buyer-1", "google-sub-buyer");
    expect(again).toMatchObject({ credits: 0, freeGranted: false });
    const verifies = g.verifyRequests.length;
    expect(await (await buy(env, again.token, "ember_credits_500", "tok-del")).json()).toEqual({ credits: 0, granted: 0 });
    expect(g.verifyRequests).toHaveLength(verifies);
    // 'sha256:' 로 시작하는 토큰은 받지 않는다
    expect((await buy(env, again.token, "ember_credits_500", "sha256:abc")).status).toBe(400);
  });
});

describe("base64url", () => {
  it("패딩 없이 URL 안전 문자만", () => {
    expect(base64UrlEncode(new Uint8Array([251, 255, 191]))).toBe("-_-_");
  });
});
