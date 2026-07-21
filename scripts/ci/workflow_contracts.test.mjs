import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { classifyPaths } from './classify_changed_paths.mjs';
import { validateJobResults } from './validate_job_results.mjs';
import { validatePrSource } from './validate_pr_source.mjs';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const workflow = (name) => readFileSync(resolve(repositoryRoot, '.github/workflows', name), 'utf8');

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

test('PR validation is deployment-secret-free and has a stable aggregate', () => {
  const content = workflow('pr-validation.yml');
  assert.match(content, /branches:\s*\[dev, master\]/);
  assert.match(content, /name:\s*PR validation required/);
  assert.doesNotMatch(content, /pull_request_target|workflow_run/);
  assert.doesNotMatch(content, /SFTP_|HTTP_BASIC_|SIGNING_|APPLE_/);
});

test('branch deployments have isolated sources, environments, and concurrency', () => {
  const development = workflow('deploy-development.yml');
  const production = workflow('release-production.yml');
  assert.match(development, /branches:\s*\n\s*- dev/);
  assert.match(development, /group:\s*deploy-development/);
  assert.match(development, /environment_name:\s*development-web/);
  assert.doesNotMatch(development, /production-web|branches:\s*\n\s*- master/);
  assert.doesNotMatch(development, /secrets:\s*inherit/);
  assert.match(production, /branches:\s*\n\s*- master/);
  assert.match(production, /group:\s*deploy-production/);
  assert.match(production, /environment_name:\s*production-web/);
  assert.doesNotMatch(production, /development-web|branches:\s*\n\s*- dev/);
  assert.doesNotMatch(production, /secrets:\s*inherit/);
});

test('privileged deployment preserves SHA, stale-head, host, smoke, and rollback gates', () => {
  const content = workflow('web-deploy-reusable.yml');
  for (const required of [
    '/branches/$SOURCE_BRANCH',
    'SFTP_HOST_FINGERPRINT',
    'EXPECTED_DEPLOYMENT_HOST',
    'smoke_development_web.sh',
    'smoke_production_web.sh',
    'SOURCE_SHA',
  ]) {
    assert.ok(content.includes(required), `missing deployment gate: ${required}`);
  }
  assert.match(content, /development:development-web:dev\|production:production-web:master/);
  assert.match(content, /atomic_web_release\.sh" promote/);
  assert.match(content, /atomic_web_release\.sh" rollback/);
  assert.match(content, /::add-mask::\$HTTP_BASIC_USERNAME/);
  assert.match(content, /::add-mask::\$HTTP_BASIC_PASSWORD/);
});

test('all third-party actions are pinned to immutable commit SHAs', () => {
  for (const name of [
    'pr-validation.yml',
    'deploy-development.yml',
    'release-production.yml',
    'mobile-release.yml',
    'scheduled-quality.yml',
    'pages.yml',
    'web-artifact.yml',
    'web-deploy-reusable.yml',
  ]) {
    const content = workflow(name);
    for (const match of content.matchAll(/^\s*uses:\s*(\S+)/gm)) {
      const reference = match[1];
      if (reference.startsWith('./')) continue;
      assert.match(reference, /@[0-9a-f]{40}$/, `${name} has a mutable action reference: ${reference}`);
    }
  }
});

test('mobile and scheduled work remain outside normal branch deployment', () => {
  const mobile = workflow('mobile-release.yml');
  const scheduled = workflow('scheduled-quality.yml');
  assert.match(mobile, /tags:\s*\[['"]v\*['"]\]/);
  assert.match(mobile, /android-release/);
  assert.match(mobile, /ios-release/);
  assert.doesNotMatch(mobile, /pull_request:/);
  assert.match(scheduled, /cron:\s*['"][^'"]+['"]/);
  assert.doesNotMatch(scheduled, /SFTP_|HTTP_BASIC_/);
});
