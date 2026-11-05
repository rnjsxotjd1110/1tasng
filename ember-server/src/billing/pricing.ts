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
 * 과금에 쓰는 단가. 목록에 없는 모델이면 요청한 모델의 단가로 계산한다.
 */
export const FALLBACK_MODEL_PRICES: Readonly<Record<string, ModelPrice>> = {
  "claude-opus-5": { input: 5.0, output: 25.0, cacheRead: 0.5 },
  "claude-opus-4-8": { input: 5.0, output: 25.0, cacheRead: 0.5 },
  "claude-sonnet-5": { input: 2.0, output: 10.0, cacheRead: 0.2 },
  "claude-sonnet-4-6": { input: 3.0, output: 15.0, cacheRead: 0.3 },
};

/** 실제 응답 모델이 알려진 단가면 그것을, 아니면 요청 모델 단가를 쓴다. */
export function resolvePrice(requestedModel: string, responseModel?: string): ModelPrice | undefined {
  if (responseModel) {
    const p = MODEL_PRICES[responseModel] ?? FALLBACK_MODEL_PRICES[responseModel];
    if (p) return p;
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
