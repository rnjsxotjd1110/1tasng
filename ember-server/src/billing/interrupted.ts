// 끝까지 받지 못한 요청의 과금(이용약관 5장, 운영자가 정한 규칙).
//
// - 최종 usage(message_delta)를 받았으면 실제 사용량으로 정산한다(이 파일과 무관).
// - 앱이 '중지'를 누르거나 연결이 끊겨 최종 usage 전에 끝나면(client_gone):
//     입력 토큰(message_start 의 usage) + 출력 추정 = ceil(받은 출력 문자 수 ÷ 3) × 2 토큰.
//     ×2 는 화면에 보이지 않는 생각(thinking) 분량을 덮는다. 예약액을 넘지 않는다.
// - Anthropic(업스트림)이나 이 서버 쪽 오류로 끊기면(upstream_error / server_error): 입력 토큰만.
// - message_start 를 받기 전에 끝났으면(생성 시작 전) 비용 0.
// 위 추정 청구는 usage_log.estimated = 1 로 남긴다.
import { computeCredits } from "./pricing";
import { emptyUsage, type Usage } from "./usage";

/** 출력 문자 몇 개를 토큰 1개로 볼지(한국어·영어 모두 실제보다 적게 잡히지 않는 쪽) */
export const OUTPUT_CHARS_PER_TOKEN = 3;
/** 보이지 않는 생각(thinking) 분량을 덮기 위한 배수 */
export const UNSEEN_THINKING_MULTIPLIER = 2;

export type StreamEnd = "client_gone" | "upstream_error" | "server_error";

/** 받은 출력 문자 수로 출력 토큰을 추정한다: ceil(chars ÷ 3) × 2 */
export function estimateOutputTokens(outputChars: number): number {
  return Math.ceil(Math.max(0, outputChars) / OUTPUT_CHARS_PER_TOKEN) * UNSEEN_THINKING_MULTIPLIER;
}

/** 입력(캐시 읽기·쓰기 포함)만 남긴 usage */
export function inputOnlyUsage(u: Usage): Usage {
  return { ...u, outputTokens: 0, webSearchRequests: 0 };
}

export interface InterruptedInput {
  /** 요청 모델(정산 기준) */
  model: string;
  /** message_start 의 message.model */
  responseModel?: string;
  /** message_start 를 받았는지(입력 토큰을 아는지) */
  sawMessageStart: boolean;
  /** message_start 의 usage(입력 토큰) */
  usage: Usage;
  /** 받은 출력 델타(text·thinking·partial_json) 문자 수 */
  outputChars: number;
  end: StreamEnd;
  markup: number;
  /** 예약액(청구 상한) */
  reserved: number;
}

export interface InterruptedCharge {
  credits: number;
  /** usage_log 에 남길 usage(추정한 출력 토큰 포함) */
  usage: Usage;
  estimated: boolean;
}

/** 최종 usage 없이 끝난 스트림의 청구액을 정한다. */
export function interruptedCharge(i: InterruptedInput): InterruptedCharge {
  if (!i.sawMessageStart) return { credits: 0, usage: emptyUsage(), estimated: false };
  const usage =
    i.end === "client_gone"
      ? { ...inputOnlyUsage(i.usage), outputTokens: estimateOutputTokens(i.outputChars) }
      : inputOnlyUsage(i.usage);
  const credits = Math.min(Math.max(0, i.reserved), computeCredits(i.model, usage, i.markup, i.responseModel).credits);
  return { credits, usage, estimated: true };
}
