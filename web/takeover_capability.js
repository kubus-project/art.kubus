// Pre-paint capability handshake for the public entity takeover (ES5, parser-blocking, same origin).
// Loaded from <head>, so the class below exists before the first paint. The takeover section is
// painted at once when this file is present, which removes the layout shift of a late reveal. Without this
// file (an older web build, a 404 for it) the class is absent and the section stays hidden, as before.
(function () {
  var root = document.documentElement;
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
})();
