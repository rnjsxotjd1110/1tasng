import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DELETED_TOMBSTONE, hashedPurchaseToken } from "../src/account-delete";
import { recordUsage } from "../src/billing/ledger";
import {
  clearGoogleJwksCache,
  GOOGLE_JWKS_URL,
  GoogleIdTokenError,
  jwksTtlSeconds,
  verifyGoogleIdToken,
} from "../src/google/id-token";
import { PURCHASE_RETENTION_SECONDS, purgeExpired } from "../src/retention";
import { hmacSha256Hex, sha256Hex } from "../src/util";
import { addUsage, call, errorBody, makeEnv, register, type TestEnv } from "./helpers/env";
import { idTokenFor, makeIdToken, TEST_CLIENT_ID, testJwks } from "./helpers/google-id";

const CLIENTS = [TEST_CLIENT_ID];

beforeEach(() => clearGoogleJwksCache());
afterEach(() => vi.unstubAllGlobals());

interface JwksServer {
  requests: number;
  status: number;
  cacheControl: string;
  kid: string;
}

/** fetch 를 가짜 JWKS 서버로 바꾼다. */
async function serveJwks(opts: Partial<JwksServer> = {}): Promise<JwksServer> {
  const s: JwksServer = { requests: 0, status: 200, cacheControl: "public, max-age=100, must-revalidate, no-transform", kid: "test-kid-1", ...opts };
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL) => {
      const url = input instanceof Request ? input.url : String(input);
      if (url !== GOOGLE_JWKS_URL) throw new Error(`unexpected fetch ${url}`);
      s.requests++;
      if (s.status !== 200) return new Response("oops", { status: s.status });
      return Response.json(await testJwks(s.kid), { headers: { "cache-control": s.cacheControl } });
    }),
  );
  return s;
}

async function expectInvalid(p: Promise<unknown>, message?: RegExp): Promise<void> {
  const err = await p.then(
    () => null,
    (e: unknown) => e,
  );
  expect(err).toBeInstanceOf(GoogleIdTokenError);
  expect((err as GoogleIdTokenError).kind).toBe("invalid");
  if (message) expect((err as GoogleIdTokenError).message).toMatch(message);
}

