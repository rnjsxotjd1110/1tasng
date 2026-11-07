import { describe, expect, it } from "vitest";
import { loadConfig, parseLegacyUnlinkedUntil, parseRequireGoogleSignin } from "../src/env";
import { ipRateKey } from "../src/ratelimit";
import { hmacSha256Hex } from "../src/util";
import { call, errorBody, makeEnv, type TestEnv } from "./helpers/env";
import { idTokenFor, makeIdToken, TEST_CLIENT_ID } from "./helpers/google-id";

const INSTALL = "3f1c2a9e-8d4b-4c7a-9e21-0a5b6c7d8e9f";

interface RegBody {
  token: string;
  credits: number;
  freeGranted: boolean;
  restored: boolean;
}

/** 가입. sub 를 주지 않으면 installId 마다 정해진 Google 계정(sub-of-<installId>), null 이면 idToken 없이. */
async function reg(env: TestEnv, installId: unknown, ip = "1.2.3.4", sub: string | null = `sub-of-${String(installId)}`): Promise<Response> {
  const json: Record<string, unknown> = { installId };
  if (sub !== null) json["idToken"] = await idTokenFor(sub);
  const { res } = await call(env, "/ember/register", { method: "POST", json, headers: { "cf-connecting-ip": ip } });
  return res;
}

async function regBody(env: TestEnv, installId: string, ip?: string, sub?: string | null): Promise<RegBody> {
  const res = await reg(env, installId, ip, sub);
  expect(res.status, await res.clone().text()).toBe(200);
  return (await res.json()) as RegBody;
}

async function balance(env: TestEnv, token: string): Promise<Response> {
  return (await call(env, "/ember/balance", { headers: { "x-api-key": token } })).res;
}

