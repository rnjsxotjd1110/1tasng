// 청약철회·환불 계산(약관 7장)과 운영자 환불 엔드포인트.
import { describe, expect, it } from "vitest";
import { addYears } from "../src/billing/lots";
import { clawBackPurchase } from "../src/play/voided";
import { computeRefund, microsToAmount, WITHDRAWAL_PERIOD_SECONDS } from "../src/refund";
import { call, errorBody, makeEnv, register, type TestEnv } from "./helpers/env";

const NOW = Math.floor(Date.now() / 1000);
const DAY = 86400;
const ADMIN = { "x-admin-key": "test-admin-key" };
const KRW = (won: number) => won * 1_000_000;

describe("computeRefund", () => {
  const base = { amountPaidMicros: KRW(5900), lotCredits: 500, purchasedAt: NOW - DAY, now: NOW };

  it("7일 이내·쓰지 않음 → 전액(청약철회), 수수료 없음", () => {
    expect(computeRefund({ ...base, remaining: 500 })).toEqual({
      withinWithdrawalPeriod: true,
      feeRate: 0,
      ratio: 1,
      grossMicros: KRW(5900),
      feeMicros: 0,
      refundableMicros: KRW(5900),
    });
  });

  it("7일 이내·일부 사용 → 결제 금액 × 남은 비율, 수수료 없음", () => {
    const r = computeRefund({ ...base, remaining: 300 });
    expect(r).toMatchObject({ withinWithdrawalPeriod: true, feeRate: 0, ratio: 0.6, refundableMicros: KRW(3540) });
  });

  it("7일이 지나면 같은 비율 × 0.9(10% 수수료)", () => {
    const r = computeRefund({ ...base, remaining: 300, purchasedAt: NOW - 8 * DAY });
    expect(r).toMatchObject({ withinWithdrawalPeriod: false, feeRate: 0.1, grossMicros: KRW(3540), feeMicros: KRW(354), refundableMicros: KRW(3186) });
    // 정확히 7일째까지는 이내
    expect(computeRefund({ ...base, remaining: 300, purchasedAt: NOW - WITHDRAWAL_PERIOD_SECONDS }).feeRate).toBe(0);
    expect(computeRefund({ ...base, remaining: 300, purchasedAt: NOW - WITHDRAWAL_PERIOD_SECONDS - 1 }).feeRate).toBe(0.1);
  });

  it("waiveFee(서비스 종료 등)면 7일이 지나도 수수료 없음. 남은 양은 0~지급량으로 자르고, 나머지는 내림", () => {
    expect(computeRefund({ ...base, remaining: 300, purchasedAt: 0, waiveFee: true })).toMatchObject({ feeRate: 0, refundableMicros: KRW(3540) });
    expect(computeRefund({ ...base, remaining: 900 }).refundableMicros).toBe(KRW(5900));
    expect(computeRefund({ ...base, remaining: -5 }).refundableMicros).toBe(0);
    expect(computeRefund({ ...base, lotCredits: 0, remaining: 0 })).toMatchObject({ ratio: 0, refundableMicros: 0 });
    expect(computeRefund({ amountPaidMicros: 1_000_000, lotCredits: 3, remaining: 1, purchasedAt: NOW, now: NOW }).refundableMicros).toBe(333_333);
  });

  it("표시 금액: 원은 정수, 달러는 소수 2자리(내림)", () => {
    expect(microsToAmount(KRW(3186) + 999_999, "KRW")).toBe(3186);
    expect(microsToAmount(4_999_999, "USD")).toBe(4.99);
  });
});

/** 지급 완료 구매(열린 묶음)를 넣고 잔액에 더한다. */
function addPurchase(
  env: TestEnv,
  o: { token: string; order: string; credits: number; remaining: number; createdAt: number; priceMicros?: number | null; product?: string },
): void {
  env.db.sqlite
    .prepare(
      `INSERT INTO purchases (purchase_token, account_id, product_id, order_id, credits, credited, created_at, expires_at, remaining, price_micros, price_currency)
       VALUES (?, 1, ?, ?, ?, 1, ?, ?, ?, ?, ?)`,
    )
    .run(
      o.token,
      o.product ?? "ember_credits_500",
      o.order,
      o.credits,
      o.createdAt,
      addYears(o.createdAt, 5),
      o.remaining,
      o.priceMicros === undefined ? KRW(5900) : o.priceMicros,
      o.priceMicros === null ? null : "KRW",
    );
  env.db.sqlite.prepare("UPDATE accounts SET credits = credits + ? WHERE id = 1").run(o.remaining);
}

