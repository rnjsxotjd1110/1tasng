import { afterEach, describe, expect, it, vi } from "vitest";
import { call, errorBody, makeEnv, register, setCredits, type TestEnv } from "./helpers/env";
import { SAMPLE_STREAM } from "./helpers/fixtures";

const BODY = {
  model: "claude-opus-5-5",
  max_tokens: 200_000,
  messages: [{ role: "user", content: "안녕" }],
};

const MESSAGE = {
  id: "msg_1",
  type: "message",
  role: "assistant",
  model: "claude-opus-5-5",
  content: [{ type: "text", text: "안녕하세요" }],
  stop_reason: "end_turn",
  usage: { input_tokens: 1000, output_tokens: 500 }, // $0.014 → 3 크레딧
};

interface Captured {
  url: string;
  headers: Headers;
  body: Record<string, unknown>;
}

function stubUpstream(respond: () => Response): Captured[] {
  const calls: Captured[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const req = new Request(input, init);
      calls.push({ url: req.url, headers: req.headers, body: (await req.json()) as Record<string, unknown> });
      return respond();
    }),
  );
  return calls;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

async function send(env: TestEnv, token: string, body: unknown = BODY, extraHeaders: Record<string, string> = {}) {
  return call(env, "/v1/messages", {
    method: "POST",
    json: body,
    headers: { "x-api-key": token, "anthropic-version": "2023-06-01", ...extraHeaders },
  });
}

function balance(env: TestEnv): number {
  return env.db.rows<{ credits: number }>("SELECT credits FROM accounts")[0]!.credits;
}

