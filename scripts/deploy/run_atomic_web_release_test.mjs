import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const rootDir = resolve(import.meta.dirname, '..', '..');
const testScript = resolve(import.meta.dirname, 'test_atomic_web_release.sh');
const candidates = process.platform === 'win32'
  ? [
      process.env.BASH_BIN,
      'C:\\Program Files\\Git\\bin\\bash.exe',
      'C:\\Program Files\\Git\\usr\\bin\\bash.exe',
    ]
  : [process.env.BASH_BIN, 'bash'];
const bash = candidates.find((candidate) => candidate && (
  candidate === 'bash' || existsSync(candidate)
));

if (!bash) {
  console.error('Git Bash or BASH_BIN is required to exercise atomic deployment.');
  process.exit(1);
}

const result = spawnSync(bash, [testScript], {
  cwd: rootDir,
  encoding: 'utf8',
  env: {
    ...process.env,
    ...(process.platform === 'win32' ? { MSYS: 'winsymlinks:nativestrict' } : {}),
  },
  stdio: 'inherit',
  shell: false,
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status ?? 1);
