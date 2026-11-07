// 청약철회·환불 계산(이용약관 7장)과 운영자용 환불 엔드포인트.
//
// 환불 금액 = 결제 금액 × (그 구매의 남은 유료 크레딧 ÷ 그 구매로 받은 크레딧)
// - 구매 후 7일 이내: 수수료 없음(쓰지 않았으면 전액 = 청약철회).
// - 7일이 지난 뒤: 위 금액의 90%(10% 는 결제 수수료 등).
// - 서비스 종료(약관 11장)처럼 수수료 없이 돌려줄 때는 waiveFee 로 수수료를 뺀다.
// 무료 크레딧은 환불하지 않는다. 묶음이 닫혔으면(만료·환불·Google 환불·탈퇴·계정 만료) 환불할 크레딧이 없다.
//
// GET  /ember/admin/refund-quote?orderId=GPA....[&waiveFee=1][&paid=5900&currency=KRW]  → 견적(바꾸는 것 없음)
// POST /ember/admin/refund {orderId, waiveFee?, paid?, currency?}                        → 묶음을 0 으로 만들고 환불 기록
// 실제 돈은 운영자가 Play Console(주문 관리)에서 돌려준다(README 6장 "환불·청약철회 처리"). 그 뒤 Google 이 알려 주는 환불(Voided Purchases)은
// 이미 크레딧을 없앴으므로 다시 빼지 않는다(play/voided.ts).
import { requireAdmin } from "./admin";
import { openLot } from "./billing/lots";
import type { Config, Env } from "./env";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { nowSeconds } from "./util";

/** 청약철회 기간(초): 구매 후 7일 */
export const WITHDRAWAL_PERIOD_SECONDS = 7 * 86400;
/** 7일이 지난 뒤 빼는 수수료 비율(10%) — 분자/분모로 둬 정수 계산 */
export const LATE_REFUND_FEE_NUM = 1;
export const LATE_REFUND_FEE_DEN = 10;

const REFUND_BODY_MAX = 4 * 1024;
const ORDER_ID_RE = /^[A-Za-z0-9._:-]{1,128}$/;

export interface RefundCalcInput {
  /** 결제 금액(백만분의 1 단위) */
  amountPaidMicros: number;
  /** 그 구매로 받은 크레딧(환불 계산 기준) */
  lotCredits: number;
  /** 그 구매의 남은 유료 크레딧 */
  remaining: number;
  /** 구매 시각(유닉스 초) */
  purchasedAt: number;
  now: number;
  /** true 면 7일이 지나도 수수료를 빼지 않는다(서비스 종료 등) */
  waiveFee?: boolean;
}

export interface RefundCalc {
  /** 구매 후 7일 이내면 true(수수료 없음) */
  withinWithdrawalPeriod: boolean;
  /** 0 또는 0.1 */
  feeRate: number;
  /** 남은 비율(0~1) */
  ratio: number;
  /** 수수료 빼기 전 금액(백만분의 1 단위, 내림) */
  grossMicros: number;
  /** 수수료(백만분의 1 단위) */
  feeMicros: number;
  /** 돌려줄 금액(백만분의 1 단위, 내림) */
  refundableMicros: number;
}

/** 환불 금액 계산(정수·BigInt, 내림). lotCredits 가 0 이하면 0. 남은 양은 0~lotCredits 로 자른다. */
export function computeRefund(i: RefundCalcInput): RefundCalc {
  const within = i.now - i.purchasedAt <= WITHDRAWAL_PERIOD_SECONDS;
  const charged = !within && !i.waiveFee;
  const credits = Math.max(0, Math.floor(i.lotCredits));
  const remaining = Math.min(credits, Math.max(0, Math.floor(i.remaining)));
  const paid = BigInt(Math.max(0, Math.floor(i.amountPaidMicros)));
  const gross = credits === 0 ? 0n : (paid * BigInt(remaining)) / BigInt(credits);
  const fee = charged ? (gross * BigInt(LATE_REFUND_FEE_NUM) + BigInt(LATE_REFUND_FEE_DEN - 1)) / BigInt(LATE_REFUND_FEE_DEN) : 0n;
  return {
    withinWithdrawalPeriod: within,
    feeRate: charged ? LATE_REFUND_FEE_NUM / LATE_REFUND_FEE_DEN : 0,
    ratio: credits === 0 ? 0 : remaining / credits,
    grossMicros: Number(gross),
    feeMicros: Number(fee),
    refundableMicros: Number(gross - fee),
  };
}

