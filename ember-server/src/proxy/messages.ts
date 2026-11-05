// POST /v1/messages: 인증·잔액·요청 제한·검증 후 Anthropic 으로 그대로 전달하고 사용량만큼 차감한다.
import { authenticate, type Account } from "../auth";
import { recordUsage } from "../billing/ledger";
import { computeCredits } from "../billing/pricing";
import { applyUsage, emptyUsage, type Usage } from "../billing/usage";
import type { Config, Env } from "../env";
import { ApiError, errorResponse, isRecord, readJsonObject } from "../http";
import type { AllowedModel } from "../models";
import { enforceRateLimit } from "../ratelimit";
import { nowSeconds } from "../util";
import { SseUsageParser } from "./sse";
import { validateMessagesBody, type ValidatedRequest } from "./validate";

const DEFAULT_ANTHROPIC_VERSION = "2023-06-01";
/** 업스트림 응답에서 앱으로 넘겨 주는 헤더(조직 정보 등은 숨긴다). */
const PASSTHROUGH_HEADERS = ["content-type", "request-id", "retry-after", "x-should-retry"] as const;
export const CREDITS_HEADER = "ember-credits-remaining";
/** 실제로 업스트림에 보낸 모델(무료 계정은 요청과 다를 수 있다). */
export const MODEL_HEADER = "ember-model";

/** 결제한 적 없는 계정(무료 크레딧만 쓰는 계정)은 이 모델 요청을 오른쪽 모델로 바꿔 보낸다. */
export const FREE_TIER_MODEL_MAP: Readonly<Partial<Record<AllowedModel, AllowedModel>>> = {
  "claude-opus-5-5": "claude-sonnet-5-5",
};

export function applyFreeTierModel(v: ValidatedRequest, paid: boolean): ValidatedRequest {
  if (paid) return v;
  const to = FREE_TIER_MODEL_MAP[v.model];
  if (to === undefined) return v;
  return { ...v, model: to, body: { ...v.body, model: to } };
}

export async function handleMessages(
  req: Request,
  env: Env,
  cfg: Config,
  ctx: ExecutionContext,
): Promise<Response> {
  const account = await authenticate(env, req);
  if (account.credits <= 0) {
    throw new ApiError(402, "insufficient_credits", "not enough credits, please purchase more");
  }
  await enforceRateLimit(env.DB, `msg:${account.id}`, cfg.messagesLimit, cfg.messagesWindowSeconds, nowSeconds());

  const raw = await readJsonObject(req, cfg.maxBodyBytes);
  // 과금도 바뀐 모델(실제로 보낸 모델) 기준이다.
  const v = applyFreeTierModel(validateMessagesBody(raw, cfg.maxOutputTokens), account.paid);

  if (!env.ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY 가 설정되지 않음");
    throw new ApiError(500, "api_error", "server is not configured");
  }

  const headers = new Headers({
    "content-type": "application/json",
    "x-api-key": env.ANTHROPIC_API_KEY,
    "anthropic-version": req.headers.get("anthropic-version") ?? DEFAULT_ANTHROPIC_VERSION,
  });
  const beta = req.headers.get("anthropic-beta");
  if (beta) headers.set("anthropic-beta", beta);

  let upstream: Response;
  try {
    upstream = await fetch(`${cfg.anthropicBaseUrl}/v1/messages`, {
      method: "POST",
      headers,
      body: JSON.stringify(v.body),
    });
  } catch (err) {
    console.error("업스트림 연결 실패:", err);
    throw new ApiError(502, "api_error", "could not reach the upstream API");
  }

  if (!upstream.ok) return passUpstreamError(upstream, env, account, v, ctx);

  const contentType = upstream.headers.get("content-type") ?? "";
  if (v.stream && contentType.includes("text/event-stream") && upstream.body) {
    return streamResponse(upstream, env, cfg, account, v, ctx);
  }
  return bufferedResponse(upstream, env, cfg, account, v);
}

function copyHeaders(from: Response, v: ValidatedRequest): Headers {
  const out = new Headers();
  for (const name of PASSTHROUGH_HEADERS) {
    const value = from.headers.get(name);
    if (value !== null) out.set(name, value);
  }
  out.set(MODEL_HEADER, v.model);
  return out;
}

