#!/usr/bin/env node
/**
 * PostToolUse hook: guard the generated localizations files.
 *
 * `puro flutter gen-l10n` regenerates lib/l10n/app_localizations*.dart from the
 * stock template, which silently drops the project's hand patch that maps
 * invalid/empty locale tags (`undefined`, `null`, ``) to the `sl` fallback.
 * The regression is invisible until `test/l10n/app_localizations_locale_guard_test.dart`
 * fails. This hook fires whenever one of those generated files is touched and
 * reminds Claude to re-apply the patch and run the guard test.
 *
 * Anchored on the guard *test path* (verified to exist) rather than any specific
 * helper name, which has been refactored historically.
 *
 * Contract: reads hook payload JSON on stdin. Exit 2 + stderr surfaces the
 * reminder back to Claude; exit 0 stays silent.
 */
'use strict';

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => (data += c));
    process.stdin.on('end', () => resolve(data));
    setTimeout(() => resolve(data), 2000).unref?.();
  });
}

function targetPaths(input) {
  if (!input || typeof input !== 'object') return [];
  const paths = [];
  if (typeof input.file_path === 'string') paths.push(input.file_path);
  if (typeof input.path === 'string') paths.push(input.path);
  if (Array.isArray(input.edits)) {
    for (const e of input.edits) if (e && typeof e.file_path === 'string') paths.push(e.file_path);
  }
  return paths;
}

function isGeneratedL10n(p) {
  const norm = String(p).replace(/\\/g, '/');
  return /(^|\/)lib\/l10n\/app_localizations(_[a-z]+)?\.dart$/.test(norm);
}

(async () => {
  try {
    const raw = await readStdin();
    if (!raw.trim()) process.exit(0);
    const payload = JSON.parse(raw);
    const tool = payload.tool_name || '';
    if (!/^(Edit|MultiEdit|Write)$/.test(tool)) process.exit(0);

    const hits = targetPaths(payload.tool_input).filter(isGeneratedL10n);
    if (hits.length === 0) process.exit(0);

    process.stderr.write(
      `l10n guard: you edited generated localizations (${hits.join(', ')}).\n` +
        `If this came from \`puro flutter gen-l10n\`, the locale-fallback hand patch was likely dropped.\n` +
        `Re-apply it so invalid tags (undefined/null/empty) resolve to 'sl', then run:\n` +
        `  puro flutter test test/l10n/app_localizations_locale_guard_test.dart\n` +
        `Tip: \`/bump-l10n\` performs the full regenerate -> patch -> verify sequence.\n`
    );
    process.exit(2);
  } catch (err) {
    process.stderr.write(`l10n-guard hook error (ignored): ${err.message}\n`);
    process.exit(0);
  }
})();
