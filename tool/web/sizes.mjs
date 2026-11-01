// Lists what a page downloads: transfer size and encoding per request.
import { chromium } from 'playwright';
const browser = await chromium.launch();
const context = await browser.newContext({ locale: 'en-US', viewport: { width: 390, height: 844 } });
const page = await context.newPage();
const cdp = await context.newCDPSession(page);
await cdp.send('Network.enable');
const info = new Map();
cdp.on('Network.responseReceived', (e) => info.set(e.requestId, { url: e.response.url, enc: e.response.headers['content-encoding'] || '-', cache: e.response.headers['cache-control'] || '' }));
cdp.on('Network.loadingFinished', (e) => { const i = info.get(e.requestId); if (i) i.kb = Math.round(e.encodedDataLength / 1024); });
page.on('console', () => {});
await page.goto(process.argv[2]);
await page.waitForTimeout(15000);
const rows = [...info.values()].filter((r) => r.kb !== undefined).sort((a, b) => b.kb - a.kb);
for (const r of rows) console.log(String(r.kb).padStart(6), 'KB', r.enc.padEnd(5), r.url.replace(/^https?:\/\/[^/]+/, '').slice(0, 70), '|', r.cache);
console.log('total', rows.reduce((s, r) => s + r.kb, 0), 'KB');
await browser.close();
