export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const deepCopy = (o) => JSON.parse(JSON.stringify(o));
export function fmt(n) {
  n = Math.floor(n);
  if (Math.abs(n) < 10000) return n.toLocaleString('ko-KR');
  const units = [[1e12, '조'], [1e8, '억'], [1e4, '만']];
  for (const [v, u] of units) if (Math.abs(n) >= v) {
    const x = n / v;
    return (x >= 100 ? Math.floor(x) : Math.floor(x * 10) / 10).toLocaleString('ko-KR') + u;
  }
  return String(n);
}
export function todayKey(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function byId(list) { const m = {}; for (const x of list) m[x.id] = x; return m; }
// 한국어 조사: josa('세렌', '와/과') → '세렌과'
export function josa(word, pair) {
  const w = String(word);
  const [a, b] = pair.split('/');
  const ch = w.replace(/[^가-힣0-9a-zA-Z]+$/g, '').slice(-1);
  let has = false;
  if (/[가-힣]/.test(ch)) has = (ch.charCodeAt(0) - 0xac00) % 28 !== 0;
  else if (/[0-9]/.test(ch)) has = '013678'.includes(ch);
  // 받침이 있으면 뒤(을/이/과/은), 없으면 앞(를/가/와/는) — 단 pair 순서는 '받침없음/받침있음' 기준
  const noB = ['를', '가', '와', '는', '로'].includes(a) ? a : b;
  const yesB = noB === a ? b : a;
  return w + (has ? yesB : noB);
}
