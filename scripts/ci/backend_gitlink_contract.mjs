#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = process.cwd();
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
const canonical = git('rev-parse', 'HEAD:backend');
if (!/^[0-9a-f]{40}$/.test(canonical)) throw new Error(`backend must resolve to a full SHA (${canonical})`);
const entry = git('ls-tree', 'HEAD', 'backend').split(/\s+/);
if (entry[0] !== '160000' || entry[1] !== 'commit') throw new Error('backend is not a gitlink');
const modules = readFileSync('.gitmodules', 'utf8');
const expectedUrl = 'git@github.com:kubus-project/art.kubus-backend.git';
if ((modules.match(new RegExp(expectedUrl.replaceAll('.', '\\.'), 'g')) || []).length !== 1) {
  throw new Error('backend must be the sole gitlink using the canonical private repository URL');
}
if (modules.includes('backend-open-art-wt')) throw new Error('retired backend-open-art-wt configuration must not exist');
process.stdout.write(`Canonical backend gitlink contract passed at ${canonical}.\n`);
