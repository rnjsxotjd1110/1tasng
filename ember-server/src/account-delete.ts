// DELETE /ember/account: 계정을 영구히 지운다(앱의 "계정 삭제", 구글 플레이 계정 삭제 정책).
//
// 지우는 것: 계정 행(토큰 해시·installId·Google sub·잔액), 요청 기록(usage_log), 처리 중 표시(inflight),
//   이 계정의 신고(reports), 계정 단위 요청 제한 카운터.
// 남기는 것(법정 보관·남용 방지):
//   - 구매 기록(전자상거래법: 대금결제·재화 공급 기록 5년). 계정과의 연결을 끊는다: account_id 를 공용 묘비 계정
//     ('deleted:tombstone', 로그인 불가)으로 바꾸고 purchase_token 을 'sha256:<해시>' 로 바꾼다.
//     상품·주문번호·수량·크레딧·시각은 그대로 남는다. 해시는 같은 영수증을 새 계정에서 다시 지급받는 것을 막는다.
//     남은 유료 크레딧 묶음은 닫는다(lot_closed_reason 'deleted', 약관 12장: 삭제하면 남은 크레딧은 사라짐).
//   - free_credit_grants(Google sub 의 HMAC): 같은 Google 계정으로 다시 가입해도 무료 크레딧을 다시 주지 않기 위해.
//     계정과의 연결을 끊고 gone_at = 지금으로 두어, 3년 뒤 cron 이 지운다(개인정보처리방침).
//   - account_deletions: 탈퇴 시각만(통계용, 식별 정보 없음).
// LEGACY_UNLINKED_UNTIL 이 지난 뒤에도 연결 안 된 계정이 쓸 수 있다.
import { authenticate } from "./auth";
import type { Env } from "./env";
import { subHashOf } from "./google/identity";
import { ApiError, jsonResponse } from "./http";
import { nowSeconds, sha256Hex } from "./util";

/** 탈퇴한 계정의 구매 기록이 옮겨 가는 공용 계정. installId·토큰 형식에 맞지 않아 로그인할 수 없다. */
export const DELETED_TOMBSTONE = "deleted:tombstone";
/** 탈퇴한 계정 구매의 purchase_token 접두사 */
export const HASHED_PURCHASE_PREFIX = "sha256:";

export async function hashedPurchaseToken(purchaseToken: string): Promise<string> {
  return HASHED_PURCHASE_PREFIX + (await sha256Hex(purchaseToken));
}

export async function handleDeleteAccount(req: Request, env: Env): Promise<Response> {
  const account = await authenticate(env, req, { allowUnlinked: true });
  // 0005 이전 기록은 아직 계정과 연결되지 않았을 수 있으므로 sub 의 HMAC 으로도 찾는다.
  const subHash = account.googleSub !== null && env.SUB_HASH_SECRET ? await subHashOf(env, account.googleSub) : undefined;
  try {
    await deleteAccount(env.DB, account.id, nowSeconds(), subHash);
  } catch (err) {
    // 예: 그 사이 구매가 들어와 묘비로 옮기지 못한 구매가 생김(외래 키). 앱이 다시 시도하면 된다.
    console.error(`계정 삭제 실패: account=${account.id}`, err);
    throw new ApiError(500, "api_error", "could not delete the account, please retry");
  }
  console.log(`계정 삭제: account=${account.id}`);
  return jsonResponse({ deleted: true });
}

/** 한 트랜잭션(batch)으로 계정을 지운다. subHash 를 주면 그 무료 크레딧 기록도 '계정 없어짐'으로 표시한다. */
export async function deleteAccount(db: D1Database, accountId: number, now: number, subHash?: string): Promise<void> {
  const { results: purchases } = await db
    .prepare("SELECT purchase_token FROM purchases WHERE account_id = ? AND purchase_token NOT LIKE 'sha256:%'")
    .bind(accountId)
    .all<{ purchase_token: string }>();
  const tombstoneId = "(SELECT id FROM accounts WHERE install_id = 'deleted:tombstone')";

  const stmts: D1PreparedStatement[] = [
    // 남은 유료 크레딧 묶음을 닫는다(구매 기록을 묘비로 옮기기 전에).
    db
      .prepare(
        `UPDATE purchases SET lot_closed_at = ?, lot_closed_reason = 'deleted', lot_closed_credits = remaining, remaining = 0
         WHERE account_id = ? AND expires_at IS NOT NULL AND lot_closed_at IS NULL`,
      )
      .bind(now, accountId),
    // 무료 크레딧 1회 기록: 계정 연결을 끊고 3년 보관 시계를 시작한다.
    db
      .prepare("UPDATE free_credit_grants SET account_id = NULL, gone_at = ? WHERE account_id = ? OR sub_hash = ?")
      .bind(now, accountId, subHash ?? null),
  ];
  if (purchases.length > 0) {
    stmts.push(
      db
        .prepare(
          `INSERT INTO accounts (install_id, token_hash, credits, free_credits, disabled, created_at, updated_at)
           VALUES ('deleted:tombstone', 'deleted:tombstone', 0, 0, 1, ?, ?)
           ON CONFLICT (install_id) DO NOTHING`,
        )
        .bind(now, now),
    );
  }
  for (const p of purchases) {
    const hashed = await hashedPurchaseToken(p.purchase_token);
    stmts.push(
      db
        .prepare(`UPDATE purchases SET purchase_token = ?, account_id = ${tombstoneId} WHERE purchase_token = ? AND account_id = ?`)
        .bind(hashed, p.purchase_token, accountId),
      db.prepare("UPDATE voided_events SET purchase_token = ? WHERE purchase_token = ?").bind(hashed, p.purchase_token),
    );
  }
  stmts.push(
    db.prepare("DELETE FROM usage_log WHERE account_id = ?").bind(accountId),
    db.prepare("DELETE FROM inflight WHERE account_id = ?").bind(accountId),
    db.prepare("DELETE FROM reports WHERE account_id = ?").bind(accountId),
    db
      .prepare("DELETE FROM rate_limits WHERE key IN (?, ?, ?)")
      .bind(`msg:${accountId}`, `rep:${accountId}`, `link:${accountId}`),
    // 외래 키: 묘비로 옮기지 못한 구매가 남아 있으면 여기서 실패하고 전부 되돌린다.
    db.prepare("DELETE FROM accounts WHERE id = ?").bind(accountId),
    db.prepare("INSERT INTO account_deletions (deleted_at) VALUES (?)").bind(now),
  );
  await db.batch(stmts);
}
