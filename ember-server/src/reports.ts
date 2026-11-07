// POST /ember/report: AI 생성 콘텐츠 신고 저장(구글 플레이 생성형 AI 정책).
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

export async function handleReport(req: Request, env: Env, cfg: Config): Promise<Response> {
  const account = await authenticate(env, req);
  const now = nowSeconds();
  // AI 응답을 받은 적이 있는 계정만 신고할 수 있다(가입만 하고 신고로 DB 를 채우는 남용 방지).
  const used = await env.DB.prepare("SELECT 1 AS x FROM usage_log WHERE account_id = ? LIMIT 1").bind(account.id).first();
  if (!used) throw new ApiError(403, "permission_error", "nothing to report: this account has no AI responses yet");
  await enforceRateLimit(env.DB, `rep:${account.id}`, REPORT_RATE_LIMIT, REPORT_RATE_WINDOW_SECONDS, now);
  await enforceRateLimit(env.DB, `repip:${clientIpKey(req)}`, REPORT_IP_RATE_LIMIT, REPORT_RATE_WINDOW_SECONDS, now);
  if (!(await tryAddDaily(env.DB, REPORTS_DAILY_KEY, 1, cfg.reportsDailyCap, now))) {
    console.warn("하루 신고 상한(REPORTS_DAILY_CAP)에 도달");
    throw new ApiError(429, "rate_limit_error", "too many reports today, please try again tomorrow", {
      "retry-after": String(86400 - (now % 86400)),
    });
  }

  const body = await readJsonObject(req, REPORT_BODY_MAX);
  const kind = body["kind"];
  if (!isKind(kind)) throw new ApiError(400, "invalid_request_error", `kind must be one of: ${REPORT_KINDS.join(", ")}`);
  const reason = text(body, "reason", true);
  const content = text(body, "content", true);
  const note = text(body, "note", false);
  const appVersion = text(body, "appVersion", false);

  const row = await env.DB.prepare(
    `INSERT INTO reports (account_id, kind, reason, content, note, app_version, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id`,
  )
    .bind(account.id, kind, reason, content, note, appVersion, now)
    .first<{ id: number }>();
  if (!row) throw new ApiError(500, "api_error", "could not save the report");
  return jsonResponse({ ok: true, id: row.id });
}
