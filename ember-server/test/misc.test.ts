import { describe, expect, it } from "vitest";
import type { Env } from "../src/env";
import worker from "../src/index";
import { hmacSha256Hex } from "../src/util";
import { addUsage, call, errorBody, makeCtx, makeEnv, register } from "./helpers/env";

describe("GET /v1/models/:id", () => {
  it("허용 모델은 model 객체, 아니면 404 not_found_error", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const ok = await call(env, "/v1/models/claude-haiku-5-5", { headers: { "x-api-key": token } });
    expect(ok.res.status).toBe(200);
    expect(await ok.res.json()).toMatchObject({ type: "model", id: "claude-haiku-5-5", display_name: "claude-haiku-5-5" });
    const nf = await call(env, "/v1/models/claude-fable-5-1", { headers: { "x-api-key": token } });
    expect(nf.res.status).toBe(404);
    expect((await errorBody(nf.res)).error.type).toBe("not_found_error");
  });

  it("인증 필요", async () => {
    const env = makeEnv();
    expect((await call(env, "/v1/models/claude-opus-5-5")).res.status).toBe(401);
  });
});

describe("POST /ember/report", () => {
  const report = { kind: "idea", reason: "부적절함", content: "AI 가 만든 글", note: "메모", appVersion: "1.0.0" };

  it("저장하고 id 를 돌려준다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    await addUsage(env, token);
    const { res } = await call(env, "/ember/report", { method: "POST", json: report, headers: { "x-api-key": token } });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, id: 1 });
    expect(env.db.rows("SELECT kind, reason, content, note, app_version FROM reports")).toEqual([
      { kind: "idea", reason: "부적절함", content: "AI 가 만든 글", note: "메모", app_version: "1.0.0" },
    ]);
  });

  it("kind·길이 검증", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    await addUsage(env, token);
    const post = (json: unknown) => call(env, "/ember/report", { method: "POST", json, headers: { "x-api-key": token } });
    expect((await post({ ...report, kind: "spam" })).res.status).toBe(400);
    expect((await post({ ...report, content: "가".repeat(20_001) })).res.status).toBe(400);
    expect((await post({ ...report, content: "가".repeat(20_000) })).res.status).toBe(200);
    expect((await post({ kind: "other", reason: "r", content: "c" })).res.status).toBe(200); // note/appVersion 생략 가능
    expect((await call(env, "/ember/report", { method: "POST", json: report })).res.status).toBe(401);
  });

  it("AI 응답 기록(usage_log)이 없는 계정은 403", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const { res } = await call(env, "/ember/report", { method: "POST", json: report, headers: { "x-api-key": token } });
    expect(res.status).toBe(403);
    expect((await errorBody(res)).error.type).toBe("permission_error");
    expect(env.db.rows("SELECT * FROM reports")).toEqual([]);
  });

  it("IP(/64)당 시간당 30회, 하루 전체 REPORTS_DAILY_CAP 으로 제한", async () => {
    const env = makeEnv({ REPORTS_DAILY_CAP: "40" });
    const tokens: string[] = [];
    for (let i = 0; i < 3; i++) {
      const { token } = await register(env);
      await addUsage(env, token);
      tokens.push(token);
    }
    const post = (token: string, ip: string) =>
      call(env, "/ember/report", { method: "POST", json: report, headers: { "x-api-key": token, "cf-connecting-ip": ip } });
    // 같은 /64 의 다른 주소·다른 계정이라도 IP 한도를 같이 쓴다
    for (let i = 0; i < 30; i++) expect((await post(tokens[i % 2]!, `2001:db8:5:5::${i + 1}`)).res.status).toBe(200);
    const ipBlocked = await post(tokens[2]!, "2001:db8:5:5::ffff");
    expect(ipBlocked.res.status).toBe(429);
    // 다른 IP 에서 하루 상한(40)까지
    for (let i = 0; i < 10; i++) expect((await post(tokens[2]!, "198.51.100.7")).res.status).toBe(200);
    const capped = await post(tokens[2]!, "198.51.100.8");
    expect(capped.res.status).toBe(429);
    expect((await errorBody(capped.res)).error.message).toMatch(/today/);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM reports")).toEqual([{ n: 40 }]);
  });
});

