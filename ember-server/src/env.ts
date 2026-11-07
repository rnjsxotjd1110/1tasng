// 환경 변수 정의와 기본값 해석.

export interface Env {
  DB: D1Database;
  // 비밀값(wrangler secret put)
  ANTHROPIC_API_KEY?: string;
  GOOGLE_SERVICE_ACCOUNT_JSON?: string;
  ADMIN_KEY?: string;
  /** Google sub 의 HMAC-SHA256 키(무료 크레딧 1회 지급 기록용). 비밀값. */
  SUB_HASH_SECRET?: string;
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
  REREGISTER_LIMIT?: string;
  FREE_CREDITS_DAILY_CAP?: string;
  MAX_CONCURRENT_REQUESTS?: string;
  INFLIGHT_STALE_SECONDS?: string;
  ALLOW_TEST_PURCHASES?: string;
  REPORTS_DAILY_CAP?: string;
  GOOGLE_OAUTH_CLIENT_IDS?: string;
  REQUIRE_GOOGLE_SIGNIN?: string;
  LEGACY_UNLINKED_UNTIL?: string;
  PRODUCT_PRICES_KRW?: string;
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
  /** 이미 있는 installId 의 재등록(토큰 재발급) 제한: IP(/64)당 창(registerWindowSeconds)당 횟수. nonce 도 이 한도. */
  reregisterLimit: number;
  /** 하루(UTC) 동안 새 계정에 줄 수 있는 무료 크레딧 합계. 다 쓰면 새 계정은 0. */
  freeCreditsDailyCap: number;
  /** 계정당 동시에 처리 중인 /v1/messages 수 상한 */
  maxConcurrentRequests: number;
  /** 이 시간(초)보다 오래된 처리 중 표시는 죽은 것으로 보고 무시한다(워커가 중간에 죽은 경우). */
  inflightStaleSeconds: number;
  /** true 면 라이선스 테스트 구매(purchaseType 0)에도 크레딧을 준다. 운영에서는 false. */
  allowTestPurchases: boolean;
  /** 하루(UTC) 전체 신고 수 상한 */
  reportsDailyCap: number;
  /** Google ID 토큰의 aud 로 허용할 OAuth 클라이언트 ID(웹 클라이언트). 비면 Google 로그인을 쓸 수 없다. */
  googleClientIds: readonly string[];
  /** true(기본)면 가입(POST /ember/register)에 idToken 이 꼭 필요하다. */
  requireGoogleSignin: boolean;
  /** 이 시각(유닉스 초) 이후로 Google 에 연결하지 않은 예전 계정은 403 google_required. null 이면 계속 쓸 수 있다. */
  legacyUnlinkedUntil: number | null;
  /**
   * 상품 ID → 1개 가격(원, KRW). Play 확인 응답에 결제 금액이 없을 때 구매 기록·환불 계산에 쓴다.
   * 비어 있으면 금액을 모르는 구매의 환불 견적은 금액 없이 나온다(README 6장 "환불·청약철회 처리").
   */
  productPricesKrw: Readonly<Record<string, number>>;
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
  reregisterLimit: 30,
  freeCreditsDailyCap: 20000,
  maxConcurrentRequests: 2,
  inflightStaleSeconds: 1800,
  reportsDailyCap: 500,
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

/** PRODUCT_PRICES_KRW JSON(상품 ID → 1개 가격, 원)을 읽는다. 비었거나 형식이 틀리면 빈 표(틀리면 오류 로그). */
export function parseProductPrices(raw: string | undefined): Readonly<Record<string, number>> {
  if (raw === undefined || raw.trim() === "") return {};
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error("not an object");
    const out: Record<string, number> = {};
    for (const [id, price] of Object.entries(parsed)) {
      if (typeof price !== "number" || !Number.isFinite(price) || price <= 0) throw new Error(`invalid price for ${id}`);
      out[id] = price;
    }
    return out;
  } catch (err) {
    console.error("PRODUCT_PRICES_KRW 형식 오류, 무시함:", err);
    return {};
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

/** 쉼표로 구분한 OAuth 클라이언트 ID 목록 */
export function parseClientIds(raw: string | undefined): string[] {
  return (raw ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s !== "");
}

/** REQUIRE_GOOGLE_SIGNIN: "false"(대소문자·공백 무시)일 때만 끈다. 비었거나 다른 값이면 켠다. */
export function parseRequireGoogleSignin(raw: string | undefined): boolean {
  return raw?.trim().toLowerCase() !== "false";
}

/**
 * LEGACY_UNLINKED_UNTIL(ISO 날짜·시각)을 유닉스 초로. 비었으면 null(제한 없음).
 * 날짜만 쓰면 그날 00:00 UTC. 형식이 틀리면 오류를 남기고 null(예전 계정을 막지 않는다).
 */
export function parseLegacyUnlinkedUntil(raw: string | undefined): number | null {
  const v = raw?.trim() ?? "";
  if (v === "") return null;
  const ms = Date.parse(v);
  if (!/^\d{4}-\d{2}-\d{2}/.test(v) || !Number.isFinite(ms)) {
    console.error(`LEGACY_UNLINKED_UNTIL 값이 잘못됨(${raw}), 무시함`);
    return null;
  }
  return Math.floor(ms / 1000);
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
    reregisterLimit: num(env.REREGISTER_LIMIT, DEFAULTS.reregisterLimit, 1, true),
    freeCreditsDailyCap: num(env.FREE_CREDITS_DAILY_CAP, DEFAULTS.freeCreditsDailyCap, 0, true),
    maxConcurrentRequests: num(env.MAX_CONCURRENT_REQUESTS, DEFAULTS.maxConcurrentRequests, 1, true),
    inflightStaleSeconds: num(env.INFLIGHT_STALE_SECONDS, DEFAULTS.inflightStaleSeconds, 60, true),
    allowTestPurchases: env.ALLOW_TEST_PURCHASES?.trim().toLowerCase() === "true",
    reportsDailyCap: num(env.REPORTS_DAILY_CAP, DEFAULTS.reportsDailyCap, 1, true),
    googleClientIds: parseClientIds(env.GOOGLE_OAUTH_CLIENT_IDS),
    requireGoogleSignin: parseRequireGoogleSignin(env.REQUIRE_GOOGLE_SIGNIN),
    legacyUnlinkedUntil: parseLegacyUnlinkedUntil(env.LEGACY_UNLINKED_UNTIL),
    productPricesKrw: parseProductPrices(env.PRODUCT_PRICES_KRW),
  };
}
