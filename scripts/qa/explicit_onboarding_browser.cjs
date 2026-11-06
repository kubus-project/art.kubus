// Run against a served release build: WEB_URL=http://127.0.0.1:8090 node scripts/qa/explicit_onboarding_browser.cjs
// The server must fall back to index.html for application routes.
const { chromium } = require('playwright');

const origin = (process.env.WEB_URL || 'http://127.0.0.1:8090').replace(/\/$/, '');
const timeout = 30000;

async function waitForWelcome(page) {
  await page.waitForSelector('flt-semantics-placeholder', { timeout, state: 'attached' });
  await page.locator('flt-semantics-placeholder').evaluate((node) => node.click());
  await page.getByText('Create an account', { exact: true }).first().waitFor({ timeout });
}

(async () => {
  const browser = await chromium.launch();
  try {
    for (const viewport of [{ width: 390, height: 844 }, { width: 1440, height: 900 }]) {
      const context = await browser.newContext({ viewport, locale: 'en-US' });
      const page = await context.newPage();
      const path = '/onboarding?entry=qa#start';
      await page.goto(origin + path);
      await waitForWelcome(page);
      if (new URL(page.url()).pathname + new URL(page.url()).search + new URL(page.url()).hash !== path) {
        throw new Error(`Explicit onboarding URL changed: ${page.url()}`);
      }
      await page.reload();
      await waitForWelcome(page);
      if (new URL(page.url()).pathname + new URL(page.url()).search + new URL(page.url()).hash !== path) {
        throw new Error(`Reload changed onboarding URL: ${page.url()}`);
      }
      await page.goto(origin + '/');
      await page.waitForURL((url) => url.pathname === '/map', { timeout });
      await page.goBack();
      await waitForWelcome(page);
      if (new URL(page.url()).pathname + new URL(page.url()).search + new URL(page.url()).hash !== path) {
        throw new Error(`Back changed onboarding URL: ${page.url()}`);
      }
      await page.goForward();
      await page.waitForURL((url) => url.pathname === '/map', { timeout });
      await context.close();
      console.log(`PASS explicit onboarding, reload and Back/Forward at ${viewport.width}px`);
    }
    const context = await browser.newContext({ locale: 'en-US' });
    const page = await context.newPage();
    await page.goto(origin + '/');
    await page.waitForURL((url) => url.pathname === '/map', { timeout });
    console.log('PASS anonymous root opens public map');
    await context.close();
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
