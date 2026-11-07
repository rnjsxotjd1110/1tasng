// /v1/messages 요청 검증: 최상위 필드 허용 목록, 모델 허용 목록, max_tokens 상한, 도구 제한, 헤더 허용 목록.
import { ApiError, isRecord } from "../http";
import { ALLOWED_MODELS, isAllowedModel, type AllowedModel } from "../models";

export interface ValidatedRequest {
  body: Record<string, unknown>;
  model: AllowedModel;
  stream: boolean;
  /** max_tokens 를 잘랐으면 true */
  clamped: boolean;
  /** 웹 검색 도구들의 max_uses 합(최악의 검색 횟수) */
  webSearchMaxUses: number;
  /** fallbacks: "default" 를 썼으면 true(응답 모델이 바뀔 수 있음) */
  fallbacks: boolean;
}

export const ALLOWED_TOOL_PREFIX = "web_search_";
/** 웹 검색 도구 하나의 max_uses 상한. 없거나 더 크면 이 값으로 바꿔 보낸다. */
export const WEB_SEARCH_MAX_USES = 5;

/**
 * 업스트림으로 넘기는 최상위 필드 허용 목록. 이 밖의 필드(mcp_servers, container, speed, service_tier,
 * context_management, inference_geo 등)는 비용 계산을 벗어날 수 있어 400 으로 거절한다.
 * cache_control(최상위 자동 캐시)은 Ember 앱이 보내므로 허용한다(캐시 쓰기는 과금표에 들어 있다).
 */
export const ALLOWED_TOP_LEVEL_FIELDS = [
  "model",
  "max_tokens",
  "messages",
  "system",
  "stream",
  "tools",
  "tool_choice",
  "thinking",
  "output_config",
  "metadata",
  "temperature",
  "top_p",
  "top_k",
  "stop_sequences",
  "fallbacks",
  "cache_control",
] as const;

/** 앱(ClaudeAiService.kt)이 보내는 베타만 넘긴다. 나머지 값은 조용히 뺀다. */
export const ALLOWED_BETAS = ["server-side-fallback-2026-07-01"] as const;
export const ALLOWED_ANTHROPIC_VERSIONS = ["2023-06-01"] as const;
export const DEFAULT_ANTHROPIC_VERSION = "2023-06-01";

function bad(message: string): ApiError {
  return new ApiError(400, "invalid_request_error", message);
}

export function validateMessagesBody(raw: Record<string, unknown>, maxOutputTokens: number): ValidatedRequest {
  for (const key of Object.keys(raw)) {
    if (!(ALLOWED_TOP_LEVEL_FIELDS as readonly string[]).includes(key)) {
      throw bad(`${key}: not supported by this server`);
    }
  }
  const body: Record<string, unknown> = { ...raw };

  const model = body["model"];
  if (!isAllowedModel(model)) {
    throw bad(`model must be one of: ${ALLOWED_MODELS.join(", ")}`);
  }

  const maxTokens = body["max_tokens"];
  if (typeof maxTokens !== "number" || !Number.isInteger(maxTokens) || maxTokens < 1) {
    throw bad("max_tokens: must be a positive integer");
  }
  const clamped = maxTokens > maxOutputTokens;
  if (clamped) body["max_tokens"] = maxOutputTokens;

  if (!Array.isArray(body["messages"])) throw bad("messages: must be an array");

  const stream = body["stream"];
  if (stream !== undefined && typeof stream !== "boolean") throw bad("stream: must be a boolean");

  const fallbacks = body["fallbacks"];
  if (fallbacks !== undefined && fallbacks !== "default") throw bad('fallbacks: only "default" is supported');

  let webSearchMaxUses = 0;
  const tools = body["tools"];
  if (tools !== undefined) {
    if (!Array.isArray(tools)) throw bad("tools: must be an array");
    body["tools"] = tools.map((tool: unknown, i: number) => {
      const type = isRecord(tool) ? tool["type"] : undefined;
      if (!isRecord(tool) || typeof type !== "string" || !type.startsWith(ALLOWED_TOOL_PREFIX)) {
        throw bad(`tools.${i}: only web_search tools are allowed on this server`);
      }
      const uses = tool["max_uses"];
      if (uses !== undefined && (typeof uses !== "number" || !Number.isInteger(uses) || uses < 1)) {
        throw bad(`tools.${i}.max_uses: must be a positive integer`);
      }
      const capped = Math.min(uses ?? WEB_SEARCH_MAX_USES, WEB_SEARCH_MAX_USES);
      webSearchMaxUses += capped;
      return { ...tool, max_uses: capped };
    });
  }

  return { body, model, stream: stream === true, clamped, webSearchMaxUses, fallbacks: fallbacks === "default" };
}

/** anthropic-version: 없으면 기본값, 허용 목록 밖이면 400. */
export function validateAnthropicVersion(raw: string | null): string {
  const v = raw?.trim() ?? "";
  if (v === "") return DEFAULT_ANTHROPIC_VERSION;
  if (!(ALLOWED_ANTHROPIC_VERSIONS as readonly string[]).includes(v)) {
    throw bad(`anthropic-version: only ${ALLOWED_ANTHROPIC_VERSIONS.join(", ")} is supported`);
  }
  return v;
}

/** anthropic-beta(쉼표 목록)에서 허용된 값만 남긴다. 남는 게 없으면 null(헤더를 보내지 않음). */
export function filterBetas(raw: string | null): string | null {
  if (!raw) return null;
  const kept = raw
    .split(",")
    .map((s) => s.trim())
    .filter((s, i, all) => (ALLOWED_BETAS as readonly string[]).includes(s) && all.indexOf(s) === i);
  return kept.length > 0 ? kept.join(",") : null;
}