/** 소수점 없는 통화(원·엔 등). 그 밖은 2자리. */
const ZERO_DECIMAL = new Set(["KRW", "JPY", "VND", "CLP", "ISK", "HUF", "TWD", "IDR", "UGX", "KES", "PYG"]);

/** 백만분의 1 단위를 통화의 최소 단위로 내림한 표시용 금액(원이면 정수, 달러면 소수 2자리). */
export function microsToAmount(micros: number, currency: string): number {
  const digits = ZERO_DECIMAL.has(currency.toUpperCase()) ? 0 : 2;
  const unit = 10 ** (6 - digits);
  return Math.floor(micros / unit) / 10 ** digits;
}

export type LotState =
  | "open"
  | "expired"
  | "refunded"
  | "voided"
  | "deleted"
  | "account_expired"
  | "pending"
  | "no_credits";

interface PurchaseRow {
  id: number;
  account_id: number;
  product_id: string;
  order_id: string;
  quantity: number;
  credits: number;
  credited: number;
  created_at: number;
  voided: number;
  voided_quantity: number;
  remaining: number;
  expires_at: number | null;
  lot_closed_at: number | null;
  lot_closed_reason: string | null;
  lot_closed_credits: number;
  price_micros: number | null;
  price_currency: string | null;
  refunded_at: number | null;
  refund_micros: number | null;
  refund_credits: number;
  open: number;
}

export interface PriceOverride {
  /** 결제 금액(통화 단위, 예: 5900) */
  paid: number;
  currency: string;
}

export interface RefundQuote {
  orderId: string;
  productId: string;
  quantity: number;
  purchasedAt: number;
  expiresAt: number | null;
  daysSincePurchase: number;
  lot: {
    state: LotState;
    /** 환불 계산 기준 크레딧(Google 수량 일부 환불분은 뺌) */
    credits: number;
    remaining: number;
    closedAt: number | null;
    closedCredits: number;
  };
  /** 결제 금액. source: purchase(구매 때 기록) / config(PRODUCT_PRICES_KRW) / override(요청 값). 모르면 null */
  price: { amountMicros: number; amount: number; currency: string; source: "purchase" | "config" | "override" } | null;
  withinWithdrawalPeriod: boolean;
  feeRate: number;
  ratio: number;
  /** 돌려줄 금액. 가격을 모르면 null */
  refundable: { amountMicros: number; amount: number; currency: string } | null;
  /** 지금 환불(POST /ember/admin/refund)할 수 있으면 true */
  refundableNow: boolean;
  /** 이미 운영자 환불을 했으면 그 기록 */
  refunded: { at: number; amountMicros: number | null; amount: number | null; credits: number } | null;
}

function lotState(p: PurchaseRow): LotState {
  if (p.credited !== 1) return "pending";
  if (p.expires_at === null) return "no_credits";
  if (p.lot_closed_at === null) return "open";
  const r = p.lot_closed_reason;
  return r === "expired" || r === "refunded" || r === "voided" || r === "deleted" || r === "account_expired"
    ? r
    : "expired";
}

async function findByOrder(db: D1Database, orderId: string, now: number): Promise<PurchaseRow> {
  const { results } = await db
    .prepare(
      `SELECT p.*, (${openLot("p")} AND p.expires_at > ?) AS open FROM purchases p WHERE p.order_id = ? ORDER BY p.id LIMIT 2`,
    )
    .bind(now, orderId)
    .all<PurchaseRow>();
  if (results.length === 0) throw new ApiError(404, "not_found_error", "no purchase with this orderId");
  if (results.length > 1) throw new ApiError(409, "invalid_request_error", "more than one purchase has this orderId");
  return results[0]!;
}

