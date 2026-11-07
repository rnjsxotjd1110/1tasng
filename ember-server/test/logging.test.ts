// 로그 규칙: Google API(확인·무결성·소비·환불 목록) 응답 본문은 남기지 않고 상태 코드와 오류 종류만.
// 토큰·sub·IP 는 콘솔에 남기지 않는다. (확인·소비는 purchase.test.ts)
import { afterEach, describe, expect, it, vi } from "vitest";
import { decodeIntegrityToken } from "../src/play/integrity";
import { googleErrorType } from "../src/play/verify";
import { listVoidedPurchases } from "../src/play/voided";
import { call, makeEnv, register } from "./helpers/env";
import { installFakeGoogle } from "./helpers/google";
import { idTokenFor } from "./helpers/google-id";

const SECRET = "SECRET-BODY-d4e5f6";

function spyAll(): { text: () => string; restore: () => void } {
  const spies = (["error", "warn", "log", "info", "debug"] as const).map((m) => vi.spyOn(console, m).mockImplementation(() => undefined));
  return {
    text: () =>
      spies
        .flatMap((s) => s.mock.calls.map((c) => c.map((x) => (x instanceof Error ? `${x.message}` : String(x))).join(" ")))
        .join("\n"),
    restore: () => spies.forEach((s) => s.mockRestore()),
  };
}

afterEach(() => vi.unstubAllGlobals());

describe("googleErrorType", () => {
  it("error.status 또는 error.errors[0].reason 만, 아니면 unknown", () => {
    expect(googleErrorType(JSON.stringify({ error: { status: "PERMISSION_DENIED", message: SECRET } }))).toBe("PERMISSION_DENIED");
    expect(googleErrorType(JSON.stringify({ error: { errors: [{ reason: "purchaseAlreadyConsumed", message: SECRET }] } }))).toBe("purchaseAlreadyConsumed");
    expect(googleErrorType(`<html>${SECRET}</html>`)).toBe("unknown");
    expect(googleErrorType(JSON.stringify({ error: { status: `bad status ${SECRET}` } }))).toBe("unknown");
  });
});

describe("Google 응답 본문을 로그·오류 메시지에 남기지 않는다", () => {
  it("Play Integrity 해독 실패(400·5xx)", async () => {
    const g = await installFakeGoogle(async () =>
      Response.json({ error: { code: 400, status: "INVALID_ARGUMENT", message: `token ${SECRET}` } }, { status: 400 }),
    );
    const log = spyAll();
    expect(await decodeIntegrityToken(g.saJson, "other.package", "integrity-token-123")).toEqual({ kind: "invalid", status: 400 });
    const text = log.text();
    log.restore();
    expect(text).toContain("INVALID_ARGUMENT");
    expect(text).not.toContain(SECRET);
    expect(text).not.toContain("integrity-token-123");
  });

  it("환불 목록(Voided Purchases) 실패: 던지는 오류에도 본문이 없다", async () => {
    const g = await installFakeGoogle(async () =>
      Response.json({ error: { code: 403, status: "PERMISSION_DENIED", message: SECRET } }, { status: 403 }),
    );
    const err = await listVoidedPurchases(g.saJson, "other.package", 0).catch((e: unknown) => e as Error);
    expect(err).toBeInstanceOf(Error);
    expect((err as Error).message).toBe("voided purchases request failed (403 PERMISSION_DENIED)");
  });
});

describe("토큰·sub·IP 를 콘솔에 남기지 않는다", () => {
  it("가입·요청·업스트림 인증 실패·신고 흐름", async () => {
    const env = makeEnv();
    const log = spyAll();
    const sub = "google-sub-secret-777";
    const ip = "203.0.113.77";
    const reg = await call(env, "/ember/register", {
      method: "POST",
      json: { installId: "install-log-00001", idToken: await idTokenFor(sub) },
      headers: { "cf-connecting-ip": ip },
    });
    const { token } = (await reg.res.json()) as { token: string };
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ type: "error", error: { type: "authentication_error", message: SECRET } }, { status: 401 })));
    const res = await call(env, "/v1/messages", {
      method: "POST",
      json: { model: "claude-sonnet-5-5", max_tokens: 10, messages: [{ role: "user", content: "hi" }] },
      headers: { "x-api-key": token, "cf-connecting-ip": ip },
    });
    expect(res.res.status).toBe(500);
    await call(env, "/ember/report/anon", { method: "POST", json: { kind: "other", reason: "r", content: "c" }, headers: { "cf-connecting-ip": ip } });
    await register(env, "install-log-00001", sub); // 같은 Google 계정으로 복원
    const text = log.text();
    log.restore();
    expect(text).toContain("authentication_error");
    for (const secret of [SECRET, token, sub, ip]) expect(text).not.toContain(secret);
  });
});
