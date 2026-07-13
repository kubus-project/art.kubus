const stableGeneratedAt = '2026-01-01T00:00:00.000Z';
const apiHosts = new Set(['api.kubus.site', 'bapi.kubus.site']);

function jsonResponse(payload) {
  return {
    status: 200,
    contentType: 'application/json; charset=utf-8',
    body: JSON.stringify(payload),
  };
}

export function buildStableApiStub(requestUrl, method = 'GET') {
  const url = new URL(requestUrl);
  if (!apiHosts.has(url.hostname)) {
    throw new Error(`Unsupported QA API host: ${url.hostname}`);
  }

  const pathname = url.pathname.replace(/\/+$/, '') || '/';
  const normalizedMethod = method.toUpperCase();

  if (
    normalizedMethod !== 'GET' &&
    (pathname === '/api/analytics/app' || pathname === '/api/diagnostics/error')
  ) {
    return { status: 204, body: '' };
  }

  if (pathname === '/health' || pathname === '/health/ready') {
    return jsonResponse({ status: 'ok', ready: true });
  }

  if (pathname === '/health/writable') {
    return jsonResponse({
      status: 'ok',
      ready: true,
      writable: true,
      isWritable: true,
      role: 'primary',
    });
  }

  const statsSnapshot = pathname.match(/^\/api\/stats\/([^/]+)\/([^/]+)$/);
  if (statsSnapshot) {
    const [, entityType, entityId] = statsSnapshot;
    const metrics = (url.searchParams.get('metrics') || '')
      .split(',')
      .map((metric) => metric.trim())
      .filter(Boolean);
    return jsonResponse({
      data: {
        entityType,
        entityId,
        scope: url.searchParams.get('scope') || 'public',
        metrics,
        counters: Object.fromEntries(metrics.map((metric) => [metric, 0])),
        generatedAt: stableGeneratedAt,
      },
    });
  }

  const statsSeries = pathname.match(
    /^\/api\/stats\/([^/]+)\/([^/]+)\/series$/,
  );
  if (statsSeries) {
    const [, entityType, entityId] = statsSeries;
    return jsonResponse({
      data: {
        entityType,
        entityId,
        scope: url.searchParams.get('scope') || 'public',
        metric: url.searchParams.get('metric') || '',
        bucket: url.searchParams.get('bucket') || 'day',
        series: [],
        generatedAt: stableGeneratedAt,
      },
    });
  }

  if (pathname === '/api/public/home-rails') {
    return jsonResponse({
      data: {
        locale: url.searchParams.get('locale') || 'en',
        generatedAt: stableGeneratedAt,
        rails: [],
      },
    });
  }

  if (pathname === '/api/institutions') {
    return jsonResponse({ institutions: [], data: [] });
  }

  if (pathname === '/api/events') {
    return jsonResponse({ events: [], data: { events: [] } });
  }

  if (pathname === '/api/art-markers') {
    return jsonResponse({ data: [], markers: [] });
  }

  return jsonResponse({
    data: [],
    pagination: { page: 1, limit: 100, total: 0, totalPages: 0 },
  });
}
