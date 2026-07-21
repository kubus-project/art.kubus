#!/usr/bin/env node
import { appendFileSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const categories = [
  'full',
  'frontend',
  'web',
  'backend',
  'android',
  'ios',
  'docs',
  'versioning',
  'ci',
  'deployment',
  'agents',
];

const matches = (path, patterns) => patterns.some((pattern) => pattern.test(path));

export function classifyPaths(paths) {
  const result = Object.fromEntries(categories.map((name) => [name, false]));

  for (const rawPath of paths) {
    const path = rawPath.trim().replaceAll('\\', '/');
    if (!path) continue;
    let recognized = false;

    if (matches(path, [/^\.github\/workflows\//, /^\.github\/actions\//, /^scripts\/ci\//])) {
      result.ci = true;
      result.full = true;
      recognized = true;
    }

    if (matches(path, [
      /^scripts\/deploy\//,
      /^docs\/DEPLOYMENT_GATES\.md$/,
      /^docs\/engineering\/branching-and-deployment\.md$/,
      /^docs\/seo-public-pages\.md$/,
      /^web\/\.htaccess$/,
    ])) {
      result.deployment = true;
      result.web = true;
      recognized = true;
    }

    if (matches(path, [
      /^AGENTS\.md$/,
      /\/AGENTS\.md$/,
      /^\.github\/copilot-instructions\.md$/,
    ])) {
      result.agents = true;
      result.docs = true;
      result.ci = true;
      recognized = true;
    }

    const sharedFlutter = matches(path, [
      /^lib\//,
      /^test\//,
      /^integration_test\//,
      /^assets\//,
      /^tool\//,
      /^packages\/kubus_lints\//,
      /^pubspec\.(?:yaml|lock)$/,
      /^analysis_options\.yaml$/,
    ]);
    if (sharedFlutter) {
      result.frontend = true;
      result.web = true;
      result.android = true;
      result.ios = true;
      recognized = true;
    }

    if (matches(path, [/^web\//, /^scripts\/qa\//])) {
      result.web = true;
      recognized = true;
    }
    if (/^android\//.test(path)) {
      result.android = true;
      recognized = true;
    }
    if (/^ios\//.test(path)) {
      result.ios = true;
      recognized = true;
    }
    if (path === 'backend' || /^scripts\/ci\/(?:checkout_backend_submodules\.sh|backend_gitlink_contract\.mjs)$/.test(path)) {
      result.backend = true;
      recognized = true;
    }
    if (matches(path, [
      /^docs\//,
      /^README\.md$/,
      /^CONTRIBUTING\.md$/,
      /^GOVERNANCE\.md$/,
      /^SECURITY\.md$/,
      /^SUPPORT\.md$/,
      /^\.github\/(?:pull_request_template\.md|ISSUE_TEMPLATE\/)/,
      /^\.github\/dependabot\.ya?ml$/,
    ])) {
      result.docs = true;
      recognized = true;
    }
    if (matches(path, [
      /^pubspec\.yaml$/,
      /^version\.json$/,
      /^package\.json$/,
      /^scripts\/(?:sync_versions\.js|sync_all_versions\.mjs|resolve_ci_build_metadata\.mjs)$/,
    ]) || path === 'backend') {
      result.versioning = true;
      recognized = true;
    }

    if (!recognized) result.full = true;
  }

  return result;
}

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? null : process.argv[index + 1];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const filesPath = arg('--files');
  if (!filesPath) throw new Error('Usage: classify_changed_paths.mjs --files <newline-file> [--github-output <path>]');
  const paths = readFileSync(filesPath, 'utf8').split(/\r?\n/).filter(Boolean);
  const result = classifyPaths(paths);
  const outputPath = arg('--github-output');
  const lines = categories.map((name) => `${name}=${result[name]}`).join('\n') + '\n';
  if (outputPath) appendFileSync(outputPath, lines);
  process.stdout.write(JSON.stringify({ paths, ...result }, null, 2) + '\n');
}