describe("POST /ember/register (Google 로그인, 기본)", () => {
  it("새 Google 계정은 토큰과 무료 크레딧을 받는다(토큰은 해시로만, 이메일·이름은 저장하지 않음)", async () => {
    const env = makeEnv();
    const body = await regBody(env, INSTALL, "1.2.3.4", "google-sub-0001");
    expect(body).toMatchObject({ credits: 100, freeGranted: true, restored: false });
    expect(body.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const rows = env.db.rows<{ token_hash: string; google_sub: string; install_id: string }>(
      "SELECT token_hash, google_sub, install_id FROM accounts",
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]!.token_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(rows[0]!.token_hash).not.toContain(body.token);
    expect(rows[0]!.google_sub).toBe("google-sub-0001");
    expect(rows[0]!.install_id).toBe(INSTALL);
    // 무료 크레딧 기록은 sub 의 HMAC 만
    const grants = env.db.rows<{ sub_hash: string }>("SELECT sub_hash FROM free_credit_grants");
    expect(grants).toEqual([{ sub_hash: await hmacSha256Hex("test-sub-hash-secret", "google-sub-0001") }]);
    // DB 어디에도 이메일·이름이 없다
    const dump = JSON.stringify(
      env.db.rows<{ name: string }>("SELECT name FROM sqlite_master WHERE type = 'table'").map((t) => env.db.rows(`SELECT * FROM ${t.name}`)),
    );
    expect(dump).not.toContain("example.com");
    expect(dump).not.toContain("Some One");
  });

  it("FREE_CREDITS 환경 변수를 따른다", async () => {
    const env = makeEnv({ FREE_CREDITS: "250" });
    expect((await regBody(env, INSTALL)).credits).toBe(250);
  });

  it("같은 Google 계정으로 새 기기(다른 installId)에서 로그인하면 같은 계정을 복원한다", async () => {
    const env = makeEnv();
    const first = await regBody(env, "phone-old-install-01", "1.1.1.1", "google-sub-restore");
    env.db.sqlite.prepare("UPDATE accounts SET credits = 7").run(); // 써서 줄여 둔다

    const second = await regBody(env, "phone-new-install-02", "2.2.2.2", "google-sub-restore");
    expect(second).toMatchObject({ credits: 7, freeGranted: false, restored: true });
    expect(second.token).not.toBe(first.token);
    expect(env.db.rows("SELECT install_id, google_sub FROM accounts")).toEqual([
      { install_id: "phone-new-install-02", google_sub: "google-sub-restore" },
    ]);
    // 새 토큰은 되고 옛 토큰은 401
    expect(await (await balance(env, second.token)).json()).toEqual({ credits: 7 });
    expect((await balance(env, first.token)).status).toBe(401);
    // 같은 기기에서 다시 로그인해도 같은 계정
    expect(await regBody(env, "phone-new-install-02", "2.2.2.2", "google-sub-restore")).toMatchObject({ credits: 7, restored: true });
    expect(env.db.rows("SELECT id FROM accounts")).toHaveLength(1);
  });

  it("Authorization: Bearer 로도 인증된다", async () => {
    const env = makeEnv();
    const { token } = await regBody(env, INSTALL);
    const { res } = await call(env, "/ember/balance", { headers: { authorization: `Bearer ${token}` } });
    expect(await res.json()).toEqual({ credits: 100 });
  });

  it("idToken 이 없으면 400 google_required 이고 계정을 만들지 않는다", async () => {
    const env = makeEnv();
    for (const idToken of [undefined, null, ""]) {
      const { res } = await call(env, "/ember/register", { method: "POST", json: { installId: INSTALL, idToken } });
      expect(res.status).toBe(400);
      expect((await errorBody(res)).error.type).toBe("google_required");
    }
    const { res } = await call(env, "/ember/register", { method: "POST", json: { installId: INSTALL, idToken: 42 } });
    expect(res.status).toBe(400);
    expect((await errorBody(res)).error.type).toBe("invalid_request_error");
    expect(env.db.rows("SELECT id FROM accounts")).toEqual([]);
  });

  it("검증에 실패한 idToken 은 401 invalid_google_token 이고 계정을 만들지 않는다", async () => {
    const env = makeEnv();
    await idTokenFor("x"); // JWKS 캐시 채우기
    const bad = [
      "not-a-jwt",
      await makeIdToken("s1", { claims: { aud: "someone-elses-client.apps.googleusercontent.com" } }),
      await makeIdToken("s2", { claims: { exp: Math.floor(Date.now() / 1000) - 3600 } }),
      await makeIdToken("s3", { claims: { iss: "https://evil.example.com" } }),
    ];
    for (const idToken of bad) {
      const { res } = await call(env, "/ember/register", { method: "POST", json: { installId: INSTALL, idToken } });
      expect(res.status).toBe(401);
      expect((await errorBody(res)).error.type).toBe("invalid_google_token");
    }
    expect(env.db.rows("SELECT id FROM accounts")).toEqual([]);
  });

  it("서버에 GOOGLE_OAUTH_CLIENT_IDS 나 SUB_HASH_SECRET 이 없으면 500", async () => {
    for (const env of [makeEnv({ GOOGLE_OAUTH_CLIENT_IDS: " , " }), makeEnv({ SUB_HASH_SECRET: undefined })]) {
      const res = await reg(env, INSTALL);
      expect(res.status).toBe(500);
      expect((await errorBody(res)).error.message).toMatch(/not configured/);
      expect(env.db.rows("SELECT id FROM accounts")).toEqual([]);
    }
  });

  it("잘못된 installId 는 400(만료 계정용 'expired-' 접두사 포함)", async () => {
    const env = makeEnv();
    for (const bad of ["short", "x".repeat(65), "has space 123", 12345678, null, "expired-123", "detached:12"]) {
      const res = await reg(env, bad);
      expect(res.status).toBe(400);
      expect((await errorBody(res)).error.type).toBe("invalid_request_error");
    }
  });

  it("IP 당 새 가입 횟수를 제한한다(기본 5회/시간)", async () => {
    const env = makeEnv();
    for (let i = 0; i < 5; i++) expect((await reg(env, `install-${i}-abcdef`, "9.9.9.9")).status).toBe(200);
    const blocked = await reg(env, "install-6-abcdef", "9.9.9.9");
    expect(blocked.status).toBe(429);
    expect((await errorBody(blocked)).error.type).toBe("rate_limit_error");
    expect(Number(blocked.headers.get("retry-after"))).toBeGreaterThan(0);
    // 다른 IP 는 영향 없음
    expect((await reg(env, "install-7-abcdef", "8.8.8.8")).status).toBe(200);
  });

  it("차단된 계정은 복원·인증이 403", async () => {
    const env = makeEnv();
    const { token } = await regBody(env, INSTALL);
    env.db.sqlite.prepare("UPDATE accounts SET disabled = 1").run();
    expect((await balance(env, token)).status).toBe(403);
    expect((await reg(env, INSTALL, "5.5.5.5")).status).toBe(403);
    expect((await reg(env, "another-device-0001", "5.5.5.6", `sub-of-${INSTALL}`)).status).toBe(403);
    expect(env.db.rows("SELECT install_id FROM accounts")).toEqual([{ install_id: INSTALL }]);
  });

  it("IPv6 는 /64 단위로 센다(같은 /64 안에서 주소를 바꿔도 같은 한도)", async () => {
    const env = makeEnv({ REGISTER_LIMIT: "2" });
    expect((await reg(env, "install-v6-000001", "2001:db8:1:2::1")).status).toBe(200);
    expect((await reg(env, "install-v6-000002", "2001:db8:1:2:aaaa:bbbb:cccc:dddd")).status).toBe(200);
    expect((await reg(env, "install-v6-000003", "2001:0db8:0001:0002::ffff")).status).toBe(429);
    // 다른 /64 는 따로
    expect((await reg(env, "install-v6-000004", "2001:db8:1:3::1")).status).toBe(200);
    // IPv4 는 주소 전체(같은 /24 라도 다른 주소는 따로)
    expect((await reg(env, "install-v4-000001", "203.0.113.1")).status).toBe(200);
    expect((await reg(env, "install-v4-000002", "203.0.113.1")).status).toBe(200);
    expect((await reg(env, "install-v4-000003", "203.0.113.1")).status).toBe(429);
    expect((await reg(env, "install-v4-000004", "203.0.113.2")).status).toBe(200);
  });

  it("복원(이미 있는 Google 계정)은 새 가입과 따로, 느슨한 한도로 센다(CGNAT)", async () => {
    const env = makeEnv({ REGISTER_LIMIT: "1", REREGISTER_LIMIT: "3" });
    expect((await reg(env, "install-cgnat-0001", "100.64.0.1")).status).toBe(200);
    // 같은 IP 의 새 가입은 막힌다
    expect((await reg(env, "install-cgnat-0002", "100.64.0.1")).status).toBe(429);
    // 이미 있는 계정의 재로그인은 된다(3회까지)
    for (let i = 0; i < 3; i++) expect((await reg(env, "install-cgnat-0001", "100.64.0.1")).status).toBe(200);
    expect((await reg(env, "install-cgnat-0001", "100.64.0.1")).status).toBe(429);
  });

  it("하루 무료 크레딧 상한(FREE_CREDITS_DAILY_CAP)에 도달하면 새 계정은 0(freeGranted: false)", async () => {
    const env = makeEnv({ FREE_CREDITS_DAILY_CAP: "250" });
    const bodies: RegBody[] = [];
    for (let i = 0; i < 4; i++) bodies.push(await regBody(env, `install-cap-${i}-xyz`, `198.51.100.${i}`));
    expect(bodies.map((b) => b.freeGranted)).toEqual([true, true, false, false]);
    expect(bodies.map((b) => b.credits)).toEqual([100, 100, 0, 0]);
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([{ count: 200 }]);
    // 상한 때문에 못 받은 Google 계정은 '받음'으로 기록하지 않는다
    expect(env.db.rows("SELECT COUNT(*) AS n FROM free_credit_grants")).toEqual([{ n: 2 }]);
    // 재로그인은 상한을 쓰지 않는다
    await reg(env, "install-cap-0-xyz", "198.51.100.9");
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([{ count: 200 }]);
  });

  it("동시에 같은 새 Google 계정이 와도 계정은 하나, 무료 크레딧·상한 카운터도 한 번", async () => {
    const env = makeEnv();
    const results = await Promise.all([1, 2, 3].map((i) => reg(env, "install-race-0001", `192.0.2.${i}`)));
    expect(results.map((r) => r.status)).toEqual([200, 200, 200]);
    const bodies = (await Promise.all(results.map((r) => r.json()))) as RegBody[];
    expect(bodies.filter((b) => b.freeGranted)).toHaveLength(1);
    expect(env.db.rows("SELECT credits FROM accounts")).toEqual([{ credits: 100 }]);
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([{ count: 100 }]);
  });

  it("무료 크레딧은 Google 계정당 한 번: 기록(free_credit_grants)이 있으면 새 계정은 0", async () => {
    const env = makeEnv();
    env.db.sqlite
      .prepare("INSERT INTO free_credit_grants (sub_hash, created_at) VALUES (?, 0)")
      .run(await hmacSha256Hex("test-sub-hash-secret", "google-sub-used"));
    expect(await regBody(env, INSTALL, "1.2.3.4", "google-sub-used")).toMatchObject({ credits: 0, freeGranted: false, restored: false });
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([]);
    // SUB_HASH_SECRET 이 다르면 다른 해시(기록과 맞지 않음)
    const other = makeEnv({ SUB_HASH_SECRET: "rotated" });
    other.db.sqlite
      .prepare("INSERT INTO free_credit_grants (sub_hash, created_at) VALUES (?, 0)")
      .run(await hmacSha256Hex("test-sub-hash-secret", "google-sub-used"));
    expect((await regBody(other, INSTALL, "1.2.3.4", "google-sub-used")).freeGranted).toBe(true);
  });

  it("같은 기기에서 다른 Google 계정으로 로그인하면 새 계정. 이전 계정은 installId 를 떼어 내고 자기 Google 계정으로 복원된다", async () => {
    const env = makeEnv();
    const a = await regBody(env, INSTALL, "1.1.1.1", "google-sub-A");
    const b = await regBody(env, INSTALL, "1.1.1.2", "google-sub-B");
    expect(b).toMatchObject({ credits: 100, freeGranted: true, restored: false });
    expect(env.db.rows("SELECT id, install_id, google_sub FROM accounts ORDER BY id")).toEqual([
      { id: 1, install_id: "detached:1", google_sub: "google-sub-A" },
      { id: 2, install_id: INSTALL, google_sub: "google-sub-B" },
    ]);
    expect((await balance(env, a.token)).status).toBe(200); // A 의 토큰은 그대로
    // 다시 A 로 로그인하면 A 가 이 installId 를 가져간다
    expect(await regBody(env, INSTALL, "1.1.1.3", "google-sub-A")).toMatchObject({ credits: 100, restored: true });
    expect(env.db.rows("SELECT id, install_id FROM accounts ORDER BY id")).toEqual([
      { id: 1, install_id: INSTALL },
      { id: 2, install_id: "detached:2" },
    ]);
  });

  it("예전 앱이 만든 연결 안 된 계정의 installId 로 Google 로그인하면 그 계정을 연결한다(잔액 유지, 무료 크레딧 다시 없음)", async () => {
    const env = makeEnv();
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `INSERT INTO accounts (install_id, token_hash, credits, free_credits, created_at, updated_at)
       VALUES ('${INSTALL}', 'old-hash', 321, 40, ${now}, ${now})`,
    );
    const body = await regBody(env, INSTALL, "1.2.3.4", "google-sub-upgrade");
    expect(body).toMatchObject({ credits: 321, freeGranted: false, restored: true });
    expect(env.db.rows("SELECT id, google_sub, install_id FROM accounts")).toEqual([
      { id: 1, google_sub: "google-sub-upgrade", install_id: INSTALL },
    ]);
    // 예전 계정이 받은 무료 크레딧도 이 Google 계정의 '받음'으로 기록
    expect(env.db.rows("SELECT sub_hash FROM free_credit_grants")).toEqual([
      { sub_hash: await hmacSha256Hex("test-sub-hash-secret", "google-sub-upgrade") },
    ]);
    // 재등록(같은 installId 의 예전 계정)이므로 느슨한 한도를 쓴다
    expect(env.db.rows("SELECT key FROM rate_limits WHERE key LIKE 'reg:%'")).toEqual([]);
  });

  it("복원할 때 새 installId 를 연결 안 된 예전 계정이 쓰고 있으면 installId 는 바꾸지 않는다", async () => {
    const env = makeEnv();
    await regBody(env, "linked-device-0001", "1.1.1.1", "google-sub-L");
    const now = Math.floor(Date.now() / 1000);
    env.db.sqlite.exec(
      `INSERT INTO accounts (install_id, token_hash, credits, created_at, updated_at) VALUES ('legacy-device-001', 'h', 5, ${now}, ${now})`,
    );
    expect(await regBody(env, "legacy-device-001", "1.1.1.2", "google-sub-L")).toMatchObject({ credits: 100, restored: true });
    expect(env.db.rows("SELECT install_id, google_sub FROM accounts ORDER BY id")).toEqual([
      { install_id: "linked-device-0001", google_sub: "google-sub-L" },
      { install_id: "legacy-device-001", google_sub: null },
    ]);
  });
});

