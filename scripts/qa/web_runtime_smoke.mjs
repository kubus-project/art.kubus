import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, devices } from 'playwright';

import { buildStableApiStub } from './web_runtime_contract.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../..');
const artifactDir = path.resolve(
  rootDir,
  process.env.QA_ARTIFACT_DIR || 'output/playwright/artifacts/web-smoke',
);
const requestedUrl = (process.env.APP_URL || '').trim();
const qaPort = Number(process.env.QA_PORT || process.env.PORT || 8090);
const appUrl = requestedUrl || `http://127.0.0.1:${qaPort}`;

await fs.mkdir(artifactDir, { recursive: true });

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForHttp(url, timeoutMs = 30000) {
  const startedAt = Date.now();
  let lastError = null;
  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await sleep(500);
  }
  throw new Error(`Timed out waiting for ${url}: ${lastError?.message || 'no response'}`);
}

async function startProxyIfNeeded() {
  if (requestedUrl) return null;

  const logPath = path.join(artifactDir, 'proxy.log');
  const log = await fs.open(logPath, 'w');
  const child = spawn(process.execPath, [path.join(__dirname, 'dev_spa_proxy.mjs')], {
    cwd: rootDir,
    env: { ...process.env, PORT: String(qaPort) },
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });

  child.stdout.on('data', (chunk) => {
    log.write(chunk).catch(() => {});
  });
  child.stderr.on('data', (chunk) => {
    log.write(chunk).catch(() => {});
  });

  child.on('exit', (code, signal) => {
    log.write(`\nproxy exited code=${code} signal=${signal}\n`).catch(() => {});
    log.close().catch(() => {});
  });

  try {
    await waitForHttp(appUrl);
    return child;
  } catch (error) {
    child.kill();
    throw error;
  }
}

async function stopProxy(child) {
  if (!child) return;
  child.kill();
  await sleep(500);
}

async function installStableNetworkStubs(page) {
  await page.routeWebSocket(
    /^wss:\/\/api\.kubus\.site\/socket\.io\//,
    (webSocket) => {
      webSocket.onMessage((message) => {
        const text = message.toString();
        if (text === '2') {
          webSocket.send('3');
        } else if (text.startsWith('40')) {
          webSocket.send('40{"sid":"qa-socket"}');
        }
      });
      webSocket.send(
        '0{"sid":"qa-engine","upgrades":[],"pingInterval":25000,"pingTimeout":20000,"maxPayload":1000000}',
      );
    },
  );

  await page.route(/^https:\/\/(?:api|bapi)\.kubus\.site\//, async (route) => {
    const request = route.request();
    await route.fulfill(buildStableApiStub(request.url(), request.method()));
  });

  await page.route('https://accounts.google.com/gsi/client**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/javascript; charset=utf-8',
      body: `
        (() => {
          const noop = () => {};
          const promptMoment = {
            isDisplayed: () => false,
            isNotDisplayed: () => true,
            isSkippedMoment: () => true,
            isDismissedMoment: () => false,
            getNotDisplayedReason: () => 'qa-stub',
            getSkippedReason: () => 'qa-stub',
            getDismissedReason: () => 'qa-stub'
          };
          window.google = window.google || {};
          window.google.accounts = window.google.accounts || {};
          window.google.accounts.id = Object.assign({
            initialize: noop,
            prompt: (callback) => {
              if (typeof callback === 'function') callback(promptMoment);
            },
            renderButton: noop,
            cancel: noop,
            disableAutoSelect: noop,
            revoke: (_hint, callback) => {
              if (typeof callback === 'function') callback({ successful: true });
            }
          }, window.google.accounts.id || {});
          window.google.accounts.oauth2 = Object.assign({
            initTokenClient: () => ({ requestAccessToken: noop }),
            initCodeClient: () => ({ requestCode: noop }),
            hasGrantedAllScopes: () => false,
            hasGrantedAnyScope: () => false,
            revoke: noop
          }, window.google.accounts.oauth2 || {});
        })();
      `,
    });
  });
}

