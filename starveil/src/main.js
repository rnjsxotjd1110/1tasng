import { boot, go } from './ui/app.js';
import { titleScreen } from './ui/scr_title.js';

function start() {
  const root = document.getElementById('app');
  try {
    boot(root);
    go(titleScreen);
  } catch (e) {
    root.innerHTML = `<div style="padding:24px;color:#fff;font-family:sans-serif">오류가 발생했어요: ${e && e.message}</div>`;
    throw e;
  }
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
window.addEventListener('error', (e) => { try { console.error('[STARVEIL]', e.message, e.filename, e.lineno); } catch (x) { /* 무시 */ } });
