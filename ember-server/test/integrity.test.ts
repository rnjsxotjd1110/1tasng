import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { loadConfig, parseIntegrityMode } from "../src/env";
import { clearGoogleTokenCache, PLAY_INTEGRITY_SCOPE } from "../src/play/google-auth";
import { checkIntegrityPayload, NONCE_TTL_SECONDS, normalizeNonce } from "../src/play/integrity";
import { call, errorBody, makeEnv, type TestEnv } from "./helpers/env";
import { DECODE_URL, installFakeGoogle, PACKAGE, passingPayload, type FakeGoogle } from "./helpers/google";

beforeEach(() => clearGoogleTokenCache());
afterEach(() => vi.unstubAllGlobals());

let ipSeq = 0;
function nextIp(): string {
  ipSeq++;
  return `172.16.${Math.floor(ipSeq / 250)}.${ipSeq % 250}`;
}

async function getNonce(env: TestEnv, ip = nextIp()): Promise<string> {
  const { res } = await call(env, "/ember/nonce", { headers: { "cf-connecting-ip": ip } });
  expect(res.status).toBe(200);
  return ((await res.json()) as { nonce: string }).nonce;
}

interface RegisterBody {
  token?: string;
  credits?: number;
  freeGranted?: boolean;
  integrity?: string;
}

async function reg(env: TestEnv, body: Record<string, unknown>): Promise<{ status: number; body: RegisterBody & { error?: { type: string } } }> {
  const { res } = await call(env, "/ember/register", {
    method: "POST",
    json: body,
    headers: { "cf-connecting-ip": nextIp() },
  });
  return { status: res.status, body: (await res.json()) as RegisterBody & { error?: { type: string } } };
}

/** nonce 를 받고, 그 nonce 로 만든(가짜) 무결성 토큰을 등록해 둔다. */
async function attest(env: TestEnv, g: FakeGoogle, payload?: (nonce: string) => unknown): Promise<{ nonce: string; integrityToken: string }> {
  const nonce = await getNonce(env);
  const integrityToken = `itok-${crypto.randomUUID()}`;
  g.integrityPayloads.set(integrityToken, payload ? payload(nonce) : passingPayload(nonce));
  return { nonce, integrityToken };
}

function accountCount(env: TestEnv): number {
  return env.db.rows("SELECT id FROM accounts").length;
}

describe("GET /ember/nonce", () => {
  it("24바이트 base64url nonce 를 5분 만료로 저장한다", async () => {
    const env = makeEnv();
    const before = Math.floor(Date.now() / 1000);
    const nonce = await getNonce(env);
    expect(nonce).toMatch(/^[A-Za-z0-9_-]{32}$/);
    const rows = env.db.rows<{ nonce: string; expires_at: number }>("SELECT nonce, expires_at FROM nonces");
    expect(rows).toHaveLength(1);
    expect(rows[0]!.nonce).toBe(nonce);
    expect(rows[0]!.expires_at - before).toBeGreaterThanOrEqual(NONCE_TTL_SECONDS);
    expect(rows[0]!.expires_at - before).toBeLessThanOrEqual(NONCE_TTL_SECONDS + 1);
    expect(await getNonce(env)).not.toBe(nonce);
  });

  it("IP 당 요청 수를 가입과 같은 한도로 제한한다", async () => {
    const env = makeEnv({ REGISTER_LIMIT: "2" });
    await getNonce(env, "7.7.7.7");
    await getNonce(env, "7.7.7.7");
    const { res } = await call(env, "/ember/nonce", { headers: { "cf-connecting-ip": "7.7.7.7" } });
    expect(res.status).toBe(429);
    expect((await errorBody(res)).error.type).toBe("rate_limit_error");
    // 가입 제한과는 따로 센다
    expect((await reg(env, { installId: "install-after-nonce-1" })).status).toBe(200);
  });
});

describe("INTEGRITY_MODE=off (기본)", () => {
  it("토큰 없이 예전처럼 가입되고, 보낸 토큰은 무시하며 integrity 필드가 없다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson });
    const plain = await reg(env, { installId: "install-off-00001" });
    expect(plain.status).toBe(200);
    expect(plain.body).toMatchObject({ credits: 100, freeGranted: true });
    expect(plain.body.integrity).toBeUndefined();
    const withToken = await reg(env, { installId: "install-off-00002", integrityToken: "junk", nonce: "junk-nonce-1234567890" });
    expect(withToken.body).toMatchObject({ credits: 100, freeGranted: true });
    expect(withToken.body.integrity).toBeUndefined();
    expect(g.decodeRequests).toHaveLength(0);
  });

  it("모르는 값은 off 로 본다", () => {
    expect(parseIntegrityMode(undefined)).toBe("off");
    expect(parseIntegrityMode(" GRANT ")).toBe("grant");
    expect(parseIntegrityMode("require")).toBe("require");
    expect(parseIntegrityMode("requrie")).toBe("off");
    expect(loadConfig(makeEnv()).integrityMode).toBe("off");
  });
});

