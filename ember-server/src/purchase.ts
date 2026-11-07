// POST /ember/purchase: Play 영수증 확인 후 크레딧 지급. 같은 purchaseToken 은 한 번만 지급한다.
//
// 순서: 확인(GET) → 지급 대기 기록(credited = 0, 이 계정) → 소비(consume) → 지급(credited = 1).
// 소비 뒤 지급이 실패해도 대기 기록이 남으므로, 같은 계정이 같은 purchaseToken 을 다시 보내면
// (Google 은 이미 소비됨으로 알려 줌) 지급된다(지급 복구). 지급은 credited 0 → 1 전환으로 한 번만 일어난다.
// 지급하면 그 구매가 유료 크레딧 묶음(remaining = 지급 크레딧, 만료 = 구매 기록 시각 + 5년)이 된다(billing/lots.ts).
// 결제 금액은 Play 확인 응답에 있으면 그 값, 없으면 PRODUCT_PRICES_KRW × 수량으로 기록한다(환불 계산용).
import { HASHED_PURCHASE_PREFIX, hashedPurchaseToken } from "./account-delete";
import { authenticate } from "./auth";
import { LOT_EXPIRES_SQL, trimLotsStmt } from "./billing/lots";
import type { Config, Env } from "./env";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { consumeProductPurchase, verifyProductPurchase, type ProductPurchase, type VerifyResult } from "./play/verify";
import { nowSeconds } from "./util";

const PURCHASE_BODY_MAX = 16 * 1024;
const MAX_PURCHASE_TOKEN_LENGTH = 4096;

export interface PurchaseResult {
  credits: number;
  granted: number;
  /** 운영에서 라이선스 테스트 구매라 크레딧을 주지 않았으면 true */
  testPurchase?: boolean;
}

/** purchaseType 0 = 라이선스 테스터의 테스트 구매(실제 결제 없음) */
export const PURCHASE_TYPE_TEST = 0;

/** 구매 기록에 남길 결제 금액 */
export interface PurchasePrice {
  micros: number;
  currency: string;
}

/** 결제 금액: Play 응답의 가격 → 없으면 PRODUCT_PRICES_KRW(1개 가격) × 수량 → 그것도 없으면 null(모름). */
export function purchasePrice(
  cfg: Pick<Config, "productPricesKrw">,
  productId: string,
  p: Pick<ProductPurchase, "quantity" | "priceAmountMicros" | "priceCurrencyCode">,
): PurchasePrice | null {
  if (p.priceAmountMicros !== undefined && p.priceCurrencyCode !== undefined) {
    return { micros: p.priceAmountMicros, currency: p.priceCurrencyCode };
  }
  const krw = cfg.productPricesKrw[productId];
  if (krw === undefined) return null;
  return { micros: Math.round(krw * 1_000_000) * p.quantity, currency: "KRW" };
}

