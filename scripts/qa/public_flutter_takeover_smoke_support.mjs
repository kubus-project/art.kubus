export function parseTakeoverEventDetail(detail) {
  if (typeof detail !== 'string') return detail;
  try {
    return JSON.parse(detail);
  } catch {
    return null;
  }
}

export function classifyBrowserFailures({
  consoleErrors,
  failedRequests,
  optionalStandbyProbeUrl,
}) {
  const expectedProbe = optionalStandbyProbeUrl
    ? new URL('/health/writable', optionalStandbyProbeUrl)
    : null;
  // The optional standby backend may be unreachable during the takeover smoke.
  // Its writable health probe and its best-effort, fire-and-forget analytics
  // beacons must not gate a deploy: they carry no user-facing behavior, and
  // (e.g.) a proxied Firefox rejects the beacon with NS_ERROR_DOM_BAD_URI even
  // though the takeover itself completed. Takeover success is asserted
  // separately; only requests to the standby origin are tolerated here.
  const isOptionalProbe = (value) => {
    if (!expectedProbe) return false;
    let actual;
    try { actual = new URL(value); } catch { return false; }
    if (actual.origin !== expectedProbe.origin) return false;
    return actual.pathname === expectedProbe.pathname
      || /^\/api\/analytics(\/|$)/.test(actual.pathname);
  };

  const optionalStandbyFailures = failedRequests.filter((request) =>
    isOptionalProbe(request.url));
  const criticalFailedRequests = failedRequests.filter((request) =>
    !isOptionalProbe(request.url));
  let genericFailureBudget = optionalStandbyFailures.length;
  const optionalStandbyConsoleErrors = [];
  const criticalConsoleErrors = [];

  for (const message of consoleErrors) {
    const explicitlyOptional = expectedProbe
      && message.includes(expectedProbe.origin)
      && message.includes(expectedProbe.pathname);
    const genericOptional = genericFailureBudget > 0
      && /^Failed to load resource: net::ERR_FAILED$/.test(message);
    if (explicitlyOptional || genericOptional) {
      optionalStandbyConsoleErrors.push(message);
      if (genericOptional) genericFailureBudget -= 1;
    } else {
      criticalConsoleErrors.push(message);
    }
  }

  return {
    criticalConsoleErrors,
    criticalFailedRequests,
    optionalStandbyConsoleErrors,
    optionalStandbyFailures,
  };
}
