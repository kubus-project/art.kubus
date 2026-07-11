import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { chromium } from 'playwright';

const baseUrl = (process.env.ADMIN_QA_BASE_URL || 'http://127.0.0.1:4173').replace(/\/$/, '');
const artifactRoot = resolve(
  process.env.QA_ARTIFACT_DIR || 'output/playwright/artifacts/admin-cdp-fixture',
);

const seededEvent = {
  id: 'fixture-error-1',
  errorId: 'err_fixture_1',
  severity: 'error',
  source: 'backend_request',
  environment: 'staging',
  service: 'api',
  releaseVersion: '0.6.2',
  commitSha: 'abcdef0123456789',
  message: 'Seeded database timeout used for deterministic visual QA',
  errorName: 'DatabaseUnavailableError',
  stackHash: 'fixture-stack-hash',
  stackPreview: null,
  method: 'GET',
  path: '/api/community/posts',
  routeGroup: 'community',
  statusCode: 503,
  latencyMs: 1250,
  actorUserId: null,
  actorWallet: null,
  sessionId: 'fixture-session',
  requestId: 'fixture-request',
  userAgent: 'Playwright visual fixture',
  clientType: 'web',
  clientVersion: '0.6.2',
  screenName: 'Community',
  screenRoute: '/community',
  flowStage: 'load',
  firstSeenAt: '2026-07-11T07:00:00.000Z',
  lastSeenAt: '2026-07-11T08:00:00.000Z',
  occurrenceCount: 3,
  resolvedAt: null,
  resolvedBy: null,
  resolutionNote: null,
};

function json(route, body, status = 200) {
  return route.fulfill({
    status,
    contentType: 'application/json',
    body: JSON.stringify(body),
  });
}

async function fulfillAdminFixture(route) {
  const requestUrl = new URL(route.request().url());
  const { pathname } = requestUrl;

  if (pathname === '/api/admin/auth/me') {
    return json(route, {
      success: true,
      admin: { username: 'fixture-admin', roles: ['admin'] },
      csrfToken: 'fixture-csrf-token',
    });
  }

  if (pathname === '/api/admin/cdp/errors/summary') {
    return json(route, {
      success: true,
      data: {
        unresolvedErrors: 1,
        newErrors24h: 1,
        affectedUsers: 0,
        affectedSessions: 1,
        frontendCrashes: 0,
        backend500s: 0,
        failedAuthGis: 0,
        failedMediaProxy: 0,
        topFailingRoute: {
          path: '/api/community/posts',
          statusCode: 503,
          occurrences: 3,
        },
        slowestEndpoint: {
          path: '/api/community/posts',
          method: 'GET',
          latencyMs: 1250,
        },
      },
    });
  }

  if (pathname === '/api/admin/cdp/errors/recent') {
    return json(route, {
      success: true,
      data: {
        items: [seededEvent],
        count: 1,
        total: 1,
        limit: 50,
        offset: 0,
      },
    });
  }

  if (pathname === '/api/admin/cdp/errors/groups') {
    return json(route, {
      success: true,
      data: {
        items: [{
          source: seededEvent.source,
          stackHash: seededEvent.stackHash,
          path: seededEvent.path,
          statusCode: seededEvent.statusCode,
          firstSeenAt: seededEvent.firstSeenAt,
          lastSeenAt: seededEvent.lastSeenAt,
          occurrenceCount: seededEvent.occurrenceCount,
          eventCount: 1,
          message: seededEvent.message,
          severity: seededEvent.severity,
          sampleId: seededEvent.id,
        }],
        total: 1,
        limit: 50,
        offset: 0,
      },
    });
  }

  return json(route, {
    success: false,
    error: `Visual fixture has no response for ${pathname}`,
  }, 404);
}

async function capture(browser, scenario) {
  const context = await browser.newContext({
    colorScheme: scenario.colorScheme,
    viewport: scenario.viewport,
  });
  const page = await context.newPage();
  const diagnostics = [];

  page.on('pageerror', (error) => diagnostics.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') diagnostics.push(`console: ${message.text()}`);
  });
  await page.route('**/api/admin/**', fulfillAdminFixture);

  await page.goto(`${baseUrl}/ops/errors`, { waitUntil: 'networkidle' });
  await page.getByText('Seeded database timeout used for deterministic visual QA').waitFor();
  await page.screenshot({
    path: resolve(artifactRoot, `${scenario.name}.png`),
    fullPage: true,
  });

  await context.close();
  if (diagnostics.length > 0) {
    throw new Error(`${scenario.name} emitted browser errors:\n${diagnostics.join('\n')}`);
  }
}

await mkdir(artifactRoot, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  for (const scenario of [
    { name: 'desktop-light', colorScheme: 'light', viewport: { width: 1440, height: 1000 } },
    { name: 'desktop-dark', colorScheme: 'dark', viewport: { width: 1440, height: 1000 } },
    { name: 'mobile-light', colorScheme: 'light', viewport: { width: 390, height: 844 } },
    { name: 'mobile-dark', colorScheme: 'dark', viewport: { width: 390, height: 844 } },
  ]) {
    await capture(browser, scenario);
  }
} finally {
  await browser.close();
}

console.log(`Admin CDP visual fixture passed; screenshots: ${artifactRoot}`);
