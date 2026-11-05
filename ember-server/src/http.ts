// 응답 생성·오류 형식·본문 읽기 도우미. 오류는 Anthropic 오류 형식으로 낸다(SDK 가 파싱하도록).

export type ErrorType =
  | "invalid_request_error"
  | "authentication_error"
  | "permission_error"
  | "not_found_error"
  | "request_too_large"
  | "rate_limit_error"
  | "api_error"
  | "overloaded_error"
  | "insufficient_credits"
  | "integrity_failed";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly type: ErrorType,
    message: string,
    readonly headers: Readonly<Record<string, string>> = {},
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export function jsonResponse(data: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", ...headers },
  });
}

export function errorResponse(
  status: number,
  type: ErrorType,
  message: string,
  headers: Record<string, string> = {},
): Response {
  return jsonResponse({ type: "error", error: { type, message } }, status, headers);
}

export function apiErrorResponse(err: ApiError): Response {
  return errorResponse(err.status, err.type, err.message, { ...err.headers });
}

export function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function tooLarge(maxBytes: number): ApiError {
  return new ApiError(413, "request_too_large", `request body exceeds ${maxBytes} bytes`);
}

/** 본문을 최대 maxBytes 까지만 읽는다. Content-Length 가 없어도 스트림을 세면서 끊는다. */
export async function readBodyBytes(req: Request, maxBytes: number): Promise<Uint8Array> {
  const declared = req.headers.get("content-length");
  if (declared !== null && Number(declared) > maxBytes) throw tooLarge(maxBytes);
  if (req.body === null) return new Uint8Array(0);

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw tooLarge(maxBytes);
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.byteLength;
  }
  return out;
}

/** JSON 객체 본문을 읽는다. 객체가 아니면 400. */
export async function readJsonObject(req: Request, maxBytes: number): Promise<Record<string, unknown>> {
  const bytes = await readBodyBytes(req, maxBytes);
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new ApiError(400, "invalid_request_error", "request body must be valid JSON");
  }
  if (!isRecord(parsed)) throw new ApiError(400, "invalid_request_error", "request body must be a JSON object");
  return parsed;
}
