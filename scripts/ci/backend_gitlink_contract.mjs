#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = process.cwd();
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
const canonical = git('rev-parse', 'HEAD:backend');
const secondary = git('rev-parse', 'HEAD:backend-open-art-wt');
if (!/^[0-9a-f]{40}$/.test(canonical) || canonical !== secondary) {
  throw new Error(`backend gitlinks must be identical full SHAs (${canonical} vs ${secondary})`);
}
for (const path of ['backend', 'backend-open-art-wt']) {
  const entry = git('ls-tree', 'HEAD', path).split(/\s+/);
  if (entry[0] !== '160000' || entry[1] !== 'commit') throw new Error(`${path} is not a gitlink`);
}
const modules = readFileSync('.gitmodules', 'utf8');
const expectedUrl = 'git@github.com:kubus-project/art.kubus-backend.git';
if ((modules.match(new RegExp(expectedUrl.replaceAll('.', '\\.'), 'g')) || []).length !== 2) {
  throw new Error('both backend gitlinks must use the canonical private backend repository URL');
}
process.stdout.write(`Backend gitlink parity contract passed at ${canonical}.\n`);