describe("POST /v1/messages", () => {
  it("모르는 토큰은 401 authentication_error", async () => {
    const env = makeEnv();
    const calls = stubUpstream(() => new Response("{}"));
    const { res } = await send(env, "nope");
    expect(res.status).toBe(401);
    expect(await errorBody(res)).toEqual({
      type: "error",
      error: { type: "authentication_error", message: "invalid x-api-key" },
    });
    expect(calls).toHaveLength(0);
  });

  it("크레딧이 0 이하면 402 insufficient_credits (Anthropic 오류 형식)", async () => {
    const env = makeEnv();
    const calls = stubUpstream(() => new Response("{}"));
    const { token } = await register(env);
    for (const credits of [0, -3]) {
      await setCredits(env, token, credits);
      const { res } = await send(env, token);
      expect(res.status).toBe(402);
      expect(res.headers.get("content-type")).toContain("application/json");
      const body = await errorBody(res);
      expect(body.type).toBe("error");
      expect(body.error.type).toBe("insufficient_credits");
      expect(typeof body.error.message).toBe("string");
    }
    expect(calls).toHaveLength(0);
  });

  it("비스트리밍: 키를 바꿔 전달하고 응답을 그대로 돌려주며 원자적으로 차감한다", async () => {
    const env = makeEnv();
    const upstreamText = JSON.stringify(MESSAGE);
    const calls = stubUpstream(
      () => new Response(upstreamText, { status: 200, headers: { "content-type": "application/json", "request-id": "req_123", "anthropic-organization-id": "org-secret" } }),
    );
    const { token } = await register(env);
    const { res } = await send(env, token, BODY, { "anthropic-beta": "server-side-fallback-2026-07-01" });

    expect(res.status).toBe(200);
    expect(await res.text()).toBe(upstreamText);
    expect(res.headers.get("request-id")).toBe("req_123");
    expect(res.headers.get("anthropic-organization-id")).toBeNull();
    expect(res.headers.get("ember-credits-remaining")).toBe("97");

    expect(calls).toHaveLength(1);
    const c = calls[0]!;
    expect(c.url).toBe("https://api.anthropic.com/v1/messages");
    expect(c.headers.get("x-api-key")).toBe("sk-ant-test-server-key");
    expect(c.headers.get("anthropic-version")).toBe("2023-06-01");
    expect(c.headers.get("anthropic-beta")).toBe("server-side-fallback-2026-07-01");
    expect(c.body["max_tokens"]).toBe(64000); // 상한으로 잘림
    expect(c.body["messages"]).toEqual(BODY.messages);

    expect(balance(env)).toBe(97);
    const log = env.db.rows("SELECT model, status, input_tokens, output_tokens, credits, streamed FROM usage_log");
    expect(log).toEqual([{ model: "claude-opus-5-5", status: 200, input_tokens: 1000, output_tokens: 500, credits: 3, streamed: 0 }]);
  });

  it("마지막 요청으로 잔액이 음수가 될 수 있다", async () => {
    const env = makeEnv();
    stubUpstream(() => new Response(JSON.stringify(MESSAGE), { headers: { "content-type": "application/json" } }));
    const { token } = await register(env);
    await setCredits(env, token, 1);
    expect((await send(env, token)).res.status).toBe(200);
    expect(balance(env)).toBe(-2);
    expect((await send(env, token)).res.status).toBe(402);
  });

  it("업스트림 오류는 그대로 넘기고 비용 0", async () => {
    const env = makeEnv();
    const err = JSON.stringify({ type: "error", error: { type: "overloaded_error", message: "Overloaded" } });
    stubUpstream(() => new Response(err, { status: 529, headers: { "content-type": "application/json", "x-should-retry": "true" } }));
    const { token } = await register(env);
    const { res, ctx } = await send(env, token);
    expect(res.status).toBe(529);
    expect(await res.text()).toBe(err);
    expect(res.headers.get("x-should-retry")).toBe("true");
    await ctx.settle();
    expect(balance(env)).toBe(100);
    expect(env.db.rows("SELECT status, credits FROM usage_log")).toEqual([{ status: 529, credits: 0 }]);
  });

  it("업스트림 401(서버 키 문제)은 앱 토큰 문제로 보이지 않게 500 으로 바꾼다", async () => {
    const env = makeEnv();
    stubUpstream(() => new Response(JSON.stringify({ type: "error", error: { type: "authentication_error", message: "invalid x-api-key" } }), { status: 401 }));
    const { token } = await register(env);
    const { res } = await send(env, token);
    expect(res.status).toBe(500);
    expect((await errorBody(res)).error.type).toBe("api_error");
    expect(res.headers.get("x-should-retry")).toBe("false");
  });

  it("허용되지 않은 모델·도구는 400 이고 업스트림을 부르지 않는다", async () => {
    const env = makeEnv();
    const calls = stubUpstream(() => new Response("{}"));
    const { token } = await register(env);
    const r1 = await send(env, token, { ...BODY, model: "claude-fable-5-1" });
    expect(r1.res.status).toBe(400);
    const r2 = await send(env, token, { ...BODY, tools: [{ name: "calc", input_schema: { type: "object" } }] });
    expect(r2.res.status).toBe(400);
    expect((await errorBody(r2.res)).error.message).toMatch(/web_search/);
    expect(calls).toHaveLength(0);
  });

  it("본문이 MAX_BODY_BYTES 를 넘으면 413 request_too_large", async () => {
    const env = makeEnv({ MAX_BODY_BYTES: "4096" });
    const calls = stubUpstream(() => new Response("{}"));
    const { token } = await register(env);
    const { res } = await send(env, token, { ...BODY, messages: [{ role: "user", content: "x".repeat(5000) }] });
    expect(res.status).toBe(413);
    expect((await errorBody(res)).error.type).toBe("request_too_large");
    expect(calls).toHaveLength(0);
  });

  it("토큰당 요청 수 제한(429 rate_limit_error)", async () => {
    const env = makeEnv({ MESSAGES_LIMIT: "2" });
    stubUpstream(() => new Response(JSON.stringify(MESSAGE), { headers: { "content-type": "application/json" } }));
    const { token } = await register(env);
    expect((await send(env, token)).res.status).toBe(200);
    expect((await send(env, token)).res.status).toBe(200);
    const { res } = await send(env, token);
    expect(res.status).toBe(429);
    expect((await errorBody(res)).error.type).toBe("rate_limit_error");
  });

  it("스트리밍: 바이트를 바꾸지 않고 통과시키고, 끝나면 usage 로 차감한다", async () => {
    const env = makeEnv();
    const bytes = new TextEncoder().encode(SAMPLE_STREAM);
    stubUpstream(() => {
      // 일부러 UTF-8 문자 중간에서 자른 작은 조각으로 보낸다
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          for (let i = 0; i < bytes.length; i += 7) controller.enqueue(bytes.slice(i, i + 7));
          controller.close();
        },
      });
      return new Response(stream, { headers: { "content-type": "text/event-stream; charset=utf-8", "request-id": "req_s" } });
    });
    const { token } = await register(env);
    const { res, ctx } = await send(env, token, { ...BODY, model: "claude-sonnet-5-5", stream: true });
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("text/event-stream");
    expect(res.headers.get("request-id")).toBe("req_s");
    expect(await res.text()).toBe(SAMPLE_STREAM);
    await ctx.settle();

    // sonnet: (1200×2 + 300×2×1.25 + 5000×0.2 + 842×10)/1e6 + 2×0.01 = 0.03257 → ×150 = 4.8855 → 5
    expect(balance(env)).toBe(95);
    expect(env.db.rows("SELECT model, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, web_search_requests, credits, streamed, estimated FROM usage_log")).toEqual([
      { model: "claude-sonnet-5-5", input_tokens: 1200, output_tokens: 842, cache_read_tokens: 5000, cache_write_tokens: 300, web_search_requests: 2, credits: 5, streamed: 1, estimated: 0 },
    ]);
  });

  it("스트리밍 중 앱이 끊으면 업스트림을 취소하고 받은 만큼(추정) 차감한다", async () => {
    const env = makeEnv();
    const head = SAMPLE_STREAM.slice(0, SAMPLE_STREAM.indexOf("event: content_block_stop"));
    let upstreamCancelled = false;
    stubUpstream(() => {
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(head));
          // 이후로는 아무것도 보내지 않고 열어 둔다(생성 중)
        },
        cancel() {
          upstreamCancelled = true;
        },
      });
      return new Response(stream, { headers: { "content-type": "text/event-stream" } });
    });
    const { token } = await register(env);
    const { res, ctx } = await send(env, token, { ...BODY, model: "claude-sonnet-5-5", stream: true });
    const reader = res.body!.getReader();
    const first = await reader.read();
    expect(new TextDecoder().decode(first.value)).toBe(head);
    await reader.cancel(); // 앱이 연결을 끊음(업스트림은 아직 아무것도 더 보내지 않는 중)
    await ctx.settle();

    expect(upstreamCancelled).toBe(true);
    const log = env.db.rows<{ estimated: number; input_tokens: number; output_tokens: number; credits: number }>(
      "SELECT estimated, input_tokens, output_tokens, credits FROM usage_log",
    );
    expect(log).toHaveLength(1);
    expect(log[0]!.estimated).toBe(1);
    expect(log[0]!.input_tokens).toBe(1200);
    expect(log[0]!.credits).toBeGreaterThan(0);
  }, 5000);
});
