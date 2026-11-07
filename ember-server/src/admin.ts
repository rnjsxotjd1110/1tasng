// 운영자용: GET /ember/admin/reports, GET /ember/admin/stats (x-admin-key 필요)
import type { Env } from "./env";
import { ApiError, jsonResponse } from "./http";
import { nowSeconds, timingSafeEqual } from "./util";

const DEFAULT_REPORT_LIMIT = 50;
const MAX_REPORT_LIMIT = 200;

export async function requireAdmin(req: Request, env: Env): Promise<void> {
  const given = req.headers.get("x-admin-key");
  // ADMIN_KEY 가 없으면 관리자 기능 전체를 막는다.
  if (!env.ADMIN_KEY || !given || !(await timingSafeEqual(given, env.ADMIN_KEY))) {
    throw new ApiError(401, "authentication_error", "invalid admin key");
  }
}

function intParam(url: URL, name: string): number | undefined {
  const raw = url.searchParams.get(name);
  if (raw === null || raw === "") return undefined;
  const v = Number(raw);
  return Number.isInteger(v) ? v : undefined;
}

export async function handleAdminReports(req: Request, env: Env): Promise<Response> {
  await requireAdmin(req, env);
  const url = new URL(req.url);
  const limit = Math.min(MAX_REPORT_LIMIT, Math.max(1, intParam(url, "limit") ?? DEFAULT_REPORT_LIMIT));
  const before = intParam(url, "before"); // 페이지 넘김: 이 id 보다 작은 것
  const stmt =
    before !== undefined
      ? env.DB.prepare("SELECT * FROM reports WHERE id < ? ORDER BY id DESC LIMIT ?").bind(before, limit)
      : env.DB.prepare("SELECT * FROM reports ORDER BY id DESC LIMIT ?").bind(limit);
  const { results } = await stmt.all<Record<string, unknown>>();
  const last = results[results.length - 1];
  return jsonResponse({
    reports: results,
    nextBefore: results.length === limit && last ? last["id"] : null,
  });
}

interface StatsRow {
  accounts: number;
  free_granted: number;
  purchased: number;
  purchases: number;
  voided: number;
  clawed_back: number;
  spent: number;
  outstanding: number;
  requests_24h: number;
  spent_24h: number;
  reports: number;
  billing_disabled: number;
  inflight: number;
}

export async function handleAdminStats(req: Request, env: Env): Promise<Response> {
  await requireAdmin(req, env);
  const since = nowSeconds() - 86400;
  const row = await env.DB.prepare(
    `SELECT
       (SELECT COUNT(*) FROM accounts) AS accounts,
       (SELECT COALESCE(SUM(free_credits), 0) FROM accounts) AS free_granted,
       (SELECT COALESCE(SUM(credits), 0) FROM purchases WHERE credited = 1) AS purchased,
       (SELECT COUNT(*) FROM purchases WHERE credited = 1 AND credits > 0) AS purchases,
       (SELECT COUNT(*) FROM purchases WHERE credited = 1 AND voided = 1) AS voided,
       (SELECT COALESCE(SUM(credits), 0) FROM voided_events WHERE applied = 1) AS clawed_back,
       (SELECT COUNT(*) FROM accounts WHERE disabled = 2) AS billing_disabled,
       (SELECT COUNT(*) FROM inflight) AS inflight,
       (SELECT COALESCE(SUM(credits), 0) FROM usage_log) AS spent,
       (SELECT COALESCE(SUM(credits), 0) FROM accounts) AS outstanding,
       (SELECT COUNT(*) FROM usage_log WHERE created_at >= ?) AS requests_24h,
       (SELECT COALESCE(SUM(credits), 0) FROM usage_log WHERE created_at >= ?) AS spent_24h,
       (SELECT COUNT(*) FROM reports) AS reports`,
  )
    .bind(since, since)
    .first<StatsRow>();
  if (!row) throw new ApiError(500, "api_error", "stats query failed");
  return jsonResponse({
    accounts: row.accounts,
    creditsGranted: { free: row.free_granted, purchased: row.purchased, total: row.free_granted + row.purchased },
    creditsSpent: row.spent,
    creditsOutstanding: row.outstanding,
    purchases: row.purchases,
    // 환불(일부 환불 포함)되어 회수한 구매(creditsGranted.purchased 에는 포함된 채로 남는다)
    voided: { purchases: row.voided, creditsClawedBack: row.clawed_back },
    // 정산 기록 실패로 자동 차단된 계정 수(disabled = 2, 로그 확인 후 수동 정산)
    billingDisabledAccounts: row.billing_disabled,
    // 처리 중인 /v1/messages 수(예약액이 빠져 있는 상태)
    inflightRequests: row.inflight,
    reports: row.reports,
    last24h: { requests: row.requests_24h, creditsSpent: row.spent_24h },
  });
}
