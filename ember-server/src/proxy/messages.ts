// POST /v1/messages: 인증·요청 제한·검증 → 동시 처리 칸 확보 → 최악의 비용 예약 → Anthropic 으로 전달 → 실제 비용으로 정산.
import { authenticate, type Account } from "../auth";
import { interruptedCharge, type StreamEnd } from "../billing/interrupted";
import { settleUsage } from "../billing/ledger";
import { computeCredits } from "../billing/pricing";
import { applyUsage, emptyUsage, type Usage } from "../billing/usage";
import type { Config, Env } from "../env";
import { ApiError, errorResponse, isRecord, readJsonObject } from "../http";
import type { AllowedModel } from "../models";
import { enforceRateLimit } from "../ratelimit";
import { nowSeconds } from "../util";
import { acquireSlot, estimateInputTokens, releaseSlot, reserveForRequest, setSlotReserved } from "./reserve";
import { SseUsageParser } from "./sse";
import { filterBetas, validateAnthropicVersion, validateMessagesBody, type ValidatedRequest } from "./validate";

/** 업스트림 응답에서 앱으로 넘겨 주는 헤더(조직 정보 등은 숨긴다). */
const PASSTHROUGH_HEADERS = ["content-type", "request-id", "retry-after", "x-should-retry"] as const;
export const CREDITS_HEADER = "ember-credits-remaining";
/** 실제로 업스트림에 보낸 모델(무료 계정은 요청과 다를 수 있다). */
export const MODEL_HEADER = "ember-model";

/** 결제한 적 없는 계정(무료 크레딧만 쓰는 계정)이 보낸 요청은 어떤 모델이든 이 모델로 바꿔 보낸다. */
export const FREE_TIER_MODEL: AllowedModel = "claude-haiku-5-5";

/**
 * 무료 계정 요청을 [FREE_TIER_MODEL] 로 바꾼다. Haiku 5.5 는 웹 검색(web_search_20260209)과
 * 서버측 거절 대체(fallbacks)를 받지 않으므로 둘을 함께 뺀다(남겨 두면 업스트림이 400 을 낸다).
 */
export function applyFreeTierModel(v: ValidatedRequest, paid: boolean): ValidatedRequest {
  if (paid || v.model === FREE_TIER_MODEL) return v;
  const body: Record<string, unknown> = { ...v.body, model: FREE_TIER_MODEL };
  delete body["tools"];
  delete body["tool_choice"];
  delete body["fallbacks"];
  return { ...v, model: FREE_TIER_MODEL, body, webSearchMaxUses: 0, fallbacks: false };
}

/** 처리 중인 요청 하나의 상태(칸·예약액). */
interface Flight {
  env: Env;
  cfg: Config;
  account: Account;
  v: ValidatedRequest;
  slotId: number;
  reserved: number;
  /** 예약액 중 유료 묶음에서 뺀 양 */
  paidDrawn: number;
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
  const validated = applyFreeTierModel(validateMessagesBody(raw, cfg.maxOutputTokens), account.paid);
  const version = validateAnthropicVersion(req.headers.get("anthropic-version"));
  // 허용 베타는 서버측 거절 대체뿐이고 무료 계정은 그 기능을 뺀 Haiku 로 보내므로, 무료 계정에는 베타 헤더를 붙이지 않는다.
  const beta = account.paid ? filterBetas(req.headers.get("anthropic-beta")) : null;

  if (!env.ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY 가 설정되지 않음");
    throw new ApiError(500, "api_error", "server is not configured");
  }

