import { existsSync, statSync, appendFileSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const backendDir = resolve(rootDir, 'backend');
const mirrorDir = resolve(rootDir, 'backend-open-art-wt');
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

function hasSubmoduleConfig(relativePath) {
  const gitmodulesPath = resolve(rootDir, '.gitmodules');
  if (!existsSync(gitmodulesPath)) return false;
  return readFileSync(gitmodulesPath, 'utf8').includes(`path = ${relativePath}`);
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

function inspectGitlink(relativePath, directory) {
  const configured = hasSubmoduleConfig(relativePath);
  const directoryPresent = isDirectory(directory);
  const packageJsonPresent = existsSync(resolve(directory, 'package.json'));
  const submoduleStatus = runGit(['submodule', 'status', '--', relativePath]);
  const head = packageJsonPresent
    ? runGit(['rev-parse', '--short', 'HEAD'], directory)
    : { ok: false, output: '', error: `${relativePath} package missing` };
  const status = packageJsonPresent
    ? runGit(['status', '--short'], directory)
    : { ok: false, output: '', error: `${relativePath} package missing` };

  return {
    relativePath,
    configured,
    directoryPresent,
    packageJsonPresent,
    submoduleStatus,
    head,
    dirty: Boolean(status.output),
  };
}

const backendInfo = inspectGitlink('backend', backendDir);
const mirrorInfo = inspectGitlink('backend-open-art-wt', mirrorDir);
const submoduleConfigured = backendInfo.configured;
const backendDirectoryPresent = isDirectory(backendDir);
const packageJsonPresent = backendInfo.packageJsonPresent;
const submoduleStatus = backendInfo.submoduleStatus;
const backendHead = backendInfo.head;
const dirty = backendInfo.dirty;
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
console.log(`- backend-open-art-wt configured: ${mirrorInfo.configured ? 'yes' : 'no'}`);
console.log(`- backend-open-art-wt directory present: ${mirrorInfo.directoryPresent ? 'yes' : 'no'}`);
console.log(`- backend-open-art-wt/package.json present: ${mirrorInfo.packageJsonPresent ? 'yes' : 'no'}`);
console.log(`- backend-open-art-wt submodule status: ${mirrorInfo.submoduleStatus.output || mirrorInfo.submoduleStatus.error || 'unavailable'}`);
console.log(`- backend-open-art-wt HEAD: ${mirrorInfo.head.output || 'unavailable'}`);
console.log(`- backend-open-art-wt worktree: ${mirrorInfo.dirty ? 'dirty' : mirrorInfo.packageJsonPresent ? 'clean' : 'unavailable'}`);
console.log(`- backend validation: ${validationAvailable ? 'available' : 'skipped'} (${reason})`);

setOutput('ok', validationAvailable ? 'true' : 'false');
setOutput('reason', reason);
setOutput('submodule_configured', submoduleConfigured ? 'true' : 'false');
setOutput('submodule_status', submoduleStatus.output || submoduleStatus.error || 'unavailable');
setOutput('backend_head', backendHead.output || 'unavailable');
setOutput('dirty', dirty ? 'true' : 'false');
setOutput('backend_open_art_wt_configured', mirrorInfo.configured ? 'true' : 'false');
setOutput('backend_open_art_wt_head', mirrorInfo.head.output || 'unavailable');
setOutput('backend_open_art_wt_dirty', mirrorInfo.dirty ? 'true' : 'false');
