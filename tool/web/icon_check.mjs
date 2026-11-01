// Checks that every icon a PCU Connect site can ask for is the PCU logo and
// never a Flutter default: <link rel=icon>, apple-touch-icon, manifest icons,
// the share image, the push service worker's icon and badge, /favicon.ico,
// and any image requested while the page loads.
// Usage: node icon_check.mjs <url>
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { chromium } from 'playwright';

const base = process.argv[2];
if (!base) {
  console.error('Usage: node icon_check.mjs <url>');
  process.exit(2);
}

// Flutter's own template icons (from the installed SDK), by SHA-256.
const flutterDefaults = new Map();
const templates = path.join(os.homedir(), 'flutter/packages/flutter_tools/templates');
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const name of fs.readdirSync(dir)) {
    const file = path.join(dir, name);
    if (fs.statSync(file).isDirectory()) walk(file);
    else if (/\.(png|ico)(\.copy\.tmpl|\.img\.tmpl)?$/.test(name)) {
      flutterDefaults.set(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'), file.slice(templates.length + 1));
    }
  }
}
walk(templates);
if (!flutterDefaults.size) {
  // Known hashes of the Flutter web template icons, for machines without the SDK.
  for (const h of ['7ab2525f4b86b65d', 'baccb205ae45f0b4', '3dce99077602f704']) flutterDefaults.set(h, 'flutter web template');
}
const isFlutter = (hash) => flutterDefaults.get(hash) || [...flutterDefaults.keys()].find((k) => k.length < 64 && hash.startsWith(k));

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, locale: 'en-US' });
const seen = new Set();
page.on('request', (r) => {
  if (r.resourceType() === 'image' || /\.(png|ico|svg|webp)(\?|$)/.test(r.url())) seen.add(r.url());
});
await page.goto(base, { waitUntil: 'load' });
await page.waitForTimeout(4000);

const fromHtml = await page.evaluate(() => {
  const abs = (h) => new URL(h, document.baseURI).href;
  const out = [];
  document.querySelectorAll('link[rel~="icon"], link[rel="apple-touch-icon"]').forEach((l) => out.push(['link ' + l.rel, abs(l.getAttribute('href'))]));
  document.querySelectorAll('meta[property="og:image"], meta[name="twitter:image"]').forEach((m) => out.push(['meta ' + (m.getAttribute('property') || m.getAttribute('name')), m.content]));
  const manifest = document.querySelector('link[rel="manifest"]');
  return { links: out, manifest: manifest ? abs(manifest.getAttribute('href')) : null, base: document.baseURI };
});
await browser.close();

const targets = [...fromHtml.links];
if (fromHtml.manifest) {
  const manifest = await (await fetch(fromHtml.manifest)).json();
  for (const icon of manifest.icons || []) targets.push(['manifest ' + (icon.purpose || 'any') + ' ' + icon.sizes, new URL(icon.src, fromHtml.manifest).href]);
}
const sw = await fetch(new URL('firebase-messaging-sw.js', fromHtml.base));
if (sw.ok) {
  const text = await sw.text();
  for (const [, name, file] of text.matchAll(/const (ICON|BADGE) = '([^']+)'/g)) targets.push(['service worker ' + name, new URL(file, sw.url).href]);
}
targets.push(['default /favicon.ico', new URL('/favicon.ico', base).href]);
for (const url of seen) if (!targets.some(([, u]) => u === url)) targets.push(['requested while loading', url]);

let failed = 0;
for (const [what, url] of targets) {
  const res = await fetch(url, { cache: 'no-store' });
  const body = Buffer.from(await res.arrayBuffer());
  const hash = crypto.createHash('sha256').update(body).digest('hex');
  const flutter = isFlutter(hash);
  // A real image, not the app page that Hosting serves for unknown paths.
  const png = body.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  const ico = body.subarray(0, 4).equals(Buffer.from([0, 0, 1, 0]));
  const image = (png || ico) && /^image\//.test(res.headers.get('content-type') || '');
  const ok = res.ok && image && !flutter;
  if (!ok) failed++;
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${what.padEnd(34)} ${res.status} ${String(body.length).padStart(7)} B ${hash.slice(0, 12)} ${flutter ? 'FLUTTER DEFAULT (' + flutter + ') ' : ''}${image ? '' : 'NOT AN IMAGE '}${url}`);
}
console.log(`${targets.length} icon URLs checked against ${flutterDefaults.size} Flutter default images: ${failed ? failed + ' FAILED' : 'none is a Flutter default'}`);
process.exit(failed ? 1 : 0);
