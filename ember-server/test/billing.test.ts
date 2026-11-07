// 예약·정산·동시 요청 제한·중단 과금·정산 실패 처리.
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  affordableMaxTokens,
  computeCredits,
  MODEL_PRICES,
  MOST_EXPENSIVE_PRICE,
  planReservation,
  reservationCredits,
} from "../src/billing/pricing";
import { emptyUsage } from "../src/billing/usage";
import { estimateInputTokens, IMAGE_TOKEN_ALLOWANCE, worstCase } from "../src/proxy/reserve";
import { validateMessagesBody } from "../src/proxy/validate";
import { call, errorBody, makeEnv, markPaid, register, setCredits, type TestEnv } from "./helpers/env";
import { ev, SAMPLE_STREAM } from "./helpers/fixtures";

const BODY = { model: "claude-sonnet-5-5", max_tokens: 4000, messages: [{ role: "user", content: "안녕" }] };
const MESSAGE = {
  id: "msg_1",
  type: "message",
  role: "assistant",
  model: "claude-sonnet-5-5",
  content: [{ type: "text", text: "hi" }],
  stop_reason: "end_turn",
  usage: { input_tokens: 1000, output_tokens: 500 }, // sonnet: $0.007 → 2 크레딧
};

afterEach(() => vi.unstubAllGlobals());

function balance(env: TestEnv): number {
  return env.db.rows<{ credits: number }>("SELECT credits FROM accounts")[0]!.credits;
}

function inflight(env: TestEnv): { reserved: number }[] {
  return env.db.rows<{ reserved: number }>("SELECT reserved FROM inflight");
}

async function send(env: TestEnv, token: string, body: unknown = BODY, headers: Record<string, string> = {}) {
  return call(env, "/v1/messages", { method: "POST", json: body, headers: { "x-api-key": token, ...headers } });
}

function expectedReservation(body: Record<string, unknown>): number {
  return reservationCredits(worstCase(validateMessagesBody(body, 64000)).plan, body["max_tokens"] as number, 1.5);
}

/** 업스트림 대역: 응답 전에 콜백(잔액 확인 등)을 부른다. */
function stub(respond: (body: Record<string, unknown>) => Response | Promise<Response>): Record<string, unknown>[] {
  const bodies: Record<string, unknown>[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const req = new Request(input, init);
      const body = (await req.json()) as Record<string, unknown>;
      bodies.push(body);
      return respond(body);
    }),
  );
  return bodies;
}

function sseResponse(text: string, keepOpen = false): { res: Response; cancelled: () => boolean } {
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    start(c) {
      c.enqueue(new TextEncoder().encode(text));
      if (!keepOpen) c.close();
    },
    cancel() {
      cancelled = true;
    },
  });
  return { res: new Response(stream, { headers: { "content-type": "text/event-stream" } }), cancelled: () => cancelled };
}

