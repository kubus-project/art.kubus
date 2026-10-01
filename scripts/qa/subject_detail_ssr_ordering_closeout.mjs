import { mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, firefox } from 'playwright';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const baseUrl = process.env.SEO_PREVIEW_URL || 'http://127.0.0.1:4177';
const outputDir = resolve(root, 'output/playwright/subject-detail-ux/ssr-ordering-closeout');
const subjects = [
  { type: 'event', path: '/en/events/33333333-3333-4333-8333-333333333333', title: 'Art by the River' },
  { type: 'exhibition', path: '/en/exhibitions/44444444-4444-4444-8444-444444444444', title: 'Shared Currents' },
];

function ensure(condition, message) {
  if (!condition) throw new Error(message);
}

function chromePath() {
  const configured = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE;
  const systemChrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  if (configured && existsSync(configured)) return configured;
  return existsSync(systemChrome) ? systemChrome : undefined;
}

async function launch(name, type) {
  const executablePath = name === 'chromium' ? chromePath() : undefined;
  return type.launch({ headless: true, ...(executablePath ? { executablePath } : {}) });
}

async function measureSsr(page, width, type) {
  return page.evaluate(({ viewportWidth, type }) => {
    const media = document.querySelector('.entity-media');
    const detail = document.querySelector('.entity-detail');
    const title = detail?.querySelector('h1');
    const facts = detail?.querySelector('.entity-facts');
    const place = detail?.querySelector('.entity-place');
    const image = media?.querySelector('img');
    const box = (node) => {
      if (!node) return null;
      const rect = node.getBoundingClientRect();
      return { top: Math.round(rect.top), left: Math.round(rect.left), width: Math.round(rect.width), height: Math.round(rect.height) };
    };
    return {
      viewportWidth,
      scrollY: window.scrollY,
      scrollWidth: document.documentElement.scrollWidth,
      media: box(media),
      mediaOrder: media ? getComputedStyle(media).order : null,
      title: box(title),
      firstContext: box(type === 'event' ? facts || place : place || facts),
      venueOrInstitution: box(place),
      venueOrInstitutionDisplay: place ? getComputedStyle(place).display : null,
      dateAndLocationFacts: box(facts),
      mediaImage: image ? { complete: image.complete, width: image.naturalWidth, height: image.naturalHeight } : null,
      detail: box(detail),
      layoutColumns: getComputedStyle(document.querySelector('.entity-layout')).gridTemplateColumns,
      canonical: document.querySelector('link[rel="canonical"]')?.href || null,
      heading: title?.textContent?.trim() || null,
    };
  }, { viewportWidth: width, type });
}

async function captureSsr(browser, browserName, subject, width, takeScreenshot = true) {
  const page = await browser.newPage({
    viewport: { width, height: 844 },
    javaScriptEnabled: false,
    reducedMotion: 'reduce',
    colorScheme: 'light',
  });
  try {
    const response = await page.goto(`${baseUrl}${subject.path}`, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `${subject.type} SSR status was ${response?.status()}`);
    await page.locator('.entity-detail h1').waitFor({ state: 'visible' });
    await page.waitForFunction(() => {
      const image = document.querySelector('.entity-media img');
      return !image || (image.complete && image.naturalWidth > 0);
    }, null, { timeout: 15000 });
    await page.waitForTimeout(250);
    const metrics = await measureSsr(page, width, subject.type);
    ensure(metrics.heading === subject.title, `${subject.type} title mismatch: ${metrics.heading}`);
    ensure(metrics.scrollY === 0, `${subject.type} SSR did not open at the top`);
    ensure(metrics.scrollWidth <= width, `${subject.type} SSR overflows ${width}px`);
    if (width === 390) {
      ensure(metrics.media.top < metrics.title.top, `${subject.type} SSR media does not precede title`);
      ensure(metrics.mediaOrder === '-1', `${subject.type} compact media order is ${metrics.mediaOrder}`);
      if (subject.type === 'event') {
        ensure(metrics.firstContext.top > metrics.title.top, 'Event date/location facts do not follow its title');
        ensure(metrics.venueOrInstitutionDisplay === 'none', 'Event repeated its venue before the labeled date/location facts');
      } else {
        ensure(metrics.venueOrInstitution.top < metrics.dateAndLocationFacts.top,
          'Exhibition institution context does not precede dates');
      }
    } else {
      ensure(metrics.mediaOrder === '0', `${subject.type} desktop media order changed: ${metrics.mediaOrder}`);
      ensure(metrics.detail.left < metrics.media.left, `${subject.type} desktop grid order changed`);
      ensure(metrics.venueOrInstitutionDisplay !== 'none', `${subject.type} desktop place presentation changed`);
    }
    const screenshot = takeScreenshot
      ? resolve(outputDir, `${subject.type}-${width}-${browserName}-ssr.png`)
      : null;
    if (screenshot) await page.screenshot({ path: screenshot, fullPage: false });
    return { browser: browserName, type: subject.type, state: 'ssr', ...metrics, screenshot };
  } finally {
    await page.close();
  }
}