/** 업스트림 오류는 비용 0 으로 기록하고 그대로 넘긴다. */
async function passUpstreamError(
  upstream: Response,
  env: Env,
  account: Account,
  v: ValidatedRequest,
  ctx: ExecutionContext,
): Promise<Response> {
  ctx.waitUntil(
    recordUsage(env.DB, {
      accountId: account.id,
      model: v.model,
      status: upstream.status,
      streamed: v.stream,
      usage: emptyUsage(),
      credits: 0,
      estimated: false,
      now: nowSeconds(),
    }).catch((err: unknown) => console.error("사용 기록 실패:", err)),
  );
  // 서버 키 문제(401/403)를 그대로 넘기면 앱이 '기기 토큰이 틀렸다'고 오해하므로 500 으로 바꾼다.
  if (upstream.status === 401 || upstream.status === 403) {
    console.error("업스트림 인증 실패:", upstream.status, await upstream.text().catch(() => ""));
    return errorResponse(500, "api_error", "server upstream credentials are invalid", {
      "x-should-retry": "false",
      [MODEL_HEADER]: v.model,
    });
  }
  return new Response(upstream.body, { status: upstream.status, headers: copyHeaders(upstream, v) });
}

/** 비스트리밍: 본문을 그대로 돌려주고 usage 로 차감한다. */
async function bufferedResponse(
  upstream: Response,
  env: Env,
  cfg: Config,
  account: Account,
  v: ValidatedRequest,
): Promise<Response> {
  const text = await upstream.text();
  const usage = emptyUsage();
  let responseModel: string | undefined;
  try {
    const parsed: unknown = JSON.parse(text);
    if (isRecord(parsed)) {
      applyUsage(usage, parsed["usage"]);
      if (typeof parsed["model"] === "string") responseModel = parsed["model"];
    }
  } catch {
    console.error("업스트림 응답 JSON 파싱 실패");
  }
  const { credits } = computeCredits(v.model, usage, cfg.markup, responseModel);
  // 응답 직후 앱이 잔액을 다시 읽어도 맞도록 차감을 기다린 뒤 응답한다(수 ms).
  await recordUsage(env.DB, {
    accountId: account.id,
    model: responseModel ?? v.model,
    status: upstream.status,
    streamed: false,
    usage,
    credits,
    estimated: false,
    now: nowSeconds(),
  }).catch((err: unknown) => console.error("차감 실패:", err));

  const headers = copyHeaders(upstream, v);
  headers.set(CREDITS_HEADER, String(account.credits - credits));
  return new Response(text, { status: upstream.status, headers });
}

/**
 * 스트리밍: 업스트림 바이트를 바꾸지 않고 그대로 흘려보내며 usage 를 파싱한다.
 * 펌프는 ctx.waitUntil 안에서 돌고, 끝나면(정상 종료·업스트림 오류·앱 연결 끊김 모두) 차감한다.
 * 앱이 중간에 끊으면 업스트림도 취소하고, 출력 토큰은 받은 델타 문자 수로 추정한다.
 */
function streamResponse(
  upstream: Response,
  env: Env,
  cfg: Config,
  account: Account,
  v: ValidatedRequest,
  ctx: ExecutionContext,
): Response {
  const body = upstream.body;
  if (!body) throw new ApiError(502, "api_error", "empty upstream stream");
  const reader = body.getReader();
  const { readable, writable } = new TransformStream<Uint8Array, Uint8Array>();
  const writer = writable.getWriter();
  const parser = new SseUsageParser();

  let clientGone = false;
  // 앱이 연결을 끊으면(응답 스트림 취소) 업스트림이 조용한 동안에도 바로 알아채고 업스트림을 취소한다.
  writer.closed.catch(() => {
    clientGone = true;
    reader.cancel().catch(() => undefined);
  });

  const pump = async (): Promise<void> => {
    let upstreamDone = false;
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) {
          upstreamDone = !clientGone;
          break;
        }
        parser.push(value);
        try {
          await writer.write(value);
        } catch {
          clientGone = true;
          break;
        }
      }
    } catch (err) {
      // 앱이 끊어 업스트림을 취소한 경우의 읽기 오류는 정상 흐름이다.
      if (!clientGone) console.error("업스트림 스트림 읽기 실패:", err);
    }
    if (!upstreamDone) await reader.cancel().catch(() => undefined);

    parser.finish();
    const { usage, estimated } = parser.billableUsage();
    await bill(env, cfg, account, v, usage, parser.result().model, estimated);

    if (clientGone) await writer.abort().catch(() => undefined);
    else await writer.close().catch(() => undefined);
  };
  ctx.waitUntil(pump());

  const headers = copyHeaders(upstream, v);
  headers.set("cache-control", "no-cache");
  return new Response(readable, { status: upstream.status, headers });
}

async function bill(
  env: Env,
  cfg: Config,
  account: Account,
  v: ValidatedRequest,
  usage: Usage,
  responseModel: string | undefined,
  estimated: boolean,
): Promise<void> {
  const { credits } = computeCredits(v.model, usage, cfg.markup, responseModel);
  try {
    await recordUsage(env.DB, {
      accountId: account.id,
      model: responseModel ?? v.model,
      status: 200,
      streamed: true,
      usage,
      credits,
      estimated,
      now: nowSeconds(),
    });
  } catch (err) {
    console.error("스트림 차감 실패:", err);
  }
}
