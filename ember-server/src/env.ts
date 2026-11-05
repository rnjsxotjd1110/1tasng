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
}

export const DEFAULT_PRODUCTS: Readonly<Record<string, number>> = {
  ember_credits_500: 500,
  ember_credits_1500: 1650,
  ember_credits_5000: 5750,
};

export const DEFAULTS = {
  packageName: "app.ember.ideas",
  freeCredits: 150,
  markup: 1.5,
  maxOutputTokens: 64000,
  maxBodyBytes: 2 * 1024 * 1024,
  registerLimit: 5,
  registerWindowSeconds: 3600,
  messagesLimit: 30,
  messagesWindowSeconds: 600,
  anthropicBaseUrl: "https://api.anthropic.com",
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
  };
}
