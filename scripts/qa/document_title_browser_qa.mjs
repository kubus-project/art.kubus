// Browser regression for the document title and head metadata through Flutter hydration and in-app navigation.
//
// Runs against a served release web build (the derived /en and /sl shells must be served at /en and /sl; entity URLs
// are served by the SEO renderer with takeover). Environment:
//   WEB_URL        origin of the web build              (default http://127.0.0.1:8090)
//   ARTWORK_PATH   a published artwork path, e.g. /en/artworks/<id>   (optional; skips the entity checks when unset)
//   BROWSERS       comma list                            (default chromium,firefox)
//   QA_OUT         output directory for screenshots/results
// Exits non-zero on any failed check.
import fs from 'node:fs';
import path from 'node:path';
import { chromium, firefox } from 'playwright';

const WEB = (process.env.WEB_URL || 'http://127.0.0.1:8090').replace(/\/$/, '');
const ARTWORK_PATH = process.env.ARTWORK_PATH || '';
const BROWSERS = (process.env.BROWSERS || 'chromium,firefox').split(',').map((s) => s.trim()).filter(Boolean);
const OUT = path.resolve(process.env.QA_OUT || 'output/playwright/artifacts/document-title');
const APPROVED_IMAGE = 'https://app.kubus.site/images/social-preview.png';
fs.mkdirSync(OUT, { recursive: true });

const results = [];
const check = (browser, name, ok, extra = '') => {
  results.push({ browser, name, ok: Boolean(ok), extra: String(extra).slice(0, 240) });
  console.log(`${ok ? 'PASS' : 'FAIL'} [${browser}] ${name}${extra ? '  ' + String(extra).slice(0, 200) : ''}`);
};