describe("verifyGoogleIdToken", () => {
  it("JWKS 를 받아 서명을 확인하고 sub 만 돌려준다. Cache-Control max-age 동안 캐시한다", async () => {
    const server = await serveJwks();
    const token = await makeIdToken("sub-123");
    const t0 = Date.now();
    expect(await verifyGoogleIdToken(token, CLIENTS, t0)).toEqual({ sub: "sub-123" });
    expect(await verifyGoogleIdToken(token, CLIENTS, t0 + 99_000)).toEqual({ sub: "sub-123" });
    expect(server.requests).toBe(1);
    expect(await verifyGoogleIdToken(token, CLIENTS, t0 + 101_000)).toEqual({ sub: "sub-123" });
    expect(server.requests).toBe(2);
  });

  it("두 iss 형식을 모두 받고, 여러 클라이언트 ID 중 하나면 된다", async () => {
    await serveJwks();
    for (const iss of ["accounts.google.com", "https://accounts.google.com"]) {
      expect(await verifyGoogleIdToken(await makeIdToken("s", { claims: { iss } }), CLIENTS)).toEqual({ sub: "s" });
    }
    const other = await makeIdToken("s", { claims: { aud: "web-2.apps.googleusercontent.com" } });
    expect(await verifyGoogleIdToken(other, ["web-1", "web-2.apps.googleusercontent.com"])).toEqual({ sub: "s" });
  });

  it("틀린 iss·aud·서명·alg·형식은 invalid", async () => {
    await serveJwks();
    const forger = (await crypto.subtle.generateKey(
      { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
      true,
      ["sign", "verify"],
    )) as CryptoKeyPair;
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { claims: { iss: "https://accounts.google.com.evil" } }), CLIENTS), /issuer/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { claims: { aud: "other" } }), CLIENTS), /audience/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { claims: { aud: [TEST_CLIENT_ID] } }), CLIENTS), /audience/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { signWith: forger.privateKey }), CLIENTS), /signature/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { header: { alg: "none" } }), CLIENTS), /alg/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { header: { alg: "HS256" } }), CLIENTS), /alg/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { header: { kid: undefined } }), CLIENTS), /kid/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("", {}), CLIENTS), /sub/);
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s", { claims: { sub: 12345 } }), CLIENTS), /sub/);
    for (const junk of ["", "a.b", "a.b.c", "!!!.e30.sig", "x".repeat(9000)]) {
      await expectInvalid(verifyGoogleIdToken(junk, CLIENTS));
    }
    // 서명 부분만 바꾼 토큰
    const good = await makeIdToken("s");
    const [h, p] = good.split(".");
    await expectInvalid(verifyGoogleIdToken(`${h}.${p}.AAAA`, CLIENTS), /signature/);
    // 내용만 바꾼 토큰(서명 불일치)
    const tampered = `${h}.${Buffer.from(JSON.stringify({ sub: "admin", aud: TEST_CLIENT_ID })).toString("base64url")}.${good.split(".")[2]}`;
    await expectInvalid(verifyGoogleIdToken(tampered, CLIENTS), /signature/);
  });

  it("exp/iat 는 60초 시계 오차를 허용한다", async () => {
    await serveJwks();
    const now = Math.floor(Date.now() / 1000);
    const ok = (claims: Record<string, unknown>) => makeIdToken("s", { claims }).then((t) => verifyGoogleIdToken(t, CLIENTS, now * 1000));
    expect(await ok({ exp: now - 30 })).toEqual({ sub: "s" });
    await expectInvalid(ok({ exp: now - 61 }), /expired/);
    await expectInvalid(ok({ exp: undefined }), /expired/);
    expect(await ok({ iat: now + 30 })).toEqual({ sub: "s" });
    await expectInvalid(ok({ iat: now + 120 }), /future/);
    await expectInvalid(ok({ iat: "yesterday" }), /future/);
  });

  it("email 이 있으면 email_verified 가 true 여야 한다(없으면 상관없음)", async () => {
    await serveJwks();
    const v = (claims: Record<string, unknown>) => makeIdToken("s", { claims }).then((t) => verifyGoogleIdToken(t, CLIENTS));
    await expectInvalid(v({ email_verified: false }), /email/);
    await expectInvalid(v({ email_verified: undefined }), /email/);
    expect(await v({ email_verified: "true" })).toEqual({ sub: "s" });
    expect(await v({ email: undefined, email_verified: undefined })).toEqual({ sub: "s" });
  });

  it("모르는 kid 면 JWKS 를 다시 받는다(키 교체). 단 1분에 한 번까지", async () => {
    const server = await serveJwks({ kid: "old-kid" });
    const t0 = Date.now();
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s"), CLIENTS, t0), /unknown signing key/);
    expect(server.requests).toBe(1); // 방금 받았으므로 다시 받지 않음
    server.kid = "test-kid-1";
    await expectInvalid(verifyGoogleIdToken(await makeIdToken("s"), CLIENTS, t0 + 30_000));
    expect(server.requests).toBe(1);
    expect(await verifyGoogleIdToken(await makeIdToken("s"), CLIENTS, t0 + 61_000)).toEqual({ sub: "s" });
    expect(server.requests).toBe(2);
  });

  it("JWKS 를 못 받으면 unavailable. 이전 키가 있으면 만료됐어도 그 키로 검증한다", async () => {
    const server = await serveJwks({ status: 503 });
    const token = await makeIdToken("s");
    const err = await verifyGoogleIdToken(token, CLIENTS).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(GoogleIdTokenError);
    expect((err as GoogleIdTokenError).kind).toBe("unavailable");

    server.status = 200;
    const t0 = Date.now();
    await verifyGoogleIdToken(token, CLIENTS, t0);
    server.status = 500;
    expect(await verifyGoogleIdToken(token, CLIENTS, t0 + 200_000)).toEqual({ sub: "s" });
    expect(server.requests).toBe(3);
    // 실패한 뒤 1분 동안은 다시 받지 않는다
    expect(await verifyGoogleIdToken(token, CLIENTS, t0 + 230_000)).toEqual({ sub: "s" });
    expect(server.requests).toBe(3);
    server.status = 200;
    expect(await verifyGoogleIdToken(token, CLIENTS, t0 + 261_000)).toEqual({ sub: "s" });
    expect(server.requests).toBe(4);
  });

  it("jwksTtlSeconds", () => {
    expect(jwksTtlSeconds("public, max-age=19742, must-revalidate, no-transform")).toBe(19742);
    expect(jwksTtlSeconds("max-age=999999")).toBe(86400);
    expect(jwksTtlSeconds(null)).toBe(3600);
    expect(jwksTtlSeconds("no-cache")).toBe(3600);
    expect(jwksTtlSeconds("s-maxage=5")).toBe(3600);
  });

  it("가입 중 JWKS 를 못 받으면 502 api_error(앱이 다시 시도)", async () => {
    await serveJwks({ status: 503 });
    const env = makeEnv();
    const { res } = await call(env, "/ember/register", {
      method: "POST",
      json: { installId: "install-jwks-down-1", idToken: await makeIdToken("s") },
    });
    expect(res.status).toBe(502);
    expect((await errorBody(res)).error.type).toBe("api_error");
    expect(env.db.rows("SELECT id FROM accounts")).toEqual([]);
  });
});

