import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import { webcrypto } from 'node:crypto';

const APP_URL = process.env.APP_URL || 'http://localhost:8090';
const OUT_DIR = path.resolve('output/playwright/runtime');
const WALLET = process.env.QA_WALLET;
const USERNAME = process.env.QA_USERNAME || 'codexuiqa_seed_20260327c';
const MNEMONIC = process.env.QA_MNEMONIC;

if (!WALLET) {
  throw new Error(
    'Set QA_WALLET before running desktop_institution_quick_qa.mjs.',
  );
}

if (!MNEMONIC) {
  throw new Error(
    'Set QA_MNEMONIC before running desktop_institution_quick_qa.mjs.',
  );
}

await fs.mkdir(OUT_DIR, { recursive: true });

async function buildSecureStorageSeed() {
  const rawKey = webcrypto.getRandomValues(new Uint8Array(32));
  const cryptoKey = await webcrypto.subtle.importKey(
    'raw',
    rawKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt'],
  );
  const encode = async (value) => {
    const iv = webcrypto.getRandomValues(new Uint8Array(12));
    const cipher = await webcrypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      cryptoKey,
      new TextEncoder().encode(value),
    );
    return `${Buffer.from(iv).toString('base64')}.${Buffer.from(cipher).toString('base64')}`;
  };
  return {
    publicKey: Buffer.from(rawKey).toString('base64'),
    cachedMnemonic: await encode(MNEMONIC),
    cachedMnemonicTs: await encode(String(Date.now())),
  };
}

async function issueWalletToken() {
  const response = await fetch('https://api.kubus.site/api/auth/register', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ walletAddress: WALLET, username: USERNAME }),
  });
  if (!response.ok) {
    throw new Error(`register failed: ${response.status} ${await response.text()}`);
  }
  const payload = await response.json();
  return payload?.data?.token ?? null;
}

async function seedSession(page) {
  const token = await issueWalletToken();
  const secureStorage = await buildSecureStorageSeed();
  await page.addInitScript(
    ({ wallet, token, secureStorage }) => {
      const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
      localStorage.setItem('FlutterSecureStorage', secureStorage.publicKey);
      localStorage.setItem(
        'FlutterSecureStorage.cached_mnemonic',
        secureStorage.cachedMnemonic,
      );
      localStorage.setItem(
        'FlutterSecureStorage.cached_mnemonic_ts',
        secureStorage.cachedMnemonicTs,
      );
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
    { wallet: WALLET, token, secureStorage },
  );
}

async function enableAccessibility(page) {
  await page.waitForTimeout(1800);
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
  await page.waitForTimeout(1000);
}

async function capture(page, name) {
  await page.waitForTimeout(3500);
  await enableAccessibility(page);
  await page.screenshot({
    path: path.join(OUT_DIR, `${name}.png`),
    fullPage: true,
  });
}

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1440, height: 1100 },
});
const page = await context.newPage();
await seedSession(page);
await page.goto(`${APP_URL}?clear_sw=1`, { waitUntil: 'domcontentloaded' });
await capture(page, 'desktop-institution-home');
await page.mouse.click(135, 790);
await capture(page, 'desktop-institution-quick-action');
await browser.close();
