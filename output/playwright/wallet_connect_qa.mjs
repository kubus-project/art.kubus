import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const APP_URL = process.env.APP_URL || 'http://localhost:8090';
const OUT_DIR = path.resolve('output/playwright/runtime');
const WALLET = process.env.QA_WALLET;
const USERNAME = process.env.QA_USERNAME || 'codexuiqa';

if (!WALLET) {
  throw new Error('Set QA_WALLET before running wallet_connect_qa.mjs.');
}

await fs.mkdir(OUT_DIR, { recursive: true });

async function issueWalletToken() {
  const response = await fetch('https://api.kubus.site/api/auth/register', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      walletAddress: WALLET,
      username: USERNAME,
    }),
  });
  const payload = await response.json();
  return payload?.data?.token ?? null;
}

async function seedSession(page) {
  const token = await issueWalletToken();
  await page.addInitScript(
    ({ wallet, token }) => {
      const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
      set('has_completed_onboarding', 'true');
      set('has_seen_welcome', 'true');
      set('is_first_launch', 'false');
      set('skipOnboardingForReturningUsers', 'true');
      set('map_onboarding_mobile_seen_v2', 'true');
      set('map_onboarding_desktop_seen_v2', 'true');
      set('wallet_address', wallet);
      set('walletAddress', wallet);
      set('wallet', wallet);
      set('user_id', wallet);
      set('has_wallet', 'true');
      set('auth_onboarding_completed', 'true');
      if (token) {
        set('jwt_token', token);
        set('auth_token', token);
      }
    },
    { wallet: WALLET, token },
  );
}

async function enableAccessibility(page) {
  await page.waitForTimeout(2000);
  await page.evaluate(() => {
    const placeholder = document.querySelector(
      'flt-semantics-placeholder[aria-label="Enable accessibility"]',
    );
    if (placeholder) {
      placeholder.dispatchEvent(
        new MouseEvent('click', { bubbles: true, cancelable: true }),
      );
      placeholder.click?.();
    }
  });
  await page.waitForTimeout(1200);
}

async function clickSemanticText(page, needle) {
  const target = await page.evaluate((value) => {
    const normalizedNeedle = value.toLowerCase();
    const nodes = Array.from(
      document.querySelectorAll('flt-semantics[role="button"]'),
    );
    for (const node of nodes) {
      const text = (node.textContent || '').trim().toLowerCase();
      if (!text.includes(normalizedNeedle)) continue;
      const rect = node.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) continue;
      return {
        x: rect.x + rect.width / 2,
        y: rect.y + rect.height / 2,
        text,
      };
    }
    return null;
  }, needle);

  if (!target) throw new Error(`semantic button not found: ${needle}`);
  console.log(`click ${needle} -> ${target.text}`);
  await page.mouse.click(target.x, target.y);
  await page.waitForTimeout(2500);
}

async function dumpVisibleButtons(page, name) {
  const buttons = await page.evaluate(() =>
    Array.from(document.querySelectorAll('flt-semantics[role="button"]'))
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return {
          text: (node.textContent || '').trim(),
          x: Math.round(rect.x),
          y: Math.round(rect.y),
          w: Math.round(rect.width),
          h: Math.round(rect.height),
        };
      })
      .filter((entry) => entry.w > 0 && entry.h > 0 && entry.text),
  );
  await fs.writeFile(
    path.join(OUT_DIR, 'wallet-connect-buttons.json'),
    JSON.stringify(buttons, null, 2),
    'utf8',
  );
}

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1440, height: 1100 },
});
const page = await context.newPage();
await seedSession(page);
await page.goto(`${APP_URL}?clear_sw=1`, { waitUntil: 'domcontentloaded' });
await page.waitForTimeout(3500);
await enableAccessibility(page);
await clickSemanticText(page, 'web3');
await enableAccessibility(page);
await clickSemanticText(page, 'preskoči');
await clickSemanticText(page, 'ustvari novo denarnico');
await page.waitForTimeout(2500);
await enableAccessibility(page);
await clickSemanticText(page, 'ustvari denarnico');
await page.waitForTimeout(4000);
await page.mouse.click(24, 24);
await page.waitForTimeout(1500);
await page.mouse.click(24, 24);
await page.waitForTimeout(4000);
await enableAccessibility(page);
await dumpVisibleButtons(page, 'wallet-connect');
await page.screenshot({
  path: path.join(OUT_DIR, 'wallet-connect.png'),
  fullPage: true,
});
await browser.close();
