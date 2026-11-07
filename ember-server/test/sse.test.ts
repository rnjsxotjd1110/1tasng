import { describe, expect, it } from "vitest";
import { SseUsageParser } from "../src/proxy/sse";
import { ev, SAMPLE_STREAM, TEXT } from "./helpers/fixtures";

const EXPECTED = {
  inputTokens: 1200,
  outputTokens: 842,
  cacheReadTokens: 5000,
  cacheWrite5mTokens: 300,
  cacheWrite1hTokens: 0,
  webSearchRequests: 2,
};

function parseChunks(chunks: Uint8Array[]): ReturnType<SseUsageParser["finish"]> {
  const p = new SseUsageParser();
  for (const c of chunks) p.push(c);
  return p.finish();
}

describe("SSE usage 파서", () => {
  const bytes = new TextEncoder().encode(SAMPLE_STREAM);

  it("한 번에 받은 스트림에서 usage·모델을 뽑는다", () => {
    const r = parseChunks([bytes]);
    expect(r.usage).toEqual(EXPECTED);
    expect(r.model).toBe("claude-sonnet-5-5");
    expect(r.sawMessageStart && r.sawMessageDelta && r.sawMessageStop).toBe(true);
    expect(r.deltaChars).toBe(TEXT.length);
  });

  it("모든 바이트 위치에서 두 조각으로 나눠도 같다(UTF-8 문자 중간 포함)", () => {
    for (let i = 1; i < bytes.length; i++) {
      const r = parseChunks([bytes.slice(0, i), bytes.slice(i)]);
      expect(r.usage, `split at ${i}`).toEqual(EXPECTED);
      expect(r.deltaChars, `split at ${i}`).toBe(TEXT.length);
    }
  });

  it("1바이트씩 받아도 같다", () => {
    const chunks = Array.from(bytes, (b) => new Uint8Array([b]));
    expect(parseChunks(chunks).usage).toEqual(EXPECTED);
  });

  it("무작위 크기 조각", () => {
    let seed = 42;
    const rand = (): number => (seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31;
    for (let round = 0; round < 50; round++) {
      const chunks: Uint8Array[] = [];
      for (let i = 0; i < bytes.length; ) {
        const n = 1 + Math.floor(rand() * 40);
        chunks.push(bytes.slice(i, i + n));
        i += n;
      }
      expect(parseChunks(chunks).usage).toEqual(EXPECTED);
    }
  });

  it("CRLF 줄바꿈과 마지막 빈 줄 없는 끝도 처리한다", () => {
    const crlf = SAMPLE_STREAM.replace(/\n/g, "\r\n").replace(/\r\n\r\n$/, "");
    const r = parseChunks([new TextEncoder().encode(crlf)]);
    expect(r.usage).toEqual(EXPECTED);
    expect(r.sawMessageStop).toBe(true);
  });

  it("message_delta 전에 끊기면 입력 usage 와 받은 델타 문자 수가 남는다(중단 과금 재료)", () => {
    const cut = SAMPLE_STREAM.slice(0, SAMPLE_STREAM.indexOf("event: message_delta"));
    const p = new SseUsageParser();
    p.push(new TextEncoder().encode(cut));
    const r = p.finish();
    expect(r.sawMessageStart).toBe(true);
    expect(r.sawMessageDelta).toBe(false);
    expect(r.usage.inputTokens).toBe(1200);
    expect(r.deltaChars).toBe(TEXT.length);
  });

  it("message_start 이전 오류면 usage 는 비어 있다", () => {
    const p = new SseUsageParser();
    p.push(new TextEncoder().encode(ev("error", { type: "error", error: { type: "overloaded_error", message: "x" } })));
    const r = p.finish();
    expect(r.sawError).toBe(true);
    expect(r.sawMessageStart).toBe(false);
    expect(r.usage).toEqual({ ...EXPECTED, inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWrite5mTokens: 0, webSearchRequests: 0 });
  });

  it("여러 줄 data 와 깨진 JSON 은 무시하고 계속한다", () => {
    const s = "event: junk\ndata: {not json\n\n" + SAMPLE_STREAM;
    expect(parseChunks([new TextEncoder().encode(s)]).usage).toEqual(EXPECTED);
  });
});