async function quote(env: TestEnv, query: string): Promise<{ status: number; body: Record<string, unknown> }> {
  const { res } = await call(env, `/ember/admin/refund-quote?${query}`, { headers: ADMIN });
  return { status: res.status, body: (await res.json()) as Record<string, unknown> };
}

async function refund(env: TestEnv, json: unknown): Promise<{ status: number; body: Record<string, unknown> }> {
  const { res } = await call(env, "/ember/admin/refund", { method: "POST", json, headers: ADMIN });
  return { status: res.status, body: (await res.json()) as Record<string, unknown> };
}

describe("GET /ember/admin/refund-quote", () => {
  it("관리자 키가 없으면 401, orderId 가 없으면 400, 모르는 주문은 404", async () => {
    const env = makeEnv();
    expect((await call(env, "/ember/admin/refund-quote?orderId=GPA.1")).res.status).toBe(401);
    expect((await quote(env, "")).status).toBe(400);
    expect((await quote(env, "orderId=GPA.none")).status).toBe(404);
    expect((await call(env, "/ember/admin/refund", { method: "POST", json: { orderId: "GPA.1" } })).res.status).toBe(401);
  });

  it("7일 이내 일부 사용: 금액·비율·묶음 상태를 돌려준다(DB 는 바꾸지 않음)", async () => {
    const env = makeEnv();
    await register(env);
    addPurchase(env, { token: "t1", order: "GPA.1111-2222", credits: 500, remaining: 300, createdAt: NOW - 2 * DAY });
    const { status, body } = await quote(env, "orderId=GPA.1111-2222");
    expect(status).toBe(200);
    expect(body).toEqual({
      orderId: "GPA.1111-2222",
      productId: "ember_credits_500",
      quantity: 1,
      purchasedAt: NOW - 2 * DAY,
      expiresAt: addYears(NOW - 2 * DAY, 5),
      daysSincePurchase: 2,
      lot: { state: "open", credits: 500, remaining: 300, closedAt: null, closedCredits: 0 },
      price: { amountMicros: KRW(5900), amount: 5900, currency: "KRW", source: "purchase" },
      withinWithdrawalPeriod: true,
      feeRate: 0,
      ratio: 0.6,
      refundable: { amountMicros: KRW(3540), amount: 3540, currency: "KRW" },
      refundableNow: true,
      refunded: null,
    });
    expect(env.db.rows("SELECT remaining FROM purchases")).toEqual([{ remaining: 300 }]);
  });

  it("7일이 지나면 10% 를 뺀다. waiveFee=1 이면 빼지 않는다", async () => {
    const env = makeEnv();
    await register(env);
    addPurchase(env, { token: "t1", order: "GPA.late", credits: 500, remaining: 500, createdAt: NOW - 30 * DAY });
    expect((await quote(env, "orderId=GPA.late")).body).toMatchObject({
      withinWithdrawalPeriod: false,
      feeRate: 0.1,
      refundable: { amount: 5310, currency: "KRW" },
    });
    expect((await quote(env, "orderId=GPA.late&waiveFee=1")).body).toMatchObject({ feeRate: 0, refundable: { amount: 5900 } });
  });

  it("구매 때 금액이 없으면 PRODUCT_PRICES_KRW, 그것도 없으면 금액 없이(환불 불가), paid 로 직접 줄 수 있다", async () => {
    const env = makeEnv({ PRODUCT_PRICES_KRW: '{"ember_credits_1500":14900}' });
    await register(env);
    addPurchase(env, { token: "t1", order: "GPA.cfg", credits: 1650, remaining: 1650, createdAt: NOW, priceMicros: null, product: "ember_credits_1500" });
    addPurchase(env, { token: "t2", order: "GPA.unknown", credits: 500, remaining: 500, createdAt: NOW, priceMicros: null });
    expect((await quote(env, "orderId=GPA.cfg")).body).toMatchObject({
      price: { amount: 14900, currency: "KRW", source: "config" },
      refundable: { amount: 14900 },
      refundableNow: true,
    });
    expect((await quote(env, "orderId=GPA.unknown")).body).toMatchObject({ price: null, refundable: null, refundableNow: false });
    expect((await refund(env, { orderId: "GPA.unknown" })).status).toBe(409);
    expect((await quote(env, "orderId=GPA.unknown&paid=5900")).body).toMatchObject({
      price: { amount: 5900, currency: "KRW", source: "override" },
      refundable: { amount: 5900 },
    });
    expect((await quote(env, "orderId=GPA.unknown&paid=-1")).status).toBe(400);
  });

  it("닫힌 묶음(만료·Google 환불·탈퇴)은 환불할 크레딧이 없다", async () => {
    const env = makeEnv();
    await register(env);
    addPurchase(env, { token: "t1", order: "GPA.exp", credits: 500, remaining: 200, createdAt: addYears(NOW, -5) - DAY });
    const { body } = await quote(env, "orderId=GPA.exp");
    // 만료 시각이 지났으면 cron 전이라도 열린 것으로 보지 않는다
    expect(body).toMatchObject({ lot: { state: "expired", remaining: 0 }, refundable: { amount: 0 }, refundableNow: false });
    env.db.sqlite.exec("UPDATE purchases SET lot_closed_at = 1, lot_closed_reason = 'voided', remaining = 0, voided = 1, voided_quantity = 1");
    expect((await quote(env, "orderId=GPA.exp")).body).toMatchObject({ lot: { state: "voided", credits: 0, remaining: 0 }, refundableNow: false });
  });
});

