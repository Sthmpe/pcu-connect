// Renders every app icon from the logo (design/logo/pcu-logo.svg and the
// glyph path next to it) with headless Chromium. Run from the repo root:
//   node tool/web/render_icons.mjs
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const root = process.cwd();
const glyph = fs.readFileSync(path.join(root, 'design/logo/heart-handshake-w300.path'), 'utf8').trim();
const NAVY_TOP = '#162C4D';
const NAVY = '#0B1F3A';
const GOLD = '#E3B341';

// The glyph's 1000-unit em box is 32/72 (44%) of the tile, as on the login screen.
const mark = (fill, scale = 32 / 72) => {
  const em = 72 * scale;
  const offset = (72 - em) / 2;
  return `<path fill="${fill}" transform="translate(${offset} ${offset + em}) scale(${em / 1000} ${-em / 1000})" d="${glyph}"/>`;
};
const gradient = `<defs><linearGradient id="n" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${NAVY_TOP}"/><stop offset="1" stop-color="${NAVY}"/></linearGradient></defs>`;

const svgs = {
  // The login tile: rounded corners, transparent outside.
  tile: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">${gradient}<rect width="72" height="72" rx="22" fill="url(#n)"/>${mark(GOLD)}</svg>`,
  // Full bleed for platforms that cut their own shape (maskable, Apple, iOS).
  square: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">${gradient}<rect width="72" height="72" fill="url(#n)"/>${mark(GOLD)}</svg>`,
  // Android status bar badge: white silhouette only.
  badge: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">${mark('#FFFFFF', 0.86)}</svg>`,
};

const outputs = [
  ['tile', 32, 'web/favicon-32.png'],
  ['tile', 48, 'web/favicon.png'],
  ['tile', 192, 'web/icons/Icon-192.png'],
  ['tile', 512, 'web/icons/Icon-512.png'],
  ['square', 192, 'web/icons/Icon-maskable-192.png'],
  ['square', 512, 'web/icons/Icon-maskable-512.png'],
  ['square', 180, 'web/icons/apple-touch-icon.png'],
  ['tile', 192, 'web/icons/notification-icon-192.png'],
  ['badge', 96, 'web/icons/notification-badge-96.png'],
];

// Android launcher icons (legacy mipmaps).
for (const [dpi, size] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]) {
  const file = `android/app/src/main/res/mipmap-${dpi}/ic_launcher.png`;
  if (fs.existsSync(path.dirname(file))) outputs.push(['tile', size, file]);
}
// iOS app icons: every size listed in the asset catalogue, full bleed.
const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
if (fs.existsSync(iosDir)) {
  for (const name of fs.readdirSync(iosDir)) {
    const m = /^Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$/.exec(name);
    if (m) outputs.push(['square', Math.round(Number(m[1]) * Number(m[2])), path.join(iosDir, name)]);
  }
}

fs.writeFileSync('design/logo/pcu-logo-square.svg', svgs.square + '\n');
fs.writeFileSync('design/logo/pcu-badge.svg', svgs.badge + '\n');

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
for (const [kind, size, file] of outputs) {
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(
    `<html><body style="margin:0;background:transparent">${svgs[kind].replace('<svg ', `<svg width="${size}" height="${size}" `)}</body></html>`,
  );
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await page.screenshot({ path: file, omitBackground: kind !== 'square', clip: { x: 0, y: 0, width: size, height: size } });
  console.log(`${String(size).padStart(4)} px  ${kind.padEnd(6)}  ${file}`);
}
await browser.close();
