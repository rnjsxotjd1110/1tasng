// 유료 크레딧 묶음(lot): 구매 한 건 = 묶음 하나(purchases 행의 remaining·expires_at·lot_closed_*).
//
// 잔액 모델(이용약관 5·6·7장):
// - accounts.credits 는 지금 쓸 수 있는 잔액 전체(무료 + 만료 안 된 유료, 처리 중 요청의 예약액은 빠진 값, 음수 = 빚)다.
// - 유료 크레딧 = 열린 묶음(지급됨 + 만료일 있음 + 닫히지 않음)의 remaining 합계. 무료 크레딧 = credits - 유료.
// - 쓰는 순서는 무료 먼저, 그다음 유료를 오래된 구매부터. 이를 위해 잔액이 줄어드는 모든 곳(예약·정산·환불 회수)에서
//   "유료 합계 ≤ max(0, credits)" 가 되도록 오래된 묶음부터 깎는다(trimLotsStmt). 그래서 유료가 남아 있는 동안
//   무료는 0 이상이고, 빚(음수)은 유료가 0 일 때만 생긴다.
// - 예약 때 유료에서 뺀 양(paidDrawn)은 정산 때 돌려줄 것이 있으면 최신 묶음부터 되돌린다(refundToLotsStmt).
// - 유효기간: 구매(purchases.created_at)로부터 달력 기준 5년. 지나면 cron(또는 그 계정의 다음 요청)이 닫고 잔액에서 뺀다.

/** 유료 크레딧 유효기간(년) */
export const LOT_LIFETIME_YEARS = 5;
/** GET /ember/balance 의 expiringSoon: 이 기간 안에 만료되는 묶음을 알린다(약관 6장: 만료 30일 전 안내). */
export const EXPIRING_SOON_SECONDS = 30 * 86400;

/** lot_closed_reason 값 */
export type LotClosedReason = "expired" | "refunded" | "voided" | "deleted" | "account_expired";

/** 열린 묶음 조건(별칭 a). 지급 완료 + 만료일 있음 + 닫히지 않음. */
export function openLot(a: string): string {
  return `${a}.credited = 1 AND ${a}.expires_at IS NOT NULL AND ${a}.lot_closed_at IS NULL`;
}

/** 구매 시각(유닉스 초)에 달력 기준 years 년을 더한다(2월 29일 + 1년 = 3월 1일, SQLite '+N years' 와 같음). */
export function addYears(sec: number, years: number): number {
  const d = new Date(sec * 1000);
  d.setUTCFullYear(d.getUTCFullYear() + years);
  return Math.floor(d.getTime() / 1000);
}

/** SQL 에서 created_at(열 이름)로 만료 시각을 계산하는 식. addYears 와 같은 결과. */
export const LOT_EXPIRES_SQL = `CAST(strftime('%s', created_at, 'unixepoch', '+${LOT_LIFETIME_YEARS} years') AS INTEGER)`;

/** 이 계정의 유료 크레딧(열린 묶음 remaining 합계) */
export function paidSumStmt(db: D1Database, accountId: number): D1PreparedStatement {
  return db
    .prepare(`SELECT COALESCE(SUM(remaining), 0) AS paid FROM purchases p WHERE p.account_id = ? AND ${openLot("p")}`)
    .bind(accountId);
}

/**
 * 열린 묶음의 합계가 max(0, credits) 를 넘으면 넘는 만큼을 오래된 묶음(created_at, id 순)부터 깎는다.
 * 무료 먼저 쓰기를 지키는 핵심 문장이다. 한 문장(UPDATE … FROM 물질화한 CTE)이라 계산 중 값이 바뀌지 않는다.
 */
export function trimLotsStmt(db: D1Database, accountId: number): D1PreparedStatement {
  return db
    .prepare(
      `WITH lots AS MATERIALIZED (
         SELECT id, remaining,
           COALESCE(SUM(remaining) OVER (ORDER BY created_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS older,
           SUM(remaining) OVER () AS total
         FROM purchases p WHERE p.account_id = ?1 AND ${openLot("p")} AND p.remaining > 0
       ), acct AS MATERIALIZED (SELECT MAX(0, credits) AS cap FROM accounts WHERE id = ?1)
       UPDATE purchases SET remaining = lots.remaining - MIN(lots.remaining, MAX(0, lots.total - acct.cap - lots.older))
       FROM lots, acct
       WHERE purchases.id = lots.id AND lots.total > acct.cap`,
    )
    .bind(accountId);
}

/**
 * amount 만큼을 최신 묶음부터(created_at, id 내림차순) 원래 지급량(credits)을 넘지 않게 되돌린다.
 * 정산 때 예약에서 유료로 뺐던 것 중 쓰지 않은 만큼을 돌려줄 때 쓴다. 들어갈 자리가 없으면 그만큼은 무료로 남는다.
 */
