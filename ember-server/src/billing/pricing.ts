// 모델별 단가와 크레딧 계산. 1 크레딧 = 마크업 포함 $0.01.
import { totalInputTokens, type Usage } from "./usage";

export interface ModelPrice {
  /** USD / 100만 토큰 */
  input: number;
  output: number;
  cacheRead: number;
  /** 입력 합계가 이 값을 넘으면 모든 토큰 단가에 longContextMultiplier 를 곱한다. */
  longContextThreshold?: number;
  longContextMultiplier?: number;
}

export const CACHE_WRITE_5M_MULTIPLIER = 1.25;
export const CACHE_WRITE_1H_MULTIPLIER = 2;
export const WEB_SEARCH_USD_PER_REQUEST = 0.01;

/** 앱이 쓸 수 있는 모델(허용 목록과 같음). */
export const MODEL_PRICES: Readonly<Record<string, ModelPrice>> = {
  "claude-opus-5-5": { input: 4.0, output: 20.0, cacheRead: 0.2 },
  "claude-sonnet-5-5": { input: 2.0, output: 10.0, cacheRead: 0.2 },
  // Haiku 5.5 는 입력 10만 토큰 초과 시 $0.50 / $2.50 (5배)
  "claude-haiku-5-5": {
    input: 0.1,
    output: 0.5,
    cacheRead: 0.01,
    longContextThreshold: 100_000,
    longContextMultiplier: 5,
  },
};

/**
 * 요청은 허용하지 않지만, 서버측 거절 대체(server-side fallback)로 응답 모델이 바뀌었을 때
 * 과금에 쓰는 단가. 목록에도 없는 모델이면 아는 단가 중 가장 비싼 값(MOST_EXPENSIVE_PRICE)으로 계산한다.
 */
export const FALLBACK_MODEL_PRICES: Readonly<Record<string, ModelPrice>> = {
  "claude-opus-5": { input: 5.0, output: 25.0, cacheRead: 0.5 },
  "claude-opus-4-8": { input: 5.0, output: 25.0, cacheRead: 0.5 },
  "claude-sonnet-5": { input: 2.0, output: 10.0, cacheRead: 0.2 },
  "claude-sonnet-4-6": { input: 3.0, output: 15.0, cacheRead: 0.3 },
};

/** 아는 모든 단가의 항목별 최댓값. 모르는 응답 모델·대체 모델 예약에 쓴다. */
export const MOST_EXPENSIVE_PRICE: ModelPrice = (() => {
  const all = [...Object.values(MODEL_PRICES), ...Object.values(FALLBACK_MODEL_PRICES)];
  return {
    input: Math.max(...all.map((p) => p.input * (p.longContextMultiplier ?? 1))),
    output: Math.max(...all.map((p) => p.output * (p.longContextMultiplier ?? 1))),
    cacheRead: Math.max(...all.map((p) => p.cacheRead * (p.longContextMultiplier ?? 1))),
  };
})();

/**
 * 과금 단가: 응답 모델이 단가표에 있으면 그 단가, 응답 모델이 있는데 모르는 모델이면 가장 비싼 단가.
 * 응답 모델을 모르면(응답 파싱 실패 등) 요청 모델 단가.
 */
export function resolvePrice(requestedModel: string, responseModel?: string): ModelPrice | undefined {
  if (responseModel) {
    const p = MODEL_PRICES[responseModel] ?? FALLBACK_MODEL_PRICES[responseModel];
    if (p) return p;
    if (MODEL_PRICES[requestedModel]) {
      console.warn(`단가표에 없는 응답 모델(${responseModel}), 가장 비싼 단가로 계산`);
      return MOST_EXPENSIVE_PRICE;
    }
  }
  return MODEL_PRICES[requestedModel];
}

/** 원가(USD, 마크업 전). */
export function computeUsd(price: ModelPrice, usage: Usage): number {
  const long =
    price.longContextThreshold !== undefined && totalInputTokens(usage) > price.longContextThreshold
      ? (price.longContextMultiplier ?? 1)
      : 1;
  const inRate = price.input * long;
  const tokenUsd =
    (usage.inputTokens * inRate +
      usage.cacheWrite5mTokens * inRate * CACHE_WRITE_5M_MULTIPLIER +
      usage.cacheWrite1hTokens * inRate * CACHE_WRITE_1H_MULTIPLIER +
      usage.cacheReadTokens * price.cacheRead * long +
      usage.outputTokens * price.output * long) /
    1_000_000;
  return tokenUsd + usage.webSearchRequests * WEB_SEARCH_USD_PER_REQUEST;
}

/** credits = ceil(usd × 100 × markup). 부동소수 오차로 1 이 더 붙지 않게 아주 작은 값을 뺀다. */
export function usdToCredits(usd: number, markup: number): number {
  if (usd <= 0) return 0;
  return Math.max(1, Math.ceil(usd * 100 * markup - 1e-9));
}

export function computeCredits(
  requestedModel: string,
  usage: Usage,
  markup: number,
  responseModel?: string,
): { usd: number; credits: number } {
  const price = resolvePrice(requestedModel, responseModel);
  if (!price) return { usd: 0, credits: 0 };
  const usd = computeUsd(price, usage);
  return { usd, credits: usdToCredits(usd, markup) };
}

/** 예약 계산: 요청 전에 알 수 있는 최악의 비용 = fixedUsd + max_tokens × outputUsdPerToken. */
export interface ReservationPlan {
  /** 입력(추정) + 웹 검색 비용(USD, 마크업 전) */
  fixedUsd: number;
  /** 출력 토큰 1개당 USD(마크업 전) */
  outputUsdPerToken: number;
}

export interface WorstCaseInput {
  /** 입력 토큰 추정치(본문 크기 기반, 웹 검색 결과 몫 포함) */
  inputTokens: number;
  /** 캐시 쓰기 배수(1 / 1.25 / 2): 최악의 경우 입력 전부가 캐시 쓰기로 청구된다고 본다. */
  inputMultiplier: number;
  /** 최대 웹 검색 횟수(max_uses 합) */
  webSearches: number;
}

export function planReservation(price: ModelPrice, w: WorstCaseInput): ReservationPlan {
  const long =
    price.longContextThreshold !== undefined && w.inputTokens > price.longContextThreshold
      ? (price.longContextMultiplier ?? 1)
      : 1;
  return {
    fixedUsd: (w.inputTokens * price.input * long * w.inputMultiplier) / 1_000_000 + w.webSearches * WEB_SEARCH_USD_PER_REQUEST,
    outputUsdPerToken: (price.output * long) / 1_000_000,
  };
}

export function reservationCredits(plan: ReservationPlan, maxTokens: number, markup: number): number {
  return usdToCredits(plan.fixedUsd + maxTokens * plan.outputUsdPerToken, markup);
}

/** balance 크레딧으로 예약할 수 있는 가장 큰 max_tokens(0 이면 입력만으로도 부족). */
export function affordableMaxTokens(plan: ReservationPlan, balance: number, markup: number): number {
  if (balance <= 0 || plan.outputUsdPerToken <= 0) return 0;
  let t = Math.floor((balance / (100 * markup) - plan.fixedUsd) / plan.outputUsdPerToken);
  if (!Number.isFinite(t) || t <= 0) return 0;
  // 올림·부동소수 오차 보정(경계에서 ±몇 토큰)
  while (t > 0 && reservationCredits(plan, t, markup) > balance) t--;
  for (let i = 0; i < 1000 && reservationCredits(plan, t + 1, markup) <= balance; i++) t++;
  return t;
}
