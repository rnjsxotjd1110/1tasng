import { describe, expect, it } from "vitest";
import { ipRateKey } from "../src/ratelimit";
import { call, errorBody, makeEnv } from "./helpers/env";

const INSTALL = "3f1c2a9e-8d4b-4c7a-9e21-0a5b6c7d8e9f";

async function reg(env: ReturnType<typeof makeEnv>, installId: unknown, ip = "1.2.3.4"): Promise<Response> {
  const { res } = await call(env, "/ember/register", {
    method: "POST",
    json: { installId },
    headers: { "cf-connecting-ip": ip },
  });
  return res;
}

describe("POST /ember/register", () => {
  it("새 설치는 토큰과 무료 크레딧을 받는다(토큰은 해시로만 저장)", async () => {
    const env = makeEnv();
    const res = await reg(env, INSTALL);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { token: string; credits: number; freeGranted: boolean };
    expect(body.freeGranted).toBe(true);
    expect(body.credits).toBe(100);
    expect(body.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const rows = env.db.rows<{ token_hash: string }>("SELECT token_hash FROM accounts");
    expect(rows).toHaveLength(1);
    expect(rows[0]!.token_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(rows[0]!.token_hash).not.toContain(body.token);
  });

  it("FREE_CREDITS 환경 변수를 따른다", async () => {
    const env = makeEnv({ FREE_CREDITS: "250" });
    const body = (await (await reg(env, INSTALL)).json()) as { credits: number };
    expect(body.credits).toBe(250);
  });

  it("같은 installId 로 다시 등록하면 새 토큰을 주지만 무료 크레딧은 다시 주지 않는다", async () => {
    const env = makeEnv();
    const first = (await (await reg(env, INSTALL)).json()) as { token: string; credits: number };

    // 크레딧을 써서 줄여 둔다
    env.db.sqlite.prepare("UPDATE accounts SET credits = 7").run();

    const res = await reg(env, INSTALL);
    const second = (await res.json()) as { token: string; credits: number; freeGranted: boolean };
    expect(second.freeGranted).toBe(false);
    expect(second.credits).toBe(7);
    expect(second.token).not.toBe(first.token);
    expect(env.db.rows("SELECT id FROM accounts")).toHaveLength(1);

    // 새 토큰은 되고 옛 토큰은 401
    const ok = await call(env, "/ember/balance", { headers: { "x-api-key": second.token } });
    expect(await ok.res.json()).toEqual({ credits: 7 });
    const old = await call(env, "/ember/balance", { headers: { "x-api-key": first.token } });
    expect(old.res.status).toBe(401);
  });

  it("Authorization: Bearer 로도 인증된다", async () => {
    const env = makeEnv();
    const { token } = (await (await reg(env, INSTALL)).json()) as { token: string };
    const { res } = await call(env, "/ember/balance", { headers: { authorization: `Bearer ${token}` } });
    expect(await res.json()).toEqual({ credits: 100 });
  });

  it("잘못된 installId 는 400", async () => {
    const env = makeEnv();
    for (const bad of ["short", "x".repeat(65), "has space 123", 12345678, null]) {
      const res = await reg(env, bad);
      expect(res.status).toBe(400);
      expect((await errorBody(res)).error.type).toBe("invalid_request_error");
    }
  });

  it("IP 당 가입 횟수를 제한한다(기본 5회/시간)", async () => {
    const env = makeEnv();
    for (let i = 0; i < 5; i++) expect((await reg(env, `install-${i}-abcdef`, "9.9.9.9")).status).toBe(200);
    const blocked = await reg(env, "install-6-abcdef", "9.9.9.9");
    expect(blocked.status).toBe(429);
    expect((await errorBody(blocked)).error.type).toBe("rate_limit_error");
    expect(Number(blocked.headers.get("retry-after"))).toBeGreaterThan(0);
    // 다른 IP 는 영향 없음
    expect((await reg(env, "install-7-abcdef", "8.8.8.8")).status).toBe(200);
  });

  it("차단된 계정은 재등록·인증이 403", async () => {
    const env = makeEnv();
    const { token } = (await (await reg(env, INSTALL)).json()) as { token: string };
    env.db.sqlite.prepare("UPDATE accounts SET disabled = 1").run();
    expect((await call(env, "/ember/balance", { headers: { "x-api-key": token } })).res.status).toBe(403);
    expect((await reg(env, INSTALL, "5.5.5.5")).status).toBe(403);
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

  it("이미 있는 installId 의 재등록(토큰 재발급)은 새 가입과 따로, 느슨한 한도로 센다(CGNAT)", async () => {
    const env = makeEnv({ REGISTER_LIMIT: "1", REREGISTER_LIMIT: "3" });
    expect((await reg(env, "install-cgnat-0001", "100.64.0.1")).status).toBe(200);
    // 같은 IP 의 새 가입은 막힌다
    expect((await reg(env, "install-cgnat-0002", "100.64.0.1")).status).toBe(429);
    // 이미 있는 installId 의 재로그인은 된다(3회까지)
    for (let i = 0; i < 3; i++) expect((await reg(env, "install-cgnat-0001", "100.64.0.1")).status).toBe(200);
    expect((await reg(env, "install-cgnat-0001", "100.64.0.1")).status).toBe(429);
  });

  it("하루 무료 크레딧 상한(FREE_CREDITS_DAILY_CAP)에 도달하면 새 계정은 0(freeGranted: false)", async () => {
    const env = makeEnv({ FREE_CREDITS_DAILY_CAP: "250" });
    const bodies: { credits: number; freeGranted: boolean }[] = [];
    for (let i = 0; i < 4; i++) {
      bodies.push((await (await reg(env, `install-cap-${i}-xyz`, `198.51.100.${i}`)).json()) as { credits: number; freeGranted: boolean });
    }
    expect(bodies.map((b) => b.freeGranted)).toEqual([true, true, false, false]);
    expect(bodies.map((b) => b.credits)).toEqual([100, 100, 0, 0]);
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([{ count: 200 }]);
    // 재등록은 상한을 쓰지 않는다
    await reg(env, "install-cap-0-xyz", "198.51.100.9");
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([{ count: 200 }]);
  });

  it("동시에 같은 새 installId 가 와도 상한 카운터에는 한 번만 남는다", async () => {
    const env = makeEnv();
    const results = await Promise.all([1, 2, 3].map((i) => reg(env, "install-race-0001", `192.0.2.${i}`)));
    const bodies = (await Promise.all(results.map((r) => r.json()))) as { freeGranted: boolean }[];
    expect(bodies.filter((b) => b.freeGranted)).toHaveLength(1);
    expect(env.db.rows("SELECT count FROM rate_limits WHERE key = 'free:day'")).toEqual([{ count: 100 }]);
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
