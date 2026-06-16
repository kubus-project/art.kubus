import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const APP_URL = process.env.APP_URL || 'http://localhost:8090';
const OUT = path.resolve('output/playwright/diag');
await fs.mkdir(OUT, { recursive: true });

async function seed(page) {
  await page.addInitScript(() => {
    const set = (k, v) => localStorage.setItem(`flutter.${k}`, v);
    set('has_completed_onboarding', 'true');
    set('has_seen_welcome', 'true');
    set('is_first_launch', 'false');
    set('skipOnboardingForReturningUsers', 'true');
    set('map_onboarding_mobile_seen_v2', 'true');
    set('map_onboarding_desktop_seen_v2', 'true');
    set('auth_onboarding_completed', 'true');
    set('has_wallet', 'true');
    set('wallet_address', '0xqadiagwallet000000000000000000000000dead');
    set('walletAddress', '0xqadiagwallet000000000000000000000000dead');
    set('user_id', '0xqadiagwallet000000000000000000000000dead');
  });
}

async function enableA11y(page) {
  await page.waitForTimeout(1500);
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    p?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    p?.click?.();
  });
  await page.waitForTimeout(1200);
}

async function clickText(page, needle) {
  const t = await page.evaluate((value) => {
    const v = value.toLowerCase();
    for (const n of document.querySelectorAll('flt-semantics[role="button"], flt-semantics[role="tab"], flt-semantics a')) {
      const txt = (n.getAttribute('aria-label') || n.textContent || '').trim().toLowerCase();
      if (!txt.includes(v)) continue;
      const r = n.getBoundingClientRect();
      if (r.width <= 0 || r.height <= 0) continue;
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }
    return null;
  }, needle);
  if (!t) return false;
  await page.mouse.click(t.x, t.y);
  await page.waitForTimeout(2500);
  return true;
}

function inspectBlur() {
  const cs = (el) => {
    const s = getComputedStyle(el);
    return s.backdropFilter || s.webkitBackdropFilter || s.getPropertyValue('-webkit-backdrop-filter');
  };
  const maps = document.querySelectorAll('.maplibregl-map');
  const host = document.getElementById('kubus-map-platform-backdrop-host');
  const regions = host ? Array.from(host.children) : [];
  const anyBackdrop = Array.from(document.querySelectorAll('*'))
    .filter((el) => { const v = cs(el); return v && v !== 'none'; })
    .slice(0, 40)
    .map((el) => {
      const r = el.getBoundingClientRect();
      return { id: el.id || '', filter: cs(el), rect: [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)] };
    });
  return {
    mapCount: maps.length,
    hostExists: !!host,
    regionCount: regions.length,
    regions: regions.map((r) => { const rect = r.getBoundingClientRect(); return { filter: cs(r), rect: [Math.round(rect.x), Math.round(rect.y), Math.round(rect.width), Math.round(rect.height)] }; }),
    anyBackdropCount: anyBackdrop.length,
    anyBackdrop,
  };
}

async function gotoMap(page) {
  await seed(page);
  await page.goto(`${APP_URL}?clear_sw=1`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(8000);
  await enableA11y(page);
  let hasMap = await page.evaluate(() => document.querySelectorAll('.maplibregl-map').length > 0);
  if (!hasMap) {
    for (const needle of ['Odkrij', 'Raziskuj', 'Discover', 'Zemljevid', 'Map']) {
      if (await clickText(page, needle)) {
        await page.waitForTimeout(4000);
        hasMap = await page.evaluate(() => document.querySelectorAll('.maplibregl-map').length > 0);
        if (hasMap) break;
      }
    }
  }
  await page.waitForTimeout(6000);
}

async function run(name, viewport) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
  await gotoMap(page);
  const diag = await page.evaluate(inspectBlur);
  await page.screenshot({ path: path.join(OUT, `${name}-full.png`) });
  await page.screenshot({ path: path.join(OUT, `${name}-header.png`), clip: { x: 0, y: 0, width: viewport.width, height: 230 } });
  // Focus the search field (top area) to test expansion + chip collapse.
  await page.mouse.click(Math.min(360, viewport.width * 0.3), 56);
  await page.waitForTimeout(1500);
  await page.keyboard.type('rr');
  await page.waitForTimeout(2500);
  await page.screenshot({ path: path.join(OUT, `${name}-search-focus.png`) });
  const diagFocus = await page.evaluate(inspectBlur);
  await fs.writeFile(path.join(OUT, `${name}.json`), JSON.stringify({ diag, diagFocus, logs: logs.slice(-40) }, null, 2), 'utf8');
  console.log(`\n=== ${name} (idle) ===`);
  console.log(JSON.stringify(diag, null, 2));
  console.log(`\n=== ${name} (search focus) host=${diagFocus.hostExists} regions=${diagFocus.regionCount} anyBackdrop=${diagFocus.anyBackdropCount} ===`);
  await browser.close();
}

await run('desktop', { width: 1600, height: 1000 });
await run('mobile', { width: 414, height: 896 });
console.log('\nDONE');
