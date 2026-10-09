// Flutter 3.44.2 SemanticIncrementable places aria-label on flt-semantics,
// while the accessible slider is a nested range input. Give only marked
// Community sliders the exact localized name supplied by the widget. Flutter
// also misses initial value text when a slider is created in pointer mode.
// Copy the widget's current value text too. Flutter owns enabled state, focus
// and adjustment actions.
// In particular, do not override its temporary pointer-mode disabled state.
(function () {
  'use strict';
  const prefix = 'community-media-slider:';
  const selector = '[flt-semantics-identifier^="' + prefix + '"]';
  const watched = new WeakSet();
  function watch(root) {
    if (watched.has(root)) return;
    watched.add(root);
    const observer = new MutationObserver(() => sync(root));
    observer.observe(root, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['flt-semantics-identifier'],
    });
    sync(root);
  }
  function sync(root) {
    root.querySelectorAll(selector).forEach((node) => {
      const input = node.querySelector('input[type="range"]');
      if (!input) return;
      let semantics;
      try {
        semantics = JSON.parse(node.getAttribute('flt-semantics-identifier').slice(prefix.length));
      } catch (_) { return; }
      if (typeof semantics.label !== 'string' || typeof semantics.value !== 'string') return;
      if (input.getAttribute('aria-label') !== semantics.label) input.setAttribute('aria-label', semantics.label);
      if (input.getAttribute('aria-valuetext') !== semantics.value) input.setAttribute('aria-valuetext', semantics.value);
    });
    root.querySelectorAll('flt-glass-pane, flutter-view').forEach((node) => {
      if (node.shadowRoot) watch(node.shadowRoot);
    });
  }
  watch(document);
})();
