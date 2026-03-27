import { chromium, devices } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import { webcrypto } from 'node:crypto';

const APP_URL = process.env.APP_URL || 'http://localhost:8090';
const OUT_DIR = path.resolve('output/playwright/runtime');
const WALLET = process.env.QA_WALLET;
const USERNAME = process.env.QA_USERNAME || 'codexuiqa_probe';
const MNEMONIC = process.env.QA_MNEMONIC;

if (!WALLET) {
  throw new Error('Set QA_WALLET before running persona_probe.mjs.');
}

if (!MNEMONIC) {
  throw new Error('Set QA_MNEMONIC before running persona_probe.mjs.');
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
  await page.waitForTimeout(2200);
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

async function dump(page, name) {
  const buttons = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('flt-semantics[role="button"]'))
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
      .filter((entry) => entry.w > 0 && entry.h > 0 && entry.text);
  });

  await fs.writeFile(
    path.join(OUT_DIR, `${name}-buttons.json`),
    JSON.stringify(buttons, null, 2),
    'utf8',
  );
  await page.screenshot({
    path: path.join(OUT_DIR, `${name}.png`),
    fullPage: true,
  });
}

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  ...devices['iPhone 13'],
});
const page = await context.newPage();
await seedSession(page);
await page.goto(`${APP_URL}?clear_sw=1`, { waitUntil: 'domcontentloaded' });
await enableAccessibility(page);
await page.mouse.click(190, 410);
await page.waitForTimeout(4500);
await enableAccessibility(page);
await dump(page, 'mobile-after-persona');
await browser.close();
