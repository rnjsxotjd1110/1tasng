// 허용 모델 목록과 GET /v1/models/:id (업스트림을 부르지 않는다).
import { authenticate } from "./auth";
import type { Env } from "./env";
import { ApiError, jsonResponse } from "./http";

export const ALLOWED_MODELS = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"] as const;
export type AllowedModel = (typeof ALLOWED_MODELS)[number];

export function isAllowedModel(id: unknown): id is AllowedModel {
  return typeof id === "string" && (ALLOWED_MODELS as readonly string[]).includes(id);
}

// SDK 의 ModelInfo 는 created_at 을 필수로 보므로 고정값을 넣어 둔다.
const MODEL_CREATED_AT = "2026-01-01T00:00:00Z";

export async function handleGetModel(req: Request, env: Env, id: string): Promise<Response> {
  await authenticate(env, req);
  if (!isAllowedModel(id)) throw new ApiError(404, "not_found_error", `model: ${id}`);
  return jsonResponse({ type: "model", id, display_name: id, created_at: MODEL_CREATED_AT });
}