  const slotId = await acquireSlot(env.DB, account.id, cfg.maxConcurrentRequests, cfg.inflightStaleSeconds, nowSeconds());
  // 스트리밍 응답을 넘기면 칸 해제·정산은 펌프가 맡는다. 그 전의 모든 경로(오류 포함)는 여기서 해제한다.
  let handedOff = false;
  try {
    const reservation = await reserveForRequest(env.DB, account.id, validated, cfg.markup, nowSeconds());
    const f: Flight = {
      env,
      cfg,
      account,
      v: reservation.request,
      slotId,
      reserved: reservation.credits,
      paidDrawn: reservation.paidDrawn,
    };
    await setSlotReserved(env.DB, slotId, reservation.credits).catch((err: unknown) =>
      console.error("inflight 예약액 기록 실패:", err),
    );

    const headers = new Headers({
      "content-type": "application/json",
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": version,
    });
    if (beta) headers.set("anthropic-beta", beta);

    let upstream: Response;
    try {
      upstream = await fetch(`${cfg.anthropicBaseUrl}/v1/messages`, {
        method: "POST",
        headers,
        body: JSON.stringify(f.v.body),
      });
    } catch (err) {
      console.error("업스트림 연결 실패:", err);
      await settle(f, { status: 502, streamed: f.v.stream, usage: emptyUsage(), credits: 0, estimated: false });
      throw new ApiError(502, "api_error", "could not reach the upstream API");
    }

    if (!upstream.ok) return await passUpstreamError(upstream, f);

    const contentType = upstream.headers.get("content-type") ?? "";
    if (f.v.stream && contentType.includes("text/event-stream") && upstream.body) {
      const res = streamResponse(upstream, f, ctx);
      handedOff = true;
      return res;
    }
    return await bufferedResponse(upstream, f);
  } finally {
    if (!handedOff) await releaseSlot(env.DB, slotId);
  }
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

interface Outcome {
  status: number;
  streamed: boolean;
  usage: Usage;
  credits: number;
  estimated: boolean;
  model?: string;
}

/** 예약액과 실제 비용을 정산한다. 정산 후 잔액(실패하면 null). */
function settle(f: Flight, o: Outcome): Promise<number | null> {
  return settleUsage(f.env.DB, {
    accountId: f.account.id,
    model: o.model ?? f.v.model,
    status: o.status,
    streamed: o.streamed,
    usage: o.usage,
    credits: o.credits,
    reserved: f.reserved,
    paidDrawn: f.paidDrawn,
    estimated: o.estimated,
    now: nowSeconds(),
  });
}

/**
 * 비스트리밍 응답을 끝까지 못 읽었거나 usage 가 없을 때(업스트림 쪽 문제): 입력 처리 비용만 청구한다.
 * 비스트리밍은 message_start 가 없어 입력 토큰을 모르므로, 요청 본문으로 추정한 입력 토큰(실제보다 크게 잡힘)을 쓴다.
 * 예약액을 넘지 않는다.
 */
function inputOnlyEstimate(f: Flight): { usage: Usage; credits: number } {
  const body = { ...f.v.body };
  delete body["max_tokens"];
  const usage = { ...emptyUsage(), inputTokens: estimateInputTokens(body) };
  return { usage, credits: Math.min(f.reserved, computeCredits(f.v.model, usage, f.cfg.markup).credits) };
}

/** Google·Anthropic 오류 응답에서 오류 종류만 뽑는다(본문·메시지는 로그에 남기지 않는다). */
export async function upstreamErrorType(res: Response): Promise<string> {
  const text = await res.text().catch(() => "");
  try {
    const parsed: unknown = JSON.parse(text);
    const err = isRecord(parsed) ? parsed["error"] : undefined;
    const type = isRecord(err) ? (err["type"] ?? err["status"]) : undefined;
    if (typeof type === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(type)) return type;
  } catch {
    // JSON 이 아니면 종류를 모른다.
  }
  return "unknown";
}

/** 업스트림 오류는 비용 0 으로 정산(예약액 전부 환불)하고 그대로 넘긴다. */
async function passUpstreamError(upstream: Response, f: Flight): Promise<Response> {
  await settle(f, { status: upstream.status, streamed: f.v.stream, usage: emptyUsage(), credits: 0, estimated: false });
  // 서버 키 문제(401/403)를 그대로 넘기면 앱이 '기기 토큰이 틀렸다'고 오해하므로 500 으로 바꾼다.
  if (upstream.status === 401 || upstream.status === 403) {
    console.error("업스트림 인증 실패:", upstream.status, await upstreamErrorType(upstream));
    return errorResponse(500, "api_error", "server upstream credentials are invalid", {
      "x-should-retry": "false",
      [MODEL_HEADER]: f.v.model,
    });
  }
  return new Response(upstream.body, { status: upstream.status, headers: copyHeaders(upstream, f.v) });
}

/**
 * 비스트리밍: 본문을 그대로 돌려주고 usage 로 정산한다.
 * usage 를 읽지 못하면(본문 읽기·파싱 실패 = 업스트림 쪽 문제) 입력 처리 비용(추정)만 청구한다.
 */
async function bufferedResponse(upstream: Response, f: Flight): Promise<Response> {
  let text: string;
  try {
    text = await upstream.text();
  } catch (err) {
    console.error("업스트림 본문 읽기 실패:", err);
    const est = inputOnlyEstimate(f);
    await settle(f, { status: 502, streamed: false, usage: est.usage, credits: est.credits, estimated: true });
    throw new ApiError(502, "api_error", "upstream response was interrupted");
  }
  const usage = emptyUsage();
  let responseModel: string | undefined;
  let sawUsage = false;
  try {
    const parsed: unknown = JSON.parse(text);
    if (isRecord(parsed)) {
      sawUsage = isRecord(parsed["usage"]);
      applyUsage(usage, parsed["usage"]);
      if (typeof parsed["model"] === "string") responseModel = parsed["model"];
    }
  } catch {
    console.error("업스트림 응답 JSON 파싱 실패");
  }
  const est = sawUsage ? undefined : inputOnlyEstimate(f);
  const credits = est ? est.credits : computeCredits(f.v.model, usage, f.cfg.markup, responseModel).credits;
  // 응답 직후 앱이 잔액을 다시 읽어도 맞도록 정산을 기다린 뒤 응답한다(수 ms).
  const balance = await settle(f, {
    status: upstream.status,
    streamed: false,
    usage: est ? est.usage : usage,
    credits,
    estimated: !sawUsage,
    model: responseModel,
  });

  const headers = copyHeaders(upstream, f.v);
  if (balance !== null) headers.set(CREDITS_HEADER, String(balance));
  return new Response(text, { status: upstream.status, headers });
}

/**
 * 스트리밍: 업스트림 바이트를 바꾸지 않고 그대로 흘려보내며 usage 를 파싱한다.
 * 펌프는 ctx.waitUntil 안에서 돌고, 끝나면(정상 종료·업스트림 오류·앱 연결 끊김 모두) 정산하고 칸을 놓는다.
 * - 최종 usage(message_delta)를 받았고 오류가 없으면 실제 비용으로 정산.
 * - 그 밖에는 billing/interrupted.ts 의 규칙(이용약관 5장):
 *   · 앱이 중지·연결 끊김: 입력 토큰 + ceil(받은 출력 문자 ÷ 3) × 2 토큰(보이지 않는 생각 포함 추정), 예약액 이하.
 *   · 업스트림 오류(error 이벤트, 업스트림 끊김·최종 usage 없이 끝남)·서버 오류: 입력 토큰만.
 *   · message_start 전에 끝났으면 비용 0.
 */
function streamResponse(upstream: Response, f: Flight, ctx: ExecutionContext): Response {
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

  let settled = false;
  const settleInterrupted = async (end: StreamEnd): Promise<void> => {
    const r = parser.result();
    const charge = interruptedCharge({
      model: f.v.model,
      responseModel: r.model,
      sawMessageStart: r.sawMessageStart,
      usage: r.usage,
      outputChars: r.deltaChars,
      end,
      markup: f.cfg.markup,
      reserved: f.reserved,
    });
    settled = true;
    await settle(f, { status: 200, streamed: true, ...charge, model: r.model });
  };

  const pump = async (): Promise<void> => {
    try {
      let upstreamDone = false;
      let upstreamFailed = false;
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
        if (!clientGone) {
          upstreamFailed = true;
          console.error("업스트림 스트림 읽기 실패:", err);
        }
      }
      if (!upstreamDone) await reader.cancel().catch(() => undefined);

      const r = parser.finish();
      if (r.sawMessageDelta && !r.sawError) {
        const credits = computeCredits(f.v.model, r.usage, f.cfg.markup, r.model).credits;
        settled = true;
        await settle(f, { status: 200, streamed: true, usage: r.usage, credits, estimated: false, model: r.model });
      } else {
        // 업스트림 error 이벤트·업스트림 끊김·최종 usage 없이 정상 종료는 업스트림 쪽 문제, 그 밖(앱이 끊음)은 중단.
        const end: StreamEnd = r.sawError || upstreamFailed || upstreamDone ? "upstream_error" : "client_gone";
        await settleInterrupted(end);
      }

      if (clientGone) await writer.abort().catch(() => undefined);
      else await writer.close().catch(() => undefined);
    } catch (err) {
      // 정산 전의 예기치 못한 서버 오류: 입력 처리 비용만 청구한다(아직 정산하지 않았을 때).
      console.error("스트림 처리 오류:", err);
      if (!settled) await settleInterrupted("server_error").catch(() => undefined);
      await writer.abort().catch(() => undefined);
    } finally {
      await releaseSlot(f.env.DB, f.slotId);
    }
  };
  ctx.waitUntil(pump());

  const headers = copyHeaders(upstream, f.v);
  headers.set("cache-control", "no-cache");
  return new Response(readable, { status: upstream.status, headers });
}
