// 원정 전체를 봇으로 진행 (시뮬레이션·테스트용)
import * as R from '../src/core/run.js';
import { createCombat, startCombat, finishCombat } from '../src/core/combat.js';
import { botTurn } from '../src/core/bot.js';
import { onBossKill } from '../src/core/profile.js';
import { EVENT_BY_ID } from '../src/data/events.js';
import { skillById } from '../src/data/skills.js';

const RAR = { c: 1, r: 2, e: 3, l: 4 };
const val = (id, up) => { const s = skillById(id); const dmg = s.fx.some((f) => f.t === 'dmg' || f.t === 'gamble' || f.t === 'dmgStatus' || f.t === 'dmgBlock'); return RAR[s.rar] + (up ? 0.5 : 0) + (dmg ? 1 : 0); };
export function playRun(profile, run, opts = {}) {
  let guard = 0;
  const log = (m) => { if (opts.verbose) console.log(m); };
  while (!run.over && guard++ < 3000) {
    const s = run.screen;
    switch (s.type) {
      case 'map': {
        const av = R.availableNodes(run);
        if (!av.length) throw new Error('막힘: 갈 수 있는 칸이 없음 ' + JSON.stringify(run.pos));
        const h = run.hero;
        const score = (a) => {
          if (a.boss) return 0;
          const n = R.nodeAt(run, a.r, a.c);
          const hpPct = h.hp / h.maxHp;
          return { battle: 3, elite: hpPct > 0.7 ? 5 : -2, rest: hpPct < 0.5 ? 6 : 1, shop: h.gold > 120 ? 5 : 1, event: 3, treasure: 6 }[n.t] + Math.random();
        };
        av.sort((a, b) => score(b) - score(a));
        R.enterNode(run, av[0].r, av[0].c);
        break;
      }
      case 'combat': {
        const c = createCombat(run, s.enemies, R.combatOptions(run));
        R.preCombat(run, c);
        startCombat(c);
        let t = 0;
        while (!c.over && t++ < 80) botTurn(c);
        if (!c.over) throw new Error('막힘: 전투가 80턴 안에 끝나지 않음 ' + s.enemies.join(','));
        finishCombat(c);
        if (c.over === 'lose') { run.deathBy = s.enemies.join('+'); R.finishRun(run, 'lose'); log(`패배 act${run.act} ${s.enemies}`); break; }
        if (s.kind === 'boss') onBossKill(profile, run.act);
        R.onCombatWin(run);
        break;
      }
      case 'reward': {
        const rw = s.reward;
        R.claimGold(run);
        if (rw.potion) R.claimPotion(run);
        if (rw.bossRelics && rw.bossRelics.length) R.claimRelic(run, rw.bossRelics[0]);
        else if (rw.relic) R.claimRelic(run);
        if (rw.skills.length) {
          const best = rw.skills.map((x, i) => [i, val(x.id, x.up)]).sort((a, b) => b[1] - a[1])[0][0];
          if (run.hero.skills.length < run.hero.skillSlots) R.claimSkill(run, best);
          else {
            const worst = run.hero.skills.map((x, i) => [i, val(x.id, x.up)]).sort((a, b) => a[1] - b[1])[0];
            if (val(rw.skills[best].id, rw.skills[best].up) > worst[1]) R.claimSkill(run, best, worst[0]); else R.skipSkill(run);
          }
        }
        R.leaveReward(run);
        break;
      }
      case 'actClear': R.nextAct(run); if (run.act > (opts.maxAct || 4) && !run.over) R.finishRun(run, 'win'); break;
      case 'event': {
        const ev = EVENT_BY_ID[s.id];
        const ok = ev.choices.map((c, i) => i).filter((i) => R.eventChoiceOk(run, ev.choices[i]));
        R.chooseEvent(run, ok[Math.floor(Math.random() * ok.length)]);
        break;
      }
      case 'eventResult': R.backToMap(run); break;
      case 'skillPick': R.learnSkill(run, s.skills[0], run.hero.skills.length >= run.hero.skillSlots ? 0 : undefined); R.backToMap(run); break;
      case 'remove': R.removeSkill(run, 0); break;
      case 'shop': {
        for (let i = 0; i < s.stock.length; i++) {
          const it = s.stock[i];
          if (it.k === 'skill' && run.hero.skills.length >= run.hero.skillSlots) continue;
          if (run.hero.gold - it.price > 40) R.buy(run, i);
        }
        R.backToMap(run);
        break;
      }
      case 'rest': {
        if (run.hero.hp < run.hero.maxHp * 0.65) R.restHeal(run);
        else { const i = run.hero.skills.findIndex((x) => !x.up); if (i >= 0) R.restUpgrade(run, i); else R.restHeal(run); }
        R.restTalk(run);
        R.backToMap(run);
        break;
      }
      case 'treasure': R.openTreasure(run); R.backToMap(run); break;
      case 'end': break;
      default: throw new Error('알 수 없는 화면 ' + s.type);
    }
  }
  if (!run.over) throw new Error('막힘: 3000단계 초과');
  return run;
}