async function captureFlutter(browser, browserName, subject, width) {
  const context = await browser.newContext({
    viewport: { width, height: 844 },
    reducedMotion: 'reduce',
    colorScheme: 'light',
  });
  const page = await context.newPage();
  await page.route('https://api.kubus.site/**', async (route) => {
    const requested = new URL(route.request().url());
    await route.fulfill({ response: await route.fetch({ url: `${baseUrl}${requested.pathname}${requested.search}` }) });
  });
  try {
    const response = await page.goto(`${baseUrl}${subject.path}`, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `${subject.type} takeover SSR status was ${response?.status()}`);
    await page.waitForFunction(() => performance.getEntriesByName('flutter_takeover_completed').length === 1, null, { timeout: 90000 });
    await page.waitForTimeout(250);
    const metrics = await page.evaluate(() => ({
      viewportWidth: document.documentElement.clientWidth,
      scrollY: window.scrollY,
      scrollWidth: document.documentElement.scrollWidth,
      flutterLeft: Math.round(document.querySelector('flutter-view')?.getBoundingClientRect().left ?? -1),
      flutterTop: Math.round(document.querySelector('flutter-view')?.getBoundingClientRect().top ?? -1),
      flutterWidth: Math.round(document.querySelector('flutter-view')?.getBoundingClientRect().width ?? -1),
      canonical: document.querySelector('link[rel="canonical"]')?.href || null,
      pathname: window.location.pathname,
      publicDocumentHidden: getComputedStyle(document.querySelector('#public-document')).opacity === '0',
    }));
    ensure(metrics.scrollY === 0, `${subject.type} takeover changed scroll position`);
    ensure(metrics.scrollWidth <= width, `${subject.type} Flutter overflows ${width}px`);
    ensure(metrics.flutterLeft === 0 && metrics.flutterTop === 0 && metrics.flutterWidth === width,
      `${subject.type} Flutter does not fill the viewport: ${JSON.stringify(metrics)}`);
    ensure(metrics.pathname === subject.path && metrics.canonical === `${baseUrl}${subject.path}`,
      `${subject.type} takeover left canonical entry`);
    ensure(metrics.publicDocumentHidden, `${subject.type} SSR remained visible after takeover`);
    const screenshot = resolve(outputDir, `${subject.type}-${width}-${browserName}-flutter.png`);
    await page.screenshot({ path: screenshot, fullPage: false });
    return { browser: browserName, type: subject.type, state: 'flutter', ...metrics, screenshot };
  } finally {
    await context.close();
  }
}

await mkdir(outputDir, { recursive: true });
const results = [];
for (const [name, type] of [['chromium', chromium], ['firefox', firefox]]) {
  const browser = await launch(name, type);
  try {
    for (const subject of subjects) {
      results.push(await captureSsr(browser, name, subject, 390));
      results.push(await captureFlutter(browser, name, subject, 390));
      if (name === 'chromium') {
        results.push(await captureSsr(browser, name, subject, 1440));
        results.push(await captureFlutter(browser, name, subject, 1440));
        for (const width of [900, 1024, 1280]) {
          results.push(await captureSsr(browser, name, subject, width, false));
        }
      }
    }
  } finally {
    await browser.close();
  }
}

const report = {
  sourceAppHead: 'a3dff933e8983f348d6a638664e1d17a0d5786c1',
  rendererBranch: 'fix/subject-detail-ssr-ordering',
  preview: baseUrl,
  fixtures: 'synthetic public-only SEO preview fixtures',
  comparison: 'SSR top-order/identity bounds and Flutter viewport/scroll/canonical continuity; screenshots are retained alongside this report',
  desktopRegressionWidths: [900, 1024, 1280, 1440],
  results: results.map((result) => ({
    ...result,
    screenshot: result.screenshot ? relative(root, result.screenshot).replaceAll('\\', '/') : null,
  })),
};
await writeFile(resolve(outputDir, 'continuity.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({ outputDir, captures: results.length }, null, 2));
