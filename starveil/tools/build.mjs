// 단일 HTML 빌드: dist/index.html (웹·아티팩트·APK 공용)
import { build } from 'esbuild';
import fs from 'fs';
import path from 'path';
import { iconSVG } from '../src/art/logo.js';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const out = path.join(root, 'dist');
fs.mkdirSync(out, { recursive: true });
const res = await build({ entryPoints: [path.join(root, 'src/main.js')], bundle: true, format: 'iife', minify: true, write: false, target: ['chrome80', 'safari14'], legalComments: 'none' });
const js = res.outputFiles[0].text.replace(/<\/script/g, '<\\/script');
const css = (await build({ entryPoints: [path.join(root, 'src/styles.css')], bundle: true, minify: true, write: false, loader: { '.css': 'css' }, target: ['chrome80', 'safari14'] })).outputFiles[0].text;
const tpl = fs.readFileSync(path.join(root, 'src/index.html'), 'utf8');
const icon = encodeURIComponent(iconSVG(64));
const html = tpl.replace('__ICON__', icon).replace('__CSS__', () => css).replace('__JS__', () => js);
fs.writeFileSync(path.join(out, 'index.html'), html);
fs.writeFileSync(path.join(out, 'icon.svg'), iconSVG(512));
console.log(`dist/index.html ${(html.length / 1024).toFixed(1)} KB`);
