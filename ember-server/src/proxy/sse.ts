// SSE 스트림을 그대로 통과시키면서 usage 만 뽑아내는 증분 파서.
// 청크 경계가 줄·UTF-8 문자 중간에 걸려도 올바르게 동작한다.
import { applyUsage, emptyUsage, type Usage } from "../billing/usage";
import { isRecord } from "../http";

/** 참고용 출력 토큰 추정(델타 문자 수 / 이 값). 과금에는 쓰지 않는다: 최종 usage 가 없으면 예약액 전체를 청구한다(messages.ts). */
export const CHARS_PER_TOKEN_ESTIMATE = 3;

export interface SseUsageResult {
  usage: Usage;
  /** message_start 의 message.model (대체 모델이면 요청과 다를 수 있다) */
  model?: string;
  sawMessageStart: boolean;
  sawMessageDelta: boolean;
  sawMessageStop: boolean;
  sawError: boolean;
  /** 받은 델타(text/thinking/partial_json) 문자 수 */
  deltaChars: number;
}

export class SseUsageParser {
  private readonly decoder = new TextDecoder();
  private buffer = "";
  private eventName = "";
  private dataLines: string[] = [];
  private readonly state: SseUsageResult = {
    usage: emptyUsage(),
    sawMessageStart: false,
    sawMessageDelta: false,
    sawMessageStop: false,
    sawError: false,
    deltaChars: 0,
  };

  push(chunk: Uint8Array): void {
    this.buffer += this.decoder.decode(chunk, { stream: true });
    this.drainLines();
  }

  /** 스트림 끝: 남은 바이트와 마지막 이벤트(빈 줄 없이 끝난 경우)를 처리한다. */
  finish(): SseUsageResult {
    this.buffer += this.decoder.decode();
    if (this.buffer.length > 0) {
      this.handleLine(this.buffer);
      this.buffer = "";
    }
    this.dispatch();
    return this.result();
  }

  result(): SseUsageResult {
    return { ...this.state, usage: { ...this.state.usage } };
  }

  /**
   * 참고용: message_delta 가 없었으면 출력 토큰을 델타 문자 수로 추정한 usage.
   * 화면에 안 보이는 사고 토큰·웹 검색을 놓치므로 과금에는 쓰지 않는다.
   */
  billableUsage(): { usage: Usage; estimated: boolean } {
    const usage = { ...this.state.usage };
    if (this.state.sawMessageDelta || !this.state.sawMessageStart) return { usage, estimated: false };
    const estimate = Math.ceil(this.state.deltaChars / CHARS_PER_TOKEN_ESTIMATE);
    usage.outputTokens = Math.max(usage.outputTokens, estimate);
    return { usage, estimated: true };
  }

  private drainLines(): void {
    let nl = this.buffer.indexOf("\n");
    while (nl !== -1) {
      this.handleLine(this.buffer.slice(0, nl));
      this.buffer = this.buffer.slice(nl + 1);
      nl = this.buffer.indexOf("\n");
    }
  }

  private handleLine(rawLine: string): void {
    const line = rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
    if (line === "") {
      this.dispatch();
      return;
    }
    if (line.startsWith(":")) return; // 주석
    const colon = line.indexOf(":");
    const field = colon === -1 ? line : line.slice(0, colon);
    let value = colon === -1 ? "" : line.slice(colon + 1);
    if (value.startsWith(" ")) value = value.slice(1);
    if (field === "event") this.eventName = value;
    else if (field === "data") this.dataLines.push(value);
  }

  private dispatch(): void {
    const name = this.eventName;
    const data = this.dataLines.join("\n");
    this.eventName = "";
    this.dataLines = [];
    if (data === "") return;

    let payload: unknown;
    try {
      payload = JSON.parse(data);
    } catch {
      return;
    }
    if (!isRecord(payload)) return;
    const type = typeof payload["type"] === "string" ? payload["type"] : name;

    switch (type) {
      case "message_start": {
        this.state.sawMessageStart = true;
        const message = payload["message"];
        if (isRecord(message)) {
          if (typeof message["model"] === "string") this.state.model = message["model"];
          applyUsage(this.state.usage, message["usage"]);
        }
        break;
      }
      case "message_delta":
        this.state.sawMessageDelta = true;
        applyUsage(this.state.usage, payload["usage"]);
        break;
      case "message_stop":
        this.state.sawMessageStop = true;
        break;
      case "content_block_delta": {
        const delta = payload["delta"];
        if (isRecord(delta)) {
          for (const key of ["text", "thinking", "partial_json"] as const) {
            const v = delta[key];
            if (typeof v === "string") this.state.deltaChars += v.length;
          }
        }
        break;
      }
      case "error":
        this.state.sawError = true;
        break;
      default:
        break;
    }
  }
}
