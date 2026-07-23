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
const deployAction = () => readFileSync(resolve(repositoryRoot, '.github/actions/deploy-web-artifact/action.yml'), 'utf8');

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
  assert.match(development, /\bworkflow_dispatch:/);
  assert.doesNotMatch(development, /\bpull_request:|\bpull_request_target:/);
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
  const content = deployAction();
  assert.match(content, /using:\s*composite/);
  for (const input of ['sftp_server', 'sftp_username', 'sftp_private_key', 'sftp_host_fingerprint']) {
    assert.match(content, new RegExp(`${input}:\\s*\\{ required: true \\}`));
  }
  assert.match(content, /inputs\.bootstrap_web_root == 'true'/);
  for (const caller of [workflow('deploy-development.yml'), workflow('release-production.yml')]) {
    assert.match(caller, /uses:\s*\.\/\.github\/actions\/deploy-web-artifact/);
    assert.match(caller, /sftp_server:\s*\$\{\{ secrets\.SFTP_SERVER \}\}/);
    assert.match(caller, /sftp_private_key:\s*\$\{\{ secrets\.SFTP_PRIVATE_KEY \}\}/);
  }
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
  assert.match(content, /atomic_web_release\.sh" prepare/);
  assert.match(content, /atomic_web_release\.sh" promote/);
  assert.match(content, /atomic_web_release\.sh" rollback/);
  assert.match(
    content,
    /Apply and verify host-local development protection[\s\S]*?atomic_web_release\.sh" prepare[\s\S]*?Atomically promote prepared release[\s\S]*?atomic_web_release\.sh" promote/,
  );
  assert.match(content, /Verify production release is free of staging protection/);
  assert.doesNotMatch(content, /DEV_HTPASSWD_FILE|\/home\//);
  assert.match(content, /::add-mask::\$HTTP_BASIC_USERNAME/);
  assert.match(content, /::add-mask::\$HTTP_BASIC_PASSWORD/);
});

test('composite deploy action is context-safe and fed environment config by its callers', () => {
  const action = deployAction();

  // A composite action cannot resolve the `vars` or `secrets` contexts at
  // runtime; referencing them makes the action fail to load. Every environment
  // value must arrive as an explicit input forwarded by the environment-bound
  // caller. This is the exact defect that broke staging and production deploys.
  assert.doesNotMatch(action, /\$\{\{\s*vars\./, 'composite action must not read the vars context');
  assert.doesNotMatch(action, /\$\{\{\s*secrets\./, 'composite action must not read the secrets context');

  // Environment variables previously read via `vars.*` are now required inputs.
  for (const input of [
    'environment_variable_name',
    'sftp_port',
    'web_server_dir',
    'web_releases_dir',
    'web_smoke_url',
    'expected_deployment_host',
  ]) {
    assert.match(action, new RegExp(`${input}:\\s*\\{ required: true \\}`), `missing required input: ${input}`);
  }

  // Both environment-bound callers forward the environment variables and secrets.
  for (const name of ['deploy-development.yml', 'release-production.yml']) {
    const caller = workflow(name);
    assert.match(caller, /environment_variable_name:\s*\$\{\{ vars\.ENVIRONMENT_NAME \}\}/);
    assert.match(caller, /sftp_port:\s*\$\{\{ vars\.SFTP_PORT \}\}/);
    assert.match(caller, /web_server_dir:\s*\$\{\{ vars\.WEB_SERVER_DIR \}\}/);
    assert.match(caller, /web_releases_dir:\s*\$\{\{ vars\.WEB_RELEASES_DIR \}\}/);
    assert.match(caller, /web_smoke_url:\s*\$\{\{ vars\.WEB_SMOKE_URL \}\}/);
    assert.match(caller, /expected_deployment_host:\s*\$\{\{ vars\.EXPECTED_DEPLOYMENT_HOST \}\}/);
    assert.match(caller, /sftp_server:\s*\$\{\{ secrets\.SFTP_SERVER \}\}/);
    assert.match(caller, /sftp_host_fingerprint:\s*\$\{\{ secrets\.SFTP_HOST_FINGERPRINT \}\}/);
  }

  // Production additionally forwards the public-takeover smoke configuration.
  const production = workflow('release-production.yml');
  for (const input of [
    'expect_public_flutter_takeover',
    'public_takeover_url',
    'public_takeover_missing_url',
    'public_takeover_optional_standby_url',
  ]) {
    assert.match(production, new RegExp(`${input}:\\s*\\$\\{\\{ vars\\.`), `production caller must forward ${input}`);
  }

  // The obsolete reusable deployment workflow must stay deleted.
  assert.throws(
    () => workflow('web-deploy-reusable.yml'),
    'the reusable deployment workflow must not be reintroduced',
  );
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
    '../actions/deploy-web-artifact/action.yml',
  ]) {
    const content = name.startsWith('../') ? deployAction() : workflow(name);
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
