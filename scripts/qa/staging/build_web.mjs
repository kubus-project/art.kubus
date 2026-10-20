#!/usr/bin/env node
// Release web build for local staging QA. Run from the app checkout root.
//
//   KUBUS_STAGING_API_ORIGIN=http://127.0.0.1:53101 \
//   KUBUS_GOOGLE_CLIENT_ID=... KUBUS_GOOGLE_WEB_CLIENT_ID=... KUBUS_GOOGLE_IOS_CLIENT_ID=... \
//   node scripts/qa/staging/build_web.mjs [--skip-flutter]
//
// The public build script (scripts/prepare_public_build_config.mjs) is used unchanged and
// only sets KUBUS_BACKEND_URL; the client reads BACKEND_BASE_URL and
// BACKEND_STANDBY_BASE_URL, which default to production. This wrapper pins all three to
// the loopback staging origin, refuses to build without one, and scans the compiled
// artifact for production API hosts afterwards. It never touches release configuration.
import cp from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { StagingConfigError, parseStagingOrigin, pinStagingDefines, verifyStagingDefines } from './isolation.mjs';
import { runPreflight } from './preflight.mjs';

const DEFINES = path.join('.dart_tool', 'public-build-defines.json');

function run(command, args, env, { shell = false } = {}) {
  // Only the Flutter launcher (flutter.bat on Windows) needs a shell.
  const result = cp.spawnSync(command, args, { stdio: 'inherit', env, shell });
  if (result.status !== 0) throw new Error(`${command} ${args[0] ?? ''} failed (exit ${result.status})`);
}

export function pinDefinesFile(file, origin) {
  const pinned = pinStagingDefines(JSON.parse(fs.readFileSync(file, 'utf8')), origin);
  const problems = verifyStagingDefines(pinned, origin);
  if (problems.length) throw new StagingConfigError(`defines still not isolated: ${problems.join('; ')}`);
  fs.writeFileSync(file, `${JSON.stringify(pinned, null, 2)}\n`);
  return pinned;
}

async function main() {
  const skipFlutter = process.argv.includes('--skip-flutter');
  const cwd = process.cwd();
  let origin;
  try {
    origin = parseStagingOrigin(process.env.KUBUS_STAGING_API_ORIGIN, 'KUBUS_STAGING_API_ORIGIN');
    if (!fs.existsSync(path.join(cwd, 'scripts', 'prepare_public_build_config.mjs'))) {
      throw new StagingConfigError('run from the app checkout root (scripts/prepare_public_build_config.mjs not found)');
    }
  } catch (error) {
    console.error(`staging build: ${error.message}`);
    process.exit(2);
  }
  const env = { ...process.env, KUBUS_BACKEND_URL: origin };
  delete env.KUBUS_REQUIRE_STAGING_BACKEND; // that switch is for deployed development builds (public HTTPS only)
  try {
    run(process.execPath, [path.join('scripts', 'prepare_public_build_config.mjs'), '--web'], env);
    pinDefinesFile(path.join(cwd, DEFINES), origin);
    console.log(`staging build: ${DEFINES} pins KUBUS_BACKEND_URL, BACKEND_BASE_URL and BACKEND_STANDBY_BASE_URL to ${origin}`);
    if (skipFlutter) return;
    const flutter = process.env.FLUTTER_BIN || 'flutter';
    const buildName = process.env.KUBUS_APP_VERSION || '0.0.0';
    const buildNumber = process.env.KUBUS_BUILD_NUMBER || '1';
    const viaShell = { shell: process.platform === 'win32' };
    run(flutter, ['pub', 'get'], env, viaShell);
    run(flutter, [
      'build', 'web', '--release', `--build-name=${buildName}`, `--build-number=${buildNumber}`,
      '--dart-define=PUBLIC_FLUTTER_TAKEOVER_ENABLED=true', '--dart-define=SEO_PUBLIC_PAGES_ENABLED=true',
      '--dart-define=KUBUS_BOOT_TRACE=false', `--dart-define-from-file=${DEFINES}`,
    ], env, viaShell);
    const report = await runPreflight({ api: origin, webRoot: path.join(cwd, 'build', 'web'), defines: DEFINES, artifactOnly: true });
    for (const c of report.checks) console.log(`${c.ok ? 'PASS' : 'FAIL'}  ${c.name}: ${c.detail}`);
    if (!report.ok) throw new Error('compiled artifact is not isolated');
  } catch (error) {
    console.error(`staging build: ${error.message}`);
    process.exit(1);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) main();