describe("POST /ember/report/anon (크레딧 계정 없는 익명 신고)", () => {
  const report = { kind: "document", reason: "부적절함", content: "AI 가 만든 글", note: "메모", appVersion: "1.5.0" };
  const post = (env: ReturnType<typeof makeEnv>, json: unknown, ip = "198.51.100.20", headers: Record<string, string> = {}) =>
    call(env, "/ember/report/anon", { method: "POST", json, headers: { "cf-connecting-ip": ip, ...headers } });

  it("인증 없이 저장하고 account_id 는 NULL. 응답은 로그인 신고와 같다", async () => {
    const env = makeEnv();
    const { res } = await post(env, report);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, id: 1 });
    expect(env.db.rows("SELECT account_id, kind, reason, content, note, app_version FROM reports")).toEqual([
      { account_id: null, kind: "document", reason: "부적절함", content: "AI 가 만든 글", note: "메모", app_version: "1.5.0" },
    ]);
    // 토큰을 보내도 계정과 연결하지 않는다
    const { token } = await register(env);
    expect((await post(env, report, "198.51.100.21", { "x-api-key": token })).res.status).toBe(200);
    expect(env.db.rows("SELECT account_id FROM reports WHERE id = 2")).toEqual([{ account_id: null }]);
    // 관리자 목록에도 나온다
    const list = await call(env, "/ember/admin/reports", { headers: { "x-admin-key": "test-admin-key" } });
    expect(((await list.res.json()) as { reports: { account_id: number | null }[] }).reports.map((r) => r.account_id)).toEqual([null, null]);
  });

  it("본문 검증은 로그인 신고와 같다", async () => {
    const env = makeEnv();
    expect((await post(env, { ...report, kind: "spam" })).res.status).toBe(400);
    expect((await post(env, { ...report, content: "가".repeat(20_001) })).res.status).toBe(400);
    expect((await post(env, { kind: "other", reason: "r" })).res.status).toBe(400);
    expect((await post(env, { kind: "other", reason: "r", content: "c" })).res.status).toBe(200);
  });

  it("IP(IPv6 는 /64)당 시간당 10회", async () => {
    const env = makeEnv();
    for (let i = 0; i < 10; i++) expect((await post(env, report, `2001:db8:7:7::${i + 1}`)).res.status).toBe(200);
    const blocked = await post(env, report, "2001:db8:7:7::ffff");
    expect(blocked.res.status).toBe(429);
    expect((await errorBody(blocked.res)).error.type).toBe("rate_limit_error");
    expect((await post(env, report, "2001:db8:7:8::1")).res.status).toBe(200); // 다른 /64
    expect(env.db.rows("SELECT key FROM rate_limits WHERE key LIKE 'repanon:%' ORDER BY key")).toEqual([
      { key: "repanon:2001:db8:7:7::/64" },
      { key: "repanon:2001:db8:7:8::/64" },
    ]);
  });

  it("하루 전체 상한(REPORTS_DAILY_CAP)을 로그인 신고와 함께 쓴다", async () => {
    const env = makeEnv({ REPORTS_DAILY_CAP: "3" });
    const { token } = await register(env);
    await addUsage(env, token);
    const signed = () => call(env, "/ember/report", { method: "POST", json: report, headers: { "x-api-key": token, "cf-connecting-ip": "198.51.100.30" } });
    expect((await signed()).res.status).toBe(200);
    expect((await post(env, report, "198.51.100.31")).res.status).toBe(200);
    expect((await post(env, report, "198.51.100.32")).res.status).toBe(200);
    const capped = await post(env, report, "198.51.100.33");
    expect(capped.res.status).toBe(429);
    expect((await errorBody(capped.res)).error.message).toMatch(/today/);
    expect((await signed()).res.status).toBe(429);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM reports")).toEqual([{ n: 3 }]);
  });

  it("GET 은 404", async () => {
    const env = makeEnv();
    expect((await call(env, "/ember/report/anon")).res.status).toBe(404);
  });
});

