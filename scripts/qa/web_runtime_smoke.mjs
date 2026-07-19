import { execSync, spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
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
// QA_MATRIX=full expands the two default captures into the responsive ×
// theme × locale (+ reduced-motion) matrix.
const fullMatrix = (process.env.QA_MATRIX || '').trim() === 'full';

await fs.mkdir(artifactDir, { recursive: true });

function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

/**
 * Refuse to run against a server this harness did not start. A leftover
 * proxy from an earlier session once served a stale bundle on the QA port
 * and silently invalidated a whole screenshot round; failing fast here
 * makes that impossible. Explicit APP_URL runs opt out (the caller owns
 * that server), but the served-bundle fingerprint check still applies.
 */
async function assertPortIsFree() {
  if (requestedUrl) return;
  let responded = false;
  try {
    const response = await fetch(appUrl, {
      signal: AbortSignal.timeout(1500),
    });
    responded = Boolean(response);
  } catch {
    // No listener — the port is ours to take.
  }
  if (responded) {
    throw new Error(
      `${appUrl} is already serving content before the QA proxy started. ` +
        'A stale server owns the port; kill it and re-run.',
    );
  }
}

/**
 * Prove the screenshots come from the intended build: hash the on-disk
 * bundle, hash the served bundle, and require them to match. The git commit
 * and dirty state pin the evidence to a revision.
 */
async function collectBuildFingerprint() {
  const bundlePath = path.join(rootDir, 'build', 'web', 'main.dart.js');
  const diskBundle = await fs.readFile(bundlePath);
  const diskHash = sha256(diskBundle);

  const servedResponse = await fetch(`${appUrl}/main.dart.js`);
  if (!servedResponse.ok) {
    throw new Error(
      `Could not fetch served bundle for fingerprinting: HTTP ${servedResponse.status}`,
    );
  }
  const servedHash = sha256(Buffer.from(await servedResponse.arrayBuffer()));

  if (servedHash !== diskHash) {
    throw new Error(
      `Served main.dart.js (${servedHash.slice(0, 12)}) does not match ` +
        `build/web/main.dart.js (${diskHash.slice(0, 12)}). ` +
        'The server is delivering a different build than the local output.',
    );
  }

  let gitCommit = 'unknown';
  let gitDirty = null;
  try {
    gitCommit = execSync('git rev-parse HEAD', { cwd: rootDir })
      .toString()
      .trim();
    gitDirty =
      execSync('git status --porcelain --untracked-files=no', { cwd: rootDir })
        .toString()
        .trim().length > 0;
  } catch {
    // Not a git checkout — record the hashes only.
  }

  let version = null;
  try {
    version = JSON.parse(
      await fs.readFile(
        path.join(rootDir, 'build', 'web', 'version.json'),
        'utf8',
      ),
    );
  } catch {
    // version.json is optional.
  }

  return {
    appUrl,
    gitCommit,
    gitDirty,
    mainDartJsSha256: diskHash,
    servedMainDartJsSha256: servedHash,
    version,
    capturedAt: new Date().toISOString(),
  };
}

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

  return {
    name,
    screenshot: path.basename(screenshotPath),
    viewport: contextOptions.viewport || null,
    colorScheme: contextOptions.colorScheme || 'light',
    locale: contextOptions.locale || 'en-US',
    reducedMotion: contextOptions.reducedMotion || 'no-preference',
    consoleErrorCount: consoleErrors.length,
    httpErrorCount: httpErrors.length,
    pageErrorCount: pageErrors.length,
    requestFailureCount: requestFailures.length,
  };
}

/** Capture contexts for the full responsive × theme × locale matrix. */
function matrixContexts() {
  const viewports = [
    { name: 'mobile-390x844', width: 390, height: 844 },
    { name: 'mobile-412x915', width: 412, height: 915 },
    { name: 'tablet-1024x768', width: 1024, height: 768 },
    { name: 'desktop-1440x1000', width: 1440, height: 1000 },
  ];
  const contexts = [];
  for (const viewport of viewports) {
    for (const colorScheme of ['light', 'dark']) {
      for (const locale of ['en-US', 'sl-SI']) {
        contexts.push({
          name: `${viewport.name}-${colorScheme}-${locale.slice(0, 2)}`,
          options: {
            viewport: { width: viewport.width, height: viewport.height },
            deviceScaleFactor: 1,
            colorScheme,
            locale,
          },
        });
      }
    }
  }
  // Reduced-motion spot checks on the two extreme viewports.
  contexts.push({
    name: 'mobile-390x844-dark-en-reduced-motion',
    options: {
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 1,
      colorScheme: 'dark',
      locale: 'en-US',
      reducedMotion: 'reduce',
    },
  });
  contexts.push({
    name: 'desktop-1440x1000-light-en-reduced-motion',
    options: {
      viewport: { width: 1440, height: 1000 },
      deviceScaleFactor: 1,
      colorScheme: 'light',
      locale: 'en-US',
      reducedMotion: 'reduce',
    },
  });
  return contexts;
}

let proxy = null;
let browser = null;
try {
  await assertPortIsFree();
  proxy = await startProxyIfNeeded();
  const fingerprint = await collectBuildFingerprint();
  browser = await chromium.launch({ headless: true });

  const captures = [];
  if (fullMatrix) {
    for (const context of matrixContexts()) {
      captures.push(await captureRuntime(context.options, context.name));
    }
  } else {
    captures.push(
      await captureRuntime(
        {
          viewport: { width: 1440, height: 1100 },
          deviceScaleFactor: 1,
        },
        'desktop-home',
      ),
    );
    captures.push(
      await captureRuntime(
        {
          ...devices['iPhone 13'],
        },
        'mobile-home',
      ),
    );
  }

  await fs.writeFile(
    path.join(artifactDir, 'report.json'),
    JSON.stringify(
      {
        passed: true,
        matrix: fullMatrix ? 'full' : 'default',
        fingerprint,
        captures,
      },
      null,
      2,
    ),
    'utf8',
  );

  console.log(
    `Web runtime smoke passed (${captures.length} captures, commit ` +
      `${fingerprint.gitCommit.slice(0, 8)}). Artifacts: ${artifactDir}`,
  );
} finally {
  if (browser) await browser.close();
  await stopProxy(proxy);
}
