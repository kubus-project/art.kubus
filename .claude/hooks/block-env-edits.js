#!/usr/bin/env node
/**
 * PreToolUse hook: block edits/writes to real environment-secret files.
 *
 * Rationale: the repo keeps live secrets in `.env`, `.env.flutter.production.json`,
 * `backend/.env*`, etc. (all gitignored). Claude should never silently rewrite
 * those. Editing the tracked `*.example` templates stays allowed.
 *
 * Contract: reads the hook payload as JSON on stdin. Exits 2 + stderr to deny;
 * exits 0 to allow. cwd is the project root, so a relative invocation works on
 * both cmd.exe and sh.
 */
'use strict';

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => (data += c));
    process.stdin.on('end', () => resolve(data));
    // If nothing is piped, don't hang.
    setTimeout(() => resolve(data), 2000).unref?.();
  });
}

function targetPaths(input) {
  if (!input || typeof input !== 'object') return [];
  const paths = [];
  if (typeof input.file_path === 'string') paths.push(input.file_path);
  if (typeof input.path === 'string') paths.push(input.path);
  // MultiEdit / batch shapes
  if (Array.isArray(input.edits)) {
    for (const e of input.edits) if (e && typeof e.file_path === 'string') paths.push(e.file_path);
  }
  return paths;
}

function isProtectedEnv(p) {
  const name = String(p).replace(/\\/g, '/').split('/').pop() || '';
  if (name.endsWith('.example') || name.endsWith('.sample')) return false;
  // Matches `.env`, `.env.local`, `.env.production`, `.env.flutter.production.json`, ...
  return /^\.env(\.|$)/.test(name);
}

(async () => {
  try {
    const raw = await readStdin();
    if (!raw.trim()) process.exit(0);
    const payload = JSON.parse(raw);
    const tool = payload.tool_name || '';
    if (!/^(Edit|MultiEdit|Write|NotebookEdit)$/.test(tool)) process.exit(0);

    const offending = targetPaths(payload.tool_input).filter(isProtectedEnv);
    if (offending.length === 0) process.exit(0);

    process.stderr.write(
      `Blocked: refusing to modify environment-secret file(s): ${offending.join(', ')}.\n` +
        `These hold live secrets and are gitignored. Edit the matching ` +
        `*.example template instead, or ask the user to change the real file by hand.\n`
    );
    process.exit(2);
  } catch (err) {
    // Fail open: a hook bug must never block normal editing.
    process.stderr.write(`block-env-edits hook error (ignored): ${err.message}\n`);
    process.exit(0);
  }
})();
