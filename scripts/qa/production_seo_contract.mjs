#!/usr/bin/env node
// Reusable production SEO transport contract for app.kubus.site.
//
// Asserts the public routing contract end to end against a live origin:
// root canonicalization, compact alias redirects, localized canonical entity
// rendering, real 404s, robots/sitemap ownership, and semantic-renderer versus
// app-shell separation.
//
// Usage:
//   node scripts/qa/production_seo_contract.mjs
//   KUBUS_ORIGIN=https://app.kubus.site \
//   KUBUS_ARTWORK_ID=<uuid> node scripts/qa/production_seo_contract.mjs
//
// Exits non-zero on any FAIL so it can gate CI and post-deploy verification.

const ORIGIN = (process.env.KUBUS_ORIGIN ?? 'https://app.kubus.site').replace(/\/+$/, '');
const ARTWORK_ID = process.env.KUBUS_ARTWORK_ID ?? '';
const MISSING_ID = '00000000-0000-0000-0000-000000000000';
const TIMEOUT_MS = Number(process.env.KUBUS_TIMEOUT_MS ?? 25000);
// Optional WAF bypass header (see smoke_production_web.sh); empty when unset.
const SMOKE_BYPASS_TOKEN = (process.env.SMOKE_BYPASS_TOKEN ?? '').trim();
const BYPASS_HEADERS = SMOKE_BYPASS_TOKEN ? { 'X-Deploy-Smoke': SMOKE_BYPASS_TOKEN } : {};

const results = [];

function record(name, ok, detail) {
  results.push({ name, ok, detail });
  const label = ok ? 'PASS' : 'FAIL';
  console.log(`${label}  ${name}\n      ${detail}`);
}

async function fetchNoRedirect(path, init = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fetch(`${ORIGIN}${path}`, {
      redirect: 'manual',
      signal: controller.signal,
      headers: { 'Cache-Control': 'no-cache', ...BYPASS_HEADERS, ...(init.headers ?? {}) },
      ...init,
    });
  } finally {
    clearTimeout(timer);
  }
}

function firstMatch(html, pattern) {
  const match = html.match(pattern);
  return match ? match[1].trim() : null;
}

async function checkStatus(name, path, expected) {
  try {
    const res = await fetchNoRedirect(path);
    record(name, res.status === expected, `${path} -> ${res.status} (expected ${expected})`);
    return res;
  } catch (error) {
    record(name, false, `${path} -> request failed: ${error.message}`);
    return null;
  }
}

async function checkRedirect(name, path, expectedStatus, expectedLocation) {
  try {
    const res = await fetchNoRedirect(path);
    const raw = res.headers.get('location');
    // A relative Location is valid per RFC 7231 and is what the public renderer
    // emits, so resolve against the origin before comparing.
    const location = raw === null ? null : new URL(raw, `${ORIGIN}/`).toString();
    const ok = res.status === expectedStatus && location === expectedLocation;
    record(name, ok, `${path} -> ${res.status} ${location ?? '<no location>'} (expected ${expectedStatus} ${expectedLocation})`);
  } catch (error) {
    record(name, false, `${path} -> request failed: ${error.message}`);
  }
}

