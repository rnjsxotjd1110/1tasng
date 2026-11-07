import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { runDailyJobs } from "../src/index";
import { loadConfig } from "../src/env";
import { clearGoogleTokenCache, ANDROID_PUBLISHER_SCOPE } from "../src/play/google-auth";
import {
  processVoidedPurchases,
  VOIDED_CURSOR_KEY,
  VOIDED_MAX_LOOKBACK_MS,
  VOIDED_OVERLAP_MS,
  voidedStartTime,
} from "../src/play/voided";
import { call, errorBody, makeCtx, makeEnv, register, type TestEnv } from "./helpers/env";
import { installFakeGoogle } from "./helpers/google";

const NOW_MS = Date.UTC(2026, 10, 5, 3, 17, 0);
const DAY = 86_400_000;

beforeEach(() => clearGoogleTokenCache());
afterEach(() => vi.unstubAllGlobals());

/** 계정을 만들고 지급 완료된 구매를 넣는다. 계정 id 를 돌려준다. */
async function paidAccount(env: TestEnv, purchaseToken: string, credits: number): Promise<{ id: number; token: string }> {
  const { token } = await register(env);
  const id = env.db.rows<{ id: number }>("SELECT MAX(id) AS id FROM accounts")[0]!.id;
  env.db.sqlite
    .prepare(
      `INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at)
       VALUES (?, ?, 'ember_credits_500', ?, 1, ?)`,
    )
    .run(purchaseToken, id, credits, Math.floor(Date.now() / 1000));
  env.db.sqlite.prepare("UPDATE accounts SET credits = credits + ? WHERE id = ?").run(credits, id);
  return { id, token };
}

function creditsOf(env: TestEnv, id: number): number {
  return env.db.rows<{ credits: number }>("SELECT credits FROM accounts WHERE id = ?", id)[0]!.credits;
}

function cursor(env: TestEnv): string | undefined {
  return env.db.rows<{ value: string }>("SELECT value FROM meta WHERE key = ?", VOIDED_CURSOR_KEY)[0]?.value;
}

