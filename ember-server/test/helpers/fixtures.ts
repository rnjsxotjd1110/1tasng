// SSE 테스트용 예시 스트림(Anthropic 스트리밍 형식).

export function ev(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

export const TEXT = "안녕하세요 🔥 세계, hello!";

export const SAMPLE_STREAM =
  ev("message_start", {
    type: "message_start",
    message: {
      id: "msg_1",
      type: "message",
      role: "assistant",
      model: "claude-sonnet-5-5",
      content: [],
      stop_reason: null,
      usage: { input_tokens: 1200, cache_creation_input_tokens: 300, cache_read_input_tokens: 5000, output_tokens: 1 },
    },
  }) +
  ev("content_block_start", { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } }) +
  "event: ping\ndata: {\"type\": \"ping\"}\n\n" +
  ": keep-alive comment\n\n" +
  ev("content_block_delta", { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: TEXT } }) +
  ev("content_block_stop", { type: "content_block_stop", index: 0 }) +
  ev("message_delta", {
    type: "message_delta",
    delta: { stop_reason: "end_turn", stop_sequence: null },
    usage: {
      input_tokens: 1200,
      cache_creation_input_tokens: 300,
      cache_read_input_tokens: 5000,
      output_tokens: 842,
      server_tool_use: { web_search_requests: 2 },
    },
  }) +
  ev("message_stop", { type: "message_stop" });