describe("관리자", () => {
  it("x-admin-key 가 틀리거나 ADMIN_KEY 가 없으면 401", async () => {
    const env = makeEnv();
    expect((await call(env, "/ember/admin/stats")).res.status).toBe(401);
    expect((await call(env, "/ember/admin/stats", { headers: { "x-admin-key": "wrong" } })).res.status).toBe(401);
    const noKey = makeEnv({ ADMIN_KEY: undefined });
    expect((await call(noKey, "/ember/admin/stats", { headers: { "x-admin-key": "" } })).res.status).toBe(401);
  });

  it("stats: 계정 수·지급·사용·24시간 요청", async () => {
    const env = makeEnv();
    await register(env);
    await register(env);
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES ('p1', 1, 'ember_credits_500', 500, 1, ${now});
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, voided_quantity, created_at) VALUES ('p2', 2, 'ember_credits_500', 500, 1, 1, 1, ${now});
       INSERT INTO voided_events (purchase_token, event_key, quantity, credits, applied) VALUES ('p2', 'full', 1, 500, 1);
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, purchase_type, created_at) VALUES ('t1', 2, 'ember_credits_500', 0, 1, 0, ${now});
       UPDATE accounts SET disabled = 2 WHERE id = 2;
       INSERT INTO inflight (account_id, reserved, started_at) VALUES (1, 9, ${now});
       INSERT INTO usage_log (account_id, model, status, credits, created_at) VALUES (1, 'claude-opus-5-5', 200, 7, ${now}), (1, 'claude-opus-5-5', 200, 3, ${now - 2 * 86400});`,
    );
    const { res } = await call(env, "/ember/admin/stats", { headers: { "x-admin-key": "test-admin-key" } });
    expect(await res.json()).toEqual({
      accounts: 2,
      googleLinkedAccounts: 2,
      deletedAccounts: { total: 0, last30d: 0 },
      creditsGranted: { free: 200, purchased: 1000, total: 1200 },
      creditsSpent: 10,
      creditsOutstanding: 200,
      paidCreditsOutstanding: 0,
      paidCreditsExpired: 0,
      adminRefunds: { purchases: 0, credits: 0 },
      purchases: 2,
      pendingPurchases: 0,
      voided: { purchases: 1, creditsClawedBack: 500 },
      billingDisabledAccounts: 1,
      inflightRequests: 1,
      reports: 0,
      last24h: { requests: 1, creditsSpent: 7 },
    });
  });

  it("reports: 최신순·limit·before", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    await addUsage(env, token);
    for (let i = 0; i < 3; i++) {
      await call(env, "/ember/report", { method: "POST", json: { kind: "other", reason: `r${i}`, content: "c" }, headers: { "x-api-key": token } });
    }
    const h = { headers: { "x-admin-key": "test-admin-key" } };
    const page1 = (await (await call(env, "/ember/admin/reports?limit=2", h)).res.json()) as { reports: { id: number }[]; nextBefore: number };
    expect(page1.reports.map((r) => r.id)).toEqual([3, 2]);
    expect(page1.nextBefore).toBe(2);
    const page2 = (await (await call(env, "/ember/admin/reports?limit=2&before=2", h)).res.json()) as { reports: { id: number }[]; nextBefore: null };
    expect(page2.reports.map((r) => r.id)).toEqual([1]);
    expect(page2.nextBefore).toBeNull();
  });
});

describe("라우팅", () => {
  it("모르는 경로·메서드는 404 not_found_error", async () => {
    const env = makeEnv();
    for (const [method, path] of [["GET", "/"], ["GET", "/v1/messages"], ["POST", "/v1/complete"], ["DELETE", "/ember/balance"], ["GET", "/v1/models"]] as const) {
      const { res } = await call(env, path, { method });
      expect(res.status, `${method} ${path}`).toBe(404);
      expect(await errorBody(res)).toEqual({ type: "error", error: { type: "not_found_error", message: "not found" } });
    }
  });

  it("잘못된 JSON 은 400", async () => {
    const env = makeEnv();
    const { res } = await call(env, "/ember/register", { method: "POST", body: "{oops", headers: { "content-type": "application/json" } });
    expect(res.status).toBe(400);
  });

  it("cron 은 오래된 rate_limits·처리 중 표시를 지운다", async () => {
    const env = makeEnv();
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `INSERT INTO rate_limits VALUES ('old', 0, 1), ('new', ${now}, 1), ('reg:1.2.3.4', ${now - 86400 - 3600}, 1), ('free:day', ${now - (now % 86400)}, 40)`,
    );
    env.db.sqlite.exec(`INSERT INTO inflight (account_id, reserved, started_at) VALUES (1, 5, ${now - 7200}), (1, 5, ${now})`);
    await worker.scheduled({} as ScheduledController, env, makeCtx());
    // IP 키는 창 시작 1일이 지나면 지운다(매일 실행이므로 기록 후 2일 안), 오늘의 하루 카운터는 남는다
    expect(env.db.rows("SELECT key FROM rate_limits ORDER BY key")).toEqual([{ key: "free:day" }, { key: "new" }]);
    expect(env.db.rows("SELECT started_at FROM inflight")).toEqual([{ started_at: now }]);
  });
});

describe("보관 기간 정리(cron)", () => {
  it("1년 지난 기록은 지우고, 1년 안 쓴 계정은 무료 크레딧이 남아 있어도 만료, 유료가 남은 계정은 그대로 둔다", async () => {
    const { purgeExpired, RETENTION_SECONDS } = await import("../src/retention");
    const env = makeEnv();
    const ids: Record<string, number> = {};
    const tokens: Record<string, string> = {};
    for (const name of ["free-empty", "free-balance", "paid-left", "paid-used", "voided-only", "fresh"]) {
      tokens[name] = (await register(env, `install-${name}-0001`)).token;
      ids[name] = env.db.rows<{ id: number }>("SELECT MAX(id) AS id FROM accounts")[0]!.id;
    }
    const now = Math.floor(Date.now() / 1000);
    const old = now - RETENTION_SECONDS - 10;
    const q = (sql: string, ...p: (string | number)[]) => env.db.sqlite.prepare(sql).run(...p);
    q("UPDATE accounts SET last_used_at = ?, updated_at = ?, credits = 0 WHERE id != ?", old, old, ids["fresh"]!);
    q("UPDATE accounts SET credits = 25 WHERE id = ?", ids["free-balance"]!);
    q("UPDATE accounts SET credits = 125 WHERE id = ?", ids["paid-left"]!);
    const lot = `INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at, expires_at, remaining)
                 VALUES (?, ?, 'ember_credits_500', 500, 1, ?, ?, ?)`;
    q(lot, "tok-left", ids["paid-left"]!, old, old + 5 * 365 * 86400, 100);
    q(lot, "tok-used", ids["paid-used"]!, old, old + 5 * 365 * 86400, 0);
    q("INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at) VALUES ('tok-void', ?, 'ember_credits_500', 500, 1, 1, ?)", ids["voided-only"]!, old);
    q("INSERT INTO usage_log (account_id, model, status, created_at) VALUES (?, 'claude-opus-5-5', 200, ?)", ids["paid-left"]!, old);
    q("INSERT INTO reports (account_id, kind, reason, content, created_at) VALUES (NULL, 'idea', 'r', 'c', ?), (NULL, 'idea', 'r', 'c', ?)", old, now);

    await purgeExpired(env.DB, now);

    const accounts = env.db.rows<{ id: number; install_id: string; credits: number }>("SELECT id, install_id, credits FROM accounts ORDER BY id");
    expect(accounts).toEqual([
      // free-empty·free-balance: 구매 없음 → 삭제(남은 무료 크레딧 25 는 사라짐)
      { id: ids["paid-left"], install_id: "install-paid-left-0001", credits: 125 }, // 만료 안 된 유료 크레딧 → 그대로
      { id: ids["paid-used"], install_id: `expired-${ids["paid-used"]}`, credits: 0 }, // 유료를 다 씀 → 토큰 무효, 구매 기록 보관
      { id: ids["voided-only"], install_id: `expired-${ids["voided-only"]}`, credits: 0 },
      { id: ids["fresh"], install_id: "install-fresh-0001", credits: 100 },
    ]);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM usage_log")).toEqual([{ n: 0 }]);
    expect(env.db.rows("SELECT created_at FROM reports")).toEqual([{ created_at: now }]); // 익명 신고도 1년
    expect(env.db.rows("SELECT purchase_token, lot_closed_reason FROM purchases ORDER BY purchase_token")).toEqual([
      { purchase_token: "tok-left", lot_closed_reason: null },
      { purchase_token: "tok-used", lot_closed_reason: "account_expired" },
      { purchase_token: "tok-void", lot_closed_reason: null },
    ]);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": tokens["paid-left"]! } })).res.status).toBe(200);
    for (const name of ["free-empty", "free-balance", "paid-used", "voided-only"]) {
      expect((await call(env, "/ember/balance", { headers: { "x-api-key": tokens[name]! } })).res.status, name).toBe(401);
    }
  });

  it("잔액 확인·요청은 마지막 사용 시각(last_used_at)을 갱신해 만료를 미룬다", async () => {
    const { purgeExpired, RETENTION_SECONDS } = await import("../src/retention");
    const env = makeEnv();
    const { token } = await register(env);
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(`UPDATE accounts SET last_used_at = ${now - RETENTION_SECONDS - 10}`);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": token } })).res.status).toBe(200);
    expect(env.db.rows<{ last_used_at: number }>("SELECT last_used_at FROM accounts")[0]!.last_used_at).toBeGreaterThanOrEqual(now);
    await purgeExpired(env.DB, now);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM accounts")).toEqual([{ n: 1 }]);
    // 1시간 안의 반복 호출은 다시 쓰지 않는다(쓰기 절약)
    env.db.sqlite.exec(`UPDATE accounts SET last_used_at = ${now - 60}`);
    await call(env, "/ember/balance", { headers: { "x-api-key": token } });
    expect(env.db.rows("SELECT last_used_at FROM accounts")).toEqual([{ last_used_at: now - 60 }]);
  });

  it("5년 지난 구매·환불 기록은 계정 상태와 관계없이 지운다(유료 묶음은 먼저 만료 처리)", async () => {
    const { purgeExpired, PURCHASE_RETENTION_YEARS } = await import("../src/retention");
    const { addYears } = await import("../src/billing/lots");
    const env = makeEnv();
    await register(env, "install-keep-paid-01");
    const now = Math.floor(Date.now() / 1000);
    const ancient = addYears(now, -PURCHASE_RETENTION_YEARS) - 10;
    env.db.sqlite.exec(
      `UPDATE accounts SET credits = 150;
       INSERT INTO accounts (install_id, token_hash, credits, created_at, updated_at, last_used_at) VALUES ('expired-99', 'expired-99', 0, 0, ${now}, ${now});
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at, expires_at, remaining)
         VALUES ('a', 1, 'p', 500, 1, ${ancient}, ${addYears(ancient, 5)}, 50), ('fresh', 1, 'p', 500, 1, ${now}, ${addYears(now, 5)}, 0);
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at)
         SELECT 'b', id, 'p', 5, 1, 1, ${ancient} FROM accounts WHERE install_id = 'expired-99';
       INSERT INTO voided_events (purchase_token, event_key) VALUES ('b', 'full');`,
    );
    await purgeExpired(env.DB, now);
    expect(env.db.rows("SELECT purchase_token FROM purchases")).toEqual([{ purchase_token: "fresh" }]);
    expect(env.db.rows("SELECT * FROM voided_events")).toEqual([]);
    // 만료된 유료 50 은 잔액에서 빠졌다
    expect(env.db.rows("SELECT credits FROM accounts WHERE id = 1")).toEqual([{ credits: 100 }]);
  });

  it("무료 크레딧 1회 기록은 계정이 있는 동안 남고, 삭제·만료된 뒤 3년이 지나면 지운다", async () => {
    const { purgeExpired, RETENTION_SECONDS, FREE_GRANT_RETENTION_YEARS } = await import("../src/retention");
    const { addYears } = await import("../src/billing/lots");
    const env = makeEnv();
    const live = await register(env, "install-grant-live1", "sub-grant-live");
    await register(env, "install-grant-idle1", "sub-grant-idle");
    const gone = await register(env, "install-grant-gone1", "sub-grant-gone");
    expect(env.db.rows("SELECT account_id, gone_at FROM free_credit_grants ORDER BY account_id")).toEqual([
      { account_id: 1, gone_at: null },
      { account_id: 2, gone_at: null },
      { account_id: 3, gone_at: null },
    ]);
    const now = Math.floor(Date.now() / 1000);
    expect((await call(env, "/ember/account", { method: "DELETE", headers: { "x-api-key": gone.token } })).res.status).toBe(200);
    env.db.sqlite.exec(`UPDATE accounts SET last_used_at = ${now - RETENTION_SECONDS - 10} WHERE id = 2`);
    await purgeExpired(env.DB, now);
    const hashOf = (sub: string) => hmacSha256Hex("test-sub-hash-secret", sub);
    const h = { live: await hashOf("sub-grant-live"), idle: await hashOf("sub-grant-idle"), gone: await hashOf("sub-grant-gone") };
    const grants = () =>
      Object.fromEntries(
        env.db
          .rows<{ sub_hash: string; account_id: number | null; gone_at: number | null }>("SELECT sub_hash, account_id, gone_at FROM free_credit_grants")
          .map((g) => [g.sub_hash, { account_id: g.account_id, gone_at: g.gone_at }]),
      );
    const g = grants();
    expect(g[h.live]).toEqual({ account_id: 1, gone_at: null }); // 계정이 있으면 그대로
    expect(g[h.idle]).toEqual({ account_id: null, gone_at: now }); // 1년 미사용으로 만료
    expect(g[h.gone]!.account_id).toBeNull(); // 탈퇴
    expect(g[h.gone]!.gone_at).toBeGreaterThanOrEqual(now);
    // 3년 뒤: 계정이 없어진 기록만 지운다(살아 있는 계정은 그 사이 사용했다고 본다)
    env.db.sqlite.exec(`UPDATE accounts SET last_used_at = ${addYears(now, FREE_GRANT_RETENTION_YEARS)} WHERE id = 1`);
    await purgeExpired(env.DB, addYears(now, FREE_GRANT_RETENTION_YEARS) + 10);
    expect(Object.keys(grants())).toEqual([h.live]);
    expect(live.freeGranted).toBe(true);
  });

  it("0005 이전 무료 크레딧 기록은 cron 이 sub 의 HMAC 으로 계정과 연결하고, 맞는 계정이 없으면 지금을 gone_at 으로 둔다", async () => {
    const { linkLegacyFreeGrants } = await import("../src/retention");
    const env = makeEnv();
    await register(env, "install-legacy-g01", "sub-legacy-live");
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `UPDATE free_credit_grants SET account_id = NULL, gone_at = NULL;
       INSERT INTO free_credit_grants (sub_hash, created_at) VALUES ('${await hmacSha256Hex("test-sub-hash-secret", "sub-deleted-long-ago")}', 0);`,
    );
    expect(await linkLegacyFreeGrants(env, now)).toEqual({ linked: 1, gone: 1 });
    expect(env.db.rows("SELECT account_id, gone_at FROM free_credit_grants ORDER BY created_at")).toEqual([
      { account_id: null, gone_at: now },
      { account_id: 1, gone_at: null },
    ]);
    expect(await linkLegacyFreeGrants(env, now + 1)).toEqual({ linked: 0, gone: 0 });
    // 아직 연결 전인 기록도 탈퇴 때 sub 의 HMAC 으로 찾아 '계정 없어짐'으로 둔다
    const other = await register(env, "install-legacy-g02", "sub-legacy-del");
    env.db.sqlite.exec(`UPDATE free_credit_grants SET account_id = NULL WHERE account_id = 2`);
    expect((await call(env, "/ember/account", { method: "DELETE", headers: { "x-api-key": other.token } })).res.status).toBe(200);
    const h = await hmacSha256Hex("test-sub-hash-secret", "sub-legacy-del");
    const row = env.db.rows<{ account_id: number | null; gone_at: number | null }>("SELECT account_id, gone_at FROM free_credit_grants WHERE sub_hash = ?", h)[0]!;
    expect(row.account_id).toBeNull();
    expect(row.gone_at).toBeGreaterThanOrEqual(now);
    expect(await linkLegacyFreeGrants(makeEnv({ SUB_HASH_SECRET: undefined }), now)).toBeNull();
  });
});

describe("마이그레이션", () => {
  type Db = InstanceType<typeof import("./helpers/d1").FakeD1>;
  /** 모든 표의 컬럼과 인덱스(이름·대상·컬럼) */
  const describeDb = (db: Db) => {
    const tables = db.rows<{ name: string }>(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return {
      tables: Object.fromEntries(tables.map((t) => [t.name, db.rows(`PRAGMA table_info(${t.name})`)])),
      indexes: db.rows("SELECT name, tbl_name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%' ORDER BY name"),
    };
  };

  async function load(): Promise<{ FakeD1: typeof import("./helpers/d1").FakeD1; m2: string; m3: string; m4: string; m5: string }> {
    const { readFileSync } = await import("node:fs");
    const { FakeD1 } = await import("./helpers/d1");
    const m2 = readFileSync(new URL("../migrations/0002_voided_integrity.sql", import.meta.url), "utf8");
    const m3 = readFileSync(new URL("../migrations/0003_billing_guards.sql", import.meta.url), "utf8");
    const m4 = readFileSync(new URL("../migrations/0004_google_signin.sql", import.meta.url), "utf8");
    const m5 = readFileSync(new URL("../migrations/0005_credit_lots_retention.sql", import.meta.url), "utf8");
    return { FakeD1, m2, m3, m4, m5 };
  }

  /** 0005 이전 스키마(= 0004 까지 적용한 DB) 흉내 */
  function before0005(db: Db): void {
    db.sqlite.exec(
      `DROP INDEX idx_free_grants_account;
       ALTER TABLE free_credit_grants DROP COLUMN gone_at; ALTER TABLE free_credit_grants DROP COLUMN account_id;
       DROP INDEX idx_purchases_order; DROP INDEX idx_purchases_expires;
       ALTER TABLE purchases DROP COLUMN refund_credits; ALTER TABLE purchases DROP COLUMN refund_micros;
       ALTER TABLE purchases DROP COLUMN refunded_at; ALTER TABLE purchases DROP COLUMN price_currency;
       ALTER TABLE purchases DROP COLUMN price_micros; ALTER TABLE purchases DROP COLUMN lot_closed_credits;
       ALTER TABLE purchases DROP COLUMN lot_closed_reason; ALTER TABLE purchases DROP COLUMN lot_closed_at;
       ALTER TABLE purchases DROP COLUMN expires_at; ALTER TABLE purchases DROP COLUMN remaining;
       ALTER TABLE accounts DROP COLUMN last_used_at;
       DROP TABLE reports;
       CREATE TABLE reports (
         id           INTEGER PRIMARY KEY AUTOINCREMENT,
         account_id   INTEGER NOT NULL,
         kind         TEXT    NOT NULL,
         reason       TEXT    NOT NULL,
         content      TEXT    NOT NULL,
         note         TEXT    NOT NULL DEFAULT '',
         app_version  TEXT    NOT NULL DEFAULT '',
         created_at   INTEGER NOT NULL
       );`,
    );
  }

  /** 0004 이전 스키마(= 0003 까지 적용한 DB) 흉내 */
  function before0004(db: Db): void {
    before0005(db);
    db.sqlite.exec(
      `DROP INDEX idx_accounts_google_sub; ALTER TABLE accounts DROP COLUMN google_sub;
       DROP TABLE free_credit_grants; DROP TABLE account_deletions;`,
    );
  }

  /** 0003 이전 스키마(= 0002 까지 적용한 DB) 흉내 */
  function before0003(db: Db): void {
    before0004(db);
    db.sqlite.exec(
      `ALTER TABLE purchases DROP COLUMN voided_quantity;
       DROP TABLE voided_events; DROP INDEX idx_inflight_account; DROP TABLE inflight;`,
    );
  }

  it("예전 스키마에 0002 → 0003 → 0004 → 0005 를 적용하면 schema.sql 과 같은 구조가 된다", async () => {
    const { FakeD1, m2, m3, m4, m5 } = await load();
    const fresh = new FakeD1();
    const old = new FakeD1();
    before0003(old);
    old.sqlite.exec(
      `ALTER TABLE purchases DROP COLUMN voided_at; ALTER TABLE purchases DROP COLUMN voided;
       DROP TABLE meta; DROP TABLE nonces;`,
    );
    expect(old.rows("PRAGMA table_info(purchases)").map((c) => (c as { name: string }).name)).not.toContain("voided");
    old.sqlite.exec("INSERT INTO accounts (install_id, token_hash, created_at, updated_at) VALUES ('i', 'h', 0, 0)");
    old.sqlite.exec("INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES ('t', 1, 'p', 5, 1, 0)");

    old.sqlite.exec(m2);
    expect(old.rows("SELECT voided, voided_at FROM purchases")).toEqual([{ voided: 0, voided_at: null }]);
    old.sqlite.exec(m3);
    expect(old.rows("PRAGMA table_info(accounts)").map((c) => (c as { name: string }).name)).not.toContain("google_sub");
    old.sqlite.exec(m4);
    expect(old.rows("PRAGMA table_info(accounts)").map((c) => (c as { name: string }).name)).not.toContain("last_used_at");
    old.sqlite.exec(m5);
    expect(describeDb(old)).toEqual(describeDb(fresh));
    expect(old.rows("SELECT voided_quantity FROM purchases")).toEqual([{ voided_quantity: 0 }]);
    expect(old.rows("SELECT install_id, google_sub FROM accounts")).toEqual([{ install_id: "i", google_sub: null }]);
  });

  it("0004: 0003 까지 적용된 DB 의 기존 계정은 연결 안 된 계정으로 남고, Google 로그인으로 연결된다", async () => {
    const { FakeD1, m4, m5 } = await load();
    const db = new FakeD1();
    before0004(db);
    const now = Math.floor(Date.now() / 1000);
    db.sqlite.exec(
      `INSERT INTO accounts (install_id, token_hash, credits, free_credits, created_at, updated_at)
       VALUES ('legacy-install-m4', 'h', 55, 40, ${now}, ${now})`,
    );
    db.sqlite.exec(m4);
    db.sqlite.exec(m5);
    const env = { ...makeEnv(), DB: db as unknown as D1Database, db };
    const r = await register(env, "legacy-install-m4", "google-sub-m4");
    expect(r).toMatchObject({ credits: 55, freeGranted: false, restored: true });
    expect(db.rows("SELECT google_sub FROM accounts")).toEqual([{ google_sub: "google-sub-m4" }]);
    expect(db.rows("SELECT COUNT(*) AS n FROM free_credit_grants")).toEqual([{ n: 1 }]);
    // 두 계정이 같은 sub 를 가질 수 없다(UNIQUE 인덱스)
    expect(() =>
      db.sqlite.exec(`INSERT INTO accounts (install_id, token_hash, google_sub, created_at, updated_at) VALUES ('x-install-01', 'h2', 'google-sub-m4', 0, 0)`),
    ).toThrow(/UNIQUE/);
  });

  it("0003: 이미 회수한 구매는 전체 수량 환불 + legacy 이벤트로 옮긴다", async () => {
    const { FakeD1, m3 } = await load();
    const old = new FakeD1();
    before0003(old);
    old.sqlite.exec(
      `INSERT INTO accounts (install_id, token_hash, created_at, updated_at) VALUES ('i', 'h', 0, 0);
       INSERT INTO purchases (purchase_token, account_id, product_id, quantity, credits, credited, voided, voided_at, created_at)
         VALUES ('v', 1, 'p', 2, 1000, 1, 1, 123, 0), ('k', 1, 'p', 1, 500, 1, 0, NULL, 0);`,
    );
    old.sqlite.exec(m3);
    expect(old.rows("SELECT purchase_token, voided_quantity FROM purchases ORDER BY purchase_token")).toEqual([
      { purchase_token: "k", voided_quantity: 0 },
      { purchase_token: "v", voided_quantity: 2 },
    ]);
    expect(old.rows("SELECT purchase_token, event_key, quantity, credits, applied, voided_at FROM voided_events")).toEqual([
      { purchase_token: "v", event_key: "legacy", quantity: 2, credits: 1000, applied: 1, voided_at: 123 },
    ]);
  });
  it("0005: 기존 잔액을 유료(환불 안 된 지급 구매 합계까지, 최신 구매부터)와 무료로 나누고, 익명 신고·마지막 사용을 준비한다", async () => {
    const { FakeD1, m5 } = await load();
    const db = new FakeD1();
    before0005(db);
    const now = Math.floor(Date.now() / 1000);
    db.sqlite.exec(
      `INSERT INTO accounts (id, install_id, token_hash, credits, created_at, updated_at) VALUES
         (1, 'acct-a', 'ha', 700, 0, 111), (2, 'acct-b', 'hb', 1200, 0, 222), (3, 'acct-c', 'hc', -50, 0, 333),
         (4, 'acct-d', 'hd', 300, 0, 444), (5, 'deleted:tombstone', 'deleted:tombstone', 0, 0, 0);
       INSERT INTO purchases (purchase_token, account_id, product_id, order_id, credits, credited, voided, voided_quantity, created_at) VALUES
         ('a-old', 1, 'p', 'GPA.A1', 500, 1, 0, 0, ${now - 200}), ('a-new', 1, 'p', 'GPA.A2', 500, 1, 0, 0, ${now - 100}),
         ('b-1', 2, 'p', 'GPA.B1', 500, 1, 0, 0, ${now}),
         ('c-1', 3, 'p', 'GPA.C1', 500, 1, 0, 0, ${now}),
         ('d-void', 4, 'p', 'GPA.D1', 500, 1, 1, 1, ${now}), ('d-pend', 4, 'p', 'GPA.D2', 500, 0, 0, 0, ${now}),
         ('d-test', 4, 'p', 'GPA.D3', 0, 1, 0, 0, ${now}),
         ('sha256:x', 5, 'p', 'GPA.E1', 500, 1, 0, 0, ${now});
       INSERT INTO reports (account_id, kind, reason, content, created_at) VALUES (1, 'idea', 'r', 'c', ${now});
       INSERT INTO free_credit_grants (sub_hash, created_at) VALUES ('h', 0);`,
    );
    db.sqlite.exec(m5);
    expect(db.rows("SELECT purchase_token, remaining, lot_closed_reason, expires_at IS NOT NULL AS lot FROM purchases ORDER BY id")).toEqual([
      { purchase_token: "a-old", remaining: 200, lot_closed_reason: null, lot: 1 }, // 700 = 최신 500 + 오래된 200
      { purchase_token: "a-new", remaining: 500, lot_closed_reason: null, lot: 1 },
      { purchase_token: "b-1", remaining: 500, lot_closed_reason: null, lot: 1 }, // 1200 = 유료 500 + 무료 700
      { purchase_token: "c-1", remaining: 0, lot_closed_reason: null, lot: 1 }, // 빚(-50): 유료 0
      { purchase_token: "d-void", remaining: 0, lot_closed_reason: "voided", lot: 1 }, // 환불된 구매는 유료로 치지 않음 → 300 은 무료
      { purchase_token: "d-pend", remaining: 0, lot_closed_reason: null, lot: 0 },
      { purchase_token: "d-test", remaining: 0, lot_closed_reason: null, lot: 0 },
      { purchase_token: "sha256:x", remaining: 0, lot_closed_reason: "deleted", lot: 1 },
    ]);
    const { addYears } = await import("../src/billing/lots");
    expect(db.rows("SELECT expires_at FROM purchases WHERE purchase_token = 'b-1'")).toEqual([{ expires_at: addYears(now, 5) }]);
    expect(db.rows("SELECT id, last_used_at FROM accounts ORDER BY id").slice(0, 2)).toEqual([
      { id: 1, last_used_at: 111 },
      { id: 2, last_used_at: 222 },
    ]);
    expect(db.rows("SELECT account_id, gone_at FROM free_credit_grants")).toEqual([{ account_id: null, gone_at: null }]);
    // 신고: 기존 행·번호는 그대로, 익명(account_id NULL) 신고를 받을 수 있다
    db.sqlite.exec(`INSERT INTO reports (account_id, kind, reason, content, created_at) VALUES (NULL, 'other', 'r', 'c', ${now})`);
    expect(db.rows("SELECT id, account_id FROM reports ORDER BY id")).toEqual([
      { id: 1, account_id: 1 },
      { id: 2, account_id: null },
    ]);
    const { balanceBreakdown } = await import("../src/billing/lots");
    const D = db as unknown as D1Database;
    expect(await balanceBreakdown(D, 1, now)).toEqual({ credits: 700, freeCredits: 0, paidCredits: 700, expiringSoon: null });
    expect(await balanceBreakdown(D, 2, now)).toEqual({ credits: 1200, freeCredits: 700, paidCredits: 500, expiringSoon: null });
    expect(await balanceBreakdown(D, 3, now)).toEqual({ credits: -50, freeCredits: -50, paidCredits: 0, expiringSoon: null });
    expect(await balanceBreakdown(D, 4, now)).toEqual({ credits: 300, freeCredits: 300, paidCredits: 0, expiringSoon: null });
  });
});

describe("운영 기본값(가격 체제)", () => {
  it("변수가 없으면 무료 20 크레딧, 마크업 2.5, 하루 무료 상한 2000(= 100명)", async () => {
    const { loadConfig } = await import("../src/env");
    const cfg = loadConfig({ DB: {} as D1Database } as Env);
    expect(cfg.freeCredits).toBe(20);
    expect(cfg.markup).toBe(2.5);
    expect(cfg.freeCreditsDailyCap).toBe(2000);
  });

  it("wrangler.toml 의 상품·가격·마크업이 앱 기본값과 맞는다", async () => {
    const { readFileSync } = await import("node:fs");
    const toml = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");
    const value = (key: string): string => new RegExp(`^${key} = (.*)$`, "m").exec(toml)![1]!.trim().replace(/^['"]|['"]$/g, "");
    expect(value("MARKUP")).toBe("2.5");
    expect(value("FREE_CREDITS")).toBe("20");
    expect(JSON.parse(value("PRODUCTS"))).toEqual({ ember_credits_500: 500, ember_credits_1500: 1650, ember_credits_5000: 5750 });
    expect(JSON.parse(value("PRODUCT_PRICES_KRW"))).toEqual({ ember_credits_500: 5900, ember_credits_1500: 17900, ember_credits_5000: 59000 });
  });
});
