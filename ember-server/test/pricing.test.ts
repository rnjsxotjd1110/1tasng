import { describe, expect, it } from "vitest";
import { computeCredits, computeUsd, MODEL_PRICES, usdToCredits } from "../src/billing/pricing";
import { applyUsage, emptyUsage, type Usage } from "../src/billing/usage";
import { ALLOWED_MODELS } from "../src/models";

function usage(p: Partial<Usage>): Usage {
  return { ...emptyUsage(), ...p };
}

describe("비용 계산", () => {
  it("허용 모델마다 단가가 있다", () => {
    for (const m of ALLOWED_MODELS) expect(MODEL_PRICES[m]).toBeDefined();
  });

  it("opus: 입력·출력 단가와 1.5배 마크업, 올림", () => {
    // (1000×4 + 500×20) / 1e6 = $0.014 → 0.014×100×1.5 = 2.1 → 3
    const r = computeCredits("claude-opus-5-5", usage({ inputTokens: 1000, outputTokens: 500 }), 1.5);
    expect(r.usd).toBeCloseTo(0.014, 10);
    expect(r.credits).toBe(3);
  });

  it("sonnet: 캐시 쓰기는 입력×1.25, 캐시 읽기는 별도 단가", () => {
    // (100×2 + 10000×2×1.25 + 50000×0.2 + 2000×10) / 1e6 = 0.0552 → 8.28 → 9
    const u = usage({ inputTokens: 100, cacheWrite5mTokens: 10_000, cacheReadTokens: 50_000, outputTokens: 2000 });
    const r = computeCredits("claude-sonnet-5-5", u, 1.5);
    expect(r.usd).toBeCloseTo(0.0552, 10);
    expect(r.credits).toBe(9);
  });

  it("1시간 캐시 쓰기는 입력×2", () => {
    // 1000×4×2 / 1e6 = 0.008 → 1.2 → 2
    expect(computeUsd(MODEL_PRICES["claude-opus-5-5"]!, usage({ cacheWrite1hTokens: 1000 }))).toBeCloseTo(0.008, 10);
    expect(computeCredits("claude-opus-5-5", usage({ cacheWrite1hTokens: 1000 }), 1.5).credits).toBe(2);
  });

  it("haiku: 작은 요청도 최소 1 크레딧", () => {
    // (10000×0.1 + 1000×0.5) / 1e6 = 0.0015 → 0.225 → 1
    const r = computeCredits("claude-haiku-5-5", usage({ inputTokens: 10_000, outputTokens: 1000 }), 1.5);
    expect(r.usd).toBeCloseTo(0.0015, 10);
    expect(r.credits).toBe(1);
  });

  it("haiku: 입력 10만 토큰 초과면 5배 단가", () => {
    // (200000×0.5 + 1000×2.5) / 1e6 = 0.1025 → 15.375 → 16
    const r = computeCredits("claude-haiku-5-5", usage({ inputTokens: 200_000, outputTokens: 1000 }), 1.5);
    expect(r.usd).toBeCloseTo(0.1025, 10);
    expect(r.credits).toBe(16);
  });

  it("웹 검색은 요청당 $0.01", () => {
    // 0.03 → 4.5 → 5
    expect(computeCredits("claude-sonnet-5-5", usage({ webSearchRequests: 3 }), 1.5).credits).toBe(5);
  });

  it("정확히 떨어지는 값은 부동소수 오차로 1 이 더 붙지 않는다", () => {
    // opus 출력 1000 = $0.02 → ×150 = 3 (0.02*150 = 3.0000000000000004)
    expect(computeCredits("claude-opus-5-5", usage({ outputTokens: 1000 }), 1.5).credits).toBe(3);
    expect(usdToCredits(0.07, 1)).toBe(7);
  });

  it("사용량 0 이면 0 크레딧", () => {
    expect(computeCredits("claude-opus-5-5", emptyUsage(), 1.5).credits).toBe(0);
  });

  it("마크업 배수를 바꿀 수 있다", () => {
    expect(computeCredits("claude-opus-5-5", usage({ outputTokens: 1000 }), 2).credits).toBe(4);
  });

  it("대체 모델로 응답하면 그 모델 단가, 모르는 모델이면 요청 모델 단가", () => {
    // claude-opus-5 출력 1000 = $0.025 → 3.75 → 4
    expect(computeCredits("claude-opus-5-5", usage({ outputTokens: 1000 }), 1.5, "claude-opus-5").credits).toBe(4);
    expect(computeCredits("claude-opus-5-5", usage({ outputTokens: 1000 }), 1.5, "claude-unknown-9").credits).toBe(3);
  });

  it("허용되지 않은 모델은 0 (검증 단계에서 이미 막힌다)", () => {
    expect(computeCredits("gpt-x", usage({ outputTokens: 1000 }), 1.5).credits).toBe(0);
  });
});

describe("usage 해석", () => {
  it("cache_creation 세부 항목을 5분/1시간으로 나눈다", () => {
    const u = emptyUsage();
    applyUsage(u, {
      input_tokens: 10,
      output_tokens: 20,
      cache_read_input_tokens: 30,
      cache_creation_input_tokens: 100,
      cache_creation: { ephemeral_5m_input_tokens: 60, ephemeral_1h_input_tokens: 40 },
      server_tool_use: { web_search_requests: 2 },
    });
    expect(u).toEqual({
      inputTokens: 10,
      outputTokens: 20,
      cacheReadTokens: 30,
      cacheWrite5mTokens: 60,
      cacheWrite1hTokens: 40,
      webSearchRequests: 2,
    });
  });

  it("세부 항목이 없으면 총계를 5분 캐시로 본다", () => {
    const u = emptyUsage();
    applyUsage(u, { cache_creation_input_tokens: 77 });
    expect(u.cacheWrite5mTokens).toBe(77);
    expect(u.cacheWrite1hTokens).toBe(0);
  });

  it("없는 필드는 기존 값을 유지하고 잘못된 값은 무시한다", () => {
    const u = usage({ inputTokens: 5, outputTokens: 1 });
    applyUsage(u, { output_tokens: 99, input_tokens: "x" });
    expect(u.inputTokens).toBe(5);
    expect(u.outputTokens).toBe(99);
    applyUsage(u, null);
    expect(u.outputTokens).toBe(99);
  });
});