/** 견적을 만든다(DB 를 바꾸지 않는다). */
export function buildQuote(cfg: Pick<Config, "productPricesKrw">, p: PurchaseRow, now: number, waiveFee: boolean, override?: PriceOverride): RefundQuote {
  const quantity = Math.max(1, p.quantity);
  const keptQuantity = Math.max(0, quantity - Math.min(quantity, p.voided_quantity));
  // Google 이 수량 일부를 환불했으면 그만큼 뺀 크레딧·금액을 기준으로 한다.
  const lotCredits = Math.floor((p.credits * keptQuantity) / quantity);

  let price: RefundQuote["price"] = null;
  if (override) {
    price = { amountMicros: Math.round(override.paid * 1_000_000), amount: 0, currency: override.currency, source: "override" };
  } else if (p.price_micros !== null && p.price_currency !== null) {
    price = { amountMicros: p.price_micros, amount: 0, currency: p.price_currency, source: "purchase" };
  } else {
    const krw = cfg.productPricesKrw[p.product_id];
    if (krw !== undefined) price = { amountMicros: Math.round(krw * 1_000_000) * quantity, amount: 0, currency: "KRW", source: "config" };
  }
  if (price) price.amount = microsToAmount(price.amountMicros, price.currency);
  const paidKeptMicros = price ? Math.floor((price.amountMicros * keptQuantity) / quantity) : 0;

  const state = lotState(p);
  const open = state === "open" && p.open === 1;
  const remaining = open ? p.remaining : 0;
  const calc = computeRefund({
    amountPaidMicros: paidKeptMicros,
    lotCredits,
    remaining,
    purchasedAt: p.created_at,
    now,
    waiveFee,
  });
  return {
    orderId: p.order_id,
    productId: p.product_id,
    quantity: p.quantity,
    purchasedAt: p.created_at,
    expiresAt: p.expires_at,
    daysSincePurchase: Math.floor(Math.max(0, now - p.created_at) / 86400),
    lot: {
      state: open || state !== "open" ? state : "expired",
      credits: lotCredits,
      remaining,
      closedAt: p.lot_closed_at,
      closedCredits: p.lot_closed_credits,
    },
    price,
    withinWithdrawalPeriod: calc.withinWithdrawalPeriod,
    feeRate: calc.feeRate,
    ratio: calc.ratio,
    refundable: price
      ? { amountMicros: calc.refundableMicros, amount: microsToAmount(calc.refundableMicros, price.currency), currency: price.currency }
      : null,
    refundableNow: open && remaining > 0 && price !== null,
    refunded:
      p.refunded_at !== null
        ? {
            at: p.refunded_at,
            amountMicros: p.refund_micros,
            amount: p.refund_micros !== null && p.price_currency !== null ? microsToAmount(p.refund_micros, p.price_currency) : null,
            credits: p.refund_credits,
          }
        : null,
  };
}

function parseOrderId(v: unknown): string {
  if (typeof v !== "string" || !ORDER_ID_RE.test(v)) throw new ApiError(400, "invalid_request_error", "orderId is required");
  return v;
}

function parseFlag(v: unknown): boolean {
  return v === true || v === "1" || v === "true";
}

function parseOverride(paid: unknown, currency: unknown): PriceOverride | undefined {
  if (paid === undefined || paid === null || paid === "") return undefined;
  const n = typeof paid === "string" ? Number(paid) : paid;
  if (typeof n !== "number" || !Number.isFinite(n) || n <= 0) {
    throw new ApiError(400, "invalid_request_error", "paid must be a positive number");
  }
  const c = currency === undefined || currency === null || currency === "" ? "KRW" : currency;
  if (typeof c !== "string" || !/^[A-Za-z]{3}$/.test(c)) throw new ApiError(400, "invalid_request_error", "currency must be ISO 4217");
  return { paid: n, currency: c.toUpperCase() };
}

