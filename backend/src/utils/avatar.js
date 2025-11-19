const { URLSearchParams } = require('url');

function buildAvatarProxyUrl(seed, options = {}) {
  const base = (process.env.HTTP_BASE_URL || '').replace(/\/$/, '');
  const {
    style = 'identicon',
    format = 'png',
    raw = true,
    extraParams = {}
  } = options;

  const params = new URLSearchParams();
  params.set('style', style);
  params.set('format', format);
  Object.entries(extraParams).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    params.set(key, value.toString());
  });
  if (raw) {
    params.set('raw', raw === true ? 'true' : raw.toString());
  }

  const route = `/api/avatar/${encodeURIComponent(seed)}`;
  const prefix = base ? `${base}${route}` : route;
  const query = params.toString();
  return query ? `${prefix}?${query}` : prefix;
}

// Utility to normalize avatar URLs stored in DB or returned by external services
function normalizeAvatarUrl(rawUrl, walletAddress) {
  const base = (process.env.HTTP_BASE_URL || '').replace(/\/$/, '');
  if (rawUrl && String(rawUrl).trim().length > 0) {
    const raw = String(rawUrl).trim();
    // If the raw URL is a DiceBear URL (legacy stored), rewrite to internal proxy
    if (/dicebear\.com/.test(raw)) {
      try {
        const parsed = new URL(raw);
        const seed = parsed.searchParams.get('seed');
        if (seed) return buildAvatarProxyUrl(seed);
        // If no search 'seed' param, try to extract from path (legacy avatars.dicebear.com style)
        const pathMatch = parsed.pathname && parsed.pathname.match(/\/api\/identicon\/([^/.]+)/);
        if (pathMatch && pathMatch[1]) return buildAvatarProxyUrl(pathMatch[1]);
      } catch (e) {
        // Not a standard URL: try fallback regex extraction
        const m = raw.match(/seed=([^&]+)/);
        if (m && m[1]) return buildAvatarProxyUrl(m[1]);
        // legacy path pattern: avatars.dicebear.com/api/identicon/<seed>.svg
        const n = raw.match(/avatars\.dicebear\.com\/api\/identicon\/([^/.]+)(?:\.|$)/);
        if (n && n[1]) return buildAvatarProxyUrl(n[1]);
      }
    }
    if (/^https?:\/\//i.test(raw)) return raw;
    if (raw.startsWith('/')) return base ? base + raw : raw;
    // if it looks like an internal path (api/avatar/...), prepend slash
    if (raw.startsWith('api/')) {
      return base ? base + '/' + raw : '/' + raw;
    }
    // default: prefix with base
    return base ? base + '/' + raw : raw;
  }
  // No rawUrl -> generate identicon via internal proxy
  return buildAvatarProxyUrl(walletAddress || 'anon');
}

module.exports = { normalizeAvatarUrl, buildAvatarProxyUrl };
