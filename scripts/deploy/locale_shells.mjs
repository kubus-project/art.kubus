// Derives the crawlable per-locale homepages from the built root document.
//
// Architecture (unchanged): `/`, `/en` and `/sl` boot the Flutter application directly and stay indexable static shells;
// the Flutter locale resolver reads the /en|/sl path prefix. What was wrong: all three paths returned ONE document that
// declared `/en` as canonical, so /sl could never be indexed on its own and the root named the wrong homepage. Now:
//   /     index.html     self-canonical, x-default alternate, the WebSite/Organization structured data
//   /en   index.en.html  self-canonical, English, reciprocal hreflang
//   /sl   index.sl.html  self-canonical, Slovenian title/description/Open Graph, reciprocal hreflang
// The shells are derived from the BUILT index.html (base href and sign-in client id already applied), never hand-copied.
const ORIGIN = 'https://app.kubus.site';

const SL = {
  title: 'art.kubus — Odprti zemljevid umetnosti in skupnostna platforma',
  description: 'Odkrivajte javno umetnost, razstave, umetnike in kulturne prostore na odprtem zemljevidu, ki ga soustvarja skupnost.',
  imageAlt: 'art.kubus odprti zemljevid umetnosti in skupnostna platforma',
};

function replaceOnce(html, pattern, replacement, label) {
  const matches = html.match(new RegExp(pattern.source, pattern.flags.includes('g') ? pattern.flags : `${pattern.flags}g`)) || [];
  if (matches.length !== 1) throw new Error(`locale shell: expected exactly one ${label}, found ${matches.length}`);
  return html.replace(pattern, replacement);
}

function metaPattern(attr, name) {
  return new RegExp(`(<meta ${attr}="${name}" content=")[^"]*(">)`);
}

export function localeShell(rootHtml, locale) {
  if (!['en', 'sl'].includes(locale)) throw new Error(`unsupported locale ${locale}`);
  let html = rootHtml;
  const url = `${ORIGIN}/${locale}`;
  html = replaceOnce(html, /(<link rel="canonical" href=")[^"]*(">)/, `$1${url}$2`, 'canonical');
  html = replaceOnce(html, metaPattern('property', 'og:url'), `$1${url}$2`, 'og:url');
  if (locale === 'sl') {
    html = replaceOnce(html, /<html lang="en">/, '<html lang="sl">', 'html lang');
    html = replaceOnce(html, /<title>[^<]*<\/title>/, `<title>${SL.title}</title>`, '<title>');
    html = replaceOnce(html, metaPattern('name', 'description'), `$1${SL.description}$2`, 'meta description');
    html = replaceOnce(html, metaPattern('property', 'og:title'), `$1${SL.title}$2`, 'og:title');
    html = replaceOnce(html, metaPattern('property', 'og:description'), `$1${SL.description}$2`, 'og:description');
    html = replaceOnce(html, metaPattern('property', 'og:image:alt'), `$1${SL.imageAlt}$2`, 'og:image:alt');
    html = replaceOnce(html, metaPattern('property', 'og:locale'), '$1sl_SI$2', 'og:locale');
    html = replaceOnce(html, metaPattern('property', 'og:locale:alternate'), '$1en_US$2', 'og:locale:alternate');
    html = replaceOnce(html, metaPattern('name', 'twitter:title'), `$1${SL.title}$2`, 'twitter:title');
    html = replaceOnce(html, metaPattern('name', 'twitter:description'), `$1${SL.description}$2`, 'twitter:description');
  }
  return html;
}

export function localeShells(rootHtml) {
  return { 'index.en.html': localeShell(rootHtml, 'en'), 'index.sl.html': localeShell(rootHtml, 'sl') };
}
