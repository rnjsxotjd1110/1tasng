import { h, sheet, btn } from './dom.js';
import { App, go, bgm } from './app.js';
import { logoSVG, iconSVG } from '../art/logo.js';
import { hubScreen } from './scr_hub.js';
import { settingsSheet } from './scr_misc.js';
import { playVN } from './vn.js';
import { saveSoon } from './app.js';

export function titleScreen(el) {
  bgm('title');
  el.classList.add('title-scr');
  const hasSave = App.p.stats.runs > 0 || App.p.tutorial.intro;
  const moon = h('div.title-moon', { html: iconSVG(180) });
  el.append(
    moon,
    h('div', { html: logoSVG(), style: { width: '100%', display: 'flex', justifyContent: 'center' } }),
    h('div.title-sub', { text: '별장막의 미궁' }),
    h('div.title-menu',
      h('button.tmenu.main', { type: 'button', onclick: start }, hasSave ? '이어서 하기' : '여정 시작'),
      h('button.tmenu', { type: 'button', onclick: () => settingsSheet() }, '설정'),
      h('button.tmenu', { type: 'button', onclick: credits }, '만든 이야기'),
    ),
    h('div.title-foot', { text: 'v1.0.0' }),
  );
  function start() {
    if (!App.p.tutorial.intro) {
      App.p.tutorial.intro = true;
      saveSoon();
      playVN({ bg: 'camp', who: 'lyra', title: '프롤로그', lines: INTRO, onEnd: () => go(hubScreen, 'home') });
    } else go(hubScreen, 'home');
  }
}

const INTRO = [
  { s: 'lyra', e: 'surprise', t: '너는 드디어 눈을 떴어! 나는 사흘 동안 네 옆을 지켰어.' },
  { s: 'me', t: '나는 아무것도 기억나지 않아. 여기는 어디야?' },
  { s: 'lyra', e: 'smile', t: '여기는 등불 야영지야. 나는 견습 별마녀 리라라고 해.' },
  { s: 'lyra', e: 'normal', t: '백 년 전에 달이 깨졌고 그 조각들이 저 아래에 미궁을 만들었어.' },
  { s: 'lyra', e: 'normal', t: '미궁은 밤마다 모양이 바뀌어. 사람들은 그곳을 별장막 미궁이라고 불러.' },
  { s: 'lyra', e: 'surprise', t: '너는 쓰러져 있을 때도 주사위 모양의 별 조각을 꼭 쥐고 있었어.' },
  { s: 'lyra', e: 'smile', t: '그 주사위는 운명 주사위야. 운명 주사위는 미궁의 힘을 다룰 수 있어.' },
  { s: 'me', t: '그럼 나도 미궁에 들어갈 수 있을까?' },
  { s: 'lyra', e: 'happy', t: '너는 당연히 들어갈 수 있어! 너는 오늘부터 우리 야영지의 별지기야.' },
  { s: 'lyra', e: 'normal', t: '미궁 깊은 곳에서 달 조각을 모으면 우리는 달을 되살릴 수 있어.' },
  { s: 'lyra', e: 'smile', t: '나는 야영지에서 너를 기다릴게. 너는 꼭 무사히 돌아와야 해!' },
];

function credits() {
  sheet((b) => {
    b.innerHTML = `<p class="muted" style="line-height:1.8">STARVEIL · 별장막의 미궁<br>
    주사위 운명 로그라이크 RPG<br><br>
    기획 · 프로그래밍 · 그림 · 소리<br>모두 코드로 만들었어요.<br><br>
    등장인물: 리라 · 미오 · 세렌<br>
    <span class="dim">오프라인에서도 플레이할 수 있어요.</span></p>`;
  }, { title: '만든 이야기', cls: 'small' });
}
