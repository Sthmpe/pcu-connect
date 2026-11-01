// Loads a PCU Connect URL like a phone on a slow network and reports how long
// it takes to show something and to draw the first Flutter frame (the login
// screen), plus every request to a host other than the app's own.
// Usage: node load_test.mjs <url> [label] [runs]
import { chromium } from 'playwright';

const url = process.argv[2];
const label = process.argv[3] || 'run';
const runs = Number(process.argv[4] || 2);
if (!url) {
  console.error('Usage: node load_test.mjs <url> [label] [runs]');
  process.exit(2);
}

// Roughly "slow 4G": 150 ms latency, 1.6 Mbit/s down, 750 kbit/s up, 4x slower CPU.
const NETWORK = { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 };
const CPU_SLOWDOWN = 4;

async function once(browser, i) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
    // Headless Chromium reports "en-US@posix", which is not a valid browser
    // locale and stops Flutter from starting; a phone reports a plain tag.
    locale: 'en-US',
    timezoneId: 'Africa/Lagos',
    userAgent:
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
  });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Network.emulateNetworkConditions', NETWORK);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: CPU_SLOWDOWN });

  // Flutter fires "flutter-first-frame" once the first frame is on screen.
  await page.addInitScript(() => {
    window.__firstFrame = null;
    window.addEventListener('flutter-first-frame', () => (window.__firstFrame = performance.now()));
  });

  const appHost = new URL(url).host;
  const external = new Map();
  let bytes = 0;
  let requests = 0;
  cdp.on('Network.loadingFinished', (e) => (bytes += e.encodedDataLength || 0));
  page.on('request', (r) => {
    requests++;
    const u = new URL(r.url());
    if (u.protocol.startsWith('http') && u.host !== appHost) {
      const key = u.host;
      external.set(key, (external.get(key) || []).concat(u.pathname.slice(0, 80)));
    }
  });

  const started = Date.now();
  await page.goto(url, { waitUntil: 'commit', timeout: 120000 });
  let firstFrame = null;
  try {
    await page.waitForFunction(() => window.__firstFrame !== null, null, { timeout: 120000, polling: 100 });
    firstFrame = Date.now() - started;
  } catch {
    firstFrame = null;
  }
  // Let the login screen settle, then measure what was fetched.
  await page.waitForTimeout(3000);
  const paints = await page.evaluate(() =>
    Object.fromEntries(performance.getEntriesByType('paint').map((p) => [p.name, Math.round(p.startTime)])),
  );
  const shot = `/tmp/load_${label}_${i}.png`;
  await page.screenshot({ path: shot });
  await context.close();
  return { firstPaintMs: paints['first-paint'] ?? null, firstContentfulPaintMs: paints['first-contentful-paint'] ?? null,
    flutterFirstFrameMs: firstFrame, requests, kb: Math.round(bytes / 1024), external: Object.fromEntries(external), screenshot: shot };
}

const browser = await chromium.launch();
const results = [];
for (let i = 0; i < runs; i++) {
  // A crashed tab (low memory on a small machine) is retried once.
  try {
    results.push(await once(browser, i));
  } catch (e) {
    console.error(`run ${i} failed (${e.message.split('\n')[0]}), retrying`);
    results.push(await once(browser, i));
  }
}
await browser.close();

console.log(JSON.stringify({ url, label, network: 'slow 4G (150 ms, 1.6 Mbit/s), CPU x4, phone 390x844, empty cache', results }, null, 2));