describe("예약(사전 차감)과 정산", () => {
  it("업스트림을 부르기 전에 최악 비용을 빼 두고, 끝나면 실제 비용만 남기고 돌려준다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const reserve = expectedReservation(BODY);
    let during = -1;
    let inflightDuring: { reserved: number }[] = [];
    stub(() => {
      during = balance(env);
      inflightDuring = inflight(env);
      return Response.json(MESSAGE);
    });
    const { res } = await send(env, token);
    expect(res.status).toBe(200);
    expect(during).toBe(100 - reserve);
    expect(inflightDuring).toEqual([{ reserved: reserve }]);
    expect(balance(env)).toBe(98);
    expect(res.headers.get("ember-credits-remaining")).toBe("98");
    expect(inflight(env)).toEqual([]);
  });

  it("ember-credits-remaining 은 정산 후 DB 잔액(그 사이 다른 변화 포함)", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    stub(() => {
      env.db.sqlite.exec("UPDATE accounts SET credits = credits + 50"); // 동시에 구매가 들어옴
      return Response.json(MESSAGE);
    });
    const { res } = await send(env, token);
    expect(res.headers.get("ember-credits-remaining")).toBe("148");
  });

  it("동시에 여러 요청이 와도 예약 합계가 잔액을 넘지 않는다", async () => {
    const env = makeEnv({ MAX_CONCURRENT_REQUESTS: "10" });
    const { token } = await register(env);
    const reserve = expectedReservation(BODY);
    await setCredits(env, token, reserve * 2 + 1);
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const bodies = stub(async () => {
      await gate;
      return Response.json(MESSAGE);
    });
    const pending = [1, 2, 3, 4].map(() => send(env, token));
    // 대기 중인 요청들이 예약을 마칠 시간을 준다
    await new Promise((r) => setTimeout(r, 20));
    expect(balance(env)).toBeGreaterThanOrEqual(0);
    release();
    const statuses = (await Promise.all(pending)).map((p) => p.res.status).sort();
    // 2개는 전액 예약, 나머지는 남은 1 크레딧으로 1024 토큰도 못 감당 → 402
    expect(statuses).toEqual([200, 200, 402, 402]);
    expect(bodies).toHaveLength(2);
    expect(balance(env)).toBe(reserve * 2 + 1 - 4);
  });

  it("업스트림 오류·연결 실패는 예약액 전부 환불", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    stub(() => Response.json({ type: "error", error: { type: "overloaded_error", message: "x" } }, { status: 529 }));
    expect((await send(env, token)).res.status).toBe(529);
    expect(balance(env)).toBe(100);
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("network down"); }));
    expect((await send(env, token)).res.status).toBe(502);
    expect(balance(env)).toBe(100);
    expect(env.db.rows("SELECT status, credits FROM usage_log ORDER BY id")).toEqual([
      { status: 529, credits: 0 },
      { status: 502, credits: 0 },
    ]);
    expect(inflight(env)).toEqual([]);
  });

  it("비스트리밍 응답에서 usage 를 읽지 못하면 예약액 전체를 청구", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const reserve = expectedReservation(BODY);
    stub(() => new Response("not json", { headers: { "content-type": "application/json" } }));
    expect((await send(env, token)).res.status).toBe(200);
    expect(balance(env)).toBe(100 - reserve);
    expect(env.db.rows("SELECT credits, estimated FROM usage_log")).toEqual([{ credits: reserve, estimated: 1 }]);
  });

  it("thinking.budget_tokens 가 줄인 max_tokens 이상이면 함께 줄인다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    await markPaid(env, token);
    await setCredits(env, token, 30); // Opus 출력 약 1만 토큰
    const bodies = stub(() => Response.json({ ...MESSAGE, model: "claude-opus-5-5" }));
    const body = { ...BODY, model: "claude-opus-5-5", max_tokens: 64000, thinking: { type: "enabled", budget_tokens: 32000 } };
    expect((await send(env, token, body)).res.status).toBe(200);
    const sent = bodies[0]!;
    const max = sent["max_tokens"] as number;
    expect(max).toBeLessThan(32000);
    expect((sent["thinking"] as { budget_tokens: number }).budget_tokens).toBe(max - 1);
  });
});

describe("최악 비용 계산", () => {
  it("이미지 base64 는 바이트 대신 장당 고정 토큰으로 센다", () => {
    const data = "A".repeat(300_000);
    const withImage = {
      messages: [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: "image/jpeg", data } }] }],
    };
    expect(estimateInputTokens(withImage)).toBeLessThan(IMAGE_TOKEN_ALLOWANCE + 100);
    expect(estimateInputTokens(withImage)).toBeGreaterThanOrEqual(IMAGE_TOKEN_ALLOWANCE);
    expect(estimateInputTokens({ messages: [{ role: "user", content: "가".repeat(3000) }] })).toBeGreaterThanOrEqual(3000);
  });

  it("웹 검색 max_uses 와 fallbacks(가장 비싼 단가)를 반영한다", () => {
    const plain = worstCase(validateMessagesBody(BODY, 64000));
    const search = worstCase(validateMessagesBody({ ...BODY, tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 3 }] }, 64000));
    expect(search.plan.fixedUsd).toBeGreaterThan(plain.plan.fixedUsd + 0.03); // 검색 3회 $0.03 + 결과 입력 토큰
    const fb = worstCase(validateMessagesBody({ ...BODY, fallbacks: "default" }, 64000));
    expect(fb.plan.outputUsdPerToken).toBe(MOST_EXPENSIVE_PRICE.output / 1e6);
    expect(plain.plan.outputUsdPerToken).toBe(MODEL_PRICES["claude-sonnet-5-5"]!.output / 1e6);
  });

  it("affordableMaxTokens 는 잔액을 넘지 않는 가장 큰 값", () => {
    const plan = planReservation(MODEL_PRICES["claude-opus-5-5"]!, { inputTokens: 1000, inputMultiplier: 1, webSearches: 0 });
    for (const balance of [1, 7, 100, 12345]) {
      const t = affordableMaxTokens(plan, balance, 1.5);
      if (t > 0) expect(reservationCredits(plan, t, 1.5)).toBeLessThanOrEqual(balance);
      expect(reservationCredits(plan, t + 1, 1.5)).toBeGreaterThan(balance);
    }
    expect(affordableMaxTokens(plan, 0, 1.5)).toBe(0);
  });

  it("단가표에 없는 응답 모델은 가장 비싼 단가로 청구", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    stub(() => Response.json({ ...MESSAGE, model: "claude-mystery-9", usage: { input_tokens: 0, output_tokens: 1000 } }));
    await send(env, token);
    // 가장 비싼 출력 $25/M × 1000 = $0.025 → 3.75 → 4 (요청한 Sonnet 이었다면 2)
    expect(env.db.rows("SELECT model, credits FROM usage_log")).toEqual([{ model: "claude-mystery-9", credits: 4 }]);
    expect(computeCredits("claude-sonnet-5-5", { ...emptyUsage(), outputTokens: 1000 }, 1.5, "claude-mystery-9").credits).toBe(4);
  });
});

