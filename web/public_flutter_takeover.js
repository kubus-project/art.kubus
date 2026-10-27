(function () {
  "use strict";

  const host = document.getElementById("flutter-host");
  const publicDocument = document.getElementById("public-document");
  if (!host || !publicDocument) {
    return;
  }

  const root = document.documentElement;
  const expected = Object.freeze({
    type: host.dataset.entityType || "",
    id: host.dataset.entityId || "",
    path: host.dataset.entityPath || "",
    locale: host.dataset.locale || "",
  });

  // Copy is chosen by comparing the locale, never looked up by a dataset value,
  // so an unexpected locale cannot select an inherited property.
  const copy =
    expected.locale === "sl"
      ? Object.freeze({
          loading: "Svet umetnosti se izrisuje …",
          failure:
            "Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje.",
          retry: "Poskusi znova",
          app: "Pojdi v aplikacijo",
        })
      : Object.freeze({
          loading: "The world of art is coming into focus…",
          failure:
            "The world of art couldn't open this time. Try refreshing the page or come back later.",
          retry: "Retry",
          app: "Go to app",
        });
  const fallbackAppHref = expected.locale === "sl" ? "/map?lang=sl" : "/map?lang=en";

  let transitionCleanup = null;
  let slowTimer = null;
  let entityIsReady = false;
  let failureShown = false;
  let bootstrapElement = null;

  const mark = (name) => {
    if (globalThis.performance && typeof globalThis.performance.mark === "function") {
      globalThis.performance.mark(name);
    }
  };

  // The app link from the markup is used only when it is a same-origin path that starts
  // with a single "/", and it is not the entity's own address. Otherwise the locale's map.
  const safeAppHref = (raw) => {
    if (typeof raw !== "string" || raw.length === 0 || raw.length > 2048) return null;
    if (raw.charAt(0) !== "/" || raw.charAt(1) === "/" || raw.charAt(1) === "\\") return null;
    if (/[\u0000-\u001F\u007F\\]/.test(raw)) return null;
    let target;
    try {
      target = new URL(raw, globalThis.location.href);
    } catch (_) {
      return null;
    }
    if (target.origin !== globalThis.location.origin) return null;
    const ownPath = expected.path.replace(/\/+$/, "");
    if (ownPath && target.pathname.replace(/\/+$/, "") === ownPath) return null;
    return raw;
  };

  // Creates the section when the page has none (PHP gateway path, older markup), or completes an
  // existing one. Query before create, so the section is never duplicated.
  const createStatusElement = () => {
    const el = document.createElement("div");
    el.setAttribute("id", "flutter-takeover-status");
    el.setAttribute("data-kubus-takeover-status", "");
    el.setAttribute("data-state", "pending");
    el.setAttribute("data-locale", expected.locale);
    el.setAttribute("data-loading-text", copy.loading);
    el.setAttribute("data-failure-text", copy.failure);
    el.setAttribute("data-refresh-label", copy.retry);
    el.setAttribute("data-app-label", copy.app);
    el.setAttribute("data-app-href", fallbackAppHref);
    el.setAttribute("hidden", "");
    return el;
  };

  // Placement matches the backend and the PHP gateway: after the first header of the public
  // document, otherwise as its first child.
  const insertStatus = (el) => {
    const header = publicDocument.querySelector("header");
    if (header && header.parentNode) {
      header.parentNode.insertBefore(el, header.nextSibling);
    } else {
      publicDocument.insertBefore(el, publicDocument.firstChild);
    }
  };

  // Message first, then one actions group holding Retry and Go to app. A Retry button from an
  // older backend is moved into the group and keeps the label the backend gave it.
  const completeStatusParts = (el) => {
    if (!el.querySelector("[data-kubus-takeover-message]")) {
      const message = document.createElement("span");
      message.setAttribute("data-kubus-takeover-message", "");
      message.setAttribute("role", "status");
      message.setAttribute("aria-live", "polite");
      message.setAttribute("aria-atomic", "true");
      el.insertBefore(message, el.firstChild);
    }

    let actions = el.querySelector("[data-kubus-takeover-actions]");
    if (!actions) {
      actions = document.createElement("span");
      actions.setAttribute("class", "takeover-actions");
      actions.setAttribute("data-kubus-takeover-actions", "");
      el.appendChild(actions);
    }

    let retry = el.querySelector("[data-kubus-takeover-refresh]");
    if (!retry) {
      retry = document.createElement("button");
      retry.setAttribute("data-kubus-takeover-refresh", "");
    }
    if (!retry.getAttribute("type")) retry.setAttribute("type", "button");
    if (retry.parentNode !== actions) actions.appendChild(retry);
    retry.textContent = el.dataset.refreshLabel || copy.retry;
    retry.removeAttribute("hidden");

    let app = el.querySelector("[data-kubus-takeover-app]");
    if (!app) {
      app = document.createElement("a");
      app.setAttribute("data-kubus-takeover-app", "");
    }
    if (app.parentNode !== actions) actions.appendChild(app);
    app.setAttribute("href", safeAppHref(el.dataset.appHref) || fallbackAppHref);
    app.textContent = el.dataset.appLabel || copy.app;
    app.removeAttribute("hidden");
  };

  const ensureStatus = () => {
    let el = document.querySelector("[data-kubus-takeover-status]");
    if (!el) {
      el = createStatusElement();
      insertStatus(el);
    }
    completeStatusParts(el);
    return el;
  };

  // The status element is removed once the exact entity is handed over, so this reference becomes null then.
  let statusEl = ensureStatus();
  const loadingText = statusEl.dataset.loadingText || copy.loading;
  const failureText = statusEl.dataset.failureText || copy.failure;
  const retryButton = statusEl.querySelector("[data-kubus-takeover-refresh]");

  const part = (selector) => (statusEl ? statusEl.querySelector(selector) : null);

  const setStatus = (state, message, visible) => {
    if (!statusEl) return;
    statusEl.dataset.state = state;
    statusEl.hidden = !visible;
    const text = part("[data-kubus-takeover-message]");
    if (text) text.textContent = message;
  };

  const removeStatus = (state) => {
    if (!statusEl) return;
    setStatus(state, "", false);
    statusEl.remove();
    statusEl = null;
  };

  const clearTimers = () => {
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

  const releaseBootstrapListeners = () => {
    globalThis.removeEventListener("error", onBootstrapResourceError, true);
    bootstrapElement?.removeEventListener("error", onBootstrapResourceError);
    bootstrapElement = null;
  };

  const setInactive = () => {
    root.classList.remove("kubus-takeover-active", "kubus-takeover-complete");
    host.setAttribute("aria-hidden", "true");
    host.inert = true;
    publicDocument.removeAttribute("aria-hidden");
    publicDocument.inert = false;
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
    setStatus("failed", failureText, true);
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

  const bootstrapResourceEntry = () => {
    const entries = globalThis.performance?.getEntriesByType?.("resource") || [];
    let latest = null;
    for (const entry of entries) {
      const path = bootstrapPath(entry.name);
      if (path && /flutter_bootstrap\.js$/.test(path)) latest = entry;
    }
    return latest;
  };

  // Firefox fires a deferred script's error event at fetch failure, which can be before this script runs
  // (the SSR page loads takeover and bootstrap with defer), so that event is never seen by a listener.
  // The failed request remains in Resource Timing: responseStatus 0 for a network failure, the HTTP
  // status for an error response. A successful or still-pending request never matches.
  const bootstrapRequestAlreadyFailed = () => {
    const latest = bootstrapResourceEntry();
    return latest !== null && (latest.responseStatus === 0 || latest.responseStatus >= 400);
  };

  const verifyBootstrapRequest = () => {
    if (bootstrapRequestAlreadyFailed()) failTakeover();
  };

  // At DOMContentLoaded, a page with no bootstrap script and no completed bootstrap request cannot start Flutter.
  const verifyScriptPresent = () => {
    if (!document.querySelector('script[src*="flutter_bootstrap.js"]') && bootstrapResourceEntry() === null) {
      failTakeover();
    }
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

  // Compares against the host's own data, never against the status element, which is removed on handoff.
  const isExpectedEntity = (detail) => {
    const value = parseDetail(detail);
    return Boolean(
      expected.locale &&
        value &&
        value.type === expected.type &&
        value.id === expected.id &&
        value.path === expected.path &&
        value.locale === expected.locale &&
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
  // definitive not-found. Either one removes the section and the overlay; only the first one counts.
  const settleTakeover = (state, markName) => {
    entityIsReady = true;
    clearTimers();
    releaseBootstrapListeners();
    removeStatus(state);
    mark(markName);
    activate();
  };

  globalThis.addEventListener("kubus:public-entity-ready", (event) => {
    if (!failureShown && !entityIsReady && isExpectedEntity(event.detail)) {
      settleTakeover("ready", "public_entity_ready");
    }
  });
  // The entity does not exist (API 404). The app shows its own not-found screen at
  // this URL, so the overlay goes away without the failed state or a Retry.
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

  // One reload per activation. The button disables itself, so a repeated activation cannot reload twice.
  const onRetry = () => {
    if (!retryButton || retryButton.disabled) return;
    retryButton.disabled = true;
    globalThis.location.reload();
  };
  retryButton?.addEventListener("click", onRetry);

  // The section is visible at once in the loading state, with no delay and no dependency on bootstrap.
  setInactive();
  setStatus("loading", loadingText, true);
  mark("public_ssr_visible");
  slowTimer = globalThis.setTimeout(() => {
    slowTimer = null;
    if (!failureShown && !entityIsReady) {
      setStatus("slow", loadingText, true);
    }
  }, 8000);
  globalThis.addEventListener("error", onBootstrapResourceError, true);
  bootstrapElement = document.querySelector('script[src*="flutter_bootstrap.js"]');
  bootstrapElement?.addEventListener("error", onBootstrapResourceError);
  verifyBootstrapRequest();
  if (document.readyState !== "complete") {
    // Deferred scripts run before DOMContentLoaded, when the bootstrap request has settled.
    document.addEventListener("DOMContentLoaded", verifyBootstrapRequest);
    document.addEventListener("DOMContentLoaded", verifyScriptPresent);
  }

  globalThis.kubusPublicTakeover = Object.freeze({
    hostElement: () => host,
    bootstrapStarted: () => {
      mark("flutter_bootstrap_started");
    },
    engineReady: () => mark("flutter_engine_ready"),
    fail: failTakeover,
  });
})();
