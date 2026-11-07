// 유료/무료 크레딧 분리: 묶음(lot), 쓰는 순서, 잔액 내역, 만료, 환불 회수, 탈퇴, 빚 갚기.
import { afterEach, describe, expect, it, vi } from "vitest";
import { recordUsage } from "../src/billing/ledger";
import { addYears, balanceBreakdown, expireLots, EXPIRING_SOON_SECONDS } from "../src/billing/lots";
import { emptyUsage } from "../src/billing/usage";
import { purgeExpired } from "../src/retention";
import { clawBackPurchase } from "../src/play/voided";
import { grantPurchase } from "../src/purchase";
import { call, makeEnv, register, type TestEnv } from "./helpers/env";

const NOW = Math.floor(Date.now() / 1000);
const DAY = 86400;

afterEach(() => vi.unstubAllGlobals());

interface LotRow {
  purchase_token: string;
  remaining: number;
  lot_closed_reason: string | null;
  lot_closed_credits: number;
}

/** 지급 완료 구매(열린 묶음)를 넣고 잔액에 더한다. */
function addLot(env: TestEnv, accountId: number, token: string, credits: number, createdAt: number, remaining = credits): void {
  env.db.sqlite
    .prepare(
      `INSERT INTO purchases (purchase_token, account_id, product_id, order_id, credits, credited, created_at, expires_at, remaining)
       VALUES (?, ?, 'ember_credits_500', ?, ?, 1, ?, ?, ?)`,
    )
    .run(token, accountId, `GPA.${token}`, credits, createdAt, addYears(createdAt, 5), remaining);
  env.db.sqlite.prepare("UPDATE accounts SET credits = credits + ? WHERE id = ?").run(remaining, accountId);
}

function lots(env: TestEnv): LotRow[] {
  return env.db.rows<LotRow>("SELECT purchase_token, remaining, lot_closed_reason, lot_closed_credits FROM purchases ORDER BY id");
}

function credits(env: TestEnv, id = 1): number {
  return env.db.rows<{ credits: number }>("SELECT credits FROM accounts WHERE id = ?", id)[0]!.credits;
}

async function balanceOf(env: TestEnv, token: string): Promise<Record<string, unknown>> {
  const { res } = await call(env, "/ember/balance", { headers: { "x-api-key": token } });
  expect(res.status).toBe(200);
  return (await res.json()) as Record<string, unknown>;
}

const BODY = { model: "claude-sonnet-5-5", max_tokens: 60000, messages: [{ role: "user", content: "안녕" }] };

/** 업스트림 대역: gate 가 풀릴 때까지 기다렸다가 usage 를 담은 응답을 준다. */
function stubMessage(usage: Record<string, number>, gate?: Promise<void>): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => {
      if (gate) await gate;
      return Response.json({
        id: "msg_1",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-5-5",
        content: [{ type: "text", text: "hi" }],
        stop_reason: "end_turn",
        usage,
      });
    }),
  );
}

async function send(env: TestEnv, token: string): Promise<Response> {
  return (await call(env, "/v1/messages", { method: "POST", json: BODY, headers: { "x-api-key": token } })).res;
}

describe("GET /ember/balance 내역", () => {
  it("credits(예전 앱 호환) + freeCredits + paidCredits + expiringSoon", async () => {
    const env = makeEnv();
    const { token } = await register(env); // 무료 100
    addLot(env, 1, "old", 500, NOW - 100 * DAY, 300);
    addLot(env, 1, "new", 1650, NOW - DAY);
    expect(await balanceOf(env, token)).toEqual({ credits: 2050, freeCredits: 100, paidCredits: 1950, expiringSoon: null });
  });

  it("30일 안에 만료되는 유료 크레딧을 알려 준다(합계, 가장 이른 만료 시각 = 유닉스 초)", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    addLot(env, 1, "a", 500, NOW, 120);
    addLot(env, 1, "b", 500, NOW, 80);
    addLot(env, 1, "late", 500, NOW, 500);
    addLot(env, 1, "used", 500, NOW, 0);
    env.db.sqlite.exec(`UPDATE purchases SET expires_at = ${NOW + 10 * DAY} WHERE purchase_token IN ('a', 'used')`);
    env.db.sqlite.exec(`UPDATE purchases SET expires_at = ${NOW + 20 * DAY} WHERE purchase_token = 'b'`);
    env.db.sqlite.exec(`UPDATE purchases SET expires_at = ${NOW + 31 * DAY} WHERE purchase_token = 'late'`);
    expect(await balanceOf(env, token)).toEqual({
      credits: 800,
      freeCredits: 100,
      paidCredits: 700,
      expiringSoon: { credits: 200, at: NOW + 10 * DAY },
    });
    expect(EXPIRING_SOON_SECONDS).toBe(30 * DAY);
  });

  it("빚(음수 잔액)이면 freeCredits 가 음수, paidCredits 는 0", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = -40");
    expect(await balanceOf(env, token)).toEqual({ credits: -40, freeCredits: -40, paidCredits: 0, expiringSoon: null });
  });
});

