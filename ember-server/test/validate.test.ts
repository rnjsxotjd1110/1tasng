import { describe, expect, it } from "vitest";
import { ApiError } from "../src/http";
import { validateMessagesBody } from "../src/proxy/validate";

const base = { model: "claude-sonnet-5-5", max_tokens: 1000, messages: [{ role: "user", content: "hi" }] };

function expect400(fn: () => unknown, msg: RegExp): void {
  try {
    fn();
  } catch (err) {
    expect(err).toBeInstanceOf(ApiError);
    const e = err as ApiError;
    expect(e.status).toBe(400);
    expect(e.type).toBe("invalid_request_error");
    expect(e.message).toMatch(msg);
    return;
  }
  throw new Error("expected ApiError");
}

describe("요청 검증", () => {
  it("허용 모델 3개는 통과", () => {
    for (const model of ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]) {
      expect(validateMessagesBody({ ...base, model }, 64000).model).toBe(model);
    }
  });

  it("허용 목록 밖 모델은 400", () => {
    expect400(() => validateMessagesBody({ ...base, model: "claude-fable-5-1" }, 64000), /model must be one of/);
    expect400(() => validateMessagesBody({ ...base, model: 5 }, 64000), /model/);
    expect400(() => validateMessagesBody({ ...base, model: undefined }, 64000), /model/);
  });

  it("max_tokens 상한으로 자르고 원본 객체는 건드리지 않는다", () => {
    const raw = { ...base, max_tokens: 128000 };
    const v = validateMessagesBody(raw, 64000);
    expect(v.body["max_tokens"]).toBe(64000);
    expect(v.clamped).toBe(true);
    expect(raw.max_tokens).toBe(128000);
    expect(validateMessagesBody({ ...base, max_tokens: 500 }, 64000).body["max_tokens"]).toBe(500);
  });

  it("max_tokens 가 없거나 이상하면 400", () => {
    for (const bad of [undefined, 0, -1, 1.5, "100"]) {
      expect400(() => validateMessagesBody({ ...base, max_tokens: bad }, 64000), /max_tokens/);
    }
  });

  it("web_search_* 도구만 허용", () => {
    const ok = validateMessagesBody(
      { ...base, tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 5 }] },
      64000,
    );
    expect(ok.body["tools"]).toHaveLength(1);
    expect(validateMessagesBody({ ...base, tools: [] }, 64000).body["tools"]).toEqual([]);
  });

  it("다른 도구가 하나라도 있으면 400", () => {
    expect400(
      () =>
        validateMessagesBody(
          { ...base, tools: [{ type: "web_search_20260209", name: "web_search" }, { name: "my_tool", input_schema: {} }] },
          64000,
        ),
      /tools\.1: only web_search/,
    );
    expect400(() => validateMessagesBody({ ...base, tools: [{ type: "code_execution_20260521", name: "code_execution" }] }, 64000), /only web_search/);
    expect400(() => validateMessagesBody({ ...base, tools: [{ type: "web_fetch_20260209", name: "web_fetch" }] }, 64000), /only web_search/);
    expect400(() => validateMessagesBody({ ...base, tools: "web_search" }, 64000), /must be an array/);
  });

  it("mcp_servers·container·fast 모드는 400", () => {
    expect400(() => validateMessagesBody({ ...base, mcp_servers: [] }, 64000), /mcp_servers/);
    expect400(() => validateMessagesBody({ ...base, container: "x" }, 64000), /container/);
    expect400(() => validateMessagesBody({ ...base, speed: "fast" }, 64000), /speed/);
    expect(validateMessagesBody({ ...base, speed: "standard" }, 64000).model).toBe("claude-sonnet-5-5");
  });

  it("stream 플래그", () => {
    expect(validateMessagesBody({ ...base, stream: true }, 64000).stream).toBe(true);
    expect(validateMessagesBody(base, 64000).stream).toBe(false);
    expect400(() => validateMessagesBody({ ...base, stream: "yes" }, 64000), /stream/);
  });

  it("다른 필드(system, thinking, fallbacks 등)는 그대로 둔다", () => {
    const raw = { ...base, system: "s", thinking: { type: "adaptive" }, fallbacks: "default", cache_control: { type: "ephemeral" } };
    expect(validateMessagesBody(raw, 64000).body).toEqual(raw);
  });
});