describe("INTEGRITY_MODE=grant", () => {
  it("통과: 무료 크레딧을 주고 integrity=ok, nonce 는 소비된다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const a = await attest(env, g);
    const r = await reg(env, { installId: "install-grant-0001", ...a });
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ credits: 100, freeGranted: true, integrity: "ok" });
    expect(g.decodeRequests).toEqual([{ body: { integrity_token: a.integrityToken } }]);
    expect(g.tokenRequests[PLAY_INTEGRITY_SCOPE]).toBe(1);
    expect(env.db.rows("SELECT nonce FROM nonces")).toEqual([]);

    // 두 번째 가입은 integrity 액세스 토큰을 캐시에서 쓴다
    const b = await attest(env, g);
    expect((await reg(env, { installId: "install-grant-0002", ...b })).body.integrity).toBe("ok");
    expect(g.tokenRequests[PLAY_INTEGRITY_SCOPE]).toBe(1);
  });

  it("토큰·nonce 가 없으면 가입은 되지만 크레딧 0, integrity=missing", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const nonce = await getNonce(env);
    for (const [installId, extra] of [
      ["install-missing-01", {}],
      ["install-missing-02", { nonce }],
      ["install-missing-03", { integrityToken: "itok" }],
    ] as const) {
      const r = await reg(env, { installId, ...extra });
      expect(r.status).toBe(200);
      expect(r.body).toMatchObject({ credits: 0, freeGranted: false, integrity: "missing" });
      expect(r.body.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    }
    expect(g.decodeRequests).toHaveLength(0);
    expect(env.db.rows("SELECT SUM(free_credits) AS f FROM accounts")).toEqual([{ f: 0 }]);
  });

  it("다른 nonce 로 만든 토큰이면 failed(크레딧 0)", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const other = await getNonce(env);
    const a = await attest(env, g, () => passingPayload(other));
    const r = await reg(env, { installId: "install-wrongnonce", ...a });
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ credits: 0, freeGranted: false, integrity: "failed" });
  });

  it("이미 쓴 nonce 는 다시 쓸 수 없다(Google 을 부르지 않음)", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const a = await attest(env, g);
    expect((await reg(env, { installId: "install-reuse-0001", ...a })).body.integrity).toBe("ok");
    const again = await reg(env, { installId: "install-reuse-0002", ...a });
    expect(again.body).toMatchObject({ credits: 0, freeGranted: false, integrity: "failed" });
    expect(g.decodeRequests).toHaveLength(1);
  });

  it("만료된 nonce·서버가 발급하지 않은 nonce 는 failed", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const a = await attest(env, g);
    env.db.sqlite.exec(`UPDATE nonces SET expires_at = ${Math.floor(Date.now() / 1000) - 1}`);
    expect((await reg(env, { installId: "install-expired-01", ...a })).body.integrity).toBe("failed");
    const forged = "A".repeat(32);
    g.integrityPayloads.set("itok-forged", passingPayload(forged));
    expect((await reg(env, { installId: "install-forged-001", integrityToken: "itok-forged", nonce: forged })).body.integrity).toBe("failed");
    expect(g.decodeRequests).toHaveLength(0);
  });

  it("Play 가 인식하지 못한 앱·기기 무결성 미달·다른 패키지면 failed", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const cases: [string, (n: string) => unknown][] = [
      ["unrecognized", (n) => passingPayload(n, { appIntegrity: { appRecognitionVerdict: "UNRECOGNIZED_VERSION" } })],
      ["unevaluated", (n) => passingPayload(n, { appIntegrity: { appRecognitionVerdict: "UNEVALUATED" } })],
      ["basic-only", (n) => passingPayload(n, { deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } })],
      ["no-device", (n) => passingPayload(n, { deviceIntegrity: {} })],
      ["other-pkg", (n) => passingPayload(n, { requestDetails: { requestPackageName: "com.evil.clone", nonce: n } })],
    ];
    for (const [name, payload] of cases) {
      const a = await attest(env, g, payload);
      const r = await reg(env, { installId: `install-bad-${name}`, ...a });
      expect(r.body, name).toMatchObject({ credits: 0, freeGranted: false, integrity: "failed" });
    }
  });

  it("Google 이 토큰을 거절(400)하면 failed, 일시 오류(5xx)면 502 이고 계정을 만들지 않는다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const nonce = await getNonce(env);
    const rejected = await reg(env, { installId: "install-gbad-0001", integrityToken: "not-a-real-token", nonce });
    expect(rejected.body.integrity).toBe("failed");

    const a = await attest(env, g);
    g.decodeFailStatus = 503;
    const r = await reg(env, { installId: "install-g503-0001", ...a });
    expect(r.status).toBe(502);
    expect(r.body.error?.type).toBe("api_error");
    expect(env.db.rows("SELECT install_id FROM accounts WHERE install_id = 'install-g503-0001'")).toEqual([]);
  });

  it("Google 이 nonce 를 표준 base64(+ / =)로 돌려줘도 같은 값으로 본다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const nonce = await getNonce(env);
    // 서버 nonce 에 - _ 가 꼭 들어가도록 저장된 값을 바꿔 둔다
    const fixed = "ab-cd_ef" + nonce.slice(8);
    env.db.sqlite.prepare("UPDATE nonces SET nonce = ?").run(fixed);
    const standard = fixed.replace(/-/g, "+").replace(/_/g, "/") + "\n";
    g.integrityPayloads.set("itok-std", passingPayload(standard));
    const r = await reg(env, { installId: "install-std-b64-01", integrityToken: "itok-std", nonce: fixed });
    expect(r.body.integrity).toBe("ok");
  });

  it("이미 있는 installId 의 재등록은 무료 크레딧을 다시 주지 않는다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "grant" });
    const first = await reg(env, { installId: "install-again-0001" }); // missing → 0
    expect(first.body.credits).toBe(0);
    const a = await attest(env, g);
    const second = await reg(env, { installId: "install-again-0001", ...a });
    expect(second.body).toMatchObject({ credits: 0, freeGranted: false, integrity: "ok" });
  });

  it("서비스 계정이 없으면 500", async () => {
    const env = makeEnv({ INTEGRITY_MODE: "grant" });
    const nonce = await getNonce(env);
    const r = await reg(env, { installId: "install-nosa-0001", integrityToken: "x", nonce });
    expect(r.status).toBe(500);
  });
});

