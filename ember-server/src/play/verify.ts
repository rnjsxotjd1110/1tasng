// Google Play Developer API 로 일회성 상품 구매를 확인한다.
import { isRecord } from "../http";
import { ANDROID_PUBLISHER_SCOPE, googleFetch } from "./google-auth";

export interface ProductPurchase {
  purchaseState: number; // 0 구매 완료, 1 취소, 2 대기
  consumptionState?: number;
  orderId?: string;
  productId?: string;
  quantity: number;
  purchaseType?: number; // 0 테스트, 1 프로모션, 2 보상형
  /**
   * 결제 금액(전체 수량, 백만분의 1 단위)과 통화. purchases.products.get(v3) 응답에는 보통 없고,
   * 응답에 있을 때만 쓴다(없으면 PRODUCT_PRICES_KRW, purchase.ts).
   */
  priceAmountMicros?: number;
  priceCurrencyCode?: string;
}

export type VerifyResult =
  | { kind: "ok"; purchase: ProductPurchase }
  | { kind: "not_found" }
  | { kind: "error"; status: number };

export function purchaseUrl(packageName: string, productId: string, purchaseToken: string): string {
  return (
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" +
    `${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}` +
    `/tokens/${encodeURIComponent(purchaseToken)}`
  );
}

function optNum(v: unknown): number | undefined {
  return typeof v === "number" && Number.isFinite(v) ? v : undefined;
}

export function parseProductPurchase(data: unknown): ProductPurchase | null {
  if (!isRecord(data)) return null;
  const state = optNum(data["purchaseState"]);
  if (state === undefined) return null;
  const quantity = optNum(data["quantity"]);
  return {
    purchaseState: state,
    consumptionState: optNum(data["consumptionState"]),
    orderId: typeof data["orderId"] === "string" ? data["orderId"] : undefined,
    productId: typeof data["productId"] === "string" ? data["productId"] : undefined,
    quantity: quantity !== undefined && Number.isInteger(quantity) && quantity >= 1 ? quantity : 1,
    purchaseType: optNum(data["purchaseType"]),
    ...parsePrice(data),
  };
}

/** 응답에 가격(priceAmountMicros: int64 문자열·숫자, priceCurrencyCode)이 둘 다 맞게 있으면 꺼낸다. */
function parsePrice(data: Record<string, unknown>): Pick<ProductPurchase, "priceAmountMicros" | "priceCurrencyCode"> {
  const rawMicros = data["priceAmountMicros"];
  const micros = typeof rawMicros === "string" && /^\d{1,18}$/.test(rawMicros) ? Number(rawMicros) : rawMicros;
  const currency = data["priceCurrencyCode"];
  if (typeof micros !== "number" || !Number.isSafeInteger(micros) || micros <= 0) return {};
  if (typeof currency !== "string" || !/^[A-Z]{3}$/.test(currency)) return {};
  return { priceAmountMicros: micros, priceCurrencyCode: currency };
}

/**
 * Google API 오류 응답에서 상태 코드 다음에 남길 '오류 종류'만 뽑는다(error.status 또는 error.errors[0].reason).
 * 응답 본문·메시지는 로그에 남기지 않는다(개인정보·토큰이 섞일 수 있음).
 */
export function googleErrorType(bodyText: string): string {
  try {
    const parsed: unknown = JSON.parse(bodyText);
    const err = isRecord(parsed) ? parsed["error"] : undefined;
    if (isRecord(err)) {
      const errors = err["errors"];
      const first = Array.isArray(errors) && isRecord(errors[0]) ? errors[0]["reason"] : undefined;
      for (const v of [err["status"], first]) {
        if (typeof v === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(v)) return v;
      }
    }
  } catch {
    // JSON 이 아니면 종류를 모른다.
  }
  return "unknown";
}

export async function verifyProductPurchase(
  serviceAccountJson: string,
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<VerifyResult> {
  const url = purchaseUrl(packageName, productId, purchaseToken);
  const res = await googleFetch(serviceAccountJson, ANDROID_PUBLISHER_SCOPE, url);
  if (res.status === 400 || res.status === 404 || res.status === 410) return { kind: "not_found" };
  if (!res.ok) {
    console.error("Play 검증 실패:", res.status, googleErrorType(await res.text().catch(() => "")));
    return { kind: "error", status: res.status };
  }
  const purchase = parseProductPurchase(await res.json().catch(() => null));
  if (!purchase) return { kind: "error", status: 502 };
  return { kind: "ok", purchase };
}

export function consumeUrl(packageName: string, productId: string, purchaseToken: string): string {
  return `${purchaseUrl(packageName, productId, purchaseToken)}:consume`;
}

export type ConsumeResult = { kind: "ok" } | { kind: "error"; status: number };

/**
 * purchases.products.consume 를 서버에서 부른다(소비 = 확인(acknowledge) 포함, 3일 뒤 자동 환불 방지, 다시 살 수 있게 됨).
 * 이미 소비된 구매면 Google 이 400 을 주는데, 멱등을 위해 성공으로 본다.
 */
export async function consumeProductPurchase(
  serviceAccountJson: string,
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<ConsumeResult> {
  const res = await googleFetch(serviceAccountJson, ANDROID_PUBLISHER_SCOPE, consumeUrl(packageName, productId, purchaseToken), {
    method: "POST",
  });
  if (res.ok) {
    await res.body?.cancel().catch(() => undefined);
    return { kind: "ok" };
  }
  const detail = await res.text().catch(() => "");
  if (res.status === 400 && /consum/i.test(detail)) return { kind: "ok" }; // purchaseAlreadyConsumed 등
  console.error("Play 소비 실패:", res.status, googleErrorType(detail));
  return { kind: "error", status: res.status };
}