describe("POST /ember/admin/refund", () => {
  it("그 구매의 남은 유료 크레딧을 0 으로 만들고(잔액에서 빼고) 기록한다. 두 번은 안 된다", async () => {
    const env = makeEnv();
    const { token } = await register(env); // 무료 100
    addPurchase(env, { token: "t1", order: "GPA.R1", credits: 500, remaining: 300, createdAt: NOW - DAY });
    addPurchase(env, { token: "t2", order: "GPA.R2", credits: 500, remaining: 500, createdAt: NOW });
    const r = await refund(env, { orderId: "GPA.R1" });
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ refunded: true, orderId: "GPA.R1", credits: 300, amount: 3540, currency: "KRW", amountMicros: KRW(3540) });
    expect(env.db.rows("SELECT remaining, lot_closed_reason, lot_closed_credits, refund_micros, refund_credits FROM purchases WHERE order_id = 'GPA.R1'")).toEqual([
      { remaining: 0, lot_closed_reason: "refunded", lot_closed_credits: 300, refund_micros: KRW(3540), refund_credits: 300 },
    ]);
    const bal = await call(env, "/ember/balance", { headers: { "x-api-key": token } });
    expect(await bal.res.json()).toEqual({ credits: 600, freeCredits: 100, paidCredits: 500, expiringSoon: null });

    const again = await refund(env, { orderId: "GPA.R1" });
    expect(again.status).toBe(409);
    expect((await quote(env, "orderId=GPA.R1")).body).toMatchObject({
      lot: { state: "refunded", remaining: 0, closedCredits: 300 },
      refundableNow: false,
      refunded: { amountMicros: KRW(3540), amount: 3540, credits: 300 },
    });
    const stats = await call(env, "/ember/admin/stats", { headers: ADMIN });
    expect(await stats.res.json()).toMatchObject({ adminRefunds: { purchases: 1, credits: 300 }, paidCreditsOutstanding: 500 });
  });

  it("운영자가 Play Console 에서 돈을 돌려준 뒤 Google 이 알려 주는 환불은 크레딧을 다시 빼지 않는다", async () => {
    const env = makeEnv();
    await register(env);
    addPurchase(env, { token: "t1", order: "GPA.R3", credits: 500, remaining: 500, createdAt: NOW });
    expect((await refund(env, { orderId: "GPA.R3" })).status).toBe(200);
    expect(env.db.rows("SELECT credits FROM accounts")).toEqual([{ credits: 100 }]);
    expect(await clawBackPurchase(env.DB, { purchaseToken: "t1" }, NOW)).toBe(0);
    expect(env.db.rows("SELECT credits FROM accounts")).toEqual([{ credits: 100 }]);
    expect(env.db.rows("SELECT voided, voided_quantity FROM purchases")).toEqual([{ voided: 1, voided_quantity: 1 }]);
    expect(env.db.rows("SELECT event_key, credits, applied FROM voided_events")).toEqual([{ event_key: "full", credits: 0, applied: 1 }]);
  });

  it("orderId 형식이 틀리면 400, 남은 크레딧이 없으면 409", async () => {
    const env = makeEnv();
    await register(env);
    addPurchase(env, { token: "t1", order: "GPA.used", credits: 500, remaining: 0, createdAt: NOW });
    expect((await refund(env, { orderId: "bad id!" })).status).toBe(400);
    const used = await call(env, "/ember/admin/refund", { method: "POST", json: { orderId: "GPA.used" }, headers: ADMIN });
    expect(used.res.status).toBe(409);
    expect((await errorBody(used.res)).error.message).toMatch(/nothing to refund/);
  });
});