/** GET /ember/admin/refund-quote?orderId=...[&waiveFee=1][&paid=5900&currency=KRW] */
export async function handleRefundQuote(req: Request, env: Env, cfg: Config): Promise<Response> {
  await requireAdmin(req, env);
  const url = new URL(req.url);
  const orderId = parseOrderId(url.searchParams.get("orderId"));
  const override = parseOverride(url.searchParams.get("paid") ?? undefined, url.searchParams.get("currency") ?? undefined);
  const now = nowSeconds();
  const p = await findByOrder(env.DB, orderId, now);
  return jsonResponse(buildQuote(cfg, p, now, parseFlag(url.searchParams.get("waiveFee")), override));
}

/**
 * POST /ember/admin/refund {orderId, waiveFee?, paid?, currency?}
 * 견적과 같은 계산으로 그 구매의 남은 유료 크레딧을 0 으로 만들고(잔액에서 빼고) 환불 기록을 남긴다.
 * 그 사이 묶음이 바뀌었으면(사용·만료 등) 409 — 다시 견적을 받는다. 돈은 운영자가 Play Console 에서 돌려준다.
 */
export async function handleRefund(req: Request, env: Env, cfg: Config): Promise<Response> {
  await requireAdmin(req, env);
  const body = await readJsonObject(req, REFUND_BODY_MAX);
  const orderId = parseOrderId(body["orderId"]);
  const override = parseOverride(body["paid"], body["currency"]);
  const now = nowSeconds();
  const p = await findByOrder(env.DB, orderId, now);
  const quote = buildQuote(cfg, p, now, parseFlag(body["waiveFee"]), override);
  if (p.refunded_at !== null) throw new ApiError(409, "invalid_request_error", "this purchase has already been refunded");
  if (!quote.refundableNow || !quote.refundable || !quote.price) {
    const why = quote.price === null ? "price unknown (set PRODUCT_PRICES_KRW or pass paid)" : `lot is ${quote.lot.state} with ${quote.lot.remaining} credits`;
    throw new ApiError(409, "invalid_request_error", `nothing to refund: ${why}`);
  }

  const remaining = quote.lot.remaining;
  const same = `id = ? AND ${openLot("purchases")} AND remaining = ? AND refunded_at IS NULL`;
  const results = await env.DB.batch([
    // 묶음이 견적 때와 같을 때만 잔액에서 뺀다(먼저 실행: 아래 문장이 묶음을 바꾸므로).
    env.DB
      .prepare(`UPDATE accounts SET credits = credits - ?, updated_at = ? WHERE id = ? AND EXISTS (SELECT 1 FROM purchases WHERE ${same})`)
      .bind(remaining, now, p.account_id, p.id, remaining),
    env.DB
      .prepare(
        `UPDATE purchases SET remaining = 0, lot_closed_at = ?, lot_closed_reason = 'refunded', lot_closed_credits = remaining,
           refunded_at = ?, refund_micros = ?, refund_credits = remaining,
           price_micros = COALESCE(price_micros, ?), price_currency = COALESCE(price_currency, ?)
         WHERE ${same}`,
      )
      .bind(now, now, quote.refundable.amountMicros, quote.price.amountMicros, quote.price.currency, p.id, remaining),
  ]);
  if ((results[1]?.meta.changes ?? 0) === 0) {
    throw new ApiError(409, "invalid_request_error", "the purchase changed while refunding, please get a new quote");
  }
  console.log(
    `운영자 환불 기록: order=${orderId} credits=${remaining} amount=${quote.refundable.amount} ${quote.refundable.currency}`,
  );
  return jsonResponse({
    refunded: true,
    orderId,
    credits: remaining,
    amountMicros: quote.refundable.amountMicros,
    amount: quote.refundable.amount,
    currency: quote.refundable.currency,
    /** 환불 직전의 견적 */
    quote,
  });
}