const head = (html) => ({
  title: (html.match(/<title>([^<]*)<\/title>/) || [])[1],
  ogTitle: (html.match(/<meta property="og:title" content="([^"]*)"/) || [])[1],
  twitterTitle: (html.match(/<meta name="twitter:title" content="([^"]*)"/) || [])[1],
  ogImage: (html.match(/<meta property="og:image" content="([^"]*)"/) || [])[1],
  twitterImage: (html.match(/<meta name="twitter:image" content="([^"]*)"/) || [])[1],
  canonical: (html.match(/<link rel="canonical" href="([^"]*)"/) || [])[1],
  lang: (html.match(/<html lang="([^"]*)"/) || [])[1],
});
const unescape = (v) => (v || '').replace(/&amp;/g, '&').replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
const liveHead = (page) => page.evaluate(() => ({
  title: document.title,
  ogTitle: document.querySelector('meta[property="og:title"]')?.content,
  twitterTitle: document.querySelector('meta[name="twitter:title"]')?.content,
  ogImage: document.querySelector('meta[property="og:image"]')?.content,
  twitterImage: document.querySelector('meta[name="twitter:image"]')?.content,
  canonical: document.querySelector('link[rel=canonical]')?.href,
  lang: document.documentElement.lang,
}));
const enableSemantics = async (page) => {
  await page.evaluate(() => { const el = document.querySelector('flt-semantics-placeholder') || document.querySelector('[aria-label="Enable accessibility"]'); if (el) el.click(); }).catch(() => {});
  await page.waitForTimeout(800);
};
const click = async (page, re) => {
  const box = await page.evaluate((src) => {
    const rx = new RegExp(src, 'i');
    const name = (n) => (n.getAttribute('aria-label') || n.textContent || '').trim();
    const m = Array.from(document.querySelectorAll('flt-semantics')).filter((n) => rx.test(name(n))).filter((n) => { const r = n.getBoundingClientRect(); return r.width > 4 && r.height > 4; })
      .sort((a, b) => ((a.getAttribute('role') === 'button' ? 0 : 1) - (b.getAttribute('role') === 'button' ? 0 : 1)) || (a.getBoundingClientRect().width * a.getBoundingClientRect().height - b.getBoundingClientRect().width * b.getBoundingClientRect().height));
    if (!m[0]) return null;
    const r = m[0].getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, re.source);
  if (!box) return false;
  await page.mouse.click(box.x, box.y);
  await page.waitForTimeout(2500);
  return true;
};
const settleTitle = async (page, expected, ms = 15000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { if ((await page.title()) === expected) return true; await page.waitForTimeout(400); }
  return false;
};

for (const browserName of BROWSERS) {
  const browser = await (browserName === 'firefox' ? firefox : chromium).launch();
  try {
    // 1. bare roots: served head vs hydrated head
    for (const p of ['/', '/en', '/sl']) {
      const served = head(await (await fetch(WEB + p)).text());
      const lang = p === '/sl' ? 'sl' : 'en';
      const generic = 'art.kubus';
      check(browserName, `${p}: served title is localized, not the generic brand`, served.title && served.title !== generic && (lang === 'sl' ? /Odprti zemljevid/.test(served.title) : /Open Art Map/.test(served.title)), served.title);
      check(browserName, `${p}: Open Graph and Twitter images are the approved social image`, served.ogImage === APPROVED_IMAGE && served.twitterImage === APPROVED_IMAGE, `${served.ogImage} | ${served.twitterImage}`);
      check(browserName, `${p}: Open Graph and Twitter titles match the title`, unescape(served.ogTitle) === unescape(served.title) && unescape(served.twitterTitle) === unescape(served.title), `${served.ogTitle} | ${served.twitterTitle}`);
      const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
      const page = await ctx.newPage();
      const errors = []; page.on('pageerror', (e) => errors.push(String(e).slice(0, 160)));
      const fontRequests = []; page.on('request', (r) => { if (/fonts\.(googleapis|gstatic)\.com/.test(r.url())) fontRequests.push(r.url()); });
      await page.goto(WEB + p, { waitUntil: 'load' });
      const early = await page.title();
      check(browserName, `${p}: title before Flutter initialization equals the served title`, early === unescape(served.title), early);
      await page.waitForTimeout(10000);
      await enableSemantics(page);
      const live = await liveHead(page);
      check(browserName, `${p}: title after Flutter initialization is unchanged (no generic fallback)`, live.title === unescape(served.title), live.title);
      check(browserName, `${p}: hydrated head keeps canonical, lang, Open Graph/Twitter titles and the approved image`, live.canonical === served.canonical && live.lang === served.lang && unescape(live.ogTitle) === unescape(served.ogTitle) && unescape(live.twitterTitle) === unescape(served.twitterTitle) && live.ogImage === APPROVED_IMAGE && live.twitterImage === APPROVED_IMAGE, JSON.stringify({ c: live.canonical, l: live.lang }));
      check(browserName, `${p}: no third-party font request, no page error`, fontRequests.length === 0 && errors.length === 0, `${fontRequests.join(',')} ${errors.join('|')}`);
      if (p === '/sl') {
        // 2. in-app navigation and history
        const historyBefore = await page.evaluate(() => history.length);
        const nav = await click(page, /^Nastavitve$|^Settings$/);
        const afterNav = await page.title();
        const historyAfter = await page.evaluate(() => history.length);
        check(browserName, '/sl: in-app navigation keeps a localized (Slovenian) title', nav && /Odprti zemljevid/.test(afterNav), `${nav} ${afterNav}`);
        if (historyAfter > historyBefore) {
          await page.goBack();
          await page.waitForTimeout(2500);
          check(browserName, '/sl: browser back restores the localized title', await settleTitle(page, unescape(served.title), 8000), await page.title());
          await page.goForward();
          await page.waitForTimeout(2500);
          const fwd = await page.title();
          check(browserName, '/sl: browser forward keeps a localized title (never the generic brand)', fwd !== generic && /Odprti zemljevid/.test(fwd), fwd);
        } else {
          check(browserName, '/sl: in-app navigation replaces the history entry (no back/forward step to verify here)', true, `history ${historyBefore} -> ${historyAfter}`);
        }
        await page.screenshot({ path: path.join(OUT, `${browserName}-sl.png`) });
      }
      await ctx.close();
    }
    // 3. entity page: the artwork-specific title survives hydration and returns on back
    if (ARTWORK_PATH) {
      const servedRaw = await (await fetch(WEB + ARTWORK_PATH)).text();
      const served = head(servedRaw);
      const expected = unescape(served.title);
      check(browserName, `${ARTWORK_PATH}: served title is artwork-specific`, expected && !/^art\.kubus/.test(expected) && / \| art\.kubus$/.test(expected), expected);
      const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
      const page = await ctx.newPage();
      await page.goto(WEB + ARTWORK_PATH, { waitUntil: 'load' });
      await page.waitForTimeout(12000);
      await enableSemantics(page);
      const live = await liveHead(page);
      check(browserName, `${ARTWORK_PATH}: artwork title is retained after hydration`, live.title === expected, live.title);
      check(browserName, `${ARTWORK_PATH}: canonical and Open Graph metadata are retained`, live.canonical === served.canonical && unescape(live.ogTitle) === unescape(served.ogTitle), live.canonical);
      const moved = await click(page, /^Home$|^Domov$|^Explore$|^Raziskuj$/);
      const away = await page.title();
      check(browserName, `${ARTWORK_PATH}: leaving the artwork switches to the localized application title`, moved && away !== expected && away !== 'art.kubus', `${moved} ${away}`);
      await page.goBack();
      await page.waitForTimeout(3000);
      check(browserName, `${ARTWORK_PATH}: back restores the artwork title`, await settleTitle(page, expected, 10000), await page.title());
      await page.screenshot({ path: path.join(OUT, `${browserName}-artwork.png`) });
      await ctx.close();
    }
  } finally {
    await browser.close();
  }
}

const failed = results.filter((r) => !r.ok);
fs.writeFileSync(path.join(OUT, 'results.json'), JSON.stringify({ web: WEB, artwork: ARTWORK_PATH, passed: results.length - failed.length, failed: failed.length, results }, null, 2));
console.log(`SUMMARY document title: ${results.length - failed.length} passed, ${failed.length} failed`);
process.exit(failed.length ? 1 : 0);
