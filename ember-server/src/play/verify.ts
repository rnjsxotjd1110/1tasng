// Google Play Developer API 로 일회성 상품 구매를 확인한다.
import { isRecord } from "../http";
import { clearGoogleTokenCache, getGoogleAccessToken } from "./google-auth";

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
  for (let attempt = 0; attempt < 2; attempt++) {
    const accessToken = await getGoogleAccessToken(serviceAccountJson);
    const res = await fetch(url, { headers: { authorization: `Bearer ${accessToken}` } });
    if (res.status === 401 && attempt === 0) {
      clearGoogleTokenCache(); // 캐시된 토큰이 만료·폐기된 경우 한 번만 다시 받는다
      continue;
    }
    if (res.status === 400 || res.status === 404 || res.status === 410) return { kind: "not_found" };
    if (!res.ok) {
      console.error("Play 검증 실패:", res.status, await res.text().catch(() => ""));
      return { kind: "error", status: res.status };
    }
    const purchase = parseProductPurchase(await res.json().catch(() => null));
    if (!purchase) return { kind: "error", status: 502 };
    return { kind: "ok", purchase };
  }
  return { kind: "error", status: 401 };
}
