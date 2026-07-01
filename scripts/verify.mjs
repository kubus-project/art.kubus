import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const backendDir = resolve(rootDir, 'backend');

function resolveFlutterCommand() {
  const configured = (process.env.FLUTTER_BIN || '').trim();
  if (configured) return configured;

  if (process.platform === 'win32') {
    const localFlutter = 'C:\\dev\\flutter\\bin\\flutter.bat';
    if (existsSync(localFlutter)) return localFlutter;
    return 'flutter.bat';
  }

  return 'flutter';
}

function commandFor(name) {
  if (process.platform !== 'win32') return name;
  if (name === 'npm') return 'npm.cmd';
  if (name === 'npx') return 'npx.cmd';
  return name;
}

const flutter = resolveFlutterCommand();

const commands = {
  architecture: [
    {
      label: 'Architecture guard',
      command: commandFor('npm'),
      args: ['run', 'guard:architecture'],
      cwd: rootDir,
    },
  ],
  docs: [
    {
      label: 'Docs doctor',
      command: commandFor('npm'),
      args: ['run', 'docs:doctor'],
      cwd: rootDir,
    },
  ],
  'flutter:analyze': [
    {
      label: 'Flutter analyze',
      command: flutter,
      args: ['analyze', '--no-fatal-infos'],
      cwd: rootDir,
    },
  ],
  'flutter:smoke': [
    {
      label: 'Flutter smoke tests',
      command: flutter,
      args: [
        'test',
        'test/services/search_service_test.dart',
        'test/settings/notifications_settings_regression_test.dart',
        'test/privacy/privacy_settings_parity_test.dart',
        'test/wallet/wallet_settings_parity_test.dart',
      ],
      cwd: rootDir,
    },
  ],
  'backend:lint': [
    {
      label: 'Backend lint',
      command: commandFor('npm'),
      args: ['run', 'lint'],
      cwd: backendDir,
    },
  ],
  'backend:status': [
    {
      label: 'Backend status',
      command: commandFor('npm'),
      args: ['run', 'backend:status'],
      cwd: rootDir,
    },
  ],
  'backend:smoke': [
    {
      label: 'Backend smoke tests',
      command: commandFor('npx'),
      args: [
        'jest',
        '--runInBand',
        'architectureGuardScript.test.js',
        'userPreferencesRoutes.test.js',
        'publicWalletLeakRoutes.test.js',
      ],
      cwd: backendDir,
      env: { NODE_ENV: 'test' },
    },
  ],
};

commands.flutter = [
  ...commands['flutter:analyze'],
  ...commands['flutter:smoke'],
];
commands.backend = [
  ...commands['backend:status'],
  ...commands['backend:lint'],
  ...commands['backend:smoke'],
];
commands.all = [
  ...commands.architecture,
  ...commands.docs,
  ...commands.flutter,
  ...commands.backend,
];

function usage() {
  const names = Object.keys(commands).sort().join(', ');
  console.log(`Usage: node scripts/verify.mjs <${names}>`);
  console.log('Set FLUTTER_BIN to override Flutter executable resolution.');
}

function runStep(step) {
  if (step.cwd === backendDir && !existsSync(resolve(backendDir, 'package.json'))) {
    console.error('Backend sources are missing; cannot run backend verification.');
    return 1;
  }

  console.log(`\n=== ${step.label} ===`);
  console.log(`$ ${step.command} ${step.args.join(' ')}`);
  const result = spawnSync(step.command, step.args, {
    cwd: step.cwd,
    env: { ...process.env, ...(step.env || {}) },
    shell: process.platform === 'win32',
    stdio: 'inherit',
  });

  if (result.error) {
    console.error(`${step.label} failed to start: ${result.error.message}`);
    return 1;
  }

  return result.status ?? 1;
}

const target = process.argv[2] || 'all';
if (target === '--help' || target === '-h' || target === 'help') {
  usage();
  process.exit(0);
}

const steps = commands[target];
if (!steps) {
  usage();
  process.exit(2);
}

for (const step of steps) {
  const status = runStep(step);
  if (status !== 0) {
    console.error(`\n${step.label} failed with exit code ${status}.`);
    process.exit(status);
  }
}

console.log(`\nVerification target "${target}" passed.`);
