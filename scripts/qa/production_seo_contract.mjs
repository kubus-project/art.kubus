#!/usr/bin/env node
// Reusable production SEO transport contract for app.kubus.site.
//
// Asserts the public routing contract end to end against a live origin:
// direct application entry at the root and bare locale roots (/, /en, /sl),
// compact alias redirects, localized canonical entity rendering on DEEPER public
// routes, real 404s, and robots/sitemap ownership.
//
// Architecture note: /, /en and /sl now boot the Flutter application directly
// (the app shell is the required response there and stays indexable). Semantic
// server-rendered HTML lives on deeper localized public-entity routes
// (/en/artworks/:id, /sl/umetnine/:id, compact aliases, sitemaps, robots). This
// supersedes the previous "root 308 -> /en, semantic /en|/sl homepage" contract.
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

// Optional SSH SOCKS egress (see open_smoke_ssh_egress.sh): when set, requests
// leave from the deployment host's trusted IP instead of the runner's greylisted
// IP. Node's global fetch cannot use a SOCKS proxy, so when proxying we route
// through Playwright's APIRequestContext (already a pinned dependency, native
// SOCKS support, no extra package) and adapt it to the fetch-like shape used
// below. Playwright expects socks5:// (DNS is resolved proxy-side regardless).
const SMOKE_SOCKS_PROXY = (process.env.SMOKE_SOCKS_PROXY ?? '').trim();
let httpFetch = globalThis.fetch;
let apiContext = null;

async function initTransport() {
  if (!SMOKE_SOCKS_PROXY) return;
  const { request } = await import('playwright');
  apiContext = await request.newContext({
    proxy: { server: SMOKE_SOCKS_PROXY.replace(/^socks5h:/, 'socks5:') },
  });
  httpFetch = async (url, init = {}) => {
    const response = await apiContext.fetch(url, {
      method: init.method ?? 'GET',
      headers: init.headers ?? {},
      maxRedirects: 0,
      failOnStatusCode: false,
      timeout: TIMEOUT_MS,
    });
    const headers = response.headers();
    return {
      status: response.status(),
      headers: { get: (name) => headers[name.toLowerCase()] ?? null },
      text: () => response.text(),
    };
  };
}

async function disposeTransport() {
  if (apiContext) await apiContext.dispose();
}

const results = [];
// Set when any request is answered with 415, the signature the origin's
// Imunify360/LiteSpeed bot filter returns to a blocked (datacenter) IP. Used to
// print an actionable, token-free hint instead of a misleading "content" fault.
let wafBlockObserved = false;

function record(name, ok, detail) {
  results.push({ name, ok, detail });
  const label = ok ? 'PASS' : 'FAIL';
  console.log(`${label}  ${name}\n      ${detail}`);
}

async function fetchNoRedirect(path, init = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await httpFetch(`${ORIGIN}${path}`, {
      redirect: 'manual',
      signal: controller.signal,
      headers: { 'Cache-Control': 'no-cache', ...BYPASS_HEADERS, ...(init.headers ?? {}) },
      ...init,
    });
    if (response.status === 415) wafBlockObserved = true;
    return response;
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
  await initTransport();
  console.log(`Production SEO contract against ${ORIGIN}\n`);

  // --- Direct application entry: root and bare locale roots ------------------
  // Root and the bare locale roots boot the Flutter application directly. There
  // is no longer a 308 to /en and no generic server-rendered homepage; the app
  // shell is the required response and stays indexable. The launch locale is
  // resolved inside the app (LocaleProvider.localeCodeFromUri), so ?lang=/?locale=
  // enter the app rather than redirecting, and unrelated parameters are carried
  // through untouched.
  const appShellEntries = [
    ['root boots the app', '/'],
    ['bare /en boots the app', '/en'],
    ['bare /sl boots the app', '/sl'],
    ['/app compatibility entry boots the app', '/app'],
    ['/onboarding refresh boots the app', '/onboarding'],
    ['direct registration campaign boots the app', '/register?utm_source=meta&utm_medium=paid_social&utm_campaign=contract&utm_content=creative_1'],
    ['?lang=sl enters the app (no redirect)', '/?lang=sl'],
    ['?lang=en enters the app (no redirect)', '/?lang=en'],
    ['?locale=sl enters the app (no redirect)', '/?locale=sl'],
    ['tracking param enters the app (no redirect)', '/?utm_source=test'],
    ['lang + tracking enters the app (no redirect)', '/?lang=sl&utm_source=test'],
  ];
  for (const [name, path] of appShellEntries) {
    const res = await checkStatus(name, path, 200);
    if (!res || res.status !== 200) continue;
    const html = await res.text();
    const hasBundle = /flutter_bootstrap\.js|main\.dart\.js/.test(html);
    record(`${name}: serves Flutter shell`, hasBundle, `bundle_present=${hasBundle}`);
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
  // Deeper localized paths are owned by the renderer, which returns a real 404
  // for anything that is not a live public entity. Unknown localized paths must
  // NOT degrade into an indexable Flutter soft 404, and unknown root paths stay
  // real 404s.
  await checkStatus('missing entity is a real 404', `/en/artworks/${MISSING_ID}`, 404);
  await checkStatus('unknown localized path is a real 404', '/en/__unknown-contract-probe', 404);
  await checkStatus('unknown SL localized path is a real 404', '/sl/__unknown-contract-probe', 404);
  await checkStatus('unknown route is a real 404', '/__unknown-contract-probe', 404);

  // --- Summary ---------------------------------------------------------------
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed.`);
  if (failed.length > 0) {
    console.log('\nFailed checks:');
    for (const f of failed) console.log(`  - ${f.name}: ${f.detail}`);
    if (wafBlockObserved) {
      const tokenConfigured = SMOKE_BYPASS_TOKEN.length > 0;
      console.log(
        '\nWAF diagnosis (token value never shown): at least one request was answered '
        + 'with HTTP 415, the signature the origin Imunify360/LiteSpeed filter returns to '
        + 'a blocked datacenter IP. This is a network filter, not a content regression.',
      );
      console.log(
        tokenConfigured
          ? '  SMOKE_BYPASS_TOKEN is set here, so the host WAF exception for the '
            + 'X-Deploy-Smoke header is not active. Install/repair the host rule per '
            + 'docs/engineering/production-waf-smoke-exception.md.'
          : '  SMOKE_BYPASS_TOKEN is empty here (unset in the production-web environment or '
            + 'not forwarded by the workflow), so no bypass header was sent.',
      );
    }
    process.exitCode = 1;
  }
}

main()
  .catch((error) => {
    console.error(`Contract run aborted: ${error.stack ?? error.message}`);
    process.exitCode = 1;
  })
  .finally(() => disposeTransport());
