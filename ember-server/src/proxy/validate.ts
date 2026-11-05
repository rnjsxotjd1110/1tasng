// /v1/messages 요청 본문 검증: 모델 허용 목록, max_tokens 상한, 도구 제한.
import { ApiError, isRecord } from "../http";
import { ALLOWED_MODELS, isAllowedModel, type AllowedModel } from "../models";

export interface ValidatedRequest {
  body: Record<string, unknown>;
  model: AllowedModel;
  stream: boolean;
  /** max_tokens 를 잘랐으면 true */
  clamped: boolean;
}

export const ALLOWED_TOOL_PREFIX = "web_search_";

/** 비용 계산을 벗어나거나 남용될 수 있는 최상위 필드. */
const DENIED_FIELDS = ["mcp_servers", "container"] as const;

function bad(message: string): ApiError {
  return new ApiError(400, "invalid_request_error", message);
}

export function validateMessagesBody(raw: Record<string, unknown>, maxOutputTokens: number): ValidatedRequest {
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

  const stream = body["stream"];
  if (stream !== undefined && typeof stream !== "boolean") throw bad("stream: must be a boolean");

  for (const field of DENIED_FIELDS) {
    if (body[field] !== undefined) throw bad(`${field}: not supported by this server`);
  }
  // fast 모드는 단가가 2배라 과금표와 맞지 않는다.
  const speed = body["speed"];
  if (speed !== undefined && speed !== "standard") throw bad("speed: only \"standard\" is supported");

  const tools = body["tools"];
  if (tools !== undefined) {
    if (!Array.isArray(tools)) throw bad("tools: must be an array");
    tools.forEach((tool: unknown, i: number) => {
      const type = isRecord(tool) ? tool["type"] : undefined;
      if (typeof type !== "string" || !type.startsWith(ALLOWED_TOOL_PREFIX)) {
        throw bad(`tools.${i}: only web_search tools are allowed on this server`);
      }
    });
  }

  return { body, model, stream: stream === true, clamped };
}
