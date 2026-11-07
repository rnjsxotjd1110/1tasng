// 기기 토큰 인증. 토큰 원문은 저장하지 않고 SHA-256 해시로만 찾는다.
import { parseLegacyUnlinkedUntil, type Env } from "./env";
import { ApiError } from "./http";
import { nowSeconds, sha256Hex } from "./util";

export interface Account {
  id: number;
  credits: number;
  /**
   * 결제 계정: 크레딧을 실제로 지급한(credits > 0, 운영에서 테스트 구매는 0) 환불되지 않은 구매가 있고,
   * 환불(일부 환불 포함)된 구매가 하나도 없으면 true. 아니면 무료 크레딧만 쓰는 계정으로 본다.
   */
  paid: boolean;
  /** 연결된 Google 계정의 sub(예전 앱이 만든 연결 안 된 계정은 null) */
  googleSub: string | null;
  /** 가입 때 받은 무료 크레딧 */
  freeCredits: number;
}

export interface AuthOptions {
  /**
   * true 면 LEGACY_UNLINKED_UNTIL 이 지난 뒤에도 Google 에 연결 안 된 계정을 통과시킨다.
   * 연결(POST /ember/link-google)과 탈퇴(DELETE /ember/account)만 쓴다(예전 계정이 빠져나갈 길).
   */
  allowUnlinked?: boolean;
}

/** LEGACY_UNLINKED_UNTIL 이 지났으면 true(연결 안 된 계정은 403 google_required). */
export function legacyUnlinkedExpired(env: Env, now: number = nowSeconds()): boolean {
  const until = parseLegacyUnlinkedUntil(env.LEGACY_UNLINKED_UNTIL);
  return until !== null && now >= until;
}

export function googleRequiredError(): ApiError {
  return new ApiError(403, "google_required", "this account must be linked to a Google account (POST /ember/link-google)");
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

export async function authenticate(env: Env, req: Request, opts: AuthOptions = {}): Promise<Account> {
  const token = extractToken(req);
  if (!token) throw new ApiError(401, "authentication_error", "missing x-api-key header");
  if (token.length > MAX_TOKEN_LENGTH) throw new ApiError(401, "authentication_error", "invalid x-api-key");
  const hash = await sha256Hex(token);
  const row = await env.DB.prepare(
    `SELECT id, credits, disabled, google_sub, free_credits,
       (EXISTS (SELECT 1 FROM purchases p
                WHERE p.account_id = accounts.id AND p.credited = 1 AND p.voided = 0 AND p.credits > 0)
        AND NOT EXISTS (SELECT 1 FROM purchases p WHERE p.account_id = accounts.id AND p.voided = 1)) AS paid
     FROM accounts WHERE token_hash = ?`,
  )
    .bind(hash)
    .first<{ id: number; credits: number; disabled: number; paid: number; google_sub: string | null; free_credits: number }>();
  if (!row) throw new ApiError(401, "authentication_error", "invalid x-api-key");
  if (row.disabled === 2) {
    // 정산 기록 실패로 자동 차단(billing/ledger.ts). 운영자가 정산한 뒤 풀어 준다.
    throw new ApiError(403, "permission_error", "this account is temporarily disabled pending billing reconciliation");
  }
  if (row.disabled) throw new ApiError(403, "permission_error", "this account has been disabled");
  if (row.google_sub === null && !opts.allowUnlinked && legacyUnlinkedExpired(env)) throw googleRequiredError();
  return {
    id: row.id,
    credits: row.credits,
    paid: row.paid === 1,
    googleSub: row.google_sub,
    freeCredits: row.free_credits,
  };
}
