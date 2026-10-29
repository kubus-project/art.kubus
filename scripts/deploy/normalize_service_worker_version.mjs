import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// `flutter build web` bakes `Random().nextInt(1 << 32)` into flutter_bootstrap.js and
// index.html (flutter_tools build_system/targets/web.dart), so two builds of one commit
// never share a manifest. The value is only a cache-busting query for the service worker,
// so a commit-derived value keeps its meaning and makes the sealed artifact reproducible.

const VERSION_PATTERN = /\bflutterServiceWorkerVersion\s*=\s*"(\d{1,10})"/g;
const REWRITTEN_FILES = ['flutter_bootstrap.js', 'index.html'];

export function deterministicServiceWorkerVersion(sourceSha) {
  if (!/^[0-9a-f]{40}$/.test(sourceSha || '')) throw new Error('source SHA must be 40 lowercase hex characters');
  const digest = createHash('sha256').update(`flutter-service-worker-version:${sourceSha}`).digest();
  return String(digest.readUInt32BE(0));
}

function walk(directory) {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

/**
 * Replaces Flutter's random service-worker version with a value derived from the source
 * commit. Returns null when the build carries no service-worker version. Throws when the
 * random value appears anywhere that is not rewritten, so an unexpected consumer can never
 * silently keep a volatile value.
 */
export function normalizeServiceWorkerVersion(directory, sourceSha) {
  const bootstrapPath = join(directory, 'flutter_bootstrap.js');
  let bootstrap;
  try {
    bootstrap = readFileSync(bootstrapPath, 'utf8');
  } catch {
    return null;
  }
  const found = [...bootstrap.matchAll(VERSION_PATTERN)].map((match) => match[1]);
  if (found.length === 0) {
    // A declaration we cannot parse must not silently bring the random value back.
    if (/\bflutterServiceWorkerVersion\s*=\s*(?!null\b)\S/.test(bootstrap)) {
      throw new Error('flutter_bootstrap.js declares a service worker version in an unrecognised form');
    }
    return null;
  }
  if (found.length !== 1) throw new Error('flutter_bootstrap.js must declare exactly one service worker version');

  const original = found[0];
  const replacement = deterministicServiceWorkerVersion(sourceSha);
  const quoted = `"${original}"`;
  const rewrite = new Set(REWRITTEN_FILES.map((name) => join(directory, name)));

  for (const file of walk(directory)) {
    const bytes = readFileSync(file);
    const text = rewrite.has(file) ? bytes.toString('utf8') : null;
    if (text === null) {
      if (bytes.includes(quoted)) throw new Error(`${file} contains the volatile service worker version outside the rewritten files`);
      continue;
    }
    if (!text.includes(quoted)) continue;
    writeFileSync(file, text.split(quoted).join(`"${replacement}"`));
  }

  const after = readFileSync(bootstrapPath, 'utf8');
  if (![...after.matchAll(VERSION_PATTERN)].every((match) => match[1] === replacement)) {
    throw new Error('service worker version was not normalized');
  }
  return { original, replacement };
}
