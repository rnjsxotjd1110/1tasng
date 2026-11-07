// 환불·취소된 구매 회수(cron). Google Play Voided Purchases API 로 목록을 받아,
// 이미 크레딧을 지급한 구매면 환불된 수량만큼(voidedQuantity / quantity) 잔액에서 빼고(음수 가능) voided 로 표시한다.
// 같은 환불 이벤트는 voided_events 표로 한 번만 뺀다.
import type { Config, Env } from "../env";
import { isRecord } from "../http";
import { ANDROID_PUBLISHER_SCOPE, googleFetch } from "./google-auth";

/** meta 표에 저장하는 "마지막으로 처리한 시각(ms)" 키 */
export const VOIDED_CURSOR_KEY = "voided_purchases_end_ms";
/** Google 이 받아 주는 가장 오래된 startTime(지금부터 30일 전). 첫 실행은 여기서부터 본다. */
export const VOIDED_MAX_LOOKBACK_MS = 30 * 86_400_000;
/** 30일 경계에서 거절당하지 않도록 두는 여유 */
const LOOKBACK_SAFETY_MS = 10 * 60_000;
/** 늦게 목록에 올라오는 환불을 놓치지 않도록 지난 실행 시각보다 이만큼 앞부터 다시 본다(처리는 멱등). */
export const VOIDED_OVERLAP_MS = 86_400_000;
const PAGE_SIZE = 1000;
/** 페이지 토큰이 끝없이 이어지는 경우를 막는 안전장치 */
const MAX_PAGES = 100;

export interface VoidedPurchase {
  purchaseToken: string;
  orderId?: string;
  voidedTimeMillis?: number;
  /** 0 사용자, 1 개발자, 2 Google */
  voidedSource?: number;
  /** 0 기타, 1 단순 변심, 2 미수령, 3 결함, 4 실수 구매, 5 사기, 6 친선 사기, 7 지불 거절(chargeback) */
  voidedReason?: number;
  /** 수량 일부 환불이면 환불된 수량(includeQuantityBasedPartialRefund=true 일 때만 옴). 없으면 전체 환불. */
  voidedQuantity?: number;
  /** 구매 수량(응답에 있으면). 없으면 purchases.quantity 를 쓴다. */
  quantity?: number;
}

export interface VoidedRunResult {
  /** Google 이 돌려준 환불 건수 */
  listed: number;
  /** 이번에 회수한 구매 수 */
  clawedBack: number;
  /** 이번에 회수한 크레딧 합계 */
  credits: number;
  startTimeMs: number;
}

export function voidedPurchasesUrl(packageName: string, startTimeMs: number, pageToken?: string): string {
  const params = new URLSearchParams({
    startTime: String(startTimeMs),
    type: "0", // 일회성 상품만(구독 제외)
    maxResults: String(PAGE_SIZE),
    // 수량 여러 개 구매의 일부 환불도 받는다(voidedQuantity 가 붙어 온다).
    includeQuantityBasedPartialRefund: "true",
  });
  if (pageToken) params.set("token", pageToken);
  return (
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" +
    `${encodeURIComponent(packageName)}/purchases/voidedpurchases?${params.toString()}`
  );
}

/** int64 는 JSON 에서 문자열로 온다. */
function int(v: unknown): number | undefined {
  const n = typeof v === "string" && v.trim() !== "" ? Number(v) : v;
  return typeof n === "number" && Number.isFinite(n) ? n : undefined;
}

function positiveInt(v: unknown): number | undefined {
  const n = int(v);
  return n !== undefined && Number.isInteger(n) && n >= 1 ? n : undefined;
}

