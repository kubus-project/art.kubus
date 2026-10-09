// Browser QA for the 0.8.2 creator-capability slice against a local release
// web build. Guest flows only: public GETs reach the real API, every write
// (analytics included) is answered locally so nothing reaches production.
// Usage: node creator_qa.mjs <build/web dir> <out dir> [scenario ...]
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const require = createRequire('C:/kubus-build/node_modules/');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2]);
const out = path.resolve(process.argv[3]);
const only = process.argv.slice(4);
fs.mkdirSync(out, { recursive: true });

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.css': 'text/css', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2', '.ico': 'image/x-icon', '.webp': 'image/webp' };
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  let p = path.resolve(path.join(root, decodeURIComponent(url.pathname)));
  if (!p.startsWith(root)) { res.writeHead(403); return res.end(); }
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': types[path.extname(p)] || 'application/octet-stream', 'cache-control': 'no-store' });
  fs.createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(8241, r));
const base = 'http://localhost:8241';

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const log = [];

async function newPage({ width, height, dark = false }) {
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: dark ? 'dark' : 'light', serviceWorkers: 'block' });
  const page = await context.newPage();
  const writes = [];
  await page.route('**/*', async (route) => {
    const req = route.request();
    const u = req.url();
    if (u.startsWith(base)) return route.continue();
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });
    if (req.method() !== 'GET' && req.method() !== 'HEAD') {
      writes.push(`${req.method()} ${u.split('?')[0]}`);
      return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*' } });
    }
    return route.continue();
  });
  page.on('pageerror', (e) => log.push(`pageerror ${e.message}`));
  return { page, context, writes };
}

async function settle(page, ms = 9000) {
  await page.waitForTimeout(ms);
}

async function shot(page, name) {
  await page.screenshot({ path: path.join(out, `${name}.png`) });
  log.push(`shot ${name} url=${page.url()}`);
}

async function enableSemantics(page) {
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder');
    if (el) el.click();
  });
  await page.waitForTimeout(800);
}

const scenarios = {
  // Cold start on the workspace URL: the studio opens for a guest.
  async 'phone-studio-cold'() {
    const { page, context, writes } = await newPage({ width: 390, height: 844 });
    await page.goto(`${base}/artist-studio`);
    await settle(page, 14000);
    await shot(page, 'phone-studio-cold');
    await page.reload();
    await settle(page, 14000);
    await shot(page, 'phone-studio-after-refresh');
    log.push(`writes ${JSON.stringify(writes)}`);
    await context.close();
  },
  async 'phone-hub-cold-320'() {
    const { page, context } = await newPage({ width: 320, height: 640 });
    await page.goto(`${base}/institution-hub`);
    await settle(page, 14000);
    await shot(page, 'phone-hub-cold-320');
    await context.close();
  },
  async 'phone-studio-sl-dark'() {
    const { page, context } = await newPage({ width: 390, height: 844, dark: true });
    await page.goto(`${base}/artist-studio?lang=sl`);
    await settle(page, 14000);
    await shot(page, 'phone-studio-sl-dark');
    await context.close();
  },
  async 'phone-home-guest'() {
    const { page, context } = await newPage({ width: 390, height: 844 });
    await page.goto(`${base}/main`);
    await settle(page, 14000);
    await shot(page, 'phone-home-guest-top');
    await context.close();
  },
  async 'desktop-studio-cold'() {
    const { page, context } = await newPage({ width: 1440, height: 900 });
    await page.goto(`${base}/artist-studio`);
    await settle(page, 15000);
    await shot(page, 'desktop-studio-cold');
    await context.close();
  },
  async 'desktop-hub-cold-dark'() {
    const { page, context } = await newPage({ width: 1440, height: 900, dark: true });
    await page.goto(`${base}/institution-hub`);
    await settle(page, 15000);
    await shot(page, 'desktop-hub-cold-dark');
    await context.close();
  },
  async 'desktop-1024-studio'() {
    const { page, context } = await newPage({ width: 1024, height: 768 });
    await page.goto(`${base}/artist-studio`);
    await settle(page, 15000);
    await shot(page, 'desktop-1024-studio');
    await context.close();
  },
  // Start -> contextual account sheet -> Not now -> still on the studio.
  async 'phone-studio-start-dismiss'() {
    const { page, context } = await newPage({ width: 390, height: 844 });
    await page.goto(`${base}/artist-studio`);
    await settle(page, 14000);
    await enableSemantics(page);
    await page.getByRole('button', { name: 'Start as an artist' }).click();
    await settle(page, 2500);
    await shot(page, 'phone-studio-start-sheet');
    await page.getByRole('button', { name: 'Not now' }).click();
    await settle(page, 2000);
    await shot(page, 'phone-studio-after-dismiss');
    await context.close();
  },
  // Back from a cold-started workspace leaves it for the shell, and the URL
  // follows the page that is showing.
  async 'phone-studio-back'() {
    const { page, context } = await newPage({ width: 390, height: 844 });
    await page.goto(`${base}/artist-studio`);
    await settle(page, 14000);
    await enableSemantics(page);
    await page.getByRole('button', { name: 'Back' }).first().click();
    await settle(page, 4000);
    await shot(page, 'phone-studio-back');
    await context.close();
  },
  // Guest desktop: discover Create, Organize and Node from the sidebar.
  async 'desktop-guest-nav'() {
    const { page, context } = await newPage({ width: 1440, height: 900 });
    await page.goto(`${base}/map`);
    await settle(page, 15000);
    await enableSemantics(page);
    for (const [label, name] of [['Organize', 'desktop-nav-organize'], ['Node', 'desktop-nav-node']]) {
      await page.getByText(label, { exact: true }).first().click();
      await settle(page, 3000);
      await shot(page, name);
    }
    await context.close();
  },
  async 'tablet-768-studio'() {
    const { page, context } = await newPage({ width: 768, height: 1024 });
    await page.goto(`${base}/artist-studio`);
    await settle(page, 14000);
    await shot(page, 'tablet-768-studio');
    await context.close();
  },
};

for (const [name, run] of Object.entries(scenarios)) {
  if (only.length && !only.includes(name)) continue;
  try {
    await run();
  } catch (e) {
    log.push(`FAILED ${name}: ${e.message}`);
  }
}
fs.writeFileSync(path.join(out, 'log.txt'), log.join('\n'));
console.log(log.join('\n'));
await browser.close();
server.close();