/** 예전 앱 방식(idToken 없이)으로 연결 안 된 계정을 만든다. */
async function legacyAccount(env: TestEnv, installId = `legacy-${crypto.randomUUID()}`): Promise<string> {
  const { res } = await call(env, "/ember/register", {
    method: "POST",
    json: { installId },
    headers: { "cf-connecting-ip": "10.9.9.9" },
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { token: string }).token;
}

async function link(env: TestEnv, token: string, idToken: unknown): Promise<Response> {
  return (await call(env, "/ember/link-google", { method: "POST", json: { idToken }, headers: { "x-api-key": token } })).res;
}

describe("POST /ember/link-google", () => {
  it("연결 안 된 예전 계정을 Google 계정에 연결한다. 이후 새 기기에서 Google 로그인하면 이 계정이 복원된다", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    const token = await legacyAccount(env, "legacy-install-0001");
    env.db.sqlite.exec("UPDATE accounts SET credits = 777");
    const res = await link(env, token, await idTokenFor("google-sub-link"));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ linked: true, credits: 777 });
    expect(env.db.rows("SELECT google_sub FROM accounts")).toEqual([{ google_sub: "google-sub-link" }]);
    // 예전에 받은 무료 크레딧(100)도 이 Google 계정의 '받음'으로 기록
    expect(env.db.rows("SELECT sub_hash FROM free_credit_grants")).toEqual([
      { sub_hash: await hmacSha256Hex("test-sub-hash-secret", "google-sub-link") },
    ]);
    // 같은 sub 로 다시 연결해도 성공(멱등)
    expect(await (await link(env, token, await idTokenFor("google-sub-link"))).json()).toEqual({ linked: true, credits: 777 });
    // 새 기기에서 Google 로그인 → 같은 계정
    const restored = await register(env, "new-phone-install-1", "google-sub-link");
    expect(restored).toMatchObject({ credits: 777, freeGranted: false, restored: true });
    expect(env.db.rows("SELECT id FROM accounts")).toHaveLength(1);
  });

  it("그 Google 계정을 이미 다른 계정이 쓰면 409 google_in_use, 아무것도 바꾸지 않는다", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    await register(env, "install-owner-0001", "google-sub-taken");
    const legacy = await legacyAccount(env);
    const res = await link(env, legacy, await idTokenFor("google-sub-taken"));
    expect(res.status).toBe(409);
    expect((await errorBody(res)).error.type).toBe("google_in_use");
    expect(env.db.rows("SELECT google_sub, credits FROM accounts ORDER BY id")).toEqual([
      { google_sub: "google-sub-taken", credits: 100 },
      { google_sub: null, credits: 100 },
    ]);
  });

  it("이미 다른 Google 계정에 연결된 계정이면 409 already_linked", async () => {
    const env = makeEnv();
    const { token } = await register(env, "install-linked-001", "google-sub-first");
    const res = await link(env, token, await idTokenFor("google-sub-second"));
    expect(res.status).toBe(409);
    expect((await errorBody(res)).error.type).toBe("already_linked");
    expect(env.db.rows("SELECT google_sub FROM accounts")).toEqual([{ google_sub: "google-sub-first" }]);
  });

  it("인증 401, idToken 없음 400, 틀린 idToken 401 invalid_google_token", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    expect((await link(env, "bad-token", await idTokenFor("s"))).status).toBe(401);
    const token = await legacyAccount(env);
    expect((await link(env, token, undefined)).status).toBe(400);
    const bad = await link(env, token, await makeIdToken("s", { claims: { aud: "nope" } }));
    expect(bad.status).toBe(401);
    expect((await errorBody(bad)).error.type).toBe("invalid_google_token");
    expect(env.db.rows("SELECT google_sub FROM accounts")).toEqual([{ google_sub: null }]);
  });
});

