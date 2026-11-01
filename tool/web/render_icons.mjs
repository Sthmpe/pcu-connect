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

// Web files carry a version suffix (-v2) because browsers cache icons hard;
// bump it (and every reference) when the logo changes.
const V = 'v2';
const outputs = [
  ['tile', 16, `web/favicon-16-${V}.png`],
  ['tile', 32, `web/favicon-32-${V}.png`],
  ['tile', 48, `web/favicon-${V}.png`],
  ['tile', 192, `web/icons/Icon-192-${V}.png`],
  ['tile', 512, `web/icons/Icon-512-${V}.png`],
  ['square', 192, `web/icons/Icon-maskable-192-${V}.png`],
  ['square', 512, `web/icons/Icon-maskable-512-${V}.png`],
  ['square', 180, `web/icons/apple-touch-icon-${V}.png`],
  ['tile', 192, `web/icons/notification-icon-192-${V}.png`],
  ['badge', 96, `web/icons/notification-badge-96-${V}.png`],
];

// Sources for flutter_launcher_icons (it writes the Android and iOS launcher icons).
svgs.foreground = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">${mark(GOLD, 0.5)}</svg>`;
svgs.monochrome = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">${mark('#FFFFFF', 0.5)}</svg>`;
outputs.push(
  ['tile', 1024, 'design/logo/launcher/pcu-logo-rounded-1024.png'],
  ['square', 1024, 'design/logo/launcher/pcu-logo-square-1024.png'],
  ['foreground', 1024, 'design/logo/launcher/pcu-adaptive-foreground-1024.png'],
  ['monochrome', 1024, 'design/logo/launcher/pcu-adaptive-monochrome-1024.png'],
);
// Android notification small icon: white silhouette, 24 dp at every density.
for (const [dpi, size] of [['mdpi', 24], ['hdpi', 36], ['xhdpi', 48], ['xxhdpi', 72], ['xxxhdpi', 96]]) {
  if (fs.existsSync('android/app/src/main/res')) outputs.push(['badge', size, `android/app/src/main/res/drawable-${dpi}/ic_notification.png`]);
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
// Share image for links (Open Graph): navy, the logo, the name in Rubik.
const font = (file) => fs.readFileSync(path.join(root, 'assets/fonts', file)).toString('base64');
await page.setViewportSize({ width: 1200, height: 630 });
await page.setContent(`<html><head><style>
  @font-face { font-family: Rubik; font-weight: 400; src: url(data:font/ttf;base64,${font('Rubik-Regular.ttf')}); }
  @font-face { font-family: Rubik; font-weight: 600; src: url(data:font/ttf;base64,${font('Rubik-SemiBold.ttf')}); }
  body { margin: 0; width: 1200px; height: 630px; display: flex; align-items: center; gap: 56px; padding: 0 110px;
    box-sizing: border-box; background: linear-gradient(135deg, ${NAVY_TOP}, ${NAVY}); font-family: Rubik; color: #fff; }
  h1 { margin: 0; font-size: 84px; font-weight: 600; letter-spacing: -1px; }
  p { margin: 18px 0 0; font-size: 34px; color: ${GOLD}; }
</style></head><body>${svgs.tile.replace('<svg ', '<svg width="240" height="240" style="filter:drop-shadow(0 18px 40px rgba(0,0,0,.35))" ')}
  <div><h1>PCU Connect</h1><p>Follow up every guest with care.</p></div></body></html>`);
await page.evaluate(() => document.fonts.ready);
const share = `web/icons/share-${V}.png`;
await page.screenshot({ path: share, clip: { x: 0, y: 0, width: 1200, height: 630 } });
console.log('1200x630 share   ' + share);
await browser.close();

// favicon.ico with the 16, 32 and 48 px PNGs inside (browsers ask for it by default).
const sizes = [16, 32, 48];
const pngs = sizes.map((s) => fs.readFileSync(s === 48 ? `web/favicon-${V}.png` : `web/favicon-${s}-${V}.png`));
const header = Buffer.alloc(6 + 16 * pngs.length);
header.writeUInt16LE(0, 0);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(pngs.length, 4);
let offset = header.length;
pngs.forEach((png, i) => {
  const e = 6 + 16 * i;
  header.writeUInt8(sizes[i], e);
  header.writeUInt8(sizes[i], e + 1);
  header.writeUInt16LE(1, e + 4);
  header.writeUInt16LE(32, e + 6);
  header.writeUInt32LE(png.length, e + 8);
  header.writeUInt32LE(offset, e + 12);
  offset += png.length;
});
fs.writeFileSync('web/favicon.ico', Buffer.concat([header, ...pngs]));
console.log('16/32/48 ico     web/favicon.ico');
