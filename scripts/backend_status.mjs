import { existsSync, statSync, appendFileSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const backendDir = resolve(rootDir, 'backend');
const writeGithubOutput = process.argv.includes('--github-output');

function runGit(args, cwd = rootDir) {
  const result = spawnSync('git', args, {
    cwd,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
  return {
    ok: result.status === 0,
    output: (result.stdout || '').trim(),
    error: (result.stderr || result.error?.message || '').trim(),
  };
}

function hasSubmoduleConfig() {
  const gitmodulesPath = resolve(rootDir, '.gitmodules');
  if (!existsSync(gitmodulesPath)) return false;
  return readFileSync(gitmodulesPath, 'utf8').includes('path = backend');
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch (_) {
    return false;
  }
}

function setOutput(name, value) {
  if (!writeGithubOutput || !process.env.GITHUB_OUTPUT) return;
  const sanitized = String(value ?? '').replace(/\r?\n/g, ' ').trim();
  appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${sanitized}\n`, 'utf8');
}

const submoduleConfigured = hasSubmoduleConfig();
const backendDirectoryPresent = isDirectory(backendDir);
const packageJsonPresent = existsSync(resolve(backendDir, 'package.json'));
const submoduleStatus = runGit(['submodule', 'status', '--', 'backend']);
const backendHead = packageJsonPresent
  ? runGit(['rev-parse', '--short', 'HEAD'], backendDir)
  : { ok: false, output: '', error: 'backend package missing' };
const backendStatus = packageJsonPresent
  ? runGit(['status', '--short'], backendDir)
  : { ok: false, output: '', error: 'backend package missing' };
const dirty = Boolean(backendStatus.output);
const validationAvailable = packageJsonPresent;
const reason = validationAvailable
  ? 'backend package present; backend lint/tests can run'
  : submoduleConfigured
    ? 'backend package missing; checkout likely skipped the backend submodule'
    : 'backend package missing and no backend submodule is configured';

console.log('Backend status');
console.log(`- submodule configured: ${submoduleConfigured ? 'yes' : 'no'}`);
console.log(`- backend directory present: ${backendDirectoryPresent ? 'yes' : 'no'}`);
console.log(`- backend/package.json present: ${packageJsonPresent ? 'yes' : 'no'}`);
console.log(`- submodule status: ${submoduleStatus.output || submoduleStatus.error || 'unavailable'}`);
console.log(`- backend HEAD: ${backendHead.output || 'unavailable'}`);
console.log(`- backend worktree: ${dirty ? 'dirty' : packageJsonPresent ? 'clean' : 'unavailable'}`);
console.log(`- backend validation: ${validationAvailable ? 'available' : 'skipped'} (${reason})`);

setOutput('ok', validationAvailable ? 'true' : 'false');
setOutput('reason', reason);
setOutput('submodule_configured', submoduleConfigured ? 'true' : 'false');
setOutput('submodule_status', submoduleStatus.output || submoduleStatus.error || 'unavailable');
setOutput('backend_head', backendHead.output || 'unavailable');
setOutput('dirty', dirty ? 'true' : 'false');