describe("쓰는 순서: 무료 먼저, 그다음 오래된 구매부터", () => {
  it("무료로 충분하면 유료 묶음은 그대로(예약 중에도)", async () => {
    const env = makeEnv();
    const { token } = await register(env); // 무료 100
    addLot(env, 1, "old", 500, NOW - 10 * DAY);
    addLot(env, 1, "new", 500, NOW - DAY);
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    stubMessage({ input_tokens: 1000, output_tokens: 500 }, gate); // 2 크레딧
    const pending = send(env, token);
    await new Promise((r) => setTimeout(r, 20));
    // 예약액(약 92)은 무료 100 안에서 빠진다
    expect(lots(env).map((l) => l.remaining)).toEqual([500, 500]);
    release();
    expect((await pending).status).toBe(200);
    expect(await balanceOf(env, token)).toEqual({ credits: 1098, freeCredits: 98, paidCredits: 1000, expiringSoon: null });
  });

  it("예약이 무료를 넘으면 오래된 묶음에서 잠시 빼고, 정산 때 쓰지 않은 만큼 그 묶음으로 되돌린다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = 10"); // 무료 10
    addLot(env, 1, "old", 500, NOW - 10 * DAY);
    addLot(env, 1, "new", 500, NOW - DAY);
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    stubMessage({ input_tokens: 1000, output_tokens: 500 }, gate); // 2 크레딧
    const pending = send(env, token);
    await new Promise((r) => setTimeout(r, 20));
    const during = lots(env).map((l) => l.remaining);
    expect(during[0]).toBeLessThan(500); // 오래된 묶음에서 예약
    expect(during[1]).toBe(500);
    expect(env.db.rows<{ reserved: number }>("SELECT reserved FROM inflight")[0]!.reserved).toBe(10 + 500 - during[0]!);
    release();
    expect((await pending).status).toBe(200);
    expect(lots(env).map((l) => l.remaining)).toEqual([500, 500]);
    expect(await balanceOf(env, token)).toMatchObject({ credits: 1008, freeCredits: 8, paidCredits: 1000 });
  });

  it("실제 비용이 무료를 넘으면 넘는 만큼 오래된 묶음에서 쓴다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = 10");
    addLot(env, 1, "old", 500, NOW - 10 * DAY);
    addLot(env, 1, "new", 500, NOW - DAY);
    stubMessage({ input_tokens: 1000, output_tokens: 10000 }); // $0.102 × 1.5 → 16 크레딧
    expect((await send(env, token)).status).toBe(200);
    expect(lots(env).map((l) => l.remaining)).toEqual([494, 500]);
    expect(await balanceOf(env, token)).toMatchObject({ credits: 994, freeCredits: 0, paidCredits: 994 });
  });

  it("예약보다 실제 비용이 큰 정산(드묾)도 무료 먼저, 그다음 오래된 묶음", async () => {
    const env = makeEnv();
    await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = 10");
    addLot(env, 1, "old", 50, NOW - 10 * DAY);
    addLot(env, 1, "new", 50, NOW - DAY);
    // 예약 2(무료에서) → 실제 30: 무료 10 을 다 쓰고 오래된 묶음에서 20
    env.db.sqlite.exec("UPDATE accounts SET credits = credits - 2");
    const balance = await recordUsage(env.DB, {
      accountId: 1, model: "claude-sonnet-5-5", status: 200, streamed: false, usage: emptyUsage(), credits: 30, reserved: 2, estimated: false, now: NOW,
    });
    expect(balance).toBe(80);
    expect(lots(env).map((l) => l.remaining)).toEqual([30, 50]);
  });

  it("오래된 묶음을 다 쓰면 다음 묶음, 모두 쓰면 잔액은 0", async () => {
    const env = makeEnv();
    await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = 0");
    addLot(env, 1, "a", 20, NOW - 30 * DAY);
    addLot(env, 1, "b", 20, NOW - 20 * DAY);
    addLot(env, 1, "c", 20, NOW - 10 * DAY);
    // 예약 없이 45 를 쓴 상태(잔액 15)에서 1 을 더 청구하는 정산: 묶음 합계를 잔액 14 에 맞춰 오래된 것부터 깎는다
    env.db.sqlite.exec("UPDATE accounts SET credits = credits - 45");
    await recordUsage(env.DB, {
      accountId: 1, model: "claude-sonnet-5-5", status: 200, streamed: false, usage: emptyUsage(), credits: 1, reserved: 0, estimated: false, now: NOW,
    });
    expect(credits(env)).toBe(14);
    expect(lots(env).map((l) => l.remaining)).toEqual([0, 0, 14]);
  });
});

