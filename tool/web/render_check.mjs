// Loads a PCU Connect URL in headless Chromium (phone viewport) and checks
// that Flutter drew its first frame (the login screen) without page errors.
// Usage: node render_check.mjs <url>
import { chromium } from 'playwright';

const url = process.argv[2];
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, locale: 'en-US', timezoneId: 'Africa/Lagos' });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));
await page.addInitScript(() => window.addEventListener('flutter-first-frame', () => (window.__ff = performance.now())));
const started = Date.now();
await page.goto(url);
await page.waitForFunction(() => window.__ff, null, { timeout: 90000 });
await page.waitForTimeout(1500);
const result = {
  firstFrameMs: Math.round(await page.evaluate(() => window.__ff)),
  flutterView: (await page.$('flutter-view')) !== null,
  splashGone: (await page.$('#splash')) === null,
  pageErrors: errors,
  wallMs: Date.now() - started,
};
console.log(JSON.stringify(result));
await browser.close();
process.exit(result.flutterView && result.splashGone && errors.length === 0 ? 0 : 1);
