#!/usr/bin/env node
// Keeps the hand-kept locale fallback in lib/l10n/app_localizations.dart.
//
// `flutter gen-l10n` regenerates AppLocalizations without the guard that maps
// unsupported locale tags to a supported one (see GitHub issue #196). This script
// is the single owner of that guard text:
//
//   node scripts/l10n/locale_guard.mjs --fix    re-insert the guard (idempotent)
//   node scripts/l10n/locale_guard.mjs --check  exit 1 if the guard is missing or differs
//   node scripts/l10n/locale_guard.mjs --file <path>  operate on another generated file
//
// The region replaced is everything from the `AppLocalizations(String locale)`
// constructor up to the `final String localeName;` field, so both the generated
// constructor and any previously inserted guard are normalized to GUARD_TEMPLATE.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// Canonical guard text, copied verbatim from lib/l10n/app_localizations.dart at
// commit 2aa8b05e (lines 65-76). Keep it in sync with the Dart analyzer output.
export const GUARD_TEMPLATE = [
  '  AppLocalizations(String locale) : localeName = _supportedLocaleName(locale);',
  '',
  '  // Keep this guard after `flutter gen-l10n`: the generator\'s default locale',
  '  // normalization does not trim input or fall back to the app\'s supported',
  '  // locales, and this constructor is used directly by non-widget callers.',
  '  static String _supportedLocaleName(String locale) {',
  '    final normalizedLocale = intl.Intl.canonicalizedLocale(locale.trim());',
  '    return switch (normalizedLocale) {',
  "      'en' || 'sl' => normalizedLocale,",
  "      _ => 'sl',",
  '    };',
  '  }',
].join('\n');

const REGION = /  AppLocalizations\(String locale\)[\s\S]*?(?=  final String localeName;)/g;
const FIELD_ANCHOR = '  final String localeName;';

export const DEFAULT_FILE = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../lib/l10n/app_localizations.dart',
);

/**
 * Returns the source with the locale guard in its canonical form.
 * Throws when the constructor region or the field anchor cannot be found.
 */
export function applyLocaleGuard(source) {
  const eol = source.includes('\r\n') ? '\r\n' : '\n';
  const template = GUARD_TEMPLATE.split('\n').join(eol);
  const matches = [...source.matchAll(REGION)];
  if (matches.length !== 1) {
    throw new Error(
      `locale guard: expected exactly one AppLocalizations(String locale) constructor, found ${matches.length}. ` +
        'The generator output shape changed; update scripts/l10n/locale_guard.mjs.',
    );
  }
  if (!source.includes(FIELD_ANCHOR)) {
    throw new Error(`locale guard: anchor "${FIELD_ANCHOR}" not found in generated file.`);
  }
  // Region match ends right before the field; keep the blank line separator.
  const [match] = matches;
  const replacement = template + eol + eol;
  return source.slice(0, match.index) + replacement + source.slice(match.index + match[0].length);
}

/** Returns true when the source already carries exactly the canonical guard. */
export function hasLocaleGuard(source) {
  return applyLocaleGuard(source) === source;
}

function main(argv) {
  const check = argv.includes('--check');
  const fix = argv.includes('--fix');
  if (check === fix) {
    process.stderr.write('usage: locale_guard.mjs (--fix | --check) [--file <path>]\n');
    return 2;
  }
  const fileIndex = argv.indexOf('--file');
  const file = fileIndex === -1 ? DEFAULT_FILE : resolve(argv[fileIndex + 1] ?? '');
  const source = readFileSync(file, 'utf8');
  let guarded;
  try {
    guarded = applyLocaleGuard(source);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    return 1;
  }
  if (fix) {
    if (guarded !== source) {
      writeFileSync(file, guarded, 'utf8');
      process.stdout.write(`locale guard restored in ${file}\n`);
    } else {
      process.stdout.write(`locale guard already canonical in ${file}\n`);
    }
    return 0;
  }
  if (guarded !== source) {
    process.stderr.write(
      `locale guard is missing or differs from the canonical form in ${file}.\n` +
        'Run `node scripts/l10n/locale_guard.mjs --fix` after `flutter gen-l10n` ' +
        '(see CONTRIBUTING.md, issue #196).\n',
    );
    return 1;
  }
  process.stdout.write(`locale guard is canonical in ${file}\n`);
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  process.exitCode = main(process.argv.slice(2));
}
