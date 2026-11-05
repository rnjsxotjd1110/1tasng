// Anthropic 응답의 usage 객체를 누적·정규화한다.
import { isRecord } from "../http";

export interface Usage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  /** 5분 캐시 쓰기(입력 단가 × 1.25) */
  cacheWrite5mTokens: number;
  /** 1시간 캐시 쓰기(입력 단가 × 2) */
  cacheWrite1hTokens: number;
  webSearchRequests: number;
}

export function emptyUsage(): Usage {
  return {
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWrite5mTokens: 0,
    cacheWrite1hTokens: 0,
    webSearchRequests: 0,
  };
}

function count(v: unknown): number | undefined {
  return typeof v === "number" && Number.isFinite(v) && v >= 0 ? Math.floor(v) : undefined;
}

/**
 * usage 객체의 값을 target 에 덮어쓴다(있는 필드만).
 * 스트리밍에서 message_delta 의 usage 는 누적값이므로 더하지 않고 덮어쓰는 것이 맞다.
 */
export function applyUsage(target: Usage, raw: unknown): void {
  if (!isRecord(raw)) return;
  const input = count(raw["input_tokens"]);
  if (input !== undefined) target.inputTokens = input;
  const output = count(raw["output_tokens"]);
  if (output !== undefined) target.outputTokens = output;
  const cacheRead = count(raw["cache_read_input_tokens"]);
  if (cacheRead !== undefined) target.cacheReadTokens = cacheRead;

  const cacheWriteTotal = count(raw["cache_creation_input_tokens"]);
  const breakdown = raw["cache_creation"];
  if (isRecord(breakdown)) {
    const w5 = count(breakdown["ephemeral_5m_input_tokens"]) ?? 0;
    const w1h = count(breakdown["ephemeral_1h_input_tokens"]) ?? 0;
    // 세부 합이 총계보다 작으면 나머지는 5분 캐시로 본다.
    const rest = cacheWriteTotal !== undefined ? Math.max(0, cacheWriteTotal - w5 - w1h) : 0;
    target.cacheWrite5mTokens = w5 + rest;
    target.cacheWrite1hTokens = w1h;
  } else if (cacheWriteTotal !== undefined) {
    target.cacheWrite5mTokens = cacheWriteTotal;
    target.cacheWrite1hTokens = 0;
  }

  const serverTools = raw["server_tool_use"];
  if (isRecord(serverTools)) {
    const searches = count(serverTools["web_search_requests"]);
    if (searches !== undefined) target.webSearchRequests = searches;
  }
}

export function totalInputTokens(u: Usage): number {
  return u.inputTokens + u.cacheReadTokens + u.cacheWrite5mTokens + u.cacheWrite1hTokens;
}