describe("유효기간 5년", () => {
  it("만료된 묶음은 다음 요청(잔액 확인) 때 바로 닫고 잔액에서 뺀다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const created = addYears(NOW, -5) - DAY; // 5년 + 1일 전 구매
    addLot(env, 1, "expired", 500, created, 300);
    addLot(env, 1, "fresh", 500, NOW, 500);
    expect(await balanceOf(env, token)).toEqual({ credits: 600, freeCredits: 100, paidCredits: 500, expiringSoon: null });
    expect(lots(env)).toEqual([
      { purchase_token: "expired", remaining: 0, lot_closed_reason: "expired", lot_closed_credits: 300 },
      { purchase_token: "fresh", remaining: 500, lot_closed_reason: null, lot_closed_credits: 0 },
    ]);
  });

  it("cron 은 모든 계정의 만료된 묶음을 닫는다(만료 시각 직전은 그대로)", async () => {
    const env = makeEnv();
    await register(env);
    await register(env);
    addLot(env, 1, "a", 500, NOW - 100 * DAY, 200);
    addLot(env, 2, "b", 500, NOW - 100 * DAY, 50);
    env.db.sqlite.exec(`UPDATE purchases SET expires_at = ${NOW - 1} WHERE purchase_token = 'a'`);
    env.db.sqlite.exec(`UPDATE purchases SET expires_at = ${NOW + 1} WHERE purchase_token = 'b'`);
    expect(await expireLots(env.DB, NOW)).toBe(1);
    expect(credits(env, 1)).toBe(100);
    expect(credits(env, 2)).toBe(150);
    await purgeExpired(env.DB, NOW + 2);
    expect(credits(env, 2)).toBe(100);
    expect(lots(env).map((l) => l.lot_closed_reason)).toEqual(["expired", "expired"]);
  });

  it("만료 시각은 구매 시각 + 달력 5년(2월 29일 → 3월 1일)", () => {
    expect(addYears(Date.UTC(2024, 1, 29) / 1000, 5)).toBe(Date.UTC(2029, 2, 1) / 1000);
    expect(addYears(Date.UTC(2026, 10, 7, 12) / 1000, 5)).toBe(Date.UTC(2031, 10, 7, 12) / 1000);
  });
});

