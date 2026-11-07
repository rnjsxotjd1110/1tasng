// POST /v1/messages: 인증·요청 제한·검증 → 동시 처리 칸 확보 → 최악의 비용 예약 → Anthropic 으로 전달 → 실제 비용으로 정산.
import { authenticate, type Account } from "../auth";
import { settleUsage } from "../billing/ledger";
import { computeCredits } from "../billing/pricing";
import { applyUsage, emptyUsage, type Usage } from "../billing/usage";
import type { Config, Env } from "../env";
import { ApiError, errorResponse, isRecord, readJsonObject } from "../http";
import type { AllowedModel } from "../models";
import { enforceRateLimit } from "../ratelimit";
import { nowSeconds } from "../util";
import { acquireSlot, releaseSlot, reserveForRequest, setSlotReserved } from "./reserve";
import { SseUsageParser } from "./sse";
import { filterBetas, validateAnthropicVersion, validateMessagesBody, type ValidatedRequest } from "./validate";

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

/** 처리 중인 요청 하나의 상태(칸·예약액). */
interface Flight {
  env: Env;
  cfg: Config;
  account: Account;
  v: ValidatedRequest;
  slotId: number;
  reserved: number;
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
  const beta = filterBetas(req.headers.get("anthropic-beta"));

  if (!env.ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY 가 설정되지 않음");
    throw new ApiError(500, "api_error", "server is not configured");
  }

  const slotId = await acquireSlot(env.DB, account.id, cfg.maxConcurrentRequests, cfg.inflightStaleSeconds, nowSeconds());
  // 스트리밍 응답을 넘기면 칸 해제·정산은 펌프가 맡는다. 그 전의 모든 경로(오류 포함)는 여기서 해제한다.
  let handedOff = false;
  try {
    const reservation = await reserveForRequest(env.DB, account.id, validated, cfg.markup, nowSeconds());
    const f: Flight = { env, cfg, account, v: reservation.request, slotId, reserved: reservation.credits };
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
    estimated: o.estimated,
    now: nowSeconds(),
  });
}

/** 업스트림 오류는 비용 0 으로 정산(예약액 전부 환불)하고 그대로 넘긴다. */
async function passUpstreamError(upstream: Response, f: Flight): Promise<Response> {
  await settle(f, { status: upstream.status, streamed: f.v.stream, usage: emptyUsage(), credits: 0, estimated: false });
  // 서버 키 문제(401/403)를 그대로 넘기면 앱이 '기기 토큰이 틀렸다'고 오해하므로 500 으로 바꾼다.
  if (upstream.status === 401 || upstream.status === 403) {
    console.error("업스트림 인증 실패:", upstream.status, await upstream.text().catch(() => ""));
    return errorResponse(500, "api_error", "server upstream credentials are invalid", {
      "x-should-retry": "false",
      [MODEL_HEADER]: f.v.model,
    });
  }
  return new Response(upstream.body, { status: upstream.status, headers: copyHeaders(upstream, f.v) });
}

/**
 * 비스트리밍: 본문을 그대로 돌려주고 usage 로 정산한다.
 * usage 를 읽지 못하면(본문 읽기·파싱 실패) 예약액 전체를 청구한다.
 */
async function bufferedResponse(upstream: Response, f: Flight): Promise<Response> {
  let text: string;
  try {
    text = await upstream.text();
  } catch (err) {
    console.error("업스트림 본문 읽기 실패:", err);
    await settle(f, { status: 502, streamed: false, usage: emptyUsage(), credits: f.reserved, estimated: true });
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
  const credits = sawUsage ? computeCredits(f.v.model, usage, f.cfg.markup, responseModel).credits : f.reserved;
  // 응답 직후 앱이 잔액을 다시 읽어도 맞도록 정산을 기다린 뒤 응답한다(수 ms).
  const balance = await settle(f, {
    status: upstream.status,
    streamed: false,
    usage,
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
 * - 최종 usage(message_delta)를 받았으면 실제 비용으로 정산.
 * - 못 받았으면(앱이 끊음, 업스트림이 끊김, 중간 error 이벤트) 예약액 전체를 청구한다. 화면에 안 보이는
 *   사고(thinking) 토큰·웹 검색도 예약액(max_tokens·max_uses 기준)에 들어 있으므로 빠져나가지 못한다.
 * - message_start 전에 error 이벤트로 끝났으면 생성이 없었으므로 비용 0.
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

  const pump = async (): Promise<void> => {
    try {
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

      const r = parser.finish();
      let credits: number;
      let estimated = false;
      if (r.sawMessageDelta && !r.sawError) {
        credits = computeCredits(f.v.model, r.usage, f.cfg.markup, r.model).credits;
      } else if (r.sawError && !r.sawMessageStart) {
        credits = 0;
      } else {
        credits = f.reserved;
        estimated = true;
      }
      await settle(f, { status: 200, streamed: true, usage: r.usage, credits, estimated, model: r.model });

      if (clientGone) await writer.abort().catch(() => undefined);
      else await writer.close().catch(() => undefined);
    } catch (err) {
      // 여기까지 오면 정산 전의 예기치 못한 오류: 예약액은 이미 빠져 있으므로(보수적) 기록만 남긴다.
      console.error("스트림 처리 오류:", err);
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
