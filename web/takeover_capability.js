// Pre-paint capability handshake for the public entity takeover (ES5, parser-blocking, same origin).
// Loaded from <head>, so the class below exists before the first paint. The takeover section is
// painted at once when this file is present, which removes the layout shift of a late reveal. Without this
// file (an older web build, a 404 for it) the class is absent and the section stays hidden, as before.
(function () {
  var root = document.documentElement;

  // Flutter's engine reads navigator.language before app initialization. Keep
  // this parser-blocking handshake ahead of the engine on both the normal app
  // shell and the server-rendered takeover shell.
  try {
    var nav = window.navigator;
    if (nav) {
      function normalizeLanguage(value) {
        if (value == null) return null;
        var normalized = String(value).trim();
        if (!normalized) return null;
        var lower = normalized.toLowerCase();
        if (lower === "undefined" || lower === "null") return null;
        try {
          if (typeof Intl === "undefined" || typeof Intl.Locale !== "function") {
            return null;
          }
          new Intl.Locale(normalized);
        } catch (_) {
          return null;
        }
        return normalized;
      }

      var rawLanguages = [];
      try {
        if (Array.isArray(nav.languages)) rawLanguages = nav.languages.slice();
      } catch (_) {}
      if (!rawLanguages.length) rawLanguages = [nav.language];

      var sanitized = rawLanguages
        .map(normalizeLanguage)
        .filter(function (value) { return !!value; });
      if (!sanitized.length) sanitized = ["en-US", "en"];

      var primary = sanitized[0];
      try {
        Object.defineProperty(nav, "language", {
          configurable: true,
          get: function () { return primary; },
        });
      } catch (_) {}
      try {
        Object.defineProperty(nav, "languages", {
          configurable: true,
          get: function () { return sanitized.slice(); },
        });
      } catch (_) {}

      var htmlLanguage = normalizeLanguage(root.lang);
      if (!htmlLanguage) {
        root.lang = (primary.split("-")[0] || "en").toLowerCase();
      }
    }
  } catch (_) {}

  root.classList.add("kubus-takeover-capable");

  // Safety: the main takeover script never ran (blocked, failed or missing). The section then moves to
  // the failed state with its failure text; Retry and Go to app stay usable, and the SSR page is untouched.
  setTimeout(function () {
    if (globalThis.kubusPublicTakeover !== undefined) return;
    var status = document.getElementById("flutter-takeover-status");
    if (!status || status.getAttribute("data-state") !== "pending") return;
    status.setAttribute("data-state", "failed");
    status.removeAttribute("hidden");
    var message = status.querySelector("[data-kubus-takeover-message]");
    var failure = status.getAttribute("data-failure-text");
    if (message && failure) message.textContent = failure;
  }, 12000);

  // Retry must work even when the main takeover script never ran (blocked, failed or not yet executed).
  // Once that script is present it owns the button, so this handler steps aside. One reload per activation.
  document.addEventListener("click", function (event) {
    if (globalThis.kubusPublicTakeover !== undefined) return;
    var node = event.target;
    while (node && !(node.getAttribute && node.getAttribute("data-kubus-takeover-refresh") != null)) {
      node = node.parentNode;
    }
    if (!node || node.disabled) return;
    node.disabled = true;
    // A cancelled reload, or a page restored from the back-forward cache, must not leave Retry dead.
    var enable = function () { node.disabled = false; };
    globalThis.addEventListener("pageshow", enable, { once: true });
    setTimeout(enable, 4000);
    globalThis.location.reload();
  });
})();