export async function handlePurchase(req: Request, env: Env, cfg: Config): Promise<Response> {
  const account = await authenticate(env, req);
  const body = await readJsonObject(req, PURCHASE_BODY_MAX);
  const productId = body["productId"];
  const purchaseToken = body["purchaseToken"];
  if (typeof productId !== "string" || cfg.products[productId] === undefined) {
    throw new ApiError(400, "invalid_request_error", "unknown productId");
  }
  if (
    typeof purchaseToken !== "string" ||
    purchaseToken.length === 0 ||
    purchaseToken.length > MAX_PURCHASE_TOKEN_LENGTH ||
    purchaseToken.startsWith(HASHED_PURCHASE_PREFIX)
  ) {
    throw new ApiError(400, "invalid_request_error", "purchaseToken is required");
  }

  // 이미 처리된 영수증(지급 완료, 다른 계정의 것, 탈퇴한 계정의 것 = 해시로 저장)이면 Google 을 부르지 않고
  // 현재 잔액만 돌려준다(재시도 안전). 이 계정의 지급 대기 기록이면 아래에서 다시 확인해 지급한다(지급 복구).
  const hashed = await hashedPurchaseToken(purchaseToken);
  const existing = await findPurchase(env.DB, purchaseToken, hashed);
  if (existing && !isOwnPending(existing, purchaseToken, account.id)) {
    return jsonResponse({ credits: await currentCredits(env.DB, account.id), granted: 0 } satisfies PurchaseResult);
  }
  if (existing && existing.product_id !== productId) {
    throw new ApiError(400, "invalid_request_error", "productId does not match the purchase");
  }

  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    console.error("GOOGLE_SERVICE_ACCOUNT_JSON 이 설정되지 않음");
    throw new ApiError(500, "api_error", "purchase verification is not configured");
  }
  let verified: VerifyResult;
  try {
    verified = await verifyProductPurchase(env.GOOGLE_SERVICE_ACCOUNT_JSON, cfg.packageName, productId, purchaseToken);
  } catch (err) {
    console.error("Play 검증 오류:", err);
    throw new ApiError(502, "api_error", "could not verify the purchase, please retry");
  }
  if (verified.kind === "not_found") throw new ApiError(400, "invalid_request_error", "purchase not found");
  if (verified.kind === "error") throw new ApiError(502, "api_error", "could not verify the purchase, please retry");

  const p = verified.purchase;
  if (p.purchaseState !== 0) {
    throw new ApiError(400, "invalid_request_error", `purchase is not completed (state ${p.purchaseState})`);
  }
  if (p.productId !== undefined && p.productId !== productId) {
    throw new ApiError(400, "invalid_request_error", "productId does not match the purchase");
  }

  // 운영(ALLOW_TEST_PURCHASES 가 true 가 아님)에서는 테스트 구매에 크레딧을 주지 않고 결제 계정으로도 치지 않는다.
  const isTest = p.purchaseType === PURCHASE_TYPE_TEST;
  const rejectTest = isTest && !cfg.allowTestPurchases;
  const credits = rejectTest ? 0 : (cfg.products[productId] ?? 0) * p.quantity;
  const price = rejectTest ? null : purchasePrice(cfg, productId, p);
  const now = nowSeconds();

  // 소비(되돌릴 수 없음) 전에 이 계정의 지급 대기 기록을 남긴다. 다른 계정이 먼저 기록했거나 탈퇴 계정의 영수증이면 지급하지 않는다.
  if (!existing) {
    await recordPendingPurchase(env.DB, account.id, productId, purchaseToken, hashed, credits, p, now, price);
    const row = await findPurchase(env.DB, purchaseToken, hashed);
    if (!row || !isOwnPending(row, purchaseToken, account.id)) {
      return jsonResponse({ credits: await currentCredits(env.DB, account.id), granted: 0 } satisfies PurchaseResult);
    }
  }

  // 지급 전에 서버에서 소비(consume)한다. 소비하지 못하면 지급하지 않는다(앱이 다시 보내면 된다).
  // 이미 소비된 구매(consumptionState 1, 또는 Google 의 '이미 소비됨' 응답)는 그대로 진행한다.
  if (p.consumptionState !== 1) {
    let consumed: Awaited<ReturnType<typeof consumeProductPurchase>>;
    try {
      consumed = await consumeProductPurchase(env.GOOGLE_SERVICE_ACCOUNT_JSON, cfg.packageName, productId, purchaseToken);
    } catch (err) {
      console.error("Play 소비 오류:", err);
      consumed = { kind: "error", status: 502 };
    }
    if (consumed.kind !== "ok") throw new ApiError(502, "api_error", "could not finalize the purchase, please retry");
  }

  let result: PurchaseResult;
  try {
    result = await grantPurchase(env.DB, account.id, productId, purchaseToken, credits, p, now, price);
  } catch (err) {
    // 소비는 끝났으므로 앱의 미소비 구매 목록에서 사라진다. 한 번 더 시도하고, 그래도 실패하면 수동 지급이 필요하다.
    console.error("지급 실패, 다시 시도:", err);
    try {
      result = await grantPurchase(env.DB, account.id, productId, purchaseToken, credits, p, now, price);
    } catch (err2) {
      console.error(
        `소비 후 지급 실패(수동 지급 필요): account=${account.id} product=${productId} credits=${credits} ` +
          `order=${p.orderId ?? "?"}`,
        err2,
      );
      throw new ApiError(500, "api_error", "could not credit the purchase, please contact support");
    }
  }
  if (rejectTest) {
    console.warn(`테스트 구매라 크레딧을 주지 않음: account=${account.id} order=${p.orderId ?? "?"}`);
    return jsonResponse({ ...result, testPurchase: true } satisfies PurchaseResult);
  }
  return jsonResponse(result);
}

interface PurchaseRow {
  purchase_token: string;
  account_id: number;
  product_id: string;
  credited: number;
}

async function findPurchase(db: D1Database, purchaseToken: string, hashed: string): Promise<PurchaseRow | null> {
  return db
    .prepare("SELECT purchase_token, account_id, product_id, credited FROM purchases WHERE purchase_token IN (?, ?)")
    .bind(purchaseToken, hashed)
    .first<PurchaseRow>();
}