async function captureRuntime(contextOptions, name) {
  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();
  const consoleEntries = [];
  const httpErrors = [];
  const pageErrors = [];
  const requestFailures = [];

  page.on('console', (msg) => {
    consoleEntries.push(`[${msg.type()}] ${msg.text()}`);
  });
  page.on('pageerror', (error) => {
    pageErrors.push(error.stack || error.message);
  });
  page.on('response', (response) => {
    if (response.status() >= 400) {
      httpErrors.push(`${response.status()} ${response.request().method()} ${response.url()}`);
    }
  });
  page.on('requestfailed', (request) => {
    requestFailures.push(
      `${request.method()} ${request.url()} ${request.failure()?.errorText || ''}`.trim(),
    );
  });
  await installStableNetworkStubs(page);

  await page.addInitScript(() => {
    const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
    set('has_completed_onboarding', 'true');
    set('has_seen_welcome', 'true');
    set('is_first_launch', 'false');
    set('skipOnboardingForReturningUsers', 'true');
    set('map_onboarding_mobile_seen_v2', 'true');
    set('map_onboarding_desktop_seen_v2', 'true');
  });

  // Every capture uses a fresh Playwright context. Do not pass the production
  // clear_sw escape hatch here: index.html responds to it with location.replace,
  // which legitimately aborts in-flight CSS/JS and makes request-failure checks
  // nondeterministic. Localhost already clears matching Flutter caches without
  // forcing a navigation, and a new context has no prior service-worker state.
  const response = await page.goto(`${appUrl}/`, {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  if (!response || !response.ok()) {
    throw new Error(`${name}: initial navigation failed with ${response?.status() || 'no response'}`);
  }

  await page.waitForFunction(
    () =>
      Boolean(
        document.querySelector('flutter-view') ||
          document.querySelector('flt-glass-pane') ||
          document.querySelector('canvas'),
      ),
    { timeout: 45000 },
  );
  await page.waitForTimeout(5000);

  const screenshotPath = path.join(artifactDir, `${name}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true });

  const state = await page.evaluate(() => {
    const bodyText = document.body.innerText || '';
    return {
      href: location.href,
      title: document.title,
      bodyText: bodyText.slice(0, 2000),
      flutterViewCount: document.querySelectorAll('flutter-view').length,
      glassPaneCount: document.querySelectorAll('flt-glass-pane').length,
      canvasCount: document.querySelectorAll('canvas').length,
      semanticsCount: document.querySelectorAll('flt-semantics').length,
    };
  });

  const consoleErrors = consoleEntries.filter((entry) =>
    entry.startsWith('[error]'),
  );
  await fs.writeFile(
    path.join(artifactDir, `${name}.json`),
    JSON.stringify(
      {
        state,
        consoleEntries,
        consoleErrors,
        httpErrors,
        pageErrors,
        requestFailures,
        screenshotPath,
      },
      null,
      2,
    ),
    'utf8',
  );

  await context.close();

  if (
    state.flutterViewCount + state.glassPaneCount + state.canvasCount ===
    0
  ) {
    throw new Error(`${name}: Flutter runtime markers were not found.`);
  }
  if (pageErrors.length > 0) {
    throw new Error(`${name}: page errors found: ${pageErrors.join(' | ')}`);
  }
  if (consoleErrors.length > 0) {
    throw new Error(`${name}: console errors found: ${consoleErrors.join(' | ')}`);
  }
  if (httpErrors.length > 0) {
    throw new Error(`${name}: HTTP errors found: ${httpErrors.join(' | ')}`);
  }
  if (requestFailures.length > 0) {
    throw new Error(
      `${name}: request failures found: ${requestFailures.join(' | ')}`,
    );
  }
}

let proxy = null;
let browser = null;
try {
  proxy = await startProxyIfNeeded();
  browser = await chromium.launch({ headless: true });

  await captureRuntime(
    {
      viewport: { width: 1440, height: 1100 },
      deviceScaleFactor: 1,
    },
    'desktop-home',
  );
  await captureRuntime(
    {
      ...devices['iPhone 13'],
    },
    'mobile-home',
  );

  console.log(`Web runtime smoke passed. Artifacts: ${artifactDir}`);
} finally {
  if (browser) await browser.close();
  await stopProxy(proxy);
}
