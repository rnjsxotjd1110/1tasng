import { describe, expect, it } from "vitest";
import worker from "../src/index";
import { call, errorBody, makeCtx, makeEnv, register } from "./helpers/env";

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
    const post = (json: unknown) => call(env, "/ember/report", { method: "POST", json, headers: { "x-api-key": token } });
    expect((await post({ ...report, kind: "spam" })).res.status).toBe(400);
    expect((await post({ ...report, content: "가".repeat(20_001) })).res.status).toBe(400);
    expect((await post({ ...report, content: "가".repeat(20_000) })).res.status).toBe(200);
    expect((await post({ kind: "other", reason: "r", content: "c" })).res.status).toBe(200); // note/appVersion 생략 가능
    expect((await call(env, "/ember/report", { method: "POST", json: report })).res.status).toBe(401);
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
       INSERT INTO usage_log (account_id, model, status, credits, created_at) VALUES (1, 'claude-opus-5-5', 200, 7, ${now}), (1, 'claude-opus-5-5', 200, 3, ${now - 2 * 86400});`,
    );
    const { res } = await call(env, "/ember/admin/stats", { headers: { "x-admin-key": "test-admin-key" } });
    expect(await res.json()).toEqual({
      accounts: 2,
      creditsGranted: { free: 200, purchased: 500, total: 700 },
      creditsSpent: 10,
      creditsOutstanding: 200,
      purchases: 1,
      reports: 0,
      last24h: { requests: 1, creditsSpent: 7 },
    });
  });

  it("reports: 최신순·limit·before", async () => {
    const env = makeEnv();
    const { token } = await register(env);
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

  it("cron 은 오래된 rate_limits 를 지운다", async () => {
    const env = makeEnv();
    env.db.sqlite.exec(`INSERT INTO rate_limits VALUES ('old', 0, 1), ('new', ${Math.floor(Date.now() / 1000)}, 1)`);
    await worker.scheduled({} as ScheduledController, env, makeCtx());
    expect(env.db.rows("SELECT key FROM rate_limits")).toEqual([{ key: "new" }]);
  });
});

describe("보관 기간 정리(cron)", () => {
  it("1년 지난 기록·결제 없는 계정은 지우고, 결제한 계정은 토큰만 무효로 만든다", async () => {
    const { purgeExpired, RETENTION_SECONDS } = await import("../src/retention");
    const env = makeEnv();
    const a = await register(env, "install-old-free-0001");
    const b = await register(env, "install-old-paid-0002");
    const now = Math.floor(Date.now() / 1000);
    const old = now - RETENTION_SECONDS - 10;
    await env.DB.prepare("UPDATE accounts SET updated_at = ?").bind(old).run();
    const paid = await env.DB.prepare("SELECT id FROM accounts WHERE install_id = ?").bind("install-old-paid-0002").first<{ id: number }>();
    await env.DB.prepare(
      "INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at) VALUES ('tok', ?, 'ember_credits_500', 500, 1, ?)",
    ).bind(paid!.id, old).run();
    await env.DB.prepare(
      "INSERT INTO usage_log (account_id, model, status, created_at) VALUES (?, 'claude-opus-5-5', 200, ?)",
    ).bind(paid!.id, old).run();

    await purgeExpired(env.DB, now);

    const accounts = await env.DB.prepare("SELECT install_id FROM accounts").all<{ install_id: string }>();
    expect(accounts.results.map((r) => r.install_id)).toEqual([`expired-${paid!.id}`]);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM usage_log").first<{ n: number }>())!.n).toBe(0);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM purchases").first<{ n: number }>())!.n).toBe(1);
    // 옛 토큰은 더 이상 통하지 않는다.
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": a.token } })).res.status).toBe(401);
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": b.token } })).res.status).toBe(401);
  });
});
