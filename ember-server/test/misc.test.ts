import { describe, expect, it } from "vitest";
import worker from "../src/index";
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
      creditsGranted: { free: 200, purchased: 1000, total: 1200 },
      creditsSpent: 10,
      creditsOutstanding: 200,
      purchases: 2,
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
    env.db.sqlite.exec(`INSERT INTO rate_limits VALUES ('old', 0, 1), ('new', ${now}, 1)`);
    env.db.sqlite.exec(`INSERT INTO inflight (account_id, reserved, started_at) VALUES (1, 5, ${now - 7200}), (1, 5, ${now})`);
    await worker.scheduled({} as ScheduledController, env, makeCtx());
    expect(env.db.rows("SELECT key FROM rate_limits")).toEqual([{ key: "new" }]);
    expect(env.db.rows("SELECT started_at FROM inflight")).toEqual([{ started_at: now }]);
  });
});

describe("보관 기간 정리(cron)", () => {
  it("1년 지난 기록은 지우고, 잔액 0 이하·구매 없는 계정만 지우고, 잔액이나 환불 안 된 구매가 있으면 그대로 둔다", async () => {
    const { purgeExpired, RETENTION_SECONDS } = await import("../src/retention");
    const env = makeEnv();
    const ids: Record<string, number> = {};
    const tokens: Record<string, string> = {};
    for (const name of ["free-empty", "free-balance", "paid-empty", "voided-only", "fresh"]) {
      tokens[name] = (await register(env, `install-${name}-0001`)).token;
      ids[name] = env.db.rows<{ id: number }>("SELECT MAX(id) AS id FROM accounts")[0]!.id;
    }
    const now = Math.floor(Date.now() / 1000);
    const old = now - RETENTION_SECONDS - 10;
    const q = (sql: string, ...p: (string | number)[]) => env.db.sqlite.prepare(sql).run(...p);
    q("UPDATE accounts SET updated_at = ?, credits = 0 WHERE id != ?", old, ids["fresh"]!);
    q("UPDATE accounts SET credits = 25 WHERE id = ?", ids["free-balance"]!);
    q("INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES ('tok-paid', ?, 'ember_credits_500', 500, 1, ?)", ids["paid-empty"]!, old);
    q("INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at) VALUES ('tok-void', ?, 'ember_credits_500', 500, 1, 1, ?)", ids["voided-only"]!, old);
    q("INSERT INTO usage_log (account_id, model, status, created_at) VALUES (?, 'claude-opus-5-5', 200, ?)", ids["paid-empty"]!, old);

    await purgeExpired(env.DB, now);

    const accounts = env.db.rows<{ id: number; install_id: string }>("SELECT id, install_id FROM accounts ORDER BY id");
    expect(accounts).toEqual([
      { id: ids["free-balance"], install_id: "install-free-balance-0001" }, // 잔액이 남음 → 그대로
      { id: ids["paid-empty"], install_id: "install-paid-empty-0001" }, // 환불 안 된 구매 → 그대로
      { id: ids["voided-only"], install_id: `expired-${ids["voided-only"]}` }, // 환불된 구매만 → 토큰 무효, 기록 보관
      { id: ids["fresh"], install_id: "install-fresh-0001" },
    ]);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM usage_log")).toEqual([{ n: 0 }]);
    expect(env.db.rows("SELECT COUNT(*) AS n FROM purchases")).toEqual([{ n: 2 }]);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": tokens["free-balance"]! } })).res.status).toBe(200);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": tokens["paid-empty"]! } })).res.status).toBe(200);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": tokens["voided-only"]! } })).res.status).toBe(401);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": tokens["free-empty"]! } })).res.status).toBe(401);
  });

  it("5년 지난 구매 기록은 만료된 계정 것만 지운다", async () => {
    const { purgeExpired, PURCHASE_RETENTION_SECONDS } = await import("../src/retention");
    const env = makeEnv();
    await register(env, "install-keep-paid-01");
    const now = Math.floor(Date.now() / 1000);
    const ancient = now - PURCHASE_RETENTION_SECONDS - 10;
    env.db.sqlite.exec(
      `INSERT INTO accounts (install_id, token_hash, credits, created_at, updated_at) VALUES ('expired-99', 'expired-99', 0, 0, ${now});
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES ('a', 1, 'p', 5, 1, ${ancient});
       INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, voided, created_at)
         SELECT 'b', id, 'p', 5, 1, 1, ${ancient} FROM accounts WHERE install_id = 'expired-99';`,
    );
    await purgeExpired(env.DB, now);
    expect(env.db.rows("SELECT purchase_token FROM purchases")).toEqual([{ purchase_token: "a" }]);
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

  async function load(): Promise<{ FakeD1: typeof import("./helpers/d1").FakeD1; m2: string; m3: string }> {
    const { readFileSync } = await import("node:fs");
    const { FakeD1 } = await import("./helpers/d1");
    const m2 = readFileSync(new URL("../migrations/0002_voided_integrity.sql", import.meta.url), "utf8");
    const m3 = readFileSync(new URL("../migrations/0003_billing_guards.sql", import.meta.url), "utf8");
    return { FakeD1, m2, m3 };
  }

  /** 0003 이전 스키마(= 0002 까지 적용한 DB) 흉내 */
  function before0003(db: Db): void {
    db.sqlite.exec(
      `ALTER TABLE purchases DROP COLUMN voided_quantity;
       DROP TABLE voided_events; DROP INDEX idx_inflight_account; DROP TABLE inflight;`,
    );
  }

  it("예전 스키마에 0002 → 0003 을 적용하면 schema.sql 과 같은 구조가 된다", async () => {
    const { FakeD1, m2, m3 } = await load();
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
    expect(describeDb(old)).toEqual(describeDb(fresh));
    expect(old.rows("SELECT voided_quantity FROM purchases")).toEqual([{ voided_quantity: 0 }]);
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
});
