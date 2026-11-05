// 기기 토큰 인증. 토큰 원문은 저장하지 않고 SHA-256 해시로만 찾는다.
import type { Env } from "./env";
import { ApiError } from "./http";
import { sha256Hex } from "./util";

export interface Account {
  id: number;
  credits: number;
}

const MAX_TOKEN_LENGTH = 256;

/** x-api-key 또는 Authorization: Bearer 에서 토큰을 꺼낸다. */
export function extractToken(req: Request): string | null {
  const apiKey = req.headers.get("x-api-key")?.trim();
  if (apiKey) return apiKey;
  const auth = req.headers.get("authorization")?.trim();
  if (auth) {
    const m = /^Bearer\s+(.+)$/i.exec(auth);
    if (m?.[1]) return m[1].trim();
  }
  return null;
}

export async function authenticate(env: Env, req: Request): Promise<Account> {
  const token = extractToken(req);
  if (!token) throw new ApiError(401, "authentication_error", "missing x-api-key header");
  if (token.length > MAX_TOKEN_LENGTH) throw new ApiError(401, "authentication_error", "invalid x-api-key");
  const hash = await sha256Hex(token);
  const row = await env.DB.prepare("SELECT id, credits, disabled FROM accounts WHERE token_hash = ?")
    .bind(hash)
    .first<{ id: number; credits: number; disabled: number }>();
  if (!row) throw new ApiError(401, "authentication_error", "invalid x-api-key");
  if (row.disabled) throw new ApiError(403, "permission_error", "this account has been disabled");
  return { id: row.id, credits: row.credits };
}
