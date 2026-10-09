#!/usr/bin/env node
// Brand parity: the WEB app owns the logo (apps/kyco/public/icon.svg). This
// tool byte-copies it into assets/brand/icon.svg and RASTERIZES that exact SVG
// (never redrawn) into every bitmap the mobile app needs:
//   assets/brand/logo.png              512² rounded mark, transparent corners (in-app KycoBrand, splash)
//   assets/icon/icon.png               1024² full-bleed (corner radius removed — iOS/Android apply their own mask)
//   assets/icon/icon_background.png    1024² gradient only (Android adaptive background)
//   assets/icon/icon_foreground.png    1024² glyphs only, inside the adaptive 72/108 visible zone
// Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
//
//   node tool/brand/render-brand.mjs [<web-app-dir>]   (default ../../AppDroid1.0/apps/kyco relative to repo)
// sharp is resolved from the web app's node_modules (the mobile repo has no Node deps).
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const web = path.resolve(process.argv[2] || process.env.KYCO_WEB_DIR || '/home/bi/w/AppDroid1-ori/AppDroid1.0/apps/kyco');
const src = path.join(web, 'public/icon.svg');
const sharp = createRequire(path.join(web, 'package.json'))('sharp');

const svg = fs.readFileSync(src, 'utf8');
fs.mkdirSync(path.join(repo, 'assets/brand'), { recursive: true });
fs.copyFileSync(src, path.join(repo, 'assets/brand/icon.svg'));

const sized = (s, px) => s.replace(/width="\d+"\s+height="\d+"/, `width="${px}" height="${px}"`);
const bgRect = /<rect [^>]*fill="url\(#kyco-bg\)"\s*\/>/;
if (!bgRect.test(svg)) throw new Error('icon.svg changed shape: background <rect fill="url(#kyco-bg)"> not found');

const fullBleed = svg.replace(/(<rect [^>]*?)\s+rx="[\d.]+"/, '$1');
const bgOnly = svg.replace(/<\/defs>[\s\S]*<\/svg>/, (m) => `</defs>\n  ${svg.match(bgRect)[0].replace(/\s+rx="[\d.]+"/, '')}\n</svg>`);
// Foreground: glyphs only, the 40-unit mark scaled into the centre 72/108 of the canvas.
const glyphs = svg.replace(bgRect, '');
const inner = glyphs.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const pad = (108 - 72) / 2 / 108 * 40 / (72 / 108); // canvas padding in mark units
const fg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${-pad} ${-pad} ${40 + 2 * pad} ${40 + 2 * pad}" width="1024" height="1024">${inner}</svg>`;

const out = async (s, px, rel) => {
  await sharp(Buffer.from(s), { density: 72 }).resize(px, px).png().toFile(path.join(repo, rel));
  console.log('wrote', rel);
};
await out(sized(svg, 512), 512, 'assets/brand/logo.png');
await out(sized(fullBleed, 1024), 1024, 'assets/icon/icon.png');
await out(sized(bgOnly, 1024), 1024, 'assets/icon/icon_background.png');
await out(fg, 1024, 'assets/icon/icon_foreground.png');