/** 이 계정의 아직 지급하지 않은 기록이면 true(지급을 이어서 할 수 있음). */
function isOwnPending(row: PurchaseRow, purchaseToken: string, accountId: number): boolean {
  return row.purchase_token === purchaseToken && row.account_id === accountId && row.credited === 0;
}

/** 지급 대기 기록(credited = 0). 같은 영수증의 기록(원문 또는 탈퇴 계정의 해시)이 이미 있으면 아무것도 하지 않는다. */
export async function recordPendingPurchase(
  db: D1Database,
  accountId: number,
  productId: string,
  purchaseToken: string,
  hashed: string,
  credits: number,
  p: Pick<ProductPurchase, "orderId" | "quantity" | "purchaseType">,
  now: number,
  price: PurchasePrice | null = null,
): Promise<void> {
  await db
    .prepare(
      `INSERT INTO purchases (purchase_token, account_id, product_id, order_id, quantity, credits,
         purchase_type, credited, created_at, price_micros, price_currency)
       SELECT ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?
       WHERE NOT EXISTS (SELECT 1 FROM purchases WHERE purchase_token = ?)
       ON CONFLICT (purchase_token) DO NOTHING`,
    )
    .bind(
      purchaseToken,
      accountId,
      productId,
      p.orderId ?? null,
      p.quantity,
      credits,
      p.purchaseType ?? null,
      now,
      price?.micros ?? null,
      price?.currency ?? null,
      hashed,
    )
    .run();
}

async function currentCredits(db: D1Database, accountId: number): Promise<number> {
  const row = await db.prepare("SELECT credits FROM accounts WHERE id = ?").bind(accountId).first<{ credits: number }>();
  return row?.credits ?? 0;
}

/**
 * 한 트랜잭션(batch)에서: 영수증 기록(대기 기록이 이미 있거나 중복이면 무시) → 이 계정의 지급 전 기록이면 크레딧 지급
 * → 지급 표시(유료 묶음 열기: remaining = credits, 만료 = created_at + 5년) → 빚(음수 잔액)이 있으면 묶음에서 갚음 → 잔액 조회.
 * purchase_token UNIQUE 와 credited 플래그 덕분에 동시에 두 번 와도 한 번만 지급된다.
 */
export async function grantPurchase(
  db: D1Database,
  accountId: number,
  productId: string,
  purchaseToken: string,
  credits: number,
  p: Pick<ProductPurchase, "orderId" | "quantity" | "purchaseType">,
  now: number,
  price: PurchasePrice | null = null,
): Promise<PurchaseResult> {
  const results = await db.batch([
    db
      .prepare(
        `INSERT INTO purchases (purchase_token, account_id, product_id, order_id, quantity, credits,
           purchase_type, credited, created_at, price_micros, price_currency)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
         ON CONFLICT (purchase_token) DO NOTHING`,
      )
      .bind(
        purchaseToken,
        accountId,
        productId,
        p.orderId ?? null,
        p.quantity,
        credits,
        p.purchaseType ?? null,
        now,
        price?.micros ?? null,
        price?.currency ?? null,
      ),
    db
      .prepare(
        `UPDATE accounts SET credits = credits + ?, updated_at = ?
         WHERE id = ? AND EXISTS (
           SELECT 1 FROM purchases WHERE purchase_token = ? AND account_id = ? AND credited = 0)`,
      )
      .bind(credits, now, accountId, purchaseToken, accountId),
    db
      .prepare(
        `UPDATE purchases SET credited = 1, credits = ?1, remaining = ?1,
           expires_at = CASE WHEN ?1 > 0 THEN ${LOT_EXPIRES_SQL} END,
           price_micros = COALESCE(price_micros, ?4), price_currency = COALESCE(price_currency, ?5)
         WHERE purchase_token = ?2 AND account_id = ?3 AND credited = 0`,
      )
      .bind(credits, purchaseToken, accountId, price?.micros ?? null, price?.currency ?? null),
    // 빚(음수 잔액)이 있었다면 새 묶음에서 먼저 갚는다(유료 합계 ≤ max(0, 잔액)).
    trimLotsStmt(db, accountId),
    db.prepare("SELECT credits FROM accounts WHERE id = ?").bind(accountId),
  ]);
  const granted = (results[1]?.meta.changes ?? 0) > 0 ? credits : 0;
  const balanceRow = results[4]?.results[0] as { credits: number } | undefined;
  return { credits: balanceRow?.credits ?? 0, granted };
}
