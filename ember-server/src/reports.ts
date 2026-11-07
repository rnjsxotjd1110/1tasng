// AI 생성 콘텐츠 신고 저장(구글 플레이 생성형 AI 정책).
// - POST /ember/report: 크레딧 계정(로그인)으로 신고. AI 응답 기록이 있는 계정만.
// - POST /ember/report/anon: 크레딧 계정이 없는 사용자(내 API 키·체험 모드)의 익명 신고. 인증 없음, account_id = NULL.
//   IP(IPv4 주소 / IPv6 /64)당 시간당 10회, 하루 전체 상한(REPORTS_DAILY_CAP)은 로그인 신고와 함께 센다.
// 본문은 둘 다 { kind, reason, content, note?, appVersion? } → { ok: true, id }. 신고는 1년 보관(retention.ts).
import { authenticate } from "./auth";
import type { Config, Env } from "./env";
import { ApiError, jsonResponse, readJsonObject } from "./http";
import { clientIpKey, enforceRateLimit, tryAddDaily } from "./ratelimit";
import { nowSeconds } from "./util";

export const REPORT_KINDS = ["question", "idea", "document", "other"] as const;
type ReportKind = (typeof REPORT_KINDS)[number];

const LIMITS = { reason: 500, content: 20_000, note: 2_000, appVersion: 64 } as const;
const REPORT_BODY_MAX = 256 * 1024;
const REPORT_RATE_LIMIT = 30;
/** IP(IPv4 주소 / IPv6 /64)당 시간당 신고 수 */
const REPORT_IP_RATE_LIMIT = 30;
const REPORT_RATE_WINDOW_SECONDS = 3600;
/** 익명 신고: IP(IPv4 주소 / IPv6 /64)당 시간당 신고 수 */
export const ANON_REPORT_IP_RATE_LIMIT = 10;
/** 하루 전체 신고 수 카운터(rate_limits 표, window_start = UTC 0시). 상한은 REPORTS_DAILY_CAP. */
export const REPORTS_DAILY_KEY = "rep:day";

function isKind(v: unknown): v is ReportKind {
  return typeof v === "string" && (REPORT_KINDS as readonly string[]).includes(v);
}

function text(body: Record<string, unknown>, field: keyof typeof LIMITS, required: boolean): string {
  const v = body[field];
  if (v === undefined || v === null) {
    if (required) throw new ApiError(400, "invalid_request_error", `${field} is required`);
    return "";
  }
  if (typeof v !== "string") throw new ApiError(400, "invalid_request_error", `${field} must be a string`);
  if (v.length > LIMITS[field]) {
    throw new ApiError(400, "invalid_request_error", `${field} must be at most ${LIMITS[field]} characters`);
  }
  return v;
}

/** 하루 전체 신고 상한(로그인·익명 공용). 넘으면 429. */
async function enforceDailyCap(env: Env, cfg: Config, now: number): Promise<void> {
  if (!(await tryAddDaily(env.DB, REPORTS_DAILY_KEY, 1, cfg.reportsDailyCap, now))) {
    console.warn("하루 신고 상한(REPORTS_DAILY_CAP)에 도달");
    throw new ApiError(429, "rate_limit_error", "too many reports today, please try again tomorrow", {
      "retry-after": String(86400 - (now % 86400)),
    });
  }
}

interface ReportBody {
  kind: ReportKind;
  reason: string;
  content: string;
  note: string;
  appVersion: string;
}

async function readReport(req: Request): Promise<ReportBody> {
  const body = await readJsonObject(req, REPORT_BODY_MAX);
  const kind = body["kind"];
  if (!isKind(kind)) throw new ApiError(400, "invalid_request_error", `kind must be one of: ${REPORT_KINDS.join(", ")}`);
  return {
    kind,
    reason: text(body, "reason", true),
    content: text(body, "content", true),
    note: text(body, "note", false),
    appVersion: text(body, "appVersion", false),
  };
}

async function saveReport(env: Env, accountId: number | null, r: ReportBody, now: number): Promise<Response> {
  const row = await env.DB.prepare(
    `INSERT INTO reports (account_id, kind, reason, content, note, app_version, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id`,
  )
    .bind(accountId, r.kind, r.reason, r.content, r.note, r.appVersion, now)
    .first<{ id: number }>();
  if (!row) throw new ApiError(500, "api_error", "could not save the report");
  return jsonResponse({ ok: true, id: row.id });
}

export async function handleReport(req: Request, env: Env, cfg: Config): Promise<Response> {
  const account = await authenticate(env, req);
  const now = nowSeconds();
  // AI 응답을 받은 적이 있는 계정만 신고할 수 있다(가입만 하고 신고로 DB 를 채우는 남용 방지).
  const used = await env.DB.prepare("SELECT 1 AS x FROM usage_log WHERE account_id = ? LIMIT 1").bind(account.id).first();
  if (!used) throw new ApiError(403, "permission_error", "nothing to report: this account has no AI responses yet");
  await enforceRateLimit(env.DB, `rep:${account.id}`, REPORT_RATE_LIMIT, REPORT_RATE_WINDOW_SECONDS, now);
  await enforceRateLimit(env.DB, `repip:${clientIpKey(req)}`, REPORT_IP_RATE_LIMIT, REPORT_RATE_WINDOW_SECONDS, now);
  await enforceDailyCap(env, cfg, now);
  return saveReport(env, account.id, await readReport(req), now);
}

/** POST /ember/report/anon: 인증 없는 익명 신고(크레딧 계정이 없는 사용자). IP 는 요청 제한 카운터(2일)에만 쓴다. */
export async function handleAnonReport(req: Request, env: Env, cfg: Config): Promise<Response> {
  const now = nowSeconds();
  await enforceRateLimit(env.DB, `repanon:${clientIpKey(req)}`, ANON_REPORT_IP_RATE_LIMIT, REPORT_RATE_WINDOW_SECONDS, now);
  const report = await readReport(req);
  await enforceDailyCap(env, cfg, now);
  return saveReport(env, null, report, now);
}