describe("환불 회수(Voided Purchases)", () => {
  it("첫 실행은 30일 전부터 조회하고, 지급된 구매의 크레딧을 빼고(음수 가능) voided 로 표시한다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "tok-refunded", 500); // 100 + 500 = 600
    env.db.sqlite.prepare("UPDATE accounts SET credits = 120 WHERE id = ?").run(a.id); // 480 크레딧 사용함
    const b = await paidAccount(env, "tok-kept", 1650);
    const voidedAt = NOW_MS - 3 * DAY;
    g.voidedPages = [[{ purchaseToken: "tok-refunded", orderId: "GPA.1", voidedTimeMillis: String(voidedAt), voidedSource: 0, voidedReason: 1 }]];

    const r = await processVoidedPurchases(env, loadConfig(env), NOW_MS);

    expect(r).toEqual({ listed: 1, clawedBack: 1, credits: 500, startTimeMs: NOW_MS - 30 * DAY + 10 * 60_000 });
    const q = g.voidedRequests[0]!;
    expect(q.searchParams.get("startTime")).toBe(String(NOW_MS - 30 * DAY + 10 * 60_000));
    expect(q.searchParams.get("type")).toBe("0");
    expect(q.searchParams.get("maxResults")).toBe("1000");
    expect(q.searchParams.get("includeQuantityBasedPartialRefund")).toBe("true");
    expect(q.searchParams.has("token")).toBe(false);
    expect(g.tokenRequests[ANDROID_PUBLISHER_SCOPE]).toBe(1);

    expect(creditsOf(env, a.id)).toBe(-380);
    expect(creditsOf(env, b.id)).toBe(1750);
    expect(env.db.rows("SELECT purchase_token, voided, voided_at FROM purchases ORDER BY id")).toEqual([
      { purchase_token: "tok-refunded", voided: 1, voided_at: Math.floor(voidedAt / 1000) },
      { purchase_token: "tok-kept", voided: 0, voided_at: null },
    ]);
    expect(cursor(env)).toBe(String(NOW_MS));

    // 음수 잔액이면 /v1/messages 는 402
    const { res } = await call(env, "/v1/messages", {
      method: "POST",
      json: { model: "claude-haiku-5-5", max_tokens: 10, messages: [] },
      headers: { "x-api-key": a.token },
    });
    expect(res.status).toBe(402);
    expect((await errorBody(res)).error.type).toBe("insufficient_credits");
  });

  it("멱등: 같은 환불이 다시 와도 한 번만 빼고, 모르는·미지급 구매는 무시한다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "tok-1", 500);
    env.db.sqlite.exec("UPDATE purchases SET credited = 0, purchase_token = 'tok-uncredited' WHERE purchase_token = 'tok-1'");
    const b = await paidAccount(env, "tok-2", 500);
    g.voidedPages = [
      [
        { purchaseToken: "tok-2", voidedTimeMillis: String(NOW_MS - DAY) },
        { purchaseToken: "tok-2", voidedTimeMillis: String(NOW_MS - DAY) }, // 같은 목록 안 중복
        { purchaseToken: "tok-unknown" },
        { purchaseToken: "tok-uncredited" },
      ],
    ];
    const first = await processVoidedPurchases(env, loadConfig(env), NOW_MS);
    expect(first).toMatchObject({ listed: 4, clawedBack: 1, credits: 500 });
    const second = await processVoidedPurchases(env, loadConfig(env), NOW_MS + DAY);
    expect(second).toMatchObject({ listed: 4, clawedBack: 0, credits: 0 });

    expect(creditsOf(env, b.id)).toBe(100);
    expect(creditsOf(env, a.id)).toBe(600); // 미지급 구매는 건드리지 않는다
    expect(env.db.rows("SELECT purchase_token, voided FROM purchases ORDER BY id")).toEqual([
      { purchase_token: "tok-uncredited", voided: 0 },
      { purchase_token: "tok-2", voided: 1 },
    ]);
  });

  it("페이지 넘김(token)을 끝까지 따라간다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "p0", 500);
    const b = await paidAccount(env, "p1", 500);
    const c = await paidAccount(env, "p2", 500);
    g.voidedPages = [[{ purchaseToken: "p0" }], [{ purchaseToken: "p1" }], [{ purchaseToken: "p2" }]];
    const r = await processVoidedPurchases(env, loadConfig(env), NOW_MS);
    expect(r).toMatchObject({ listed: 3, clawedBack: 3, credits: 1500 });
    expect(g.voidedRequests.map((u) => u.searchParams.get("token"))).toEqual([null, "page1", "page2"]);
    for (const acc of [a, b, c]) expect(creditsOf(env, acc.id)).toBe(100);
    // voidedTimeMillis 가 없으면 처리 시각을 쓴다
    expect(env.db.rows<{ voided_at: number }>("SELECT voided_at FROM purchases")[0]!.voided_at).toBe(NOW_MS / 1000);
  });

  it("다음 실행은 지난 처리 시각 - 1일부터, 단 30일보다 오래 전으로는 가지 않는다", async () => {
    expect(voidedStartTime(undefined, NOW_MS)).toBe(NOW_MS - VOIDED_MAX_LOOKBACK_MS + 10 * 60_000);
    expect(voidedStartTime(NOW_MS - DAY, NOW_MS)).toBe(NOW_MS - DAY - VOIDED_OVERLAP_MS);
    expect(voidedStartTime(NOW_MS - 60 * DAY, NOW_MS)).toBe(NOW_MS - VOIDED_MAX_LOOKBACK_MS + 10 * 60_000);

    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    await processVoidedPurchases(env, loadConfig(env), NOW_MS);
    await processVoidedPurchases(env, loadConfig(env), NOW_MS + DAY);
    expect(g.voidedRequests[1]!.searchParams.get("startTime")).toBe(String(NOW_MS + DAY - DAY - VOIDED_OVERLAP_MS));
    expect(cursor(env)).toBe(String(NOW_MS + DAY));
    expect(g.tokenRequests[ANDROID_PUBLISHER_SCOPE]).toBe(1); // 액세스 토큰 캐시
  });

  it("Google 오류면 예외를 던지고 처리 시각을 올리지 않는다(다음 실행에서 다시 본다)", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "p0", 500);
    g.voidedPages = [[{ purchaseToken: "p0" }], [{ purchaseToken: "p1" }]];
    g.voidedFailStatus = 503;
    await expect(processVoidedPurchases(env, loadConfig(env), NOW_MS)).rejects.toThrow(/503/);
    expect(cursor(env)).toBeUndefined();
    expect(creditsOf(env, a.id)).toBe(600);
  });

  it("서비스 계정이 없으면 건너뛴다", async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);
    const env = makeEnv();
    expect(await processVoidedPurchases(env, loadConfig(env), NOW_MS)).toBeNull();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("scheduled(cron) 에서 돌고, 환불 회수가 실패해도 다른 정리 작업은 끝낸 뒤 실패를 알린다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "tok-cron", 500);
    g.voidedPages = [[{ purchaseToken: "tok-cron" }]];
    await worker.scheduled({} as ScheduledController, env, makeCtx());
    expect(creditsOf(env, a.id)).toBe(100);

    g.voidedFailStatus = 500;
    const nowSec = Math.floor(NOW_MS / 1000);
    env.db.sqlite.exec(`INSERT INTO rate_limits VALUES ('old', 0, 1); INSERT INTO nonces VALUES ('expired-nonce-000000', ${nowSec - 1})`);
    await expect(runDailyJobs(env, NOW_MS)).rejects.toThrow(/환불 회수/);
    expect(env.db.rows("SELECT key FROM rate_limits WHERE key = 'old'")).toEqual([]);
    expect(env.db.rows("SELECT nonce FROM nonces")).toEqual([]);
  });

  it("수량 일부 환불(voidedQuantity)은 그 비율만큼만 회수하고, 같은 이벤트는 한 번만, 나중의 전체 환불은 나머지만", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "tok-multi", 1500); // 100 + 1500
    env.db.sqlite.exec("UPDATE purchases SET quantity = 3 WHERE purchase_token = 'tok-multi'");
    const t1 = String(NOW_MS - 2 * DAY);
    g.voidedPages = [[{ purchaseToken: "tok-multi", voidedTimeMillis: t1, voidedQuantity: 1 }]];

    expect(await processVoidedPurchases(env, loadConfig(env), NOW_MS)).toMatchObject({ clawedBack: 1, credits: 500 });
    expect(creditsOf(env, a.id)).toBe(1100);
    // 다음 날 같은 이벤트가 다시 와도(겹쳐 보기) 한 번만
    expect(await processVoidedPurchases(env, loadConfig(env), NOW_MS + DAY)).toMatchObject({ clawedBack: 0, credits: 0 });
    expect(creditsOf(env, a.id)).toBe(1100);
    expect(env.db.rows("SELECT voided, voided_quantity FROM purchases")).toEqual([{ voided: 1, voided_quantity: 1 }]);

    // 다른 시각의 두 번째 일부 환불 1개, 그리고 전체 환불 → 나머지 1개 몫만
    g.voidedPages = [[
      { purchaseToken: "tok-multi", voidedTimeMillis: t1, voidedQuantity: 1 },
      { purchaseToken: "tok-multi", voidedTimeMillis: String(NOW_MS - DAY), voidedQuantity: 1 },
      { purchaseToken: "tok-multi", voidedTimeMillis: String(NOW_MS) },
    ]];
    expect(await processVoidedPurchases(env, loadConfig(env), NOW_MS + 2 * DAY)).toMatchObject({ clawedBack: 2, credits: 1000 });
    expect(creditsOf(env, a.id)).toBe(100);
    expect(env.db.rows("SELECT event_key, quantity, credits, applied FROM voided_events ORDER BY rowid")).toEqual([
      { event_key: `q:${t1}:1`, quantity: 1, credits: 500, applied: 1 },
      { event_key: `q:${NOW_MS - DAY}:1`, quantity: 1, credits: 500, applied: 1 },
      { event_key: "full", quantity: 1, credits: 500, applied: 1 },
    ]);
  });

  it("나눠떨어지지 않는 크레딧도 누적 기준으로 나눠 전부 환불되면 정확히 전액", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "tok-odd", 1000);
    env.db.sqlite.exec("UPDATE purchases SET quantity = 3 WHERE purchase_token = 'tok-odd'");
    g.voidedPages = [[
      { purchaseToken: "tok-odd", voidedTimeMillis: "1", voidedQuantity: 1 },
      { purchaseToken: "tok-odd", voidedTimeMillis: "2", voidedQuantity: 1 },
      { purchaseToken: "tok-odd", voidedTimeMillis: "3", voidedQuantity: 5 }, // 남은 것보다 많으면 남은 만큼
    ]];
    const r = await processVoidedPurchases(env, loadConfig(env), NOW_MS);
    expect(r).toMatchObject({ credits: 1000 });
    expect(env.db.rows<{ credits: number }>("SELECT credits FROM voided_events ORDER BY rowid").map((e) => e.credits)).toEqual([333, 333, 334]);
    expect(creditsOf(env, a.id)).toBe(100);
  });

  it("일부 환불만 있어도 결제 계정에서 빠진다(Opus → Sonnet)", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const a = await paidAccount(env, "tok-pp", 1000);
    env.db.sqlite.exec("UPDATE purchases SET quantity = 2 WHERE purchase_token = 'tok-pp'");
    const { authenticate } = await import("../src/auth");
    const paid = async () => (await authenticate(env, new Request("https://x", { headers: { "x-api-key": a.token } }))).paid;
    expect(await paid()).toBe(true);
    g.voidedPages = [[{ purchaseToken: "tok-pp", voidedTimeMillis: "5", voidedQuantity: 1 }]];
    await processVoidedPurchases(env, loadConfig(env), NOW_MS);
    expect(creditsOf(env, a.id)).toBe(600);
    expect(await paid()).toBe(false);
  });
});