export function parseVoidedPage(data: unknown): { items: VoidedPurchase[]; nextPageToken?: string } {
  if (!isRecord(data)) throw new Error("voided purchases response is not an object");
  const items: VoidedPurchase[] = [];
  const list = data["voidedPurchases"];
  if (Array.isArray(list)) {
    for (const raw of list) {
      if (!isRecord(raw) || typeof raw["purchaseToken"] !== "string" || raw["purchaseToken"] === "") continue;
      items.push({
        purchaseToken: raw["purchaseToken"],
        orderId: typeof raw["orderId"] === "string" ? raw["orderId"] : undefined,
        voidedTimeMillis: int(raw["voidedTimeMillis"]),
        voidedSource: int(raw["voidedSource"]),
        voidedReason: int(raw["voidedReason"]),
        voidedQuantity: positiveInt(raw["voidedQuantity"]),
        quantity: positiveInt(raw["quantity"]),
      });
    }
  }
  const pagination = data["tokenPagination"];
  const next = isRecord(pagination) ? pagination["nextPageToken"] : undefined;
  return { items, nextPageToken: typeof next === "string" && next !== "" ? next : undefined };
}

/** startTimeMs 이후의 환불 목록 전체(페이지 넘김 포함). 실패하면 예외. */
export async function listVoidedPurchases(
  serviceAccountJson: string,
  packageName: string,
  startTimeMs: number,
): Promise<VoidedPurchase[]> {
  const all: VoidedPurchase[] = [];
  let pageToken: string | undefined;
  for (let page = 0; page < MAX_PAGES; page++) {
    const res = await googleFetch(
      serviceAccountJson,
      ANDROID_PUBLISHER_SCOPE,
      voidedPurchasesUrl(packageName, startTimeMs, pageToken),
    );
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`voided purchases request failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const { items, nextPageToken } = parseVoidedPage(await res.json().catch(() => null));
    all.push(...items);
    if (!nextPageToken) return all;
    pageToken = nextPageToken;
  }
  throw new Error(`voided purchases: more than ${MAX_PAGES} pages`);
}

/** 환불 이벤트 키: 전체 환불은 'full'(남은 수량 전부), 일부 환불은 시각·수량으로 구분한다. */
export function voidedEventKey(item: Pick<VoidedPurchase, "voidedQuantity" | "voidedTimeMillis">): string {
  return item.voidedQuantity === undefined ? "full" : `q:${item.voidedTimeMillis ?? "?"}:${item.voidedQuantity}`;
}

/**
 * 구매 하나의 환불 이벤트를 회수한다. 지급된(credited = 1) 구매만 대상이다.
 * - 전체 환불: 아직 회수하지 않은 수량 전부. 일부 환불(voidedQuantity): 그 수량만큼(credits × 수량 / quantity).
 * - 한 트랜잭션에서 이벤트 기록·잔액 차감·구매 표시를 같이 하고, 같은 이벤트 키는 한 번만 반영한다.
 * 회수한 크레딧 수(대상이 아니거나 이미 반영했으면 0)를 돌려준다.
 */
export async function clawBackPurchase(
  db: D1Database,
  item: Pick<VoidedPurchase, "purchaseToken" | "voidedQuantity" | "voidedTimeMillis" | "quantity">,
  voidedAt: number,
): Promise<number> {
  const p = await db
    .prepare("SELECT account_id, credits, quantity, voided_quantity, credited FROM purchases WHERE purchase_token = ?")
    .bind(item.purchaseToken)
    .first<{ account_id: number; credits: number; quantity: number; voided_quantity: number; credited: number }>();
  if (!p || p.credited !== 1) return 0;

  const quantity = Math.max(1, item.quantity ?? p.quantity);
  const already = Math.min(quantity, Math.max(0, p.voided_quantity));
  const add = Math.min(quantity - already, item.voidedQuantity ?? quantity);
  const after = already + add;
  // 누적 기준으로 나눠 반올림 오차가 쌓이지 않게 한다(전부 환불되면 정확히 credits).
  const credits = Math.floor((p.credits * after) / quantity) - Math.floor((p.credits * already) / quantity);
  const key = voidedEventKey(item);

  const pending = "EXISTS (SELECT 1 FROM voided_events WHERE purchase_token = ? AND event_key = ? AND applied = 0)";
  const results = await db.batch([
    db
      .prepare(
        `INSERT INTO voided_events (purchase_token, event_key, quantity, credits, applied, voided_at)
         VALUES (?, ?, ?, ?, 0, ?)
         ON CONFLICT (purchase_token, event_key) DO UPDATE
           SET quantity = excluded.quantity, credits = excluded.credits, voided_at = excluded.voided_at
           WHERE applied = 0`,
      )
      .bind(item.purchaseToken, key, add, credits, voidedAt),
    db
      .prepare(
        `UPDATE accounts SET credits = credits - ? WHERE id = ? AND ${pending}
           AND EXISTS (SELECT 1 FROM purchases WHERE purchase_token = ? AND voided_quantity = ?)`,
      )
      .bind(credits, p.account_id, item.purchaseToken, key, item.purchaseToken, p.voided_quantity),
    db
      .prepare(
        `UPDATE purchases SET voided = 1, voided_at = ?, voided_quantity = ?
         WHERE purchase_token = ? AND voided_quantity = ? AND ${pending}`,
      )
      .bind(voidedAt, after, item.purchaseToken, p.voided_quantity, item.purchaseToken, key),
    db
      // 구매 표시가 실제로 바뀐 경우에만 반영 완료로 둔다(그 사이 다른 처리로 수량이 바뀌었으면 다음 실행에서 다시).
      .prepare(
        `UPDATE voided_events SET applied = 1 WHERE purchase_token = ? AND event_key = ? AND applied = 0
           AND EXISTS (SELECT 1 FROM purchases WHERE purchase_token = ? AND voided_quantity = ? AND voided = 1)`,
      )
      .bind(item.purchaseToken, key, item.purchaseToken, after),
  ]);
  if ((results[2]?.meta.changes ?? 0) === 0) return 0;
  return credits;
}

async function readCursor(db: D1Database): Promise<number | undefined> {
  const row = await db.prepare("SELECT value FROM meta WHERE key = ?").bind(VOIDED_CURSOR_KEY).first<{ value: string }>();
  const v = row ? Number(row.value) : NaN;
  return Number.isFinite(v) ? v : undefined;
}

async function writeCursor(db: D1Database, valueMs: number): Promise<void> {
  await db
    .prepare("INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value")
    .bind(VOIDED_CURSOR_KEY, String(valueMs))
    .run();
}

/** 이번 조회의 startTime: (지난 처리 시각 - 겹침) 과 (지금 - 30일 + 여유) 중 늦은 쪽. */
export function voidedStartTime(cursorMs: number | undefined, nowMs: number): number {
  const oldestAllowed = nowMs - VOIDED_MAX_LOOKBACK_MS + LOOKBACK_SAFETY_MS;
  if (cursorMs === undefined) return oldestAllowed;
  return Math.max(oldestAllowed, Math.min(nowMs, cursorMs - VOIDED_OVERLAP_MS));
}

/**
 * cron 에서 하루 한 번 부른다. 서비스 계정이 없으면 건너뛴다(null).
 * 목록 전체를 처리한 뒤에만 처리 시각을 저장하므로, 중간에 실패하면 다음 실행에서 다시 본다.
 */
export async function processVoidedPurchases(env: Env, cfg: Config, nowMs: number): Promise<VoidedRunResult | null> {
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    console.log("GOOGLE_SERVICE_ACCOUNT_JSON 이 없어 환불 회수를 건너뜀");
    return null;
  }
  const startTimeMs = voidedStartTime(await readCursor(env.DB), nowMs);
  const items = await listVoidedPurchases(env.GOOGLE_SERVICE_ACCOUNT_JSON, cfg.packageName, startTimeMs);

  const result: VoidedRunResult = { listed: items.length, clawedBack: 0, credits: 0, startTimeMs };
  const nowSec = Math.floor(nowMs / 1000);
  for (const item of items) {
    const voidedAt = item.voidedTimeMillis !== undefined ? Math.floor(item.voidedTimeMillis / 1000) : nowSec;
    const credits = await clawBackPurchase(env.DB, item, voidedAt);
    if (credits > 0) {
      result.clawedBack++;
      result.credits += credits;
      console.log(
        `환불 회수: order=${item.orderId ?? "?"} credits=${credits} quantity=${item.voidedQuantity ?? "all"} ` +
          `reason=${item.voidedReason ?? "?"} source=${item.voidedSource ?? "?"}`,
      );
    }
  }
  await writeCursor(env.DB, nowMs);
  console.log(`환불 목록 ${result.listed}건 확인, ${result.clawedBack}건 ${result.credits} 크레딧 회수`);
  return result;
}
