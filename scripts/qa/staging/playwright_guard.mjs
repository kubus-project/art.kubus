// Installs the staging isolation rules on a Playwright browser context. Every local
// staging browser run must call this before opening a page.
import { parseStagingOrigin, shouldBlockRequest } from './isolation.mjs';

/**
 * Aborts every request to a production API host and every write outside the staging
 * origins. Returns the list of blocked requests; a run should fail if it is not empty.
 */
export async function installStagingGuard(context, { apiOrigin, webOrigin }) {
  const allowedOrigins = [parseStagingOrigin(apiOrigin, 'API origin'), parseStagingOrigin(webOrigin, 'web origin')];
  const blocked = [];
  await context.route('**/*', (route) => {
    const request = route.request();
    const decision = shouldBlockRequest({ url: request.url(), method: request.method() }, { allowedOrigins });
    if (decision.block) {
      blocked.push({ method: request.method(), url: request.url(), reason: decision.reason });
      return route.abort('blockedbyclient');
    }
    return route.fallback();
  });
  return blocked;
}