describe("환불 회수(Google Voided Purchases): 그 구매의 묶음 먼저, 그다음 나머지 잔액", () => {
  it("남은 묶음에서 먼저 빼고, 모자라면 무료 → 다른 묶음 순서로, 그래도 모자라면 음수", async () => {
    const env = makeEnv();
    const { token } = await register(env); // 무료 100
    addLot(env, 1, "A", 500, NOW - 10 * DAY, 300);
    addLot(env, 1, "B", 500, NOW - DAY, 500);
    expect(credits(env)).toBe(900);

    // B 전체 환불: B 의 500 에서 전부
    expect(await clawBackPurchase(env.DB, { purchaseToken: "B" }, NOW)).toBe(500);
    expect(await balanceOf(env, token)).toMatchObject({ credits: 400, freeCredits: 100, paidCredits: 300 });
    expect(lots(env)[1]).toEqual({ purchase_token: "B", remaining: 0, lot_closed_reason: "voided", lot_closed_credits: 0 });

    // A 전체 환불(500): A 에 남은 300 + 나머지 200(무료 100 → 다른 묶음 없음 → 음수 100)
    expect(await clawBackPurchase(env.DB, { purchaseToken: "A" }, NOW)).toBe(500);
    expect(await balanceOf(env, token)).toEqual({ credits: -100, freeCredits: -100, paidCredits: 0, expiringSoon: null });
  });

  it("그 묶음을 다 썼으면 무료에서, 무료도 없으면 다른 오래된 묶음에서", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = 30"); // 무료 30
    addLot(env, 1, "A", 500, NOW - 10 * DAY, 400);
    addLot(env, 1, "B", 500, NOW - DAY, 100);
    expect(await clawBackPurchase(env.DB, { purchaseToken: "B" }, NOW)).toBe(500);
    // B 100 → 0, 나머지 400: 무료 30 → A 에서 370
    expect(await balanceOf(env, token)).toMatchObject({ credits: 30, freeCredits: 0, paidCredits: 30 });
    expect(lots(env).map((l) => l.remaining)).toEqual([30, 0]);
  });

  it("수량 일부 환불은 묶음을 열어 둔 채 그만큼만 뺀다", async () => {
    const env = makeEnv();
    await register(env);
    addLot(env, 1, "Q", 1000, NOW - DAY, 1000);
    env.db.sqlite.exec("UPDATE purchases SET quantity = 2 WHERE purchase_token = 'Q'");
    expect(await clawBackPurchase(env.DB, { purchaseToken: "Q", voidedQuantity: 1, voidedTimeMillis: 1 }, NOW)).toBe(500);
    expect(lots(env)[0]).toEqual({ purchase_token: "Q", remaining: 500, lot_closed_reason: null, lot_closed_credits: 0 });
    expect(credits(env)).toBe(600);
  });
});

describe("구매 지급과 빚", () => {
  it("빚(음수 잔액)이 있으면 새 묶음에서 먼저 갚는다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    env.db.sqlite.exec("UPDATE accounts SET credits = -50");
    const r = await grantPurchase(env.DB, 1, "ember_credits_500", "tok-debt", 500, { orderId: "GPA.D", quantity: 1 }, NOW, {
      micros: 5_900_000_000,
      currency: "KRW",
    });
    expect(r).toEqual({ credits: 450, granted: 500 });
    expect(await balanceOf(env, token)).toMatchObject({ credits: 450, freeCredits: 0, paidCredits: 450 });
    expect(env.db.rows("SELECT remaining, expires_at, price_micros, price_currency FROM purchases")).toEqual([
      { remaining: 450, expires_at: addYears(NOW, 5), price_micros: 5_900_000_000, price_currency: "KRW" },
    ]);
  });

  it("0 크레딧(운영의 테스트 구매)은 묶음을 만들지 않는다", async () => {
    const env = makeEnv();
    await register(env);
    await grantPurchase(env.DB, 1, "ember_credits_500", "tok-test", 0, { orderId: "GPA.T", quantity: 1, purchaseType: 0 }, NOW);
    expect(env.db.rows("SELECT remaining, expires_at FROM purchases")).toEqual([{ remaining: 0, expires_at: null }]);
  });
});

describe("탈퇴", () => {
  it("남은 유료 묶음을 닫는다('deleted')", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    addLot(env, 1, "L", 500, NOW, 320);
    expect((await call(env, "/ember/account", { method: "DELETE", headers: { "x-api-key": token } })).res.status).toBe(200);
    expect(env.db.rows("SELECT remaining, lot_closed_reason, lot_closed_credits FROM purchases")).toEqual([
      { remaining: 0, lot_closed_reason: "deleted", lot_closed_credits: 320 },
    ]);
  });
});

describe("balanceBreakdown", () => {
  it("없는 계정은 0", async () => {
    const env = makeEnv();
    expect(await balanceBreakdown(env.DB, 99, NOW)).toEqual({ credits: 0, freeCredits: 0, paidCredits: 0, expiringSoon: null });
  });
});
