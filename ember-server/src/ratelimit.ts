// D1 기반 고정 창 요청 제한.
import { ApiError } from "./http";

export const DAY_SECONDS = 86400;

/** key 의 이번 창 카운터를 1 올리고, limit 을 넘으면 429 를 던진다. */
export async function enforceRateLimit(
  db: D1Database,
  key: string,
  limit: number,
  windowSeconds: number,
  now: number,
): Promise<void> {
  const windowStart = Math.floor(now / windowSeconds) * windowSeconds;
  const row = await db
    .prepare(
      `INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 1)
       ON CONFLICT (key, window_start) DO UPDATE SET count = count + 1
       RETURNING count`,
    )
    .bind(key, windowStart)
    .first<{ count: number }>();
  const count = row?.count ?? 1;
  if (count > limit) {
    const retryAfter = Math.max(1, windowStart + windowSeconds - now);
    throw new ApiError(429, "rate_limit_error", "too many requests, please try again later", {
      "retry-after": String(retryAfter),
    });
  }
}

/**
 * 하루(UTC) 단위 합계 카운터에 amount 를 더한다. 더한 뒤 합계가 cap 을 넘으면 더하지 않고 false.
 * 한 SQL 문(UPSERT … WHERE)이라 동시에 불려도 cap 을 넘지 않는다.
 */
export async function tryAddDaily(db: D1Database, key: string, amount: number, cap: number, now: number): Promise<boolean> {
  if (amount <= 0) return true;
  if (amount > cap) return false;
  const day = Math.floor(now / DAY_SECONDS) * DAY_SECONDS;
  const row = await db
    .prepare(
      `INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, ?)
       ON CONFLICT (key, window_start) DO UPDATE SET count = count + excluded.count
         WHERE count + excluded.count <= ?
       RETURNING count`,
    )
    .bind(key, day, amount, cap)
    .first<{ count: number }>();
  return row !== null;
}

/** tryAddDaily 로 더한 양을 되돌린다(예: 계정이 이미 있어 무료 크레딧을 주지 않은 경우). */
export async function subtractDaily(db: D1Database, key: string, amount: number, now: number): Promise<void> {
  if (amount <= 0) return;
  const day = Math.floor(now / DAY_SECONDS) * DAY_SECONDS;
  await db
    .prepare("UPDATE rate_limits SET count = MAX(0, count - ?) WHERE key = ? AND window_start = ?")
    .bind(amount, key, day)
    .run();
}

/** IPv6 문자열을 8개의 16비트 값으로 푼다. 형식이 틀리면 null. */
function parseIpv6(ip: string): number[] | null {
  let s = ip.trim().toLowerCase();
  const zone = s.indexOf("%");
  if (zone !== -1) s = s.slice(0, zone);
  // 끝이 IPv4 표기(::ffff:1.2.3.4)면 16비트 두 개로 바꾼다.
  const v4 = /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(s);
  if (v4) {
    const b = v4.slice(1).map(Number);
    if (b.some((x) => x > 255)) return null;
    s = s.slice(0, v4.index) + `${((b[0]! << 8) | b[1]!).toString(16)}:${((b[2]! << 8) | b[3]!).toString(16)}`;
  }
  const halves = s.split("::");
  if (halves.length > 2) return null;
  const head = halves[0] ? halves[0].split(":") : [];
  const tail = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  const missing = 8 - head.length - tail.length;
  if (halves.length === 1 ? missing !== 0 : missing < 1) return null;
  const groups = [...head, ...Array<string>(halves.length === 2 ? missing : 0).fill("0"), ...tail];
  const out: number[] = [];
  for (const g of groups) {
    if (!/^[0-9a-f]{1,4}$/.test(g)) return null;
    out.push(parseInt(g, 16));
  }
  return out.length === 8 ? out : null;
}

/**
 * 요청 제한용 IP 키. IPv4 는 주소 전체, IPv6 는 /64 (한 가입자가 보통 /64 이상을 받아 주소를 마음대로 바꿀 수 있다).
 * IPv4 매핑 IPv6(::ffff:1.2.3.4)는 IPv4 로 본다. 헤더가 없거나 형식이 틀리면 원문(최대 64자) 그대로.
 */
export function ipRateKey(raw: string | null): string {
  const ip = (raw ?? "").trim();
  if (ip === "") return "unknown";
  if (!ip.includes(":")) return ip.slice(0, 64);
  const g = parseIpv6(ip);
  if (!g) return ip.slice(0, 64);
  if (g.slice(0, 5).every((x) => x === 0) && g[5] === 0xffff) {
    return `${g[6]! >> 8}.${g[6]! & 255}.${g[7]! >> 8}.${g[7]! & 255}`;
  }
  return `${g.slice(0, 4).map((x) => x.toString(16)).join(":")}::/64`;
}

export function clientIpKey(req: Request): string {
  return ipRateKey(req.headers.get("cf-connecting-ip"));
}

/** 이틀보다 오래된 카운터 삭제(cron). */
export async function purgeOldRateLimits(db: D1Database, now: number): Promise<void> {
  await db.prepare("DELETE FROM rate_limits WHERE window_start < ?").bind(now - 2 * 86400).run();
}
