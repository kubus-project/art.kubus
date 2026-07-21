import assert from 'node:assert/strict';
import test from 'node:test';

import { classifyPaths } from './classify_changed_paths.mjs';
import { validateJobResults } from './validate_job_results.mjs';
import { validatePrSource } from './validate_pr_source.mjs';

test('documentation-only changes avoid platform compilation', () => {
  const result = classifyPaths(['docs/README.md', 'CONTRIBUTING.md']);
  assert.equal(result.docs, true);
  assert.equal(result.android, false);
  assert.equal(result.ios, false);
  assert.equal(result.web, false);
  assert.equal(result.full, false);
});

test('agent instructions select documentation and governance checks', () => {
  const result = classifyPaths(['lib/screens/AGENTS.md']);
  assert.equal(result.agents, true);
  assert.equal(result.docs, true);
  assert.equal(result.ci, true);
  assert.equal(result.full, false);
});

test('shared Flutter inputs select web and both mobile platforms', () => {
  const result = classifyPaths(['lib/main.dart']);
  assert.equal(result.frontend, true);
  assert.equal(result.web, true);
  assert.equal(result.android, true);
  assert.equal(result.ios, true);
});

test('platform-only and web-only changes stay isolated', () => {
  assert.equal(classifyPaths(['android/app/build.gradle']).ios, false);
  assert.equal(classifyPaths(['ios/Runner/Info.plist']).android, false);
  const web = classifyPaths(['web/index.html']);
  assert.equal(web.web, true);
  assert.equal(web.android, false);
  assert.equal(web.ios, false);
});

test('workflow and unknown paths fail safe to full validation', () => {
  assert.equal(classifyPaths(['.github/workflows/pr-validation.yml']).full, true);
  assert.equal(classifyPaths(['unexpected-root-file.bin']).full, true);
});

test('deployment changes select web and deployment contracts', () => {
  const result = classifyPaths(['scripts/deploy/atomic_web_release.sh']);
  assert.equal(result.deployment, true);
  assert.equal(result.web, true);
});

test('integration PRs accept topic branches but not protected branches', () => {
  assert.equal(validatePrSource({ eventName: 'pull_request', baseRef: 'dev', headRef: 'fix/a', headRepository: 'fork/repo', repository: 'kubus-project/art.kubus' }).tier, 'integration');
  assert.throws(() => validatePrSource({ eventName: 'pull_request', baseRef: 'dev', headRef: 'master', headRepository: 'kubus-project/art.kubus', repository: 'kubus-project/art.kubus' }));
});

test('master provenance permits same-repository dev and hotfix only', () => {
  const common = { eventName: 'pull_request', baseRef: 'master', headRepository: 'kubus-project/art.kubus', repository: 'kubus-project/art.kubus' };
  assert.equal(validatePrSource({ ...common, headRef: 'dev' }).tier, 'release');
  assert.equal(validatePrSource({ ...common, headRef: 'hotfix/urgent-fix' }).tier, 'hotfix');
  assert.throws(() => validatePrSource({ ...common, headRef: 'feature/nope' }));
  assert.throws(() => validatePrSource({ ...common, headRef: 'dev', headRepository: 'fork/art.kubus' }));
});

test('aggregate accepts success/skipped and rejects failure, cancellation, or missing jobs', () => {
  validateJobResults({ a: { result: 'success' }, b: { result: 'skipped' } }, ['a', 'b']);
  assert.throws(() => validateJobResults({ a: { result: 'failure' } }, ['a']));
  assert.throws(() => validateJobResults({ a: { result: 'cancelled' } }, ['a']));
  assert.throws(() => validateJobResults({}, ['a']));
});