describe("계정당 동시 요청 제한", () => {
  it("처리 중 2개면 세 번째는 429, 끝나면 다시 된다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    stub(async () => {
      await gate;
      return Response.json(MESSAGE);
    });
    const a = send(env, token);
    const b = send(env, token);
    await new Promise((r) => setTimeout(r, 20));
    const c = await send(env, token);
    expect(c.res.status).toBe(429);
    expect((await errorBody(c.res)).error.type).toBe("rate_limit_error");
    release();
    expect((await a).res.status).toBe(200);
    expect((await b).res.status).toBe(200);
    expect(inflight(env)).toEqual([]);
    expect((await send(env, token)).res.status).toBe(200);
  });

  it("402·400·업스트림 오류·스트림 중단 후에도 칸을 놓는다", async () => {
    const env = makeEnv({ MAX_CONCURRENT_REQUESTS: "1" });
    const { token } = await register(env);
    await setCredits(env, token, 1);
    stub(() => Response.json(MESSAGE));
    expect((await send(env, token, { ...BODY, max_tokens: 64000 })).res.status).toBe(402);
    expect(inflight(env)).toEqual([]);
    await setCredits(env, token, 100);
    expect((await send(env, token, { ...BODY, bogus: 1 })).res.status).toBe(400);
    stub(() => new Response("{}", { status: 500 }));
    expect((await send(env, token)).res.status).toBe(500);
    expect(inflight(env)).toEqual([]);

    const head = SAMPLE_STREAM.slice(0, SAMPLE_STREAM.indexOf("event: content_block_stop"));
    stub(() => sseResponse(head, true).res);
    const { res, ctx } = await send(env, token, { ...BODY, stream: true });
    const reader = res.body!.getReader();
    await reader.read();
    expect(inflight(env)).toHaveLength(1);
    await reader.cancel();
    await ctx.settle();
    expect(inflight(env)).toEqual([]);
  });

  it("오래된(stale) 처리 중 표시는 세지 않는다", async () => {
    const env = makeEnv({ MAX_CONCURRENT_REQUESTS: "1", INFLIGHT_STALE_SECONDS: "60" });
    const { token } = await register(env);
    env.db.sqlite.exec(`INSERT INTO inflight (account_id, reserved, started_at) VALUES (1, 5, ${Math.floor(Date.now() / 1000) - 3600})`);
    stub(() => Response.json(MESSAGE));
    expect((await send(env, token)).res.status).toBe(200);
    expect(inflight(env)).toEqual([]);
  });
});

describe("스트림 중단 과금", () => {
  it("최종 usage 없이 업스트림이 끝나면 예약액 전체를 청구", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const reserve = expectedReservation({ ...BODY, stream: true });
    const head = SAMPLE_STREAM.slice(0, SAMPLE_STREAM.indexOf("event: message_delta"));
    stub(() => sseResponse(head).res);
    const { res, ctx } = await send(env, token, { ...BODY, stream: true });
    expect(await res.text()).toBe(head);
    await ctx.settle();
    expect(balance(env)).toBe(100 - reserve);
    expect(env.db.rows("SELECT credits, estimated FROM usage_log")).toEqual([{ credits: reserve, estimated: 1 }]);
  });

  it("화면에 안 보이는 사고(display omitted)·웹 검색 중에 끊어도 예약액 전체(max_tokens·max_uses 기준)를 청구", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const body = {
      ...BODY,
      stream: true,
      thinking: { type: "adaptive", display: "omitted" },
      tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 5 }],
    };
    const reserve = expectedReservation(body);
    const head =
      ev("message_start", { type: "message_start", message: { model: "claude-sonnet-5-5", usage: { input_tokens: 10, output_tokens: 1 } } }) +
      ev("content_block_start", { type: "content_block_start", index: 0, content_block: { type: "thinking", thinking: "" } });
    stub(() => sseResponse(head, true).res);
    const { res, ctx } = await send(env, token, body);
    const reader = res.body!.getReader();
    await reader.read();
    await reader.cancel();
    await ctx.settle();
    expect(reserve).toBeGreaterThan(3); // 검색 5회만 해도 $0.05 → 8 크레딧 이상
    expect(balance(env)).toBe(100 - reserve);
  });

  it("최종 usage 를 받은 뒤 끊긴 경우는 실제 비용", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const head = SAMPLE_STREAM.slice(0, SAMPLE_STREAM.indexOf("event: message_stop"));
    stub(() => sseResponse(head).res);
    const { res, ctx } = await send(env, token, { ...BODY, stream: true });
    await res.text();
    await ctx.settle();
    expect(balance(env)).toBe(95); // messages.test 의 SAMPLE_STREAM 요금
  });

  it("message_start 전에 error 이벤트로 끝나면 비용 0", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const text = ev("error", { type: "error", error: { type: "overloaded_error", message: "Overloaded" } });
    stub(() => sseResponse(text).res);
    const { res, ctx } = await send(env, token, { ...BODY, stream: true });
    await res.text();
    await ctx.settle();
    expect(balance(env)).toBe(100);
  });
});

