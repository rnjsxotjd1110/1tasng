import { describe, expect, it } from "vitest";
import { ApiError } from "../src/http";
import { filterBetas, validateAnthropicVersion, validateMessagesBody, WEB_SEARCH_MAX_USES } from "../src/proxy/validate";

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

  it("허용 목록 밖 최상위 필드(mcp_servers·container·speed·service_tier 등)는 400", () => {
    for (const field of ["mcp_servers", "container", "speed", "service_tier", "context_management", "inference_geo", "betas", "foo"]) {
      expect400(() => validateMessagesBody({ ...base, [field]: "x" }, 64000), new RegExp(`${field}: not supported`));
    }
  });

  it("fallbacks 는 문자열 \"default\" 만", () => {
    expect(validateMessagesBody({ ...base, fallbacks: "default" }, 64000).fallbacks).toBe(true);
    expect(validateMessagesBody(base, 64000).fallbacks).toBe(false);
    for (const bad of ["claude-opus-5", ["default"], { model: "x" }, null]) {
      expect400(() => validateMessagesBody({ ...base, fallbacks: bad }, 64000), /fallbacks/);
    }
  });

  it("messages 는 배열이어야 한다", () => {
    expect400(() => validateMessagesBody({ ...base, messages: "hi" }, 64000), /messages/);
  });

  it("web_search max_uses: 없거나 5 보다 크면 5, 이상한 값은 400, 합계를 돌려준다", () => {
    const v = validateMessagesBody(
      { ...base, tools: [{ type: "web_search_20260209", name: "a" }, { type: "web_search_20260209", name: "b", max_uses: 2 }, { type: "web_search_20260209", name: "c", max_uses: 99 }] },
      64000,
    );
    expect((v.body["tools"] as { max_uses: number }[]).map((t) => t.max_uses)).toEqual([WEB_SEARCH_MAX_USES, 2, WEB_SEARCH_MAX_USES]);
    expect(v.webSearchMaxUses).toBe(12);
    expect(validateMessagesBody(base, 64000).webSearchMaxUses).toBe(0);
    expect400(() => validateMessagesBody({ ...base, tools: [{ type: "web_search_20260209", name: "a", max_uses: 0 }] }, 64000), /max_uses/);
    expect400(() => validateMessagesBody({ ...base, tools: [{ type: "web_search_20260209", name: "a", max_uses: "3" }] }, 64000), /max_uses/);
  });

  it("anthropic-version·anthropic-beta 허용 목록", () => {
    expect(validateAnthropicVersion(null)).toBe("2023-06-01");
    expect(validateAnthropicVersion("2023-06-01")).toBe("2023-06-01");
    expect400(() => validateAnthropicVersion("2023-01-01"), /anthropic-version/);
    expect(filterBetas(null)).toBeNull();
    expect(filterBetas("server-side-fallback-2026-07-01")).toBe("server-side-fallback-2026-07-01");
    expect(filterBetas(" interleaved-thinking-2025-05-14 , server-side-fallback-2026-07-01,server-side-fallback-2026-07-01")).toBe(
      "server-side-fallback-2026-07-01",
    );
    expect(filterBetas("context-1m-2025-08-07")).toBeNull();
  });

  it("stream 플래그", () => {
    expect(validateMessagesBody({ ...base, stream: true }, 64000).stream).toBe(true);
    expect(validateMessagesBody(base, 64000).stream).toBe(false);
    expect400(() => validateMessagesBody({ ...base, stream: "yes" }, 64000), /stream/);
  });

  it("허용된 필드(system, thinking, output_config, fallbacks, cache_control 등)는 그대로 둔다", () => {
    const raw = {
      ...base,
      system: "s",
      thinking: { type: "adaptive" },
      output_config: { effort: "high" },
      fallbacks: "default",
      cache_control: { type: "ephemeral" },
      metadata: { user_id: "u" },
      temperature: 1,
      top_p: 0.9,
      top_k: 5,
      stop_sequences: ["x"],
      tool_choice: { type: "auto" },
      stream: false,
    };
    expect(validateMessagesBody(raw, 64000).body).toEqual(raw);
  });
});
