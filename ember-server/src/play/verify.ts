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
  };
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
    console.error("Play 검증 실패:", res.status, await res.text().catch(() => ""));
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
  console.error("Play 소비 실패:", res.status, detail.slice(0, 500));
  return { kind: "error", status: res.status };
}
