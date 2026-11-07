// 요청 처리에서 쓰는 Google 로그인 도우미: 설정 확인, ID 토큰 → sub, 무료 크레딧 1회 지급 기록(sub 의 HMAC).
import type { Config, Env } from "../env";
import { ApiError } from "../http";
import { hmacSha256Hex } from "../util";
import { GoogleIdTokenError, verifyGoogleIdToken } from "./id-token";

/**
 * idToken 을 검증해 sub 를 돌려준다.
 * - 서버 설정(GOOGLE_OAUTH_CLIENT_IDS, SUB_HASH_SECRET)이 없으면 500(로그에 이유).
 * - 토큰이 틀리면 401 invalid_google_token, Google 공개키를 못 받으면 502(앱이 다시 시도).
 */
export async function verifyGoogleSignIn(env: Env, cfg: Config, idToken: unknown): Promise<string> {
  if (typeof idToken !== "string" || idToken === "") {
    throw new ApiError(400, "invalid_request_error", "idToken must be a non-empty string");
  }
  if (cfg.googleClientIds.length === 0 || !env.SUB_HASH_SECRET) {
    console.error("Google 로그인 설정 없음: GOOGLE_OAUTH_CLIENT_IDS(변수)와 SUB_HASH_SECRET(비밀)을 확인하세요");
    throw new ApiError(500, "api_error", "Google sign-in is not configured on the server");
  }
  try {
    return (await verifyGoogleIdToken(idToken, cfg.googleClientIds)).sub;
  } catch (err) {
    if (err instanceof GoogleIdTokenError && err.kind === "invalid") {
      console.warn("Google ID 토큰 거절:", err.message);
      throw new ApiError(401, "invalid_google_token", `invalid Google ID token: ${err.message}`);
    }
    console.error("Google ID 토큰 확인 오류:", err);
    throw new ApiError(502, "api_error", "could not verify the Google sign-in, please retry");
  }
}

/** 무료 크레딧 지급 기록용 sub 해시: HMAC-SHA256(sub, SUB_HASH_SECRET). verifyGoogleSignIn 뒤에만 부른다. */
export async function subHashOf(env: Env, sub: string): Promise<string> {
  if (!env.SUB_HASH_SECRET) throw new ApiError(500, "api_error", "Google sign-in is not configured on the server");
  return hmacSha256Hex(env.SUB_HASH_SECRET, sub);
}

/**
 * 이 sub 에 연결된 계정이 무료 크레딧을 받았으면(free_credits > 0) free_credit_grants 에 해시를 남긴다(이미 있으면 그대로).
 * 계정을 지워도 이 기록은 남아, 같은 Google 계정의 새 계정은 무료 크레딧을 다시 받지 못한다.
 */
export function recordFreeGrantStmt(db: D1Database, subHash: string, sub: string, now: number): D1PreparedStatement {
  return db
    .prepare(
      `INSERT INTO free_credit_grants (sub_hash, created_at, account_id)
       SELECT ?, ?, id FROM accounts WHERE google_sub = ? AND free_credits > 0
       ON CONFLICT (sub_hash) DO NOTHING`,
    )
    .bind(subHash, now, sub);
}

/**
 * 이 Google 계정의 무료 크레딧 기록(있으면)을 sub 에 연결된 지금 계정에 묶는다(gone_at 을 지운다).
 * 기록은 묶인 계정이 있는 동안 남고, 그 계정이 삭제·만료되면 3년 뒤 지운다(retention.ts).
 * 탈퇴 후 같은 Google 계정으로 다시 가입하면 기록은 새 계정에 다시 묶인다(보관 3년은 새 계정이 없어진 때부터).
 */
export function linkFreeGrantStmt(db: D1Database, subHash: string, sub: string): D1PreparedStatement {
  return db
    .prepare(
      `UPDATE free_credit_grants SET account_id = (SELECT id FROM accounts WHERE google_sub = ?1), gone_at = NULL
       WHERE sub_hash = ?2 AND EXISTS (SELECT 1 FROM accounts WHERE google_sub = ?1)`,
    )
    .bind(sub, subHash);
}

/**
 * 다른 Google 계정에 연결된 계정이 이 installId 를 쓰고 있으면 그 계정의 installId 를 떼어 낸다('detached:<id>').
 * Google 에 연결된 계정은 installId 가 아니라 sub 로 찾으므로 잃는 것이 없다. 연결 안 된 예전 계정은 건드리지 않는다.
 */
export function detachInstallStmt(db: D1Database, installId: string, sub: string): D1PreparedStatement {
  return db
    .prepare(
      `UPDATE accounts SET install_id = 'detached:' || id
       WHERE install_id = ? AND google_sub IS NOT NULL AND google_sub <> ?`,
    )
    .bind(installId, sub);
}
