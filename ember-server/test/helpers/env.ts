// 워커를 노드에서 직접 호출하기 위한 env·ctx·요청 도우미.
import worker from "../../src/index";
import type { Env } from "../../src/env";
import { FakeD1 } from "./d1";

export interface TestCtx extends ExecutionContext {
  /** waitUntil 로 넘어온 작업이 모두 끝날 때까지 기다린다. */
  settle(): Promise<void>;
}

export function makeCtx(): TestCtx {
  const pending: Promise<unknown>[] = [];
  return {
    waitUntil(p: Promise<unknown>): void {
      pending.push(p);
    },
    passThroughOnException(): void {},
    props: {},
    async settle(): Promise<void> {
      while (pending.length > 0) await Promise.allSettled(pending.splice(0));
    },
  } as unknown as TestCtx;
}

export interface TestEnv extends Env {
  db: FakeD1;
}

export function makeEnv(overrides: Partial<Env> = {}): TestEnv {
  const db = new FakeD1();
  return {
    DB: db as unknown as D1Database,
    db,
    ANTHROPIC_API_KEY: "sk-ant-test-server-key",
    ADMIN_KEY: "test-admin-key",
    // 테스트는 무료 크레딧 100 을 기준으로 계산한다(운영 기본값은 40).
    FREE_CREDITS: "100",
    ...overrides,
  };
}

export const BASE = "https://ember.test";

export async function call(
  env: Env,
  path: string,
  init: RequestInit & { json?: unknown } = {},
  ctx: TestCtx = makeCtx(),
): Promise<{ res: Response; ctx: TestCtx }> {
  const { json, ...rest } = init;
  const headers = new Headers(rest.headers);
  if (json !== undefined) headers.set("content-type", "application/json");
  const req = new Request(BASE + path, {
    ...rest,
    headers,
    body: json !== undefined ? JSON.stringify(json) : rest.body,
  });
  const res = await worker.fetch(req, env, ctx);
  return { res, ctx };
}

let ipCounter = 0;
/** 계정을 하나 만들고 토큰을 돌려준다(매번 다른 IP 로 가입 제한을 피한다). */
export async function register(env: Env, installId = crypto.randomUUID()): Promise<{ token: string; credits: number }> {
  ipCounter++;
  const { res } = await call(env, "/ember/register", {
    method: "POST",
    json: { installId },
    headers: { "cf-connecting-ip": `10.0.0.${ipCounter}` },
  });
  if (res.status !== 200) throw new Error(`register failed: ${res.status} ${await res.text()}`);
  return (await res.json()) as { token: string; credits: number };
}

export async function setCredits(env: TestEnv, token: string, credits: number): Promise<void> {
  const { sha256Hex } = await import("../../src/util");
  env.db.sqlite.prepare("UPDATE accounts SET credits = ? WHERE token_hash = ?").run(credits, await sha256Hex(token));
}

/** 이 토큰의 계정에 지급 완료된 구매 기록을 넣어 결제 계정으로 만든다(크레딧은 바꾸지 않음). */
export async function markPaid(env: TestEnv, token: string, purchaseToken = `paid-${crypto.randomUUID()}`): Promise<void> {
  const { sha256Hex } = await import("../../src/util");
  env.db.sqlite
    .prepare(
      `INSERT INTO purchases (purchase_token, account_id, product_id, credits, credited, created_at)
       SELECT ?, id, 'ember_credits_500', 500, 1, ? FROM accounts WHERE token_hash = ?`,
    )
    .run(purchaseToken, Math.floor(Date.now() / 1000), await sha256Hex(token));
}

export async function errorBody(res: Response): Promise<{ type: string; error: { type: string; message: string } }> {
  return (await res.json()) as { type: string; error: { type: string; message: string } };
}