describe("LEGACY_UNLINKED_UNTIL", () => {
  it("설정하지 않았거나 아직 그 시각 전이면 연결 안 된 계정도 그대로 쓴다", async () => {
    for (const until of [undefined, "2999-01-01", "not-a-date"]) {
      const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false", LEGACY_UNLINKED_UNTIL: until });
      const token = await legacyAccount(env);
      expect((await call(env, "/ember/balance", { headers: { "x-api-key": token } })).res.status).toBe(200);
    }
  });

  it("지나면 연결 안 된 계정은 403 google_required. 연결(link-google)과 탈퇴는 된다. 연결된 계정은 영향 없음", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    const legacy = await legacyAccount(env);
    const legacy2 = await legacyAccount(env);
    const linked = await register(env);
    env.LEGACY_UNLINKED_UNTIL = "2020-01-01";

    for (const [path, method] of [["/ember/balance", "GET"], ["/v1/models/claude-haiku-5-5", "GET"], ["/ember/purchase", "POST"], ["/ember/report", "POST"], ["/v1/messages", "POST"]] as const) {
      const { res } = await call(env, path, { method, headers: { "x-api-key": legacy }, ...(method === "POST" ? { json: {} } : {}) });
      expect(res.status, path).toBe(403);
      expect((await errorBody(res)).error.type, path).toBe("google_required");
    }
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": linked.token } })).res.status).toBe(200);

    expect((await link(env, legacy, await idTokenFor("google-sub-late"))).status).toBe(200);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": legacy } })).res.status).toBe(200);

    const del = await call(env, "/ember/account", { method: "DELETE", headers: { "x-api-key": legacy2 } });
    expect(del.res.status).toBe(200);
  });
});

