// Index ownership policy v1 declares translated locales through reciprocal
// hreflang alternates. Untranslated documents have no locale alternates.
function alternates(html) {
  const result = new Map();
  for (const tag of html.matchAll(/<link\b[^>]*>/gi)) {
    const attrs = Object.fromEntries([...tag[0].matchAll(/\b(rel|href|hreflang)\s*=\s*["']([^"']+)["']/gi)]
      .map((match) => [match[1].toLowerCase(), match[2]]));
    if (attrs.rel?.toLowerCase() === 'alternate' && attrs.hreflang) result.set(attrs.hreflang, attrs.href);
  }
  return result;
}

export function artworkLocaleOwner(enHtml, slHtml, enUrl, slUrl) {
  const en = alternates(enHtml);
  const sl = alternates(slHtml);
  const translated = en.get('sl') === slUrl && sl.get('en') === enUrl;
  const fallback = en.size === 0 && sl.size === 0;
  const reciprocal = translated
    && en.get('en') === enUrl && sl.get('sl') === slUrl
    && en.get('x-default') === enUrl && sl.get('x-default') === enUrl;
  return { canonical: translated ? slUrl : enUrl, translated, valid: fallback || reciprocal };
}
