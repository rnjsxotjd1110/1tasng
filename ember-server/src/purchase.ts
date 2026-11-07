// POST /ember/purchase: Play 영수증 확인 후 크레딧 지급. 같은 purchaseToken 은 한 번만 지급한다.
import { authenticate } from "./auth";
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
    purchaseToken.length > MAX_PURCHASE_TOKEN_LENGTH
  ) {
    throw new ApiError(400, "invalid_request_error", "purchaseToken is required");
  }

  // 이미 처리된 영수증이면 Google 을 부르지 않고 현재 잔액만 돌려준다(재시도 안전).
  const existing = await env.DB.prepare("SELECT credited FROM purchases WHERE purchase_token = ?")
    .bind(purchaseToken)
    .first<{ credited: number }>();
  if (existing?.credited) {
    return jsonResponse({ credits: await currentCredits(env.DB, account.id), granted: 0 } satisfies PurchaseResult);
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

  const now = nowSeconds();
  let result: PurchaseResult;
  try {
    result = await grantPurchase(env.DB, account.id, productId, purchaseToken, credits, p, now);
  } catch (err) {
    // 소비는 끝났으므로 앱의 미소비 구매 목록에서 사라진다. 한 번 더 시도하고, 그래도 실패하면 수동 지급이 필요하다.
    console.error("지급 실패, 다시 시도:", err);
    try {
      result = await grantPurchase(env.DB, account.id, productId, purchaseToken, credits, p, now);
    } catch (err2) {
      console.error(
        `소비 후 지급 실패(수동 지급 필요): account=${account.id} product=${productId} credits=${credits} ` +
          `order=${p.orderId ?? "?"} token=${purchaseToken.slice(0, 16)}…`,
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

async function currentCredits(db: D1Database, accountId: number): Promise<number> {
  const row = await db.prepare("SELECT credits FROM accounts WHERE id = ?").bind(accountId).first<{ credits: number }>();
  return row?.credits ?? 0;
}

/**
 * 한 트랜잭션(batch)에서: 영수증 기록(중복이면 무시) → 아직 지급 전이면 크레딧 지급 → 지급 표시 → 잔액 조회.
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
): Promise<PurchaseResult> {
  const results = await db.batch([
    db
      .prepare(
        `INSERT INTO purchases (purchase_token, account_id, product_id, order_id, quantity, credits,
           purchase_type, credited, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
         ON CONFLICT (purchase_token) DO NOTHING`,
      )
      .bind(purchaseToken, accountId, productId, p.orderId ?? null, p.quantity, credits, p.purchaseType ?? null, now),
    db
      .prepare(
        `UPDATE accounts SET credits = credits + ?, updated_at = ?
         WHERE id = ? AND EXISTS (
           SELECT 1 FROM purchases WHERE purchase_token = ? AND account_id = ? AND credited = 0)`,
      )
      .bind(credits, now, accountId, purchaseToken, accountId),
    db
      .prepare("UPDATE purchases SET credited = 1 WHERE purchase_token = ? AND account_id = ? AND credited = 0")
      .bind(purchaseToken, accountId),
    db.prepare("SELECT credits FROM accounts WHERE id = ?").bind(accountId),
  ]);
  const granted = (results[1]?.meta.changes ?? 0) > 0 ? credits : 0;
  const balanceRow = results[3]?.results[0] as { credits: number } | undefined;
  return { credits: balanceRow?.credits ?? 0, granted };
}
