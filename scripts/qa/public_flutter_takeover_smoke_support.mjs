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
  const isOptionalProbe = (value) => {
    if (!expectedProbe) return false;
    const actual = new URL(value);
    return actual.origin === expectedProbe.origin
      && actual.pathname === expectedProbe.pathname;
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
