// /v1/messages 의 사전 예약: 최악의 비용을 계산해 업스트림을 부르기 전에 잔액에서 미리 빼고,
// 계정당 동시 처리 수를 제한한다(inflight 표).
import {
  affordableMaxTokens,
  CACHE_WRITE_1H_MULTIPLIER,
  CACHE_WRITE_5M_MULTIPLIER,
  MODEL_PRICES,
  MOST_EXPENSIVE_PRICE,
  planReservation,
  reservationCredits,
  type ReservationPlan,
} from "../billing/pricing";
import { ApiError, isRecord } from "../http";
import type { ValidatedRequest } from "./validate";

/** 입력 토큰 추정: 본문 UTF-8 바이트 / 이 값(한국어·영어 모두 실제보다 많게 잡힌다). */
export const INPUT_BYTES_PER_TOKEN = 3;
/** base64 이미지 한 장의 입력 토큰 상한 추정(바이트 수 대신 사용. 고해상도 이미지도 이보다 작다). */
export const IMAGE_TOKEN_ALLOWANCE = 5000;
/** 웹 검색 1회가 결과로 추가하는 입력 토큰 추정치. */
export const WEB_SEARCH_INPUT_TOKEN_ALLOWANCE = 8000;
/** 잔액이 모자라 max_tokens 를 줄일 때의 하한(요청한 값이 이보다 작으면 요청한 값). */
export const MIN_REDUCED_MAX_TOKENS = 1024;
/** extended thinking(type: enabled)의 budget_tokens 최솟값(API 규칙). */
const MIN_THINKING_BUDGET = 1024;

export interface WorstCase {
  plan: ReservationPlan;
  inputTokens: number;
}

/** 본문에서 입력 토큰 수를 넉넉하게 추정한다(이미지 base64 는 장당 IMAGE_TOKEN_ALLOWANCE 로 셈). */
export function estimateInputTokens(body: Record<string, unknown>): number {
  let images = 0;
  const json = JSON.stringify(body, (_key, value: unknown) => {
    if (
      isRecord(value) &&
      value["type"] === "base64" &&
      typeof value["data"] === "string" &&
      typeof value["media_type"] === "string" &&
      value["media_type"].startsWith("image/")
    ) {
      images++;
      return { ...value, data: "" };
    }
    return value;
  });
  const bytes = new TextEncoder().encode(json).byteLength;
  return Math.ceil(bytes / INPUT_BYTES_PER_TOKEN) + images * IMAGE_TOKEN_ALLOWANCE;
}

/** 캐시 쓰기 배수 추정: 1시간 캐시가 보이면 ×2, cache_control 이 있으면 ×1.25, 없으면 ×1. */
function inputMultiplier(body: Record<string, unknown>): number {
  const json = JSON.stringify(body);
  if (!json.includes('"cache_control"')) return 1;
  return /"ttl"\s*:\s*"1h"/.test(json) ? CACHE_WRITE_1H_MULTIPLIER : CACHE_WRITE_5M_MULTIPLIER;
}

/**
 * 최악의 비용 계획. fallbacks 를 쓰면 응답 모델이 바뀔 수 있으므로 아는 단가 중 가장 비싼 값으로 잡는다.
 * max_tokens 는 계획에 넣지 않는다(잔액에 맞춰 줄일 수 있도록).
 */
export function worstCase(v: ValidatedRequest): WorstCase {
  const price = v.fallbacks ? MOST_EXPENSIVE_PRICE : MODEL_PRICES[v.model];
  if (!price) throw new ApiError(500, "api_error", "no price for model");
  const bodyWithoutMax = { ...v.body };
  delete bodyWithoutMax["max_tokens"];
  const inputTokens = estimateInputTokens(bodyWithoutMax) + v.webSearchMaxUses * WEB_SEARCH_INPUT_TOKEN_ALLOWANCE;
  return {
    inputTokens,
    plan: planReservation(price, {
      inputTokens,
      inputMultiplier: inputMultiplier(v.body),
      webSearches: v.webSearchMaxUses,
    }),
  };
}

/** credits 를 잔액에서 원자적으로 뺀다. 잔액이 credits 보다 적으면 빼지 않고 false. */
export async function tryReserve(db: D1Database, accountId: number, credits: number, now: number): Promise<boolean> {
  const row = await db
    .prepare("UPDATE accounts SET credits = credits - ?, updated_at = ? WHERE id = ? AND credits >= ? RETURNING credits")
    .bind(credits, now, accountId, credits)
    .first<{ credits: number }>();
  return row !== null;
}

export interface Reservation {
  /** 미리 뺀 크레딧 */
  credits: number;
  /** 실제로 보낼 본문(max_tokens·thinking 예산을 줄였을 수 있음) */
  request: ValidatedRequest;
  /** 잔액이 모자라 max_tokens 를 줄였으면 true */
  reduced: boolean;
}

function insufficient(): ApiError {
  return new ApiError(402, "insufficient_credits", "not enough credits, please purchase more");
}

