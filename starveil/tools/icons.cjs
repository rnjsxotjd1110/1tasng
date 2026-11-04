// 앱 아이콘 PNG 렌더링 (안드로이드 mipmap + 웹용)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const { iconSVG } = await import('../src/art/logo.js');
  const root = path.join(__dirname, '..');
  const b = await chromium.launch();
  const sizes = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
  const pg = await b.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: 1 });
  const render = async (size, file, round) => {
    await pg.setViewportSize({ width: size, height: size });
    const svg = iconSVG(size).replace('rx="112"', round ? 'rx="256"' : 'rx="112"');
    await pg.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await pg.screenshot({ path: file, omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
  };
  for (const [d, s] of Object.entries(sizes)) {
    const dir = path.join(root, 'android', 'res', 'mipmap-' + d);
    fs.mkdirSync(dir, { recursive: true });
    await render(s, path.join(dir, 'ic_launcher.png'), false);
    await render(s, path.join(dir, 'ic_launcher_round.png'), true);
  }
  fs.mkdirSync(path.join(root, 'dist'), { recursive: true });
  await render(512, path.join(root, 'dist', 'icon-512.png'), false);
  await b.close();
  console.log('icons ok');
})();