describe("DELETE /ember/account", () => {
  async function del(env: TestEnv, token: string): Promise<Response> {
    return (await call(env, "/ember/account", { method: "DELETE", headers: { "x-api-key": token } })).res;
  }

  it("계정·요청 기록·처리 중 표시·신고·계정 카운터를 지우고, 구매 기록은 계정 연결을 끊고 토큰을 해시로 바꿔 남긴다", async () => {
    const env = makeEnv();
    const victim = await register(env, "install-delete-0001", "google-sub-delete");
    const bystander = await register(env, "install-keep-00001", "google-sub-keep");
    await addUsage(env, victim.token);
    await addUsage(env, bystander.token);
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `INSERT INTO purchases (purchase_token, account_id, product_id, order_id, quantity, credits, credited, voided, voided_quantity, voided_at, created_at)
         VALUES ('raw-token-1', 1, 'ember_credits_500', 'GPA.1111', 1, 500, 1, 0, 0, NULL, ${now}),
                ('raw-token-2', 1, 'ember_credits_1500', 'GPA.2222', 1, 1650, 1, 1, 1, ${now}, ${now}),
                ('raw-token-3', 2, 'ember_credits_500', 'GPA.3333', 1, 500, 1, 0, 0, NULL, ${now});
       INSERT INTO voided_events (purchase_token, event_key, quantity, credits, applied, voided_at) VALUES ('raw-token-2', 'full', 1, 1650, 1, ${now});
       INSERT INTO inflight (account_id, reserved, started_at) VALUES (1, 5, ${now}), (2, 5, ${now});
       INSERT INTO reports (account_id, kind, reason, content, created_at) VALUES (1, 'idea', 'r', 'c', ${now}), (2, 'idea', 'r', 'c', ${now});
       INSERT INTO rate_limits (key, window_start, count) VALUES ('msg:1', ${now}, 3), ('rep:1', ${now}, 1), ('msg:2', ${now}, 3), ('reg:1.2.3.4', ${now}, 1);`,
    );

    const res = await del(env, victim.token);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ deleted: true });

    expect(env.db.rows("SELECT id, install_id, google_sub, disabled FROM accounts ORDER BY id")).toEqual([
      { id: 2, install_id: "install-keep-00001", google_sub: "google-sub-keep", disabled: 0 },
      { id: 3, install_id: DELETED_TOMBSTONE, google_sub: null, disabled: 1 },
    ]);
    expect(env.db.rows("SELECT account_id FROM usage_log")).toEqual([{ account_id: 2 }]);
    expect(env.db.rows("SELECT account_id FROM inflight")).toEqual([{ account_id: 2 }]);
    expect(env.db.rows("SELECT account_id FROM reports")).toEqual([{ account_id: 2 }]);
    expect(env.db.rows("SELECT key FROM rate_limits WHERE key LIKE 'msg:%' OR key LIKE 'rep:%' OR key LIKE 'reg:1.%' ORDER BY key")).toEqual([
      { key: "msg:2" },
      { key: "reg:1.2.3.4" },
    ]);
    // 구매: 묘비 계정 + 해시 토큰, 상품·주문번호·금액·시각·환불 표시는 그대로
    expect(env.db.rows("SELECT purchase_token, account_id, product_id, order_id, credits, voided, created_at FROM purchases ORDER BY order_id")).toEqual([
      { purchase_token: await hashedPurchaseToken("raw-token-1"), account_id: 3, product_id: "ember_credits_500", order_id: "GPA.1111", credits: 500, voided: 0, created_at: now },
      { purchase_token: await hashedPurchaseToken("raw-token-2"), account_id: 3, product_id: "ember_credits_1500", order_id: "GPA.2222", credits: 1650, voided: 1, created_at: now },
      { purchase_token: "raw-token-3", account_id: 2, product_id: "ember_credits_500", order_id: "GPA.3333", credits: 500, voided: 0, created_at: now },
    ]);
    expect(await hashedPurchaseToken("raw-token-1")).toBe(`sha256:${await sha256Hex("raw-token-1")}`);
    expect(env.db.rows("SELECT purchase_token FROM voided_events")).toEqual([{ purchase_token: await hashedPurchaseToken("raw-token-2") }]);
    // 무료 크레딧 기록은 남고, 탈퇴 수가 기록된다
    expect(env.db.rows("SELECT COUNT(*) AS n FROM free_credit_grants")).toEqual([{ n: 2 }]);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM account_deletions")).toEqual([{ n: 1 }]);
    // 옛 토큰은 401, 다시 지우기도 401
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": victim.token } })).res.status).toBe(401);
    expect((await del(env, victim.token)).status).toBe(401);
    // 다른 계정은 영향 없음
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": bystander.token } })).res.status).toBe(200);
  });

  it("같은 Google 계정으로 다시 가입할 수 있지만 무료 크레딧은 없다. 묘비 계정은 하나만 쓴다. stats 에 나온다", async () => {
    const env = makeEnv();
    const a = await register(env, "install-again-del-1", "google-sub-again");
    expect(a.freeGranted).toBe(true);
    const buyRow = (accountId: number, tok: string) =>
      env.db.sqlite
        .prepare("INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES (?, ?, 'p', 5, 1, 0)")
        .run(tok, accountId);
    buyRow(1, "tok-a");
    expect((await del(env, a.token)).status).toBe(200);
    const b = await register(env, "install-again-del-1", "google-sub-again");
    expect(b).toMatchObject({ credits: 0, freeGranted: false, restored: false });
    buyRow(env.db.rows<{ id: number }>("SELECT MAX(id) AS id FROM accounts")[0]!.id, "tok-b");
    expect((await del(env, b.token)).status).toBe(200);
    const c = await register(env, "install-again-del-2", "google-sub-again");
    expect(c).toMatchObject({ credits: 0, freeGranted: false });
    await register(env); // 다른 Google 계정은 그대로 무료 크레딧
    expect(env.db.rows("SELECT COUNT(*) AS n FROM accounts WHERE install_id = ?", DELETED_TOMBSTONE)).toEqual([{ n: 1 }]);

    const { res } = await call(env, "/ember/admin/stats", { headers: { "x-admin-key": "test-admin-key" } });
    expect(await res.json()).toMatchObject({ accounts: 2, googleLinkedAccounts: 2, deletedAccounts: { total: 2, last30d: 2 } });
  });

  it("연결 안 된 예전 계정도 지울 수 있다. 인증이 없으면 401", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    const token = await legacyAccount(env);
    expect((await call(env, "/ember/account", { method: "DELETE" })).res.status).toBe(401);
    expect((await del(env, token)).status).toBe(200);
    expect(env.db.rows("SELECT id FROM accounts")).toEqual([]); // 구매가 없으면 묘비 계정도 만들지 않는다
  });

  it("요청 처리 중에 계정이 지워지면 정산 때 기록을 남기지 않는다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    expect((await del(env, token)).status).toBe(200);
    const usage = { inputTokens: 1, outputTokens: 1, cacheReadTokens: 0, cacheWrite5mTokens: 0, cacheWrite1hTokens: 0, webSearchRequests: 0 };
    const balance = await recordUsage(env.DB, {
      accountId: 1, model: "claude-sonnet-5-5", status: 200, streamed: false, usage, credits: 1, reserved: 5, estimated: false, now: 0,
    } as Parameters<typeof recordUsage>[1]);
    expect(balance).toBeNull();
    expect(env.db.rows("SELECT * FROM usage_log")).toEqual([]);
  });

  it("보관 정리: 묘비 계정은 만료시키지 않고, 그 구매 기록은 5년 뒤 지운다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const now = Math.floor(Date.now() / 1000);
    const ancient = now - PURCHASE_RETENTION_SECONDS - 10;
    env.db.sqlite.exec(
      `INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at)
         VALUES ('old-tok', 1, 'p', 5, 1, 1, ${ancient}), ('new-tok', 1, 'p', 5, 1, 1, ${now})`,
    );
    expect((await del(env, token)).status).toBe(200);
    env.db.sqlite.exec(`UPDATE accounts SET updated_at = 0`);
    await purgeExpired(env.DB, now);
    expect(env.db.rows("SELECT install_id FROM accounts")).toEqual([{ install_id: DELETED_TOMBSTONE }]);
    expect(env.db.rows("SELECT purchase_token FROM purchases")).toEqual([{ purchase_token: await hashedPurchaseToken("new-tok") }]);
  });

  it("보관 정리: 구매 기록이 지워진 환불 이벤트도 지운다", async () => {
    const env = makeEnv();
    await register(env);
    env.db.sqlite.exec(
      `INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at) VALUES ('kept', 1, 'p', 5, 1, 1, 0);
       INSERT INTO voided_events (purchase_token, event_key) VALUES ('kept', 'full'), ('gone', 'full');`,
    );
    await purgeExpired(env.DB, Math.floor(Date.now() / 1000));
    expect(env.db.rows("SELECT purchase_token FROM voided_events")).toEqual([{ purchase_token: "kept" }]);
  });
});

