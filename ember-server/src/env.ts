// 환경 변수 정의와 기본값 해석.

export interface Env {
  DB: D1Database;
  // 비밀값(wrangler secret put)
  ANTHROPIC_API_KEY?: string;
  GOOGLE_SERVICE_ACCOUNT_JSON?: string;
  ADMIN_KEY?: string;
  // 공개 설정값(wrangler.toml [vars])
  PACKAGE_NAME?: string;
  FREE_CREDITS?: string;
  MARKUP?: string;
  MAX_OUTPUT_TOKENS?: string;
  MAX_BODY_BYTES?: string;
  PRODUCTS?: string;
  REGISTER_LIMIT?: string;
  REGISTER_WINDOW_SECONDS?: string;
  MESSAGES_LIMIT?: string;
  MESSAGES_WINDOW_SECONDS?: string;
  ANTHROPIC_BASE_URL?: string;
  INTEGRITY_MODE?: string;
}

export interface Config {
  packageName: string;
  freeCredits: number;
  markup: number;
  maxOutputTokens: number;
  maxBodyBytes: number;
  products: Readonly<Record<string, number>>;
  registerLimit: number;
  registerWindowSeconds: number;
  messagesLimit: number;
  messagesWindowSeconds: number;
  anthropicBaseUrl: string;
  integrityMode: IntegrityMode;
}

/**
 * 가입 시 Play Integrity 확인 방식.
 * - off: 확인하지 않는다(예전과 같음).
 * - grant: 확인에 통과한 새 설치에만 무료 크레딧을 준다. 실패해도 가입은 된다(크레딧 0).
 * - require: 확인에 통과하지 못하면 가입 자체를 거절한다(403 integrity_failed).
 */
export const INTEGRITY_MODES = ["off", "grant", "require"] as const;
export type IntegrityMode = (typeof INTEGRITY_MODES)[number];

export const DEFAULT_PRODUCTS: Readonly<Record<string, number>> = {
  ember_credits_500: 500,
  ember_credits_1500: 1650,
  ember_credits_5000: 5750,
};

export const DEFAULTS = {
  packageName: "app.ember.ideas",
  freeCredits: 40,
  markup: 1.5,
  maxOutputTokens: 64000,
  maxBodyBytes: 2 * 1024 * 1024,
  registerLimit: 5,
  registerWindowSeconds: 3600,
  messagesLimit: 30,
  messagesWindowSeconds: 600,
  anthropicBaseUrl: "https://api.anthropic.com",
  integrityMode: "off",
} as const;

/** 숫자 설정값을 읽는다. 비었거나 잘못됐거나 min 미만이면 기본값. */
function num(raw: string | undefined, fallback: number, min: number, integer: boolean): number {
  if (raw === undefined || raw.trim() === "") return fallback;
  const v = Number(raw);
  if (!Number.isFinite(v) || v < min) return fallback;
  if (integer && !Number.isInteger(v)) return fallback;
  return v;
}

/** PRODUCTS JSON 을 읽는다. 형식이 틀리면 기본 상품표를 쓴다. */
export function parseProducts(raw: string | undefined): Readonly<Record<string, number>> {
  if (raw === undefined || raw.trim() === "") return DEFAULT_PRODUCTS;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error("not an object");
    const out: Record<string, number> = {};
    for (const [id, credits] of Object.entries(parsed)) {
      if (typeof credits !== "number" || !Number.isInteger(credits) || credits <= 0) {
        throw new Error(`invalid credits for ${id}`);
      }
      out[id] = credits;
    }
    return out;
  } catch (err) {
    console.error("PRODUCTS 형식 오류, 기본값 사용:", err);
    return DEFAULT_PRODUCTS;
  }
}

/** INTEGRITY_MODE 를 읽는다. 비었으면 off, 모르는 값이면 오류를 남기고 off. */
export function parseIntegrityMode(raw: string | undefined): IntegrityMode {
  const v = raw?.trim().toLowerCase() ?? "";
  if (v === "") return DEFAULTS.integrityMode;
  if ((INTEGRITY_MODES as readonly string[]).includes(v)) return v as IntegrityMode;
  console.error(`INTEGRITY_MODE 값이 잘못됨(${raw}), off 로 동작`);
  return DEFAULTS.integrityMode;
}

export function loadConfig(env: Env): Config {
  return {
    packageName: env.PACKAGE_NAME?.trim() || DEFAULTS.packageName,
    freeCredits: num(env.FREE_CREDITS, DEFAULTS.freeCredits, 0, true),
    markup: num(env.MARKUP, DEFAULTS.markup, 1, false),
    maxOutputTokens: num(env.MAX_OUTPUT_TOKENS, DEFAULTS.maxOutputTokens, 1, true),
    maxBodyBytes: num(env.MAX_BODY_BYTES, DEFAULTS.maxBodyBytes, 1024, true),
    products: parseProducts(env.PRODUCTS),
    registerLimit: num(env.REGISTER_LIMIT, DEFAULTS.registerLimit, 1, true),
    registerWindowSeconds: num(env.REGISTER_WINDOW_SECONDS, DEFAULTS.registerWindowSeconds, 1, true),
    messagesLimit: num(env.MESSAGES_LIMIT, DEFAULTS.messagesLimit, 1, true),
    messagesWindowSeconds: num(env.MESSAGES_WINDOW_SECONDS, DEFAULTS.messagesWindowSeconds, 1, true),
    anthropicBaseUrl: (env.ANTHROPIC_BASE_URL?.trim() || DEFAULTS.anthropicBaseUrl).replace(/\/+$/, ""),
    integrityMode: parseIntegrityMode(env.INTEGRITY_MODE),
  };
}
