#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(fileURLToPath(new URL('..', import.meta.url)));
const androidVersionCodeLimit = 2100000000;

function valueFromArgs(name) {
  const prefixed = `--${name}=`;
  const prefixedArgument = process.argv.find((argument) => argument.startsWith(prefixed));
  if (prefixedArgument) return prefixedArgument.slice(prefixed.length);

  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function parseBuildDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error('build date must use YYYY-MM-DD.');
  }
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new Error('build date is not a real calendar date.');
  }
  return { year, date };
}

function parseVersion(version) {
  if (!/^\d+\.\d+\.\d+$/.test(version || '')) {
    throw new Error('version.json version must use X.Y.Z.');
  }
  return version;
}

function parseSourceSha(sourceSha) {
  if (!/^[0-9a-f]{40}$/.test(sourceSha || '')) {
    throw new Error('web source SHA must be a full lowercase commit SHA.');
  }
  return sourceSha;
}

function utcDateToday() {
  return new Date().toISOString().slice(0, 10);
}

export function resolveBuildMetadata({ version, buildDate, runNumber }) {
  parseVersion(version);
  if (!Number.isSafeInteger(runNumber) || runNumber < 1) {
    throw new Error('CI run number must be a positive integer.');
  }

  const { year, date } = parseBuildDate(buildDate);
  const startOfYear = Date.UTC(year, 0, 1);
  const dayOfYear = Math.floor((date.getTime() - startOfYear) / 86400000) + 1;
  const dailySequence = ((runNumber - 1) % 10000) + 1;
  const buildNumber = (year % 100) * 10000000 + dayOfYear * 10000 + dailySequence;

  if (buildNumber > androidVersionCodeLimit) {
    throw new Error('computed Android versionCode exceeds its supported maximum.');
  }

  return {
    version,
    buildDate,
    buildNumber,
  };
}

export function deterministicWebBuildNumber(sourceSha) {
  const validatedSha = parseSourceSha(sourceSha);
  const modulus = androidVersionCodeLimit - 1;
  let value = 0;
  for (const digit of validatedSha) {
    value = (value * 16 + Number.parseInt(digit, 16)) % modulus;
  }
  return value + 1;
}

export function resolveWebBuildMetadata({ version, buildDate, sourceSha }) {
  parseVersion(version);
  parseBuildDate(buildDate);

  return {
    version,
    buildDate,
    buildNumber: deterministicWebBuildNumber(sourceSha),
  };
}

function main() {
  const manifest = JSON.parse(readFileSync(resolve(rootDir, 'version.json'), 'utf8'));
  const mode = valueFromArgs('mode') || 'mobile';
  const requestedBuildDate = valueFromArgs('build-date');
  let metadata;

  if (mode === 'web') {
    if (!requestedBuildDate) {
      throw new Error('web metadata mode requires --build-date from the source commit.');
    }
    metadata = resolveWebBuildMetadata({
      version: manifest.version,
      buildDate: requestedBuildDate,
      sourceSha: valueFromArgs('source-sha') || process.env.GITHUB_SHA,
    });
  } else if (mode === 'mobile') {
    const runNumberText = valueFromArgs('run-number') || process.env.GITHUB_RUN_NUMBER;
    metadata = resolveBuildMetadata({
      version: manifest.version,
      buildDate: requestedBuildDate || utcDateToday(),
      runNumber: Number.parseInt(runNumberText || '', 10),
    });
  } else {
    throw new Error('metadata mode must be web or mobile.');
  }

  const githubOutputPath = valueFromArgs('github-output');
  if (githubOutputPath) {
    writeFileSync(
      githubOutputPath,
      [
        `version=${metadata.version}`,
        `build_date=${metadata.buildDate}`,
        `build_number=${metadata.buildNumber}`,
        '',
      ].join('\n'),
      'utf8',
    );
  }

  process.stdout.write(`${JSON.stringify(metadata)}\n`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
