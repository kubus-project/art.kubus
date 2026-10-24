(function () {
  "use strict";

  const host = document.getElementById("flutter-host");
  const publicDocument = document.getElementById("public-document");
  if (!host || !publicDocument) {
    return;
  }

  const root = document.documentElement;
  const status = document.querySelector("[data-kubus-takeover-status]");
  const refreshButton = status?.querySelector("[data-kubus-takeover-refresh]");
  let statusMessage = status?.querySelector("[data-kubus-takeover-message]");
  if (status && !statusMessage) {
    statusMessage = document.createElement("span");
    statusMessage.dataset.kubusTakeoverMessage = "";
    status.insertBefore(statusMessage, status.firstChild);
  }

  const expected = Object.freeze({
    type: host.dataset.entityType || "",
    id: host.dataset.entityId || "",
    path: host.dataset.entityPath || "",
    locale: host.dataset.locale || "",
  });
  const loadingText =
    status?.dataset.loadingText ||
    (expected.locale === "sl"
      ? "Svet umetnosti se izrisuje …"
      : "The world of art is coming into focus…");
  const failureText =
    status?.dataset.failureText ||
    (expected.locale === "sl"
      ? "Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje."
      : "The world of art couldn't open this time. Try refreshing the page or come back later.");
  const refreshLabel =
    status?.dataset.refreshLabel || (expected.locale === "sl" ? "Osveži" : "Refresh");

  let transitionCleanup = null;
  let loadingTimer = null;
  let slowTimer = null;
  let entityIsReady = false;
  let failureShown = false;
  let bootstrapWasStarted = false;

  const mark = (name) => {
    if (globalThis.performance && typeof globalThis.performance.mark === "function") {
      globalThis.performance.mark(name);
    }
  };

  const setInactive = () => {
    root.classList.remove("kubus-takeover-active", "kubus-takeover-complete");
    host.setAttribute("aria-hidden", "true");
    host.inert = true;
    publicDocument.removeAttribute("aria-hidden");
    publicDocument.inert = false;
  };

  const setStatus = (state, message, visible, showRefresh = false) => {
    if (!status) return;
    status.dataset.state = state;
    status.hidden = !visible;
    if (statusMessage) statusMessage.textContent = message;
    if (refreshButton) {
      refreshButton.hidden = !showRefresh;
      refreshButton.textContent = refreshLabel;
    }
  };

  const clearTimers = () => {
    if (loadingTimer !== null) {
      globalThis.clearTimeout(loadingTimer);
      loadingTimer = null;
    }
    if (slowTimer !== null) {
      globalThis.clearTimeout(slowTimer);
      slowTimer = null;
    }
  };

  const bootstrapPath = (url) => {
    try {
      return new URL(url, globalThis.location.href).pathname;
    } catch (_) {
      return null;
    }
  };

  let bootstrapElement = null;

  const releaseBootstrapListeners = () => {
    globalThis.removeEventListener("error", onBootstrapResourceError, true);
    bootstrapElement?.removeEventListener("error", onBootstrapResourceError);
    bootstrapElement = null;
  };

  const failTakeover = () => {
    if (failureShown || entityIsReady) return;
    failureShown = true;
    clearTimers();
    releaseBootstrapListeners();
    if (transitionCleanup !== null) {
      globalThis.clearTimeout(transitionCleanup);
      transitionCleanup = null;
    }
    setInactive();
    setStatus("failed", failureText, true, true);
    mark("flutter_takeover_failed");
  };

  // Both the window capture listener and an element listener funnel into failTakeover, which is idempotent.
  function onBootstrapResourceError(event) {
    const target = event.target;
    if (!(target instanceof HTMLScriptElement)) return;
    const path = bootstrapPath(target.src);
    if (!path || !/(?:flutter_bootstrap|main\.dart|canvaskit|skwasm).*\.js$/.test(path)) return;
    failTakeover();
  }

  // Firefox fires a deferred script's error event at fetch failure, which can be before this script runs
  // (the SSR page loads takeover and bootstrap with defer), so that event is never seen by a listener.
  // The failed request remains in Resource Timing: responseStatus 0 for a network failure, the HTTP
  // status for an error response. A successful or still-pending request never matches.
  const bootstrapRequestAlreadyFailed = () => {
    const entries = globalThis.performance?.getEntriesByType?.("resource") || [];
    let latest = null;
    for (const entry of entries) {
      const path = bootstrapPath(entry.name);
      if (path && /flutter_bootstrap\.js$/.test(path)) latest = entry;
    }
    if (latest === null) return false;
    return latest.responseStatus === 0 || latest.responseStatus >= 400;
  };

  const verifyBootstrapRequest = () => {
    if (bootstrapRequestAlreadyFailed()) failTakeover();
  };

  const finishTransition = () => {
    if (!root.classList.contains("kubus-takeover-active")) {
      return;
    }
    if (transitionCleanup !== null) {
      globalThis.clearTimeout(transitionCleanup);
      transitionCleanup = null;
    }
    root.classList.add("kubus-takeover-complete");
    mark("flutter_takeover_completed");
    globalThis.dispatchEvent(new CustomEvent("kubus:flutter-takeover-completed"));
  };

  const parseDetail = (detail) => {
    if (typeof detail === "string") {
      try {
        return JSON.parse(detail);
      } catch (_) {
        return null;
      }
    }
    return detail && typeof detail === "object" ? detail : null;
  };

  const isExpectedEntity = (detail) => {
    const value = parseDetail(detail);
    return Boolean(
      expected.locale &&
        value &&
        value.type === expected.type &&
        value.id === expected.id &&
        value.path === expected.path &&
        value.locale === expected.locale &&
        status?.dataset.locale === expected.locale &&
        globalThis.location.pathname === expected.path,
    );
  };

  const activate = () => {
    if (root.classList.contains("kubus-takeover-active")) {
      return;
    }
    host.removeAttribute("aria-hidden");
    host.inert = false;
    publicDocument.setAttribute("aria-hidden", "true");
    publicDocument.inert = true;
    root.classList.add("kubus-takeover-active");

    const reducedMotion = globalThis.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reducedMotion) {
      finishTransition();
      return;
    }

    const onTransitionEnd = (event) => {
      if (event.target !== host || event.propertyName !== "opacity") {
        return;
      }
      host.removeEventListener("transitionend", onTransitionEnd);
      finishTransition();
    };
    host.addEventListener("transitionend", onTransitionEnd);
    transitionCleanup = globalThis.setTimeout(() => {
      host.removeEventListener("transitionend", onTransitionEnd);
      finishTransition();
    }, 260);
  };

  // "Settled" means the exact entity has an answer the app now shows: ready, or a
  // definitive not-found. Either one removes the overlay; only the first one counts.
  const settleTakeover = (state, markName) => {
    entityIsReady = true;
    clearTimers();
    releaseBootstrapListeners();
    setStatus(state, "", false);
    mark(markName);
    activate();
  };

  globalThis.addEventListener("kubus:public-entity-ready", (event) => {
    if (!failureShown && !entityIsReady && isExpectedEntity(event.detail)) {
      settleTakeover("ready", "public_entity_ready");
    }
  });
  // The entity does not exist (API 404). The app shows its own not-found screen at
  // this URL, so the overlay goes away without the failed state or a Refresh.
  globalThis.addEventListener("kubus:public-entity-resolved", (event) => {
    if (!failureShown && !entityIsReady && isExpectedEntity(event.detail)) {
      settleTakeover("resolved", "public_entity_resolved");
    }
  });
  globalThis.addEventListener("kubus:public-entity-route-parsed", (event) => {
    if (isExpectedEntity(event.detail)) {
      mark("public_entity_route_parsed");
    }
  });
  // Flutter reports an entity it could not load for lack of an answer (rate limit,
  // outage). It is the same failure as a bootstrap error: failTakeover is idempotent,
  // and does nothing once the exact entity is ready.
  globalThis.addEventListener("kubus:public-entity-failed", (event) => {
    if (isExpectedEntity(event.detail)) {
      failTakeover();
    }
  });

  if (refreshButton) {
    refreshButton.addEventListener("click", () => globalThis.location.reload());
  }

  setInactive();
  setStatus("pending", "", false);
  mark("public_ssr_visible");
  globalThis.addEventListener("error", onBootstrapResourceError, true);
  bootstrapElement = document.querySelector('script[src*="flutter_bootstrap.js"]');
  bootstrapElement?.addEventListener("error", onBootstrapResourceError);
  verifyBootstrapRequest();
  if (document.readyState !== "complete") {
    // Deferred scripts run before DOMContentLoaded, when the bootstrap request has settled.
    document.addEventListener("DOMContentLoaded", verifyBootstrapRequest);
  }

  globalThis.kubusPublicTakeover = Object.freeze({
    hostElement: () => host,
    bootstrapStarted: () => {
      mark("flutter_bootstrap_started");
      if (bootstrapWasStarted || failureShown || entityIsReady) return;
      bootstrapWasStarted = true;
      loadingTimer = globalThis.setTimeout(() => {
        loadingTimer = null;
        if (!failureShown && !entityIsReady) {
          setStatus("loading", loadingText, true);
        }
      }, 500);
      slowTimer = globalThis.setTimeout(() => {
        slowTimer = null;
        if (!failureShown && !entityIsReady) {
          setStatus("slow", loadingText, true);
        }
      }, 8000);
    },
    engineReady: () => mark("flutter_engine_ready"),
    fail: failTakeover,
  });
})();
