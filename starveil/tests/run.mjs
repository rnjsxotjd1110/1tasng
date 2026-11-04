// 헤드리스 테스트: node tests/run.mjs
import { HEROINES } from '../src/data/heroines/index.js';
import { SKILLS, resolveSkill } from '../src/data/skills.js';
import { RELICS } from '../src/data/relics.js';
import { ENEMIES, ACTS } from '../src/data/enemies.js';
import { EVENTS } from '../src/data/events.js';
import { GIFT_BY_ID } from '../src/data/gifts.js';
import { CLASSES } from '../src/data/classes.js';
import { defaultProfile, exportSave, importSave, doTalk, doGift, addGift, addAff, heroineState, ensureDaily, claimMission, crystalStored, buyTree, onRunEnd, onBossKill } from '../src/core/profile.js';
import { newRun, genMap, ROWS, COLS, addRelic } from '../src/core/run.js';
import { createCombat, startCombat, endTurn } from '../src/core/combat.js';
import { botTurn } from '../src/core/bot.js';
import { playRun } from '../tools/autopilot.mjs';
import { fxText, skillDesc } from '../src/ui/describe.js';

let checks = 0, fails = 0;
const ok = (cond, msg) => { checks++; if (!cond) { fails++; console.log('  ✗ ' + msg); } };
const section = (n) => console.log('· ' + n);

// ───── 대사 규칙 ─────
const EXPR = ['normal', 'smile', 'happy', 'blush', 'surprise', 'sad', 'pout'];
const BG = ['camp', 'lake', 'kitchen', 'market', 'library', 'hill', 'ruins'];
function lintLine(t, where) {
  const parts = t.split(/[.!?…~]+/).map((x) => x.trim()).filter(Boolean);
  for (const p of parts) {
    const hangul = p.replace(/[^가-힣]/g, '');
    if (hangul.endsWith('다')) ok(false, `'다'로 끝남 (${where}): ${t}`);
  }
  ok(!/(^|[.!?…]\s*)[^\s,]+,/.test(t), `단어+쉼표 (${where}): ${t}`);
}
section('대사 규칙');
for (const [id, d] of Object.entries(HEROINES)) {
  const all = [];
  const push = (arr, w) => arr.forEach((l) => all.push([l, w]));
  for (const k of ['low', 'mid', 'high']) { push(d.greet[k], 'greet'); push(d.touch[k], 'touch'); }
  for (const t of d.talks) { push(t.lines, t.id); for (const c of t.choices) { all.push([{ t: c.t }, t.id]); push(c.reply, t.id); } ok(t.choices.length === 3, `${t.id} 선택지 3개`); }
  for (const k in d.giftLines) push(d.giftLines[k], 'gift');
  for (const s of d.scenes) { push(s.lines, 'scene' + s.lv); ok(BG.includes(s.bg), `${id} 배경 ${s.bg}`); }
  for (const k in d.battle) push(d.battle[k], 'battle');
  for (const k in d.minigame) push(d.minigame[k], 'mini');
  for (const [l, w] of all) {
    lintLine(l.t, `${id}/${w}`);
    if (l.e) ok(EXPR.includes(l.e), `${id} 표정 ${l.e}`);
    ok(l.s !== 'narr', `${id} 내레이션 금지`);
  }
  ok(d.talks.length === 20 && d.scenes.length === 10, `${id} 대화 20·장면 10`);
  for (const k of ['love', 'like', 'dislike']) for (const g of d.gifts[k]) ok(!!GIFT_BY_ID[g], `${id} 선물 ${g}`);
}
for (const e of ENEMIES) { if (e.intro) lintLine(e.intro, e.id); if (e.phaseLine) lintLine(e.phaseLine, e.id); }
for (const ev of EVENTS) { lintLine(ev.text, ev.id); for (const c of ev.choices) { for (const k of ['res', 'win', 'lose']) if (c[k]) lintLine(c[k], ev.id); } }

// ───── 데이터 ─────
section('데이터 무결성');
for (const s of SKILLS) {
  const a = resolveSkill(s.id, false), b = resolveSkill(s.id, true);
  ok(fxText(a.fx).length > 0, `기술 설명 ${s.id}`);
  ok(skillDesc(b).length > 0, `강화 설명 ${s.id}`);
  ok(JSON.stringify(a) !== JSON.stringify({ ...b, name: a.name, upgraded: undefined }), `강화 차이 ${s.id}`);
}
for (const c of CLASSES) { ok(c.skills.every((id) => SKILLS.find((s) => s.id === id)), `시작 기술 ${c.id}`); ok(!!RELICS.find((r) => r.id === c.relic), `시작 유물 ${c.id}`); }
for (let a = 1; a <= 4; a++) for (const k of ['easy', 'normal', 'elite']) for (const g of ACTS[a][k]) for (const id of g) ok(!!ENEMIES.find((e) => e.id === id), `조우 ${id}`);