async function main() {
  console.log(`Production SEO contract against ${ORIGIN}\n`);

  // --- Root canonicalization -------------------------------------------------
  // Root must collapse into the localized canonical in one permanent hop and
  // must never serve the app shell as a competing indexable homepage.
  await checkRedirect('root canonicalization', '/', 308, `${ORIGIN}/en`);

  // ?lang= selects the locale and is then dropped: carrying it through would
  // produce /sl?lang=sl, a redundant parameter on a URL whose locale is already
  // in the path. Tracking parameters must survive, so attribution is not lost
  // at the redirect.
  await checkRedirect('language alias dropped (?lang=sl)', '/?lang=sl', 308, `${ORIGIN}/sl`);
  await checkRedirect('language alias dropped (?lang=en)', '/?lang=en', 308, `${ORIGIN}/en`);
  await checkRedirect(
    'tracking preserved without lang',
    '/?utm_source=test',
    308,
    `${ORIGIN}/en?utm_source=test`,
  );
  await checkRedirect(
    'lang dropped, tracking preserved (lang first)',
    '/?lang=sl&utm_source=test',
    308,
    `${ORIGIN}/sl?utm_source=test`,
  );
  await checkRedirect(
    'lang dropped, tracking preserved (lang last)',
    '/?utm_source=test&lang=sl',
    308,
    `${ORIGIN}/sl?utm_source=test`,
  );
  await checkRedirect(
    'lang dropped, tracking preserved (lang mid)',
    '/?utm_source=test&lang=sl&utm_medium=cpc',
    308,
    `${ORIGIN}/sl?utm_source=test&utm_medium=cpc`,
  );

  // --- Localized public homepages -------------------------------------------
  for (const [locale, altLocale] of [['en', 'sl'], ['sl', 'en']]) {
    const res = await checkStatus(`localized homepage /${locale}`, `/${locale}`, 200);
    if (!res || res.status !== 200) continue;
    const html = await res.text();

    const canonical = firstMatch(html, /<link[^>]+rel="canonical"[^>]+href="([^"]+)"/i);
    record(
      `/${locale} canonical`,
      canonical === `${ORIGIN}/${locale}`,
      `canonical=${canonical ?? '<absent>'}`,
    );

    const hasSelf = html.includes(`hreflang="${locale}"`);
    const hasAlt = html.includes(`hreflang="${altLocale}"`);
    record(`/${locale} reciprocal hreflang`, hasSelf && hasAlt, `self=${hasSelf} alt=${hasAlt}`);

    const h1 = firstMatch(html, /<h1[^>]*>([^<]+)<\/h1>/i);
    record(`/${locale} server-rendered H1`, Boolean(h1), `h1=${h1 ?? '<absent>'}`);

    // Locale homepages are the semantic surface; the interactive bundle must
    // not load here or crawlers index an empty shell.
    const leaksBundle = /flutter_bootstrap\.js|main\.dart\.js/.test(html);
    record(`/${locale} is semantic, not app shell`, !leaksBundle, `bundle_present=${leaksBundle}`);
  }

  // --- Interactive app namespace --------------------------------------------
  const appRes = await checkStatus('app namespace /app', '/app', 200);
  if (appRes && appRes.status === 200) {
    const html = await appRes.text();
    const hasBundle = /flutter_bootstrap\.js|main\.dart\.js/.test(html);
    record('/app serves the interactive shell', hasBundle, `bundle_present=${hasBundle}`);
  }

  // --- Robots and sitemap ownership -----------------------------------------
  const robotsRes = await checkStatus('robots.txt', '/robots.txt', 200);
  if (robotsRes && robotsRes.status === 200) {
    const robots = await robotsRes.text();
    record(
      'robots advertises own sitemap',
      robots.includes(`Sitemap: ${ORIGIN}/sitemap.xml`),
      `declares_own_sitemap=${robots.includes(`${ORIGIN}/sitemap.xml`)}`,
    );
  }

  const sitemapRes = await checkStatus('sitemap.xml', '/sitemap.xml', 200);
  if (sitemapRes && sitemapRes.status === 200) {
    const xml = await sitemapRes.text();
    // A healthy production sitemap is the backend-generated index, not a stale
    // static root-only file.
    const isIndex = xml.includes('<sitemapindex');
    record('sitemap is backend-generated index', isIndex, `sitemapindex=${isIndex}`);
  }

  // --- Entity contract -------------------------------------------------------
  if (ARTWORK_ID) {
    await checkRedirect(
      'compact alias -> EN canonical',
      `/a/${ARTWORK_ID}`,
      308,
      `${ORIGIN}/en/artworks/${ARTWORK_ID}`,
    );
    await checkRedirect(
      'compact alias ?lang=sl -> SL canonical',
      `/a/${ARTWORK_ID}?lang=sl`,
      308,
      `${ORIGIN}/sl/umetnine/${ARTWORK_ID}`,
    );

    const entityRes = await checkStatus(
      'canonical entity renders',
      `/en/artworks/${ARTWORK_ID}`,
      200,
    );
    if (entityRes && entityRes.status === 200) {
      const html = await entityRes.text();
      const canonical = firstMatch(html, /<link[^>]+rel="canonical"[^>]+href="([^"]+)"/i);
      record(
        'entity canonical is self-referential',
        canonical === `${ORIGIN}/en/artworks/${ARTWORK_ID}`,
        `canonical=${canonical ?? '<absent>'}`,
      );

      const h1 = firstMatch(html, /<h1[^>]*>([^<]+)<\/h1>/i);
      record('entity server-rendered H1', Boolean(h1), `h1=${h1 ?? '<absent>'}`);

      // Entity pages are the takeover surface: semantic HTML first, then the
      // app progressively takes over for real browsers.
      const hasTakeover = html.includes('public_flutter_takeover.js');
      record('entity carries Flutter takeover', hasTakeover, `takeover_present=${hasTakeover}`);

      const jsonLd = html.includes('application/ld+json');
      record('entity emits JSON-LD', jsonLd, `json_ld=${jsonLd}`);
    }

    // The Slovenian canonical is a distinct document, not a redirect back to
    // English, and must point at itself.
    const slRes = await checkStatus(
      'Slovenian canonical entity renders',
      `/sl/umetnine/${ARTWORK_ID}`,
      200,
    );
    if (slRes && slRes.status === 200) {
      const html = await slRes.text();
      const canonical = firstMatch(html, /<link[^>]+rel="canonical"[^>]+href="([^"]+)"/i);
      record(
        'SL entity canonical is self-referential',
        canonical === `${ORIGIN}/sl/umetnine/${ARTWORK_ID}`,
        `canonical=${canonical ?? '<absent>'}`,
      );
      const altEn = html.includes(`${ORIGIN}/en/artworks/${ARTWORK_ID}`);
      record('SL entity links EN alternate', altEn, `en_alternate=${altEn}`);
    }
  } else {
    record(
      'entity contract',
      false,
      'skipped: set KUBUS_ARTWORK_ID to a real eligible artwork id',
    );
  }

  // --- Honest failure behavior ----------------------------------------------
  await checkStatus('missing entity is a real 404', `/en/artworks/${MISSING_ID}`, 404);
  await checkStatus('unknown route is a real 404', '/__unknown-contract-probe', 404);

  // --- Summary ---------------------------------------------------------------
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed.`);
  if (failed.length > 0) {
    console.log('\nFailed checks:');
    for (const f of failed) console.log(`  - ${f.name}: ${f.detail}`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(`Contract run aborted: ${error.stack ?? error.message}`);
  process.exitCode = 1;
});