describe("POST /ember/register (예전 방식, REQUIRE_GOOGLE_SIGNIN=false)", () => {
  it("idToken 없이 가입·재등록된다. 재등록은 새 토큰, 무료 크레딧은 다시 없음", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    const first = await regBody(env, INSTALL, "1.2.3.4", null);
    expect(first).toMatchObject({ credits: 100, freeGranted: true, restored: false });
    env.db.sqlite.prepare("UPDATE accounts SET credits = 7").run();
    const second = await regBody(env, INSTALL, "1.2.3.4", null);
    expect(second).toMatchObject({ credits: 7, freeGranted: false, restored: true });
    expect(second.token).not.toBe(first.token);
    expect(env.db.rows("SELECT google_sub FROM accounts")).toEqual([{ google_sub: null }]);
    expect(env.db.rows("SELECT * FROM free_credit_grants")).toEqual([]);
    expect(await (await balance(env, second.token)).json()).toEqual({ credits: 7 });
    expect((await balance(env, first.token)).status).toBe(401);
  });

  it("idToken 을 보내면 Google 로그인으로 처리한다", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    await regBody(env, INSTALL, "1.2.3.4", "google-sub-opt");
    expect(env.db.rows("SELECT google_sub FROM accounts")).toEqual([{ google_sub: "google-sub-opt" }]);
  });

  it("Google 에 연결된 계정의 installId 로는 idToken 없이 토큰을 받을 수 없다(400 google_required)", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    await regBody(env, INSTALL, "1.2.3.4", "google-sub-protected");
    const res = await reg(env, INSTALL, "1.2.3.4", null);
    expect(res.status).toBe(400);
    expect((await errorBody(res)).error.type).toBe("google_required");
  });

  it("LEGACY_UNLINKED_UNTIL 이 지나면 idToken 없는 가입은 403 google_required", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false", LEGACY_UNLINKED_UNTIL: "2020-01-01" });
    const res = await reg(env, INSTALL, "1.2.3.4", null);
    expect(res.status).toBe(403);
    expect((await errorBody(res)).error.type).toBe("google_required");
    // Google 로그인은 된다
    expect((await reg(env, INSTALL, "1.2.3.4")).status).toBe(200);
  });

  it("차단된 계정은 재등록이 403", async () => {
    const env = makeEnv({ REQUIRE_GOOGLE_SIGNIN: "false" });
    await regBody(env, INSTALL, "1.2.3.4", null);
    env.db.sqlite.prepare("UPDATE accounts SET disabled = 1").run();
    expect((await reg(env, INSTALL, "5.5.5.5", null)).status).toBe(403);
  });
});