/** max_tokens 를 바꾼 요청. thinking.budget_tokens 가 새 max_tokens 이상이면 함께 줄인다(안 되면 null). */
function withMaxTokens(v: ValidatedRequest, maxTokens: number): ValidatedRequest | null {
  const body: Record<string, unknown> = { ...v.body, max_tokens: maxTokens };
  const thinking = body["thinking"];
  if (isRecord(thinking) && typeof thinking["budget_tokens"] === "number" && thinking["budget_tokens"] >= maxTokens) {
    const budget = maxTokens - 1;
    if (budget < MIN_THINKING_BUDGET) return null;
    body["thinking"] = { ...thinking, budget_tokens: budget };
  }
  return { ...v, body };
}

/**
 * 최악의 비용을 예약한다. 잔액이 모자라면 max_tokens 를 잔액이 감당하는 만큼(하한 MIN_REDUCED_MAX_TOKENS)
 * 줄여 다시 예약하고, 그래도 안 되면 402 를 던진다.
 */
export async function reserveForRequest(
  db: D1Database,
  accountId: number,
  v: ValidatedRequest,
  markup: number,
  now: number,
): Promise<Reservation> {
  const { plan } = worstCase(v);
  const requested = v.body["max_tokens"] as number;
  const full = reservationCredits(plan, requested, markup);
  if (await tryReserve(db, accountId, full, now)) return { credits: full, request: v, reduced: false };

  const row = await db.prepare("SELECT credits FROM accounts WHERE id = ?").bind(accountId).first<{ credits: number }>();
  const balance = row?.credits ?? 0;
  const affordable = Math.min(requested, affordableMaxTokens(plan, balance, markup));
  if (affordable < Math.min(requested, MIN_REDUCED_MAX_TOKENS)) throw insufficient();
  const reducedRequest = withMaxTokens(v, affordable);
  if (!reducedRequest) throw insufficient();
  const credits = reservationCredits(plan, affordable, markup);
  // 그 사이 다른 요청이 잔액을 썼으면 실패할 수 있다(다시 시도하지 않고 402).
  if (!(await tryReserve(db, accountId, credits, now))) throw insufficient();
  return { credits, request: reducedRequest, reduced: affordable < requested };
}

/**
 * 계정의 동시 처리 칸을 하나 잡는다. 이미 limit 개가 처리 중이면 429.
 * 한 SQL 문(INSERT … SELECT … WHERE COUNT < limit)이라 동시에 와도 limit 을 넘지 않는다.
 * staleSeconds 보다 오래된 행은 죽은 요청으로 보고 세지 않는다(그리고 지운다).
 */
export async function acquireSlot(
  db: D1Database,
  accountId: number,
  limit: number,
  staleSeconds: number,
  now: number,
): Promise<number> {
  const staleBefore = now - staleSeconds;
  await db.prepare("DELETE FROM inflight WHERE account_id = ? AND started_at <= ?").bind(accountId, staleBefore).run();
  const row = await db
    .prepare(
      `INSERT INTO inflight (account_id, started_at)
       SELECT ?, ? WHERE (SELECT COUNT(*) FROM inflight WHERE account_id = ? AND started_at > ?) < ?
       RETURNING id`,
    )
    .bind(accountId, now, accountId, staleBefore, limit)
    .first<{ id: number }>();
  if (!row) {
    throw new ApiError(429, "rate_limit_error", `too many concurrent requests (max ${limit}), please wait`, {
      "retry-after": "5",
    });
  }
  return row.id;
}

export async function setSlotReserved(db: D1Database, slotId: number, credits: number): Promise<void> {
  await db.prepare("UPDATE inflight SET reserved = ? WHERE id = ?").bind(credits, slotId).run();
}

/** 칸을 놓는다. 실패해도 예외를 던지지 않는다(오래되면 stale 로 정리된다). */
export async function releaseSlot(db: D1Database, slotId: number): Promise<void> {
  try {
    await db.prepare("DELETE FROM inflight WHERE id = ?").bind(slotId).run();
  } catch (err) {
    console.error(`inflight 해제 실패(id=${slotId}):`, err);
  }
}

/** 오래된 inflight 행 정리(cron). 남은 행은 워커가 중간에 죽은 요청이며, 예약액은 그대로 청구된 상태다. */
export async function purgeStaleInflight(db: D1Database, now: number, staleSeconds: number): Promise<void> {
  const { results } = await db
    .prepare("SELECT id, account_id, reserved, started_at FROM inflight WHERE started_at <= ?")
    .bind(now - staleSeconds)
    .all<{ id: number; account_id: number; reserved: number; started_at: number }>();
  for (const r of results) {
    console.warn(`정산되지 않은 요청 정리: account=${r.account_id} reserved=${r.reserved} started_at=${r.started_at}`);
  }
  await db.prepare("DELETE FROM inflight WHERE started_at <= ?").bind(now - staleSeconds).run();
}