describe("INTEGRITY_MODE=require", () => {
  it("통과하면 가입(integrity=ok), 없거나 실패하면 403 integrity_failed 이고 계정을 만들지 않는다", async () => {
    const g = await installFakeGoogle();
    const env = makeEnv({ GOOGLE_SERVICE_ACCOUNT_JSON: g.saJson, INTEGRITY_MODE: "require" });

    const missing = await reg(env, { installId: "install-req-0001" });
    expect(missing.status).toBe(403);
    expect(missing.body).toEqual({ type: "error", error: { type: "integrity_failed", message: "device integrity check missing" } });

    const bad = await attest(env, g, (n) => passingPayload(n, { appIntegrity: { appRecognitionVerdict: "UNRECOGNIZED_VERSION" } }));
    const failed = await reg(env, { installId: "install-req-0002", ...bad });
    expect(failed.status).toBe(403);
    expect(failed.body.error?.type).toBe("integrity_failed");
    expect(accountCount(env)).toBe(0);

    const good = await attest(env, g);
    const ok = await reg(env, { installId: "install-req-0003", ...good });
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({ credits: 100, freeGranted: true, integrity: "ok" });

    // 재등록도 확인이 필요하다
    expect((await reg(env, { installId: "install-req-0003" })).status).toBe(403);
    const again = await attest(env, g);
    const re = await reg(env, { installId: "install-req-0003", ...again });
    expect(re.status).toBe(200);
    expect(re.body).toMatchObject({ freeGranted: false, integrity: "ok" });
    expect(accountCount(env)).toBe(1);
  });
});

describe("판정 확인 단위 테스트", () => {
  it("normalizeNonce 는 base64url·무패딩으로 맞춘다", () => {
    expect(normalizeNonce("ab+/cd==")).toBe("ab-_cd");
    expect(normalizeNonce(" ab-_cd \n")).toBe("ab-_cd");
  });

  it("checkIntegrityPayload", () => {
    const n = "N".repeat(32);
    expect(checkIntegrityPayload(passingPayload(n), n, PACKAGE)).toBeNull();
    expect(checkIntegrityPayload(undefined, n, PACKAGE)).toMatch(/tokenPayloadExternal/);
    expect(checkIntegrityPayload(passingPayload("x".repeat(32)), n, PACKAGE)).toBe("nonce mismatch");
    expect(checkIntegrityPayload(passingPayload(n), n, "other.pkg")).toBe("package name mismatch");
  });

  it("decode 주소", () => {
    expect(DECODE_URL).toBe("https://playintegrity.googleapis.com/v1/app.ember.ideas:decodeIntegrityToken");
  });
});