describe("설정 해석", () => {
  it("REQUIRE_GOOGLE_SIGNIN 은 'false' 일 때만 꺼진다", () => {
    expect(parseRequireGoogleSignin(undefined)).toBe(true);
    expect(parseRequireGoogleSignin("")).toBe(true);
    expect(parseRequireGoogleSignin("true")).toBe(true);
    expect(parseRequireGoogleSignin("no")).toBe(true);
    expect(parseRequireGoogleSignin(" FALSE ")).toBe(false);
  });

  it("LEGACY_UNLINKED_UNTIL: 날짜만이면 그날 00:00 UTC, 틀리면 null", () => {
    expect(parseLegacyUnlinkedUntil(undefined)).toBeNull();
    expect(parseLegacyUnlinkedUntil(" ")).toBeNull();
    expect(parseLegacyUnlinkedUntil("2027-07-01")).toBe(Date.UTC(2027, 6, 1) / 1000);
    expect(parseLegacyUnlinkedUntil("2027-07-01T09:00:00+09:00")).toBe(Date.UTC(2027, 6, 1) / 1000);
    expect(parseLegacyUnlinkedUntil("next year")).toBeNull();
    expect(parseLegacyUnlinkedUntil("2027-13-45")).toBeNull();
  });

  it("GOOGLE_OAUTH_CLIENT_IDS 는 쉼표로 나눈다", () => {
    expect(loadConfig(makeEnv()).googleClientIds).toEqual(["other-client.apps.googleusercontent.com", TEST_CLIENT_ID]);
    expect(loadConfig(makeEnv({ GOOGLE_OAUTH_CLIENT_IDS: undefined })).googleClientIds).toEqual([]);
  });
});

describe("ipRateKey", () => {
  it("IPv4 는 그대로, IPv6 는 /64, IPv4 매핑 IPv6 는 IPv4", () => {
    expect(ipRateKey("1.2.3.4")).toBe("1.2.3.4");
    expect(ipRateKey("2001:db8::1")).toBe("2001:db8:0:0::/64");
    expect(ipRateKey("2001:DB8:0:0:1:2:3:4")).toBe("2001:db8:0:0::/64");
    expect(ipRateKey("2001:db8:a:b:c:d:e:f")).toBe("2001:db8:a:b::/64");
    expect(ipRateKey("::ffff:1.2.3.4")).toBe("1.2.3.4");
    expect(ipRateKey("::1")).toBe("0:0:0:0::/64");
    expect(ipRateKey("fe80::1%eth0")).toBe("fe80:0:0:0::/64");
    expect(ipRateKey(null)).toBe("unknown");
    expect(ipRateKey("garbage:::x")).toBe("garbage:::x");
  });
});