describe("보관 정리와 Google 연결", () => {
  it("만료된 계정은 Google 연결도 지워, 같은 Google 계정으로 새로 가입할 수 있다(무료 크레딧 없이)", async () => {
    const env = makeEnv();
    const { token } = await register(env, "install-expire-g-01", "google-sub-expire");
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `UPDATE accounts SET credits = 0, updated_at = 0;
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at) VALUES ('v', 1, 'p', 5, 1, 1, ${now});`,
    );
    await purgeExpired(env.DB, now);
    expect(env.db.rows("SELECT install_id, google_sub FROM accounts")).toEqual([{ install_id: "expired-1", google_sub: null }]);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": token } })).res.status).toBe(401);
    expect(await register(env, "install-expire-g-01", "google-sub-expire")).toMatchObject({ freeGranted: false, restored: false });
  });

  it("지급 대기 구매(credited = 0)만 있는 계정도 만료 대상이다", async () => {
    const env = makeEnv();
    await register(env, "install-pending-exp1");
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `UPDATE accounts SET credits = 0, updated_at = 0;
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES ('pend', 1, 'p', 5, 0, ${now});`,
    );
    await purgeExpired(env.DB, now);
    expect(env.db.rows("SELECT install_id FROM accounts")).toEqual([{ install_id: "expired-1" }]);
  });
});
