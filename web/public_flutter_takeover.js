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
  });
  let transitionCleanup = null;
  const onBootstrapResourceError = (event) => {
    const target = event.target;
    if (!(target instanceof HTMLScriptElement)) return;
    const path = new URL(target.src, globalThis.location.href).pathname;
    if (!/(?:main\.dart|canvaskit|skwasm).*\.js$/.test(path)) return;
    globalThis.kubusPublicTakeover?.fail();
  };

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
      value &&
        value.type === expected.type &&
        value.id === expected.id &&
        value.path === expected.path &&
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

  globalThis.addEventListener("kubus:public-entity-ready", (event) => {
    if (isExpectedEntity(event.detail)) {
      mark("public_entity_ready");
      activate();
    }
  });
  globalThis.addEventListener("kubus:public-entity-route-parsed", (event) => {
    if (isExpectedEntity(event.detail)) {
      mark("public_entity_route_parsed");
    }
  });

  setInactive();
  mark("public_ssr_visible");
  globalThis.addEventListener("error", onBootstrapResourceError, true);

  globalThis.kubusPublicTakeover = Object.freeze({
    hostElement: () => host,
    bootstrapStarted: () => mark("flutter_bootstrap_started"),
    engineReady: () => {
      globalThis.removeEventListener("error", onBootstrapResourceError, true);
      mark("flutter_engine_ready");
    },
    fail: () => {
      globalThis.removeEventListener("error", onBootstrapResourceError, true);
      if (transitionCleanup !== null) {
        globalThis.clearTimeout(transitionCleanup);
        transitionCleanup = null;
      }
      setInactive();
      mark("flutter_takeover_failed");
    },
  });
})();