export function refundToLotsStmt(db: D1Database, accountId: number, amount: number): D1PreparedStatement {
  return db
    .prepare(
      `WITH lots AS MATERIALIZED (
         SELECT id, remaining, MAX(0, credits - remaining) AS room,
           COALESCE(SUM(MAX(0, credits - remaining)) OVER (
             ORDER BY created_at DESC, id DESC ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS newer
         FROM purchases p WHERE p.account_id = ?1 AND ${openLot("p")} AND p.remaining < p.credits
       )
       UPDATE purchases SET remaining = lots.remaining + MIN(lots.room, MAX(0, ?2 - lots.newer))
       FROM lots
       WHERE purchases.id = lots.id AND ?2 > lots.newer`,
    )
    .bind(accountId, amount);
}

/** 만료 대상 묶음 조건(별칭 a): 열려 있고 만료 시각이 지남. */
function dueLot(a: string): string {
  return `${openLot(a)} AND ${a}.expires_at <= ?`;
}

/**
 * 만료된 묶음을 닫는다: 남은 양을 잔액에서 빼고(lot_closed_credits 에 기록) remaining 을 0 으로.
 * accountId 를 주면 그 계정만(요청 때 바로), 안 주면 전체(cron). 닫은 묶음 수를 돌려준다.
 */
export async function expireLots(db: D1Database, now: number, accountId?: number): Promise<number> {
  const only = accountId === undefined ? "" : " AND p.account_id = ?";
  const onlyArgs = accountId === undefined ? [] : [accountId];
  const results = await db.batch([
    db
      .prepare(
        `UPDATE accounts SET credits = credits - (
           SELECT COALESCE(SUM(p.remaining), 0) FROM purchases p WHERE p.account_id = accounts.id AND ${dueLot("p")})
         WHERE id IN (SELECT p.account_id FROM purchases p WHERE ${dueLot("p")}${only})`,
      )
      .bind(now, now, ...onlyArgs),
    db
      .prepare(
        `UPDATE purchases SET lot_closed_at = ?, lot_closed_reason = 'expired', lot_closed_credits = remaining, remaining = 0
         WHERE id IN (SELECT p.id FROM purchases p WHERE ${dueLot("p")}${only})`,
      )
      .bind(now, now, ...onlyArgs),
  ]);
  return results[1]?.meta.changes ?? 0;
}

export interface BalanceBreakdown {
  /** 지금 쓸 수 있는 잔액 전체(예전 앱 호환). 음수 = 빚 */
  credits: number;
  /** 무료 크레딧(= credits - paidCredits). 빚이 있으면 음수 */
  freeCredits: number;
  /** 만료 안 된 유료 크레딧 */
  paidCredits: number;
  /** 30일 안에 만료되는 유료 크레딧(합계, 가장 이른 만료 시각 = 유닉스 초). 없으면 null */
  expiringSoon: { credits: number; at: number } | null;
}

/** 잔액 내역. 묶음 합계가 잔액을 넘는(정상이라면 없는) 경우에도 유료 ≤ max(0, credits) 로 보여 준다. */
export async function balanceBreakdown(db: D1Database, accountId: number, now: number): Promise<BalanceBreakdown> {
  const row = await db
    .prepare(
      `SELECT a.credits AS credits,
         (SELECT COALESCE(SUM(p.remaining), 0) FROM purchases p WHERE p.account_id = a.id AND ${openLot("p")}) AS paid,
         (SELECT COALESCE(SUM(p.remaining), 0) FROM purchases p
            WHERE p.account_id = a.id AND ${openLot("p")} AND p.remaining > 0 AND p.expires_at <= ?) AS soon,
         (SELECT MIN(p.expires_at) FROM purchases p
            WHERE p.account_id = a.id AND ${openLot("p")} AND p.remaining > 0 AND p.expires_at <= ?) AS soon_at
       FROM accounts a WHERE a.id = ?`,
    )
    .bind(now + EXPIRING_SOON_SECONDS, now + EXPIRING_SOON_SECONDS, accountId)
    .first<{ credits: number; paid: number; soon: number; soon_at: number | null }>();
  if (!row) return { credits: 0, freeCredits: 0, paidCredits: 0, expiringSoon: null };
  const paid = Math.min(row.paid, Math.max(0, row.credits));
  return {
    credits: row.credits,
    freeCredits: row.credits - paid,
    paidCredits: paid,
    expiringSoon: row.soon > 0 && row.soon_at !== null ? { credits: Math.min(row.soon, paid), at: row.soon_at } : null,
  };
}
