#!/usr/bin/env node
/**
 * Kubus lint ratchet.
 *
 * --grandfather  Add `// ignore_for_file:` headers for kubus lint rules to
 *                every lib/ file that currently violates them (regex-based
 *                over-approximation of the custom_lint rules).
 * --check        Recount grandfathered files per rule and compare with
 *                tool/kubus_lint_ratchet.json. Fails (exit 1) if any count
 *                INCREASED. Prints per-rule deltas.
 * --write        With --check: update the baseline to current counts
 *                (use after intentionally migrating files).
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const RULES = {
  kubus_no_raw_color: /\bColor(\.fromARGB|\.fromRGBO)?\s*\(\s*0x/,
  kubus_no_raw_border:
    /\b(Border\.all|BorderSide)\s*\((?:[^()]|\([^()]*\))*color:\s*(const\s+)?(Color(\.from)?\s*\(|Colors\.)/s,
  kubus_no_raw_backdropfilter: /\bBackdropFilter\s*\(/,
  kubus_no_inline_google_fonts: /\bGoogleFonts\.\w+\s*\(/,
  kubus_no_raw_progress_indicator:
    /\b(CircularProgressIndicator|LinearProgressIndicator)\s*\(/,
};

const CENTRAL_COLOR_FILES = [
  'lib/utils/design_tokens.dart',
  'lib/utils/kubus_color_roles.dart',
  'lib/utils/kubus_accent_gradients.dart',
  'lib/utils/kubus_brand_colors.dart',
  'lib/utils/app_color_utils.dart',
  'lib/utils/category_accent_color.dart',
  'lib/utils/rarity_ui.dart',
  'lib/widgets/map_marker_style_config.dart',
  'lib/providers/themeprovider.dart',
];

const ALLOW = {
  kubus_no_raw_color: CENTRAL_COLOR_FILES,
  kubus_no_raw_border: CENTRAL_COLOR_FILES,
  kubus_no_raw_backdropfilter: [
    'lib/widgets/glass/glass_surface.dart',
    'lib/widgets/glass_components.dart',
  ],
  kubus_no_inline_google_fonts: ['lib/utils/design_tokens.dart'],
  kubus_no_raw_progress_indicator: [
    'lib/widgets/inline_loading.dart',
    'lib/widgets/inline_progress.dart',
    'lib/widgets/app_loading.dart',
  ],
};

const BASELINE_PATH = 'tool/kubus_lint_ratchet.json';

function* dartFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const st = statSync(p);
    if (st.isDirectory()) yield* dartFiles(p);
    else if (p.endsWith('.dart')) yield p;
  }
}

const norm = (p) => p.replaceAll('\\', '/');

function violatedRules(path, text) {
  const rules = [];
  for (const [rule, re] of Object.entries(RULES)) {
    if (ALLOW[rule].some((suffix) => norm(path).endsWith(suffix))) continue;
    if (re.test(text)) rules.push(rule);
  }
  return rules;
}

function existingIgnores(text) {
  const m = text.match(/\/\/ ignore_for_file:\s*([^\n]*)/g) ?? [];
  return new Set(
    m.flatMap((line) =>
      line
        .replace('// ignore_for_file:', '')
        .split(',')
        .map((s) => s.trim()),
    ),
  );
}

const mode = process.argv[2];
const files = [...dartFiles('lib')];

if (mode === '--grandfather') {
  let touched = 0;
  for (const path of files) {
    // Strip any BOM: prepending a header before U+FEFF would leave it
    // mid-file, which the Dart compiler rejects.
    const text = readFileSync(path, 'utf8').replaceAll('﻿', '');
    const ignored = existingIgnores(text);
    const rules = violatedRules(path, text).filter((r) => !ignored.has(r));
    if (rules.length === 0) continue;
    const header =
      `// ignore_for_file: ${rules.join(', ')}\n` +
      `// Grandfathered kubus design-token violations. Remove this header\n` +
      `// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).\n`;
    writeFileSync(path, header + text);
    touched++;
  }
  console.log(`Grandfathered ${touched} files.`);
} else if (mode === '--check') {
  const counts = Object.fromEntries(Object.keys(RULES).map((r) => [r, 0]));
  for (const path of files) {
    const text = readFileSync(path, 'utf8');
    for (const rule of existingIgnores(text)) {
      if (rule in counts) counts[rule]++;
    }
  }
  if (process.argv.includes('--write')) {
    writeFileSync(BASELINE_PATH, JSON.stringify(counts, null, 2) + '\n');
    console.log('Baseline updated:', counts);
    process.exit(0);
  }
  const baseline = JSON.parse(readFileSync(BASELINE_PATH, 'utf8'));
  let failed = false;
  for (const [rule, count] of Object.entries(counts)) {
    const base = baseline[rule] ?? 0;
    const delta = count - base;
    console.log(
      `${rule}: ${count} (baseline ${base}, delta ${delta >= 0 ? '+' : ''}${delta})`,
    );
    if (count > base) failed = true;
  }
  if (failed) {
    console.error('\nRatchet violation: grandfathered-file count increased.');
    console.error(
      'New code must use kubus tokens — do not add ignore_for_file headers.',
    );
    process.exit(1);
  }
  console.log('\nRatchet OK.');
} else {
  console.error(
    'Usage: node scripts/kubus-lint-ratchet.mjs --grandfather | --check [--write]',
  );
  process.exit(2);
}