// ───── 맵 ─────
section('맵 연결성');
for (let i = 0; i < 200; i++) {
  const p = defaultProfile();
  const run = newRun(p, { cls: 'knight', seed: 7 + i * 31 });
  const rows = run.map.rows;
  ok(rows[0].some(Boolean), '첫 줄 존재');
  for (let r = 0; r < ROWS - 1; r++) for (const n of rows[r]) if (n) ok(n.next.length > 0 && n.next.every((c) => rows[r + 1][c]), `노드 ${r}:${n.c} 다음 칸`);
  for (const n of rows[ROWS - 1]) if (n) ok(n.t === 'rest', '보스 앞 휴식');
}

// ───── 유물 전투 ─────
section('유물 훅');
for (const r of RELICS) {
  const p = defaultProfile();
  const run = newRun(p, { cls: r.cls || 'knight', seed: 99 });
  addRelic(run, r.id);
  try {
    const c = createCombat(run, ['moss_slime', 'spider'], { seed: 5, kind: 'normal' });
    startCombat(c);
    for (let t = 0; t < 30 && !c.over; t++) botTurn(c);
    ok(true, r.id);
  } catch (e) { ok(false, `유물 ${r.id}: ${e.message}`); }
}

// ───── 원정 시뮬레이션 ─────
section('원정 시뮬레이션(막힘 검사)');
let runs = 0, wins = 0;
const t0 = Date.now();
for (const c of CLASSES) for (let i = 0; i < 60; i++) {
  const p = defaultProfile();
  p.unlocked.act4 = true;
  p.tree = i % 2 ? { hp: 6, heal: 3, rest: 3, gold: 3, upgrade: 2 } : {};
  p.classes[c.id].xp = i % 3 ? 4000 : 0;
  try {
    const run = newRun(p, { cls: c.id, phase: i % 7, seed: 5000 + i * 131, companion: { id: ['lyra', 'mio', 'seren'][i % 3], lv: i % 11 } });
    playRun(p, run);
    runs++; if (run.over === 'win') wins++;
    const res = onRunEnd(p, run);
    ok(res.shards >= 0 && Number.isFinite(res.shards), '별조각 정산');
  } catch (e) { ok(false, `${c.id} #${i}: ${e.message}`); }
}
console.log(`  ${runs}런 완료, 완주 ${wins}회, ${((Date.now() - t0) / 1000).toFixed(1)}초`);

// ───── 프로필 ─────
section('프로필·저장');
{
  const p = defaultProfile();
  addGift(p, 'star_candy', 3);
  const d = HEROINES.lyra;
  const r1 = doGift(p, 'lyra', d, 'star_candy');
  ok(r1 && r1.kind === 'love', '선물 반응');
  ok(doGift(p, 'lyra', d, 'star_candy') === null, '선물 하루 제한');
  const t = d.talks[0];
  for (let i = 0; i < 3; i++) ok(!!doTalk(p, 'lyra', t, 0), '대화');
  ok(doTalk(p, 'lyra', t, 0) === null, '대화 하루 제한');
  const ups = addAff(p, 'mio', 700);
  ok(ups.length === 10 && p.heroines.mio.lv === 10, '호감도 레벨업');
  ok(p.heroines.mio.outfits.includes('festival'), '의상 해금');
  const code = exportSave(p);
  const q = importSave(code);
  ok(q.heroines.mio.lv === 10 && q.inv.gifts.star_candy === 4, '저장 코드 왕복');
  ensureDaily(p);
  p.daily.missions[0].prog = p.daily.missions[0].n;
  ok(claimMission(p, 0), '임무 보상');
  p.crystal.last = Date.now() - 3 * 3600000;
  ok(crystalStored(p) >= 100, '수정 누적');
  p.shards = 1000;
  ok(buyTree(p, 'hp') && p.tree.hp === 1, '트리 구매');
  ok(!buyTree(p, 'slot'), '트리 선행 조건');
  const news = onBossKill(p, 1);
  ok(news.some((n) => n.k === 'class') && p.unlocked.classes.includes('witch'), '보스 해금');
  ok(onBossKill(p, 1).length === 0, '두 번째 처치는 해금 없음');
}

console.log(`\n${checks} checks, ${fails} failures`);
process.exit(fails ? 1 : 0);
