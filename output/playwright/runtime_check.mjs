import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const outputDir = path.dirname(__filename);

const browser = await chromium.launch({
  headless: true,
});

const page = await browser.newPage({
  viewport: { width: 1440, height: 1100 },
});

const consoleEntries = [];
page.on('console', (msg) => {
  consoleEntries.push(`[${msg.type()}] ${msg.text()}`);
});
page.on('pageerror', (error) => {
  consoleEntries.push(`[pageerror] ${error.stack || error.message}`);
});
page.on('requestfailed', (request) => {
  consoleEntries.push(
    `[requestfailed] ${request.method()} ${request.url()} ${request.failure()?.errorText || ''}`.trim(),
  );
});

await page.goto('http://localhost:8090/', { waitUntil: 'domcontentloaded' });
await page.evaluate(() => {
  localStorage.setItem('flutter.has_completed_onboarding', 'true');
  localStorage.setItem('flutter.has_seen_welcome', 'true');
  localStorage.setItem('flutter.is_first_launch', 'false');
  localStorage.setItem('flutter.skipOnboardingForReturningUsers', 'true');
});
await page.reload({ waitUntil: 'domcontentloaded' });
await page.waitForTimeout(10000);

await page.screenshot({
  path: path.join(outputDir, 'runtime-home-desktop.png'),
  fullPage: true,
});

const state = await page.evaluate(() => ({
  href: location.href,
  title: document.title,
  bodyText: document.body.innerText.slice(0, 3000),
}));

await fs.writeFile(
  path.join(outputDir, 'runtime-home-desktop.json'),
  JSON.stringify(
    {
      state,
      consoleEntries,
    },
    null,
    2,
  ),
);

await browser.close();
