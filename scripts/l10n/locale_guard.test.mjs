import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

import { DEFAULT_FILE, GUARD_TEMPLATE, applyLocaleGuard, hasLocaleGuard } from './locale_guard.mjs';

const script = fileURLToPath(new URL('./locale_guard.mjs', import.meta.url));

// Shape of a committed (guarded) AppLocalizations header.
const canonicalSource = [
  'abstract class AppLocalizations {',
  GUARD_TEMPLATE,
  '',
  '  final String localeName;',
  '',
  '  static AppLocalizations? of(BuildContext context) => null;',
  '}',
  '',
].join('\n');

// What `flutter gen-l10n` emits (before and after dart format) when the guard is dropped.
const generatedOneLine = canonicalSource.replace(
  GUARD_TEMPLATE,
  '  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());\n',
);
const generatedWrapped = canonicalSource.replace(
  GUARD_TEMPLATE,
  '  AppLocalizations(String locale)\n      : localeName = intl.Intl.canonicalizedLocale(locale.toString());\n',
);

const toCrlf = (text) => text.replace(/\r?\n/g, '\r\n');

function withTempFile(content, run) {
  const dir = mkdtempSync(join(tmpdir(), 'kubus-locale-guard-'));
  try {
    const file = join(dir, 'app_localizations.dart');
    writeFileSync(file, content, 'utf8');
    return run(file);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function runScript(args) {
  return spawnSync(process.execPath, [script, ...args], { encoding: 'utf8' });
}

test('fix restores the canonical guard after gen-l10n drops it', () => {
  for (const generated of [generatedOneLine, generatedWrapped]) {
    assert.equal(hasLocaleGuard(generated), false);
    assert.equal(applyLocaleGuard(generated), canonicalSource);
  }
});

test('fix keeps CRLF line endings', () => {
  const generated = toCrlf(generatedWrapped);
  assert.equal(applyLocaleGuard(generated), toCrlf(canonicalSource));
});

test('fix is idempotent', () => {
  const once = applyLocaleGuard(generatedOneLine);
  assert.equal(applyLocaleGuard(once), once);
  assert.equal(applyLocaleGuard(canonicalSource), canonicalSource);
});

test('fix replaces a guard that drifted from the canonical text', () => {
  const drifted = canonicalSource.replace("      _ => 'sl',", "      _ => 'en',");
  assert.notEqual(drifted, canonicalSource);
  assert.equal(applyLocaleGuard(drifted), canonicalSource);
});

test('fix rejects output without the generated constructor', () => {
  assert.throws(() => applyLocaleGuard('abstract class AppLocalizations {\n  final String localeName;\n}\n'), /expected exactly one/);
});

test('check fails when the guard is missing and names the fix command', () => {
  withTempFile(generatedOneLine, (file) => {
    const result = runScript(['--check', '--file', file]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /missing or differs/);
    assert.match(result.stderr, /locale_guard\.mjs --fix/);
  });
});

test('check fails when the guard differs from the canonical text', () => {
  const drifted = canonicalSource.replace("      _ => 'sl',", "      _ => 'en',");
  withTempFile(drifted, (file) => {
    assert.equal(runScript(['--check', '--file', file]).status, 1);
  });
});

test('check passes on canonical output and fix does not modify it', () => {
  withTempFile(canonicalSource, (file) => {
    assert.equal(runScript(['--check', '--file', file]).status, 0);
    assert.equal(runScript(['--fix', '--file', file]).status, 0);
    assert.equal(readFileSync(file, 'utf8'), canonicalSource);
  });
});

test('fix on generated output writes the guard and then check passes', () => {
  withTempFile(generatedWrapped, (file) => {
    assert.equal(runScript(['--fix', '--file', file]).status, 0);
    assert.equal(readFileSync(file, 'utf8'), canonicalSource);
    assert.equal(runScript(['--check', '--file', file]).status, 0);
  });
});

test('committed AppLocalizations carries the canonical guard', () => {
  assert.equal(hasLocaleGuard(readFileSync(DEFAULT_FILE, 'utf8')), true);
});