describe("정산 실패", () => {
  function failSettlement(env: TestEnv, times: number): { failures: number } {
    const state = { failures: 0 };
    const original = env.db.batch.bind(env.db);
    env.db.batch = (async (stmts: Parameters<typeof original>[0]) => {
      if (state.failures < times && stmts.some((s) => s.sql.includes("INSERT INTO usage_log"))) {
        state.failures++;
        throw new Error("D1 unavailable");
      }
      return original(stmts);
    }) as typeof env.db.batch;
    return state;
  }

  it("한 번 실패하면 다시 시도해 정상 정산", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const state = failSettlement(env, 1);
    stub(() => Response.json(MESSAGE));
    const { res } = await send(env, token);
    expect(res.status).toBe(200);
    expect(state.failures).toBe(1);
    expect(balance(env)).toBe(98);
    expect(env.db.rows("SELECT disabled FROM accounts")).toEqual([{ disabled: 0 }]);
  });

  it("두 번 다 실패하면 예약액을 그대로 두고 계정을 막는다(disabled = 2)", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const reserve = expectedReservation(BODY);
    failSettlement(env, 2);
    const errors = vi.spyOn(console, "error").mockImplementation(() => undefined);
    stub(() => Response.json(MESSAGE));
    const { res } = await send(env, token);
    expect(res.status).toBe(200);
    expect(res.headers.get("ember-credits-remaining")).toBeNull();
    expect(balance(env)).toBe(100 - reserve); // 무료 사용 없음
    expect(env.db.rows("SELECT disabled FROM accounts")).toEqual([{ disabled: 2 }]);
    expect(errors.mock.calls.some((c) => String(c[0]).includes("정산 실패"))).toBe(true);
    errors.mockRestore();
    const next = await send(env, token);
    expect(next.res.status).toBe(403);
    expect((await errorBody(next.res)).error.message).toMatch(/billing reconciliation/);
  });
});

describe("요청 헤더·필드 허용 목록", () => {
  it("anthropic-version 은 허용 목록만, 없으면 기본값", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const bodies: Headers[] = [];
    vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      bodies.push(new Request(input, init).headers);
      return Response.json(MESSAGE);
    }));
    expect((await send(env, token, BODY, { "anthropic-version": "2099-01-01" })).res.status).toBe(400);
    expect((await send(env, token)).res.status).toBe(200);
    expect(bodies[0]!.get("anthropic-version")).toBe("2023-06-01");
    expect(bodies[0]!.get("anthropic-beta")).toBeNull();
    await send(env, token, BODY, { "anthropic-beta": "context-1m-2025-08-07, files-api-2025-04-14" });
    expect(bodies[1]!.get("anthropic-beta")).toBeNull(); // 허용되지 않은 베타는 전부 뺀다
  });

  it("허용 목록 밖 최상위 필드는 400 이고 업스트림을 부르지 않는다", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const bodies = stub(() => Response.json(MESSAGE));
    for (const extra of [{ service_tier: "auto" }, { context_management: {} }, { speed: "fast" }, { fallbacks: ["claude-opus-5"] }]) {
      const { res } = await send(env, token, { ...BODY, ...extra });
      expect(res.status, JSON.stringify(extra)).toBe(400);
    }
    expect(bodies).toHaveLength(0);
    expect(balance(env)).toBe(100);
  });

  it("웹 검색 max_uses 는 5 이하로 강제", async () => {
    const env = makeEnv();
    const { token } = await register(env);
    const bodies = stub(() => Response.json(MESSAGE));
    await send(env, token, { ...BODY, tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 50 }, { type: "web_search_20260209", name: "web_search2" }] });
    expect((bodies[0]!["tools"] as { max_uses: number }[]).map((t) => t.max_uses)).toEqual([5, 5]);
  });
});
