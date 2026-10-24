import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { classifyPaths } from './classify_changed_paths.mjs';
import {
  DRAFT_CHECK_CONTEXT,
  REQUIRED_CHECK_CONTEXT,
  assertDraftTierStillValid,
  checkContextForTier,
  fetchLiveDraft,
  resolveTier,
} from './pr_validation_tier.mjs';
import { describeSkippedJobs, validateJobResults } from './validate_job_results.mjs';
import { validatePrSource } from './validate_pr_source.mjs';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const workflow = (name) => readFileSync(resolve(repositoryRoot, '.github/workflows', name), 'utf8');
// Evaluates the `required` job's name expression in pr-validation.yml for a given tier output, as
// the Actions runner does: `${{ needs.changes.outputs.tier == 'draft' && 'A' || 'B' }}`. The
// accepted shape is deliberately narrow so a rewrite of the expression has to update this contract.
function requiredJobContext(tier) {
  const content = workflow('pr-validation.yml');
  const job = content.slice(content.indexOf('\n  required:'));
  const match = job.match(/\n    name: \$\{\{ needs\.changes\.outputs\.tier == '([^']+)' && '([^']+)' \|\| '([^']+)' \}\}/);
  assert.ok(match, 'required job name must be the draft/required context expression');
  const [, draftTier, draftName, requiredName] = match;
  assert.equal(draftTier, 'draft');
  assert.equal(draftName, DRAFT_CHECK_CONTEXT);
  assert.equal(requiredName, REQUIRED_CHECK_CONTEXT);
  return tier === draftTier ? draftName : requiredName;
}
const deployAction = () => readFileSync(resolve(repositoryRoot, '.github/actions/deploy-web-artifact/action.yml'), 'utf8');

test('successful web release retains its host-side rollback command outside httpdocs', () => {
  const action = deployAction();
  assert.match(action, /\$RELEASE_ROOT\/host-scripts\/\$SOURCE_SHA\.sh/);
  assert.match(action, /chmod 700 "\$RELEASE_ROOT\/host-scripts\/\$SOURCE_SHA\.sh"/);
  assert.ok(action.indexOf('host-scripts/$SOURCE_SHA.sh') < action.lastIndexOf('rm -rf "$INCOMING_DIR"'));
});

test('Netcup artifact serves raw WebAssembly without precompressed rewrite companions', () => {
  const artifactWorkflow = workflow('web-artifact.yml');
  const htaccess = readFileSync(resolve(repositoryRoot, 'web/.htaccess'), 'utf8');
  assert.match(artifactWorkflow, /Netcup-compatible WebAssembly/);
  assert.match(artifactWorkflow, /-name '\*\.wasm\.br'/);
  assert.match(artifactWorkflow, /-name '\*\.wasm\.gz'/);
  assert.doesNotMatch(artifactWorkflow, /brotli -f|gzip -n -kf/);
  assert.doesNotMatch(htaccess, /Content-Encoding br|Content-Encoding gzip|REQUEST_FILENAME\.br|REQUEST_FILENAME\.gz/);
});

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
  const full = { tier: 'full' };
  validateJobResults({ a: { result: 'success' }, b: { result: 'skipped' } }, ['a', 'b'], full);
  assert.throws(() => validateJobResults({ a: { result: 'failure' } }, ['a'], full));
  assert.throws(() => validateJobResults({ a: { result: 'cancelled' } }, ['a'], full));
  assert.throws(() => validateJobResults({}, ['a'], full));
});

test('PR validation is deployment-secret-free and has a stable aggregate', () => {
  const content = workflow('pr-validation.yml');
  assert.match(content, /branches:\s*\[dev, master\]/);
  assert.equal(requiredJobContext('full'), 'PR validation required');
  assert.doesNotMatch(content, /pull_request_target|workflow_run/);
  assert.doesNotMatch(content, /SFTP_|HTTP_BASIC_|SIGNING_|APPLE_/);
});

test('PR validation keeps the PRODUCT motion acceptance gate', () => {
  const content = workflow('pr-validation.yml');
  assert.match(content, /product_motion_gallery_main\.dart/);
  assert.match(content, /scripts\/qa\/product_motion_acceptance\.mjs/);
  assert.match(content, /for browser in chromium firefox/);
  assert.match(content, /for reduced in 0 1/);
});

test('branch deployments have isolated sources, environments, and concurrency', () => {
  const development = workflow('deploy-development.yml');
  const production = workflow('release-production.yml');
  assert.match(development, /\bpush:\s*branches:\s*\[dev\]/);
  assert.match(development, /\bworkflow_dispatch:/);
  assert.match(development, /test "\$SOURCE_REF" = refs\/heads\/dev/);
  assert.doesNotMatch(development, /\bpull_request:|\bpull_request_target:/);
  assert.match(development, /group:\s*deploy-development/);
  assert.match(development, /environment_name:\s*development-web/);
  assert.doesNotMatch(development, /production-web|branches:\s*\n\s*- master/);
  assert.doesNotMatch(development, /secrets:\s*inherit/);
  assert.doesNotMatch(production, /\bpush:/);
  assert.match(production, /test "\$SOURCE_REF" = refs\/heads\/master/);
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
    /Apply and verify host-local development protection[\s\S]*?atomic_web_release\.sh" prepare[\s\S]*?Promote prepared physical release with guarded rollback[\s\S]*?atomic_web_release\.sh" promote/,
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

test('Netcup callers do not forward the historical Domenca WAF bypass secret', () => {
  const action = deployAction();
  const production = workflow('release-production.yml');
  const development = workflow('deploy-development.yml');

  // The composite action declares the optional token input and never resolves a
  // secret context itself.
  assert.match(action, /smoke_bypass_token:\s*\{ required: false \}/);
  assert.match(action, /SMOKE_BYPASS_TOKEN:\s*\$\{\{ inputs\.smoke_bypass_token \}\}/);

  // The production smoke step receives the token as an environment variable.
  assert.match(
    action,
    /id: production_smoke[\s\S]*?SMOKE_BYPASS_TOKEN:\s*\$\{\{ inputs\.smoke_bypass_token \}\}[\s\S]*?smoke_production_web\.sh/,
  );

  // The legacy token remains optional inside the action for a future measured
  // Netcup filter, but no caller forwards the Domenca Environment secret.
  for (const caller of [production, development]) {
    assert.match(caller, /smoke_bypass_token:\s*''/);
    assert.doesNotMatch(caller, /secrets\.SMOKE_BYPASS_TOKEN/);
  }

  // The token is never exposed as a plain repository variable or echoed.
  assert.doesNotMatch(action, /vars\.SMOKE_BYPASS_TOKEN/);
  assert.doesNotMatch(action, /echo[^\n]*SMOKE_BYPASS_TOKEN/);
});

test('optional SSH smoke egress remains verified but is disabled on Netcup callers', () => {
  const action = deployAction();

  // Declared optional input, defaulting off.
  assert.match(action, /use_ssh_smoke_egress:\s*\{ required: false, default: false \}/);

  // Opening is gated on the flag and a live (non-stale) deploy, and runs the
  // verified opener; teardown always runs when the flag is on.
  assert.match(
    action,
    /Open verified SSH smoke egress[\s\S]*?inputs\.use_ssh_smoke_egress == 'true'[\s\S]*?open_smoke_ssh_egress\.sh/,
  );
  assert.match(
    action,
    /Close SSH smoke egress[\s\S]*?always\(\)[\s\S]*?inputs\.use_ssh_smoke_egress == 'true'[\s\S]*?close_smoke_ssh_egress\.sh/,
  );
  // The tunnel opens before the smoke steps run.
  assert.ok(
    action.indexOf('open_smoke_ssh_egress.sh') < action.indexOf('smoke_production_web.sh'),
    'the egress tunnel must open before the production smoke',
  );

  // Both Netcup callers disable the old optional remote DNS path.
  for (const name of ['deploy-development.yml', 'release-production.yml']) {
    assert.match(workflow(name), /use_ssh_smoke_egress:\s*false/);
    assert.doesNotMatch(workflow(name), /vars\.USE_SSH_SMOKE_EGRESS/);
  }
});

test('all third-party actions are pinned to immutable commit SHAs', () => {
  for (const name of [
    'pr-validation.yml',
    'deploy-development.yml',
    'release-production.yml',
    'mobile-release.yml',
    'ios-unsigned-build.yml',
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

test('the unsigned iOS build is manual, secret-free and never publishes', () => {
  const unsigned = workflow('ios-unsigned-build.yml');
  const triggers = unsigned.slice(unsigned.indexOf('\non:'), unsigned.indexOf('\npermissions:'));
  assert.match(triggers, /workflow_dispatch:/);
  assert.doesNotMatch(triggers, /\bpush:|pull_request|workflow_run|schedule:/);
  assert.match(unsigned, /permissions:\s*\n\s*contents: read/);
  assert.doesNotMatch(unsigned, /contents: write|secrets\.|environment:|release-action|gh release/);
  assert.match(unsigned, /flutter build ipa --release --no-codesign/);
  assert.match(unsigned, /embedded\.mobileprovision/);
  // Only the master definition runs, before any source is resolved.
  assert.match(unsigned, /\[ "\$EVENT_REF" = refs\/heads\/master \] \|\| fail/);
  assert.ok(unsigned.indexOf('refs/heads/master ] || fail') < unsigned.indexOf('ref="$SOURCE_REF"'));
  // Only release tags or the two integration branches are built.
  assert.match(unsigned, /\^v\[0-9A-Za-z\._-\]\+\$/);
  assert.match(unsigned, /\[ "\$ref" = dev \] \|\| \[ "\$ref" = master \]/);
});

function jobBlock(content, name) {
  const start = content.indexOf(`\n  ${name}:\n`);
  assert.ok(start >= 0, `job ${name} is missing`);
  const rest = content.slice(start + 1);
  const next = rest.slice(1).search(/\n  [a-z][a-z-]*:\n/);
  return next < 0 ? rest : rest.slice(0, next + 1);
}

test('every release tag builds Android and iOS, and iOS is never skipped', () => {
  const mobile = workflow('mobile-release.yml');
  const source = jobBlock(mobile, 'source');
  // A tag push always builds both platforms; the repository variable only
  // chooses between a signed and an explicitly unsigned IPA.
  assert.match(source, /ios_mode=unsigned; \[ "\$IOS_RELEASE_ENABLED" = true \] && ios_mode=signed/);
  assert.match(source, /build_android=true; build_ios=true/);
  assert.doesNotMatch(source, /build_ios=false; \[ "\$IOS_RELEASE_ENABLED"/);
  assert.match(jobBlock(mobile, 'ios'), /if: \$\{\{ needs\.source\.outputs\.ios_mode == 'signed' \}\}/);
  assert.match(jobBlock(mobile, 'ios-unsigned'), /if: \$\{\{ needs\.source\.outputs\.ios_mode == 'unsigned' \}\}/);
  // Publishing from a partial manual run is refused before anything builds.
  assert.match(source, /targets=both, so a published release never lacks a platform/);
});

test('the unsigned release IPA job holds no secrets and no signing environment', () => {
  const job = jobBlock(workflow('mobile-release.yml'), 'ios-unsigned');
  assert.doesNotMatch(job, /secrets\.|environment:|contents: write|release-action|gh release/);
  assert.match(job, /flutter build ipa --release --no-codesign/);
  assert.match(job, /embedded\.mobileprovision/);
  assert.match(job, /"signed":false/);
  assert.match(job, /-unsigned"/);
  assert.match(job, /name: ios-release-\$\{\{ needs\.source\.outputs\.sha \}\}/);
});

test('publishing requires both platforms and verifies the manifest before and after', () => {
  const publish = jobBlock(workflow('mobile-release.yml'), 'publish');
  assert.match(publish, /needs: \[source, android, ios, ios-unsigned\]/);
  assert.match(publish, /needs\.source\.outputs\.build_android == 'true'/);
  assert.match(publish, /needs\.source\.outputs\.build_ios == 'true'/);
  assert.match(publish, /needs\.android\.result == 'success'/);
  assert.match(publish, /needs\.ios\.result == 'success' \|\| needs\.ios-unsigned\.result == 'success'/);
  // A skipped platform job must never be accepted as success.
  assert.doesNotMatch(publish, /result == 'skipped'/);
  assert.ok(publish.indexOf('release_manifest.mjs build') < publish.indexOf('release-action'));
  assert.ok(publish.indexOf('release-action') < publish.indexOf('Verify the published release'));
  assert.match(publish, /gh release download/);
  assert.match(publish, /release_manifest\.mjs verify --dir published/);
});

test('a GitHub Release stays a draft until every asset is uploaded and verified', () => {
  const publish = jobBlock(workflow('mobile-release.yml'), 'publish');
  const at = (needle) => {
    const index = publish.indexOf(needle);
    assert.ok(index >= 0, `publish job lacks: ${needle}`);
    return index;
  };
  // The action creates only a draft and any upload error fails the run.
  const action = publish.slice(at('ncipollo/release-action'), at('Verify the uploaded draft'));
  assert.match(action, /draft: true/);
  assert.match(action, /artifactErrorsFailBuild: true/);
  assert.match(action, /allowUpdates: false/);
  assert.match(action, /replacesArtifacts: false/);
  // immutableCreate would publish inside the action, before verification.
  assert.doesNotMatch(publish, /immutableCreate: true|skipIfReleaseExists: true|omitDraftDuringUpdate: true/);
  // A retry can neither reuse nor overwrite an existing release or draft.
  assert.ok(at('Refuse to reuse an existing release') < at('ncipollo/release-action'));
  assert.match(publish.slice(at('Refuse to reuse an existing release'), at('ncipollo/release-action')), /exit 1/);
  // Order: assemble and verify files, upload draft, verify draft, publish, verify public.
  const order = ['release_manifest.mjs verify --dir dist', 'ncipollo/release-action', 'Verify the uploaded draft', 'draft=false', 'Verify the published release'].map(at);
  assert.deepEqual(order, [...order].sort((a, b) => a - b));
  // The draft's own bytes are checked, not just its file names.
  assert.match(publish.slice(at('Verify the uploaded draft'), at('draft=false')), /sha256sum -c SHA256SUMS[\s\S]*release_manifest\.mjs verify --dir draft-check/);
  // Success is reported only by the final verification step.
  const verify = publish.slice(at('Verify the published release'), at('Withdraw an unverified release'));
  assert.match(verify, /echo 'verified=true'/);
  assert.ok(verify.indexOf("verified=true") > verify.indexOf('release_manifest.mjs verify'));
  assert.doesNotMatch(publish.slice(0, at('Verify the published release')), /### Release .* published/);
  // A failure leaves nothing public: drafts are deleted, public releases returned to draft.
  const withdraw = publish.slice(at('Withdraw an unverified release'));
  assert.match(withdraw, /steps\.precheck\.outcome == 'success'/);
  assert.match(withdraw, /steps\.verify\.outputs\.verified != 'true'/);
  assert.match(withdraw, /-X DELETE/);
  assert.match(withdraw, /-F draft=true/);
  assert.match(withdraw, /exit 1\s*$/);
  // Publication never triggers a web deployment.
  assert.doesNotMatch(workflow('mobile-release.yml'), /release-production|deploy-web-artifact|workflow_run/);
});

// ---- Tiered PR validation (draft tier vs full tier) -------------------------

test('tier: draft PRs into dev get the draft tier, decided by the live PR state', () => {
  const draft = resolveTier({ eventName: 'pull_request', baseRef: 'dev', payloadDraft: true, liveDraft: true });
  assert.equal(draft.tier, 'draft');
  assert.equal(draft.platformBuilds, false);
  assert.match(draft.scope, /draft tier: platform builds not run/);
  const ready = resolveTier({ eventName: 'pull_request', baseRef: 'dev', payloadDraft: false, liveDraft: false });
  assert.equal(ready.tier, 'full');
  assert.equal(ready.platformBuilds, true);
});

test('tier: a stale draft payload on a PR that is now ready runs the full tier', () => {
  const result = resolveTier({ eventName: 'pull_request', baseRef: 'dev', payloadDraft: true, liveDraft: false });
  assert.equal(result.tier, 'full');
});

test('tier: a ready payload on a PR that has since gone back to draft runs the draft tier', () => {
  const result = resolveTier({ eventName: 'pull_request', baseRef: 'dev', payloadDraft: false, liveDraft: true });
  assert.equal(result.tier, 'draft');
});

test('tier: an unreadable live state fails closed to the full tier, whatever the payload says', () => {
  for (const payloadDraft of [true, false, undefined]) {
    for (const liveDraft of [null, undefined, 'maybe']) {
      assert.equal(resolveTier({ eventName: 'pull_request', baseRef: 'dev', payloadDraft, liveDraft }).tier, 'full');
    }
  }
});

test('tier: master PRs and manual runs are always full, draft or not', () => {
  for (const draft of [true, false]) {
    assert.equal(resolveTier({ eventName: 'pull_request', baseRef: 'master', payloadDraft: draft, liveDraft: draft }).tier, 'full');
  }
  assert.equal(resolveTier({ eventName: 'workflow_dispatch', baseRef: '', payloadDraft: undefined, liveDraft: undefined }).tier, 'full');
});

test('tier: any base other than dev fails closed to the full tier, even a draft with a readable state', () => {
  for (const baseRef of ['release/0.8.4', 'feature/x', '', undefined]) {
    const result = resolveTier({ eventName: 'pull_request', baseRef, payloadDraft: true, liveDraft: true });
    assert.equal(result.tier, 'full', `base ${baseRef} must run full`);
  }
  assert.equal(resolveTier({ eventName: 'pull_request', baseRef: 'dev', payloadDraft: true, liveDraft: true }).tier, 'draft');
});

test('tier: the aggregator refuses a draft-tier result for any base other than dev', () => {
  assert.throws(() => assertDraftTierStillValid({ tier: 'draft', baseRef: 'release/0.8.4', liveDraft: true }), /only validate a PR into dev/);
  assert.throws(() => assertDraftTierStillValid({ tier: 'draft', baseRef: undefined, liveDraft: true }), /only validate a PR into dev/);
});

test('aggregate: a missing tier is an error, never treated as full', () => {
  const needs = { flutter_quality: { result: 'success' } };
  assert.throws(() => validateJobResults(needs, ['flutter_quality'], {}), /Unknown validation tier: missing/);
  const script = resolve(dirname(fileURLToPath(import.meta.url)), 'validate_job_results.mjs');
  const run = spawnSync(process.execPath, [script], {
    env: { ...process.env, NEEDS_JSON: JSON.stringify(needs), EXPECTED_JOBS: 'flutter_quality', TIER: '', GITHUB_STEP_SUMMARY: '', GITHUB_OUTPUT: '' },
    encoding: 'utf8',
  });
  assert.notEqual(run.status, 0);
  assert.match(run.stderr, /Unknown validation tier: missing/);
});

test('tier: the aggregator refuses a draft-tier result unless the PR is still confirmed draft into dev', () => {
  assertDraftTierStillValid({ tier: 'draft', baseRef: 'dev', liveDraft: true });
  assertDraftTierStillValid({ tier: 'full', baseRef: 'master', liveDraft: false });
  assert.throws(() => assertDraftTierStillValid({ tier: 'draft', baseRef: 'dev', liveDraft: false }), /ready for review/);
  assert.throws(() => assertDraftTierStillValid({ tier: 'draft', baseRef: 'dev', liveDraft: null }), /could not be confirmed/);
  assert.throws(() => assertDraftTierStillValid({ tier: 'draft', baseRef: 'master', liveDraft: true }), /only validate a PR into dev/);
  assert.throws(() => assertDraftTierStillValid({ tier: 'bogus', baseRef: 'dev', liveDraft: true }), /Unknown validation tier/);
});

test('tier: live draft state is read from the PR API and any failure is reported as unknown', async () => {
  const calls = [];
  const ok = (draft) => async (url, init) => {
    calls.push({ url, init });
    return { ok: true, json: async () => ({ draft }) };
  };
  const args = { repository: 'kubus-project/art.kubus', number: '7', token: 't' };
  assert.equal(await fetchLiveDraft({ ...args, fetchImpl: ok(true) }), true);
  assert.equal(await fetchLiveDraft({ ...args, fetchImpl: ok(false) }), false);
  assert.match(calls[0].url, /\/repos\/kubus-project\/art\.kubus\/pulls\/7$/);
  assert.equal(calls[0].init.headers.Authorization, 'Bearer t');
  assert.equal(await fetchLiveDraft({ ...args, fetchImpl: async () => ({ ok: false, status: 403 }) }), null);
  assert.equal(await fetchLiveDraft({ ...args, fetchImpl: async () => { throw new Error('network'); } }), null);
  assert.equal(await fetchLiveDraft({ ...args, fetchImpl: ok('yes') }), null);
  assert.equal(await fetchLiveDraft({ ...args, token: '', fetchImpl: ok(true) }), null);
});

test('aggregate: draft tier accepts skipped platform jobs but never lets them vouch for a full run', () => {
  const needs = {
    changes: { result: 'success' },
    flutter_quality: { result: 'success' },
    web_artifact: { result: 'skipped' },
    android: { result: 'skipped' },
    ios: { result: 'skipped' },
  };
  const expected = Object.keys(needs);
  validateJobResults(needs, expected, { tier: 'draft' });
  // The same skipped platform jobs are not acceptable when a full run must have executed everything.
  assert.throws(() => validateJobResults(needs, expected, { tier: 'full', fullRun: true }), /android: skipped/);
  // A path-filtered full-tier run on dev may still skip jobs the classifier did not select.
  validateJobResults(needs, expected, { tier: 'full', fullRun: false });
  // Draft tier must not hide a failure.
  assert.throws(() => validateJobResults({ ...needs, flutter_quality: { result: 'failure' } }, expected, { tier: 'draft' }));
  assert.throws(() => validateJobResults(needs, expected, { tier: 'bogus' }), /Unknown validation tier/);
});

test('aggregate: skipped platform jobs are reported as not run by tier in a draft run', () => {
  const needs = {
    flutter_quality: { result: 'success' },
    web_artifact: { result: 'skipped' },
    android: { result: 'skipped' },
    ios: { result: 'skipped' },
    web_routing: { result: 'success' },
  };
  const expected = Object.keys(needs);
  assert.deepEqual(describeSkippedJobs(needs, expected, 'draft'), [
    '- `web_artifact`: not run by tier (draft tier: platform builds and browser smoke not run)',
    '- `android`: not run by tier (draft tier: platform builds and browser smoke not run)',
    '- `ios`: not run by tier (draft tier: platform builds and browser smoke not run)',
  ]);
  // The same skips in a full run are path-classification skips, never reported as tier skips.
  const fullLines = describeSkippedJobs(needs, expected, 'full');
  assert.equal(fullLines.length, 3);
  assert.ok(fullLines.every((line) => line.endsWith('skipped by path classification')));
});

test('PR validation workflow wires the tiers without weakening the required check', () => {
  const content = workflow('pr-validation.yml');
  assert.match(content, /types:\s*\[opened, synchronize, reopened, ready_for_review\]/);
  assert.equal(requiredJobContext('full'), 'PR validation required');
  assert.match(content, /node scripts\/ci\/pr_validation_tier\.mjs/);
  // Concurrency still cancels superseded runs of the same PR.
  assert.match(content, /group:\s*pr-validation-\$\{\{ github\.event\.pull_request\.number \|\| github\.ref_name \}\}\s+cancel-in-progress:\s*true/);
  const job = (name, next) => content.slice(content.indexOf(`\n  ${name}:`), next ? content.indexOf(`\n  ${next}:`) : undefined);
  for (const [name, next] of [['web_artifact', 'backend_contract'], ['android', 'ios'], ['ios', 'web_routing']]) {
    assert.match(job(name, next), /needs\.changes\.outputs\.tier == 'full'/, `${name} must be gated on the full tier`);
  }
  // The cheap real signals stay in the draft tier.
  for (const [name, next] of [['guardrails', 'documentation'], ['documentation', 'flutter_quality'], ['backend_contract', 'android'], ['web_routing', 'required']]) {
    assert.doesNotMatch(job(name, next), /outputs\.tier/, `${name} must run in the draft tier`);
  }
  const flutter = job('flutter_quality', 'map_browser_regression');
  assert.doesNotMatch(flutter.slice(0, flutter.indexOf('steps:')), /outputs\.tier/);
  assert.match(flutter, /flutter analyze --fatal-infos --fatal-warnings/);
  assert.match(flutter, /flutter test --coverage; else flutter test/);
  for (const step of [
    'PRODUCT motion acceptance',
    'Community feature flag contracts in both configurations',
  ]) {
    const at = flutter.indexOf(`- name: ${step}`);
    assert.ok(at > 0, `${step} step exists`);
    assert.match(flutter.slice(at, at + 220), /if:\s*\$\{\{ needs\.changes\.outputs\.tier == 'full' \}\}/, `${step} must be full-tier only`);
  }
  assert.doesNotMatch(flutter, /map_screen_web_smoke_test/, 'the Chrome widget test must not share the 60-minute flutter_quality budget');
  // The browser widget test is its own full-tier job with its own budget, and the aggregate requires it.
  const mapBrowser = job('map_browser_regression', 'web_artifact');
  assert.match(mapBrowser.slice(0, mapBrowser.indexOf('steps:')), /needs\.changes\.outputs\.tier == 'full'/, 'map_browser_regression must be full-tier only');
  assert.match(mapBrowser, /timeout-minutes:\s*45/);
  assert.match(mapBrowser, /playwright install --with-deps chromium/);
  assert.match(mapBrowser, /CHROME_EXECUTABLE=.*chromium\.executablePath\(\)/);
  assert.match(mapBrowser, /flutter test --platform chrome --reporter expanded --concurrency=1 test\/map\/map_screen_web_smoke_test\.dart/);
  assert.doesNotMatch(mapBrowser, /--ignore-timeouts/, 'a suite-load failure must fail in minutes, not wait for the job limit');
  const controlAt = mapBrowser.indexOf('- name: Browser harness positive control');
  const mapStepAt = mapBrowser.indexOf('- name: Mounted map fallback revocation in Chrome');
  assert.ok(controlAt > 0 && controlAt < mapStepAt, 'the browser harness positive control runs before the map test');
  assert.match(mapBrowser.slice(controlAt, mapStepAt), /test\/web\/basic_browser_smoke_test\.dart[\s\S]*All tests passed/);
  assert.match(mapBrowser.slice(controlAt, mapStepAt), /test\/widgets\/map\/glass\/kubus_map_platform_backdrop_mount_browser_test\.dart/);
  assert.match(content.slice(content.indexOf('\n  required:')), /^\s+- map_browser_regression$/m, 'the required aggregate must need map_browser_regression');
  assert.match(content, /EXPECTED_JOBS:[^\n]*map_browser_regression/);
  const required = content.slice(content.indexOf('\n  required:'));
  assert.match(required, /pull-requests:\s*read/);
  assert.match(required, /TIER:\s*\$\{\{ needs\.changes\.outputs\.tier \}\}/);
  assert.match(required, /FULL_RUN:\s*\$\{\{ needs\.changes\.outputs\.full \}\}/);
  assert.match(required, /tier: \$\{\{ steps\.aggregate\.outputs\.tier \}\}/);
});

// ---- Draft results can never satisfy the required check ---------------------

// The check context a run reports under, given the PR situation: the tier is resolved exactly as
// the `changes` job does, then mapped through the workflow's own `required` job name expression.
const contextFor = (situation) => requiredJobContext(resolveTier(situation).tier);
const dev = { eventName: 'pull_request', baseRef: 'dev' };

test('context: a draft PR into dev reports under the non-required draft context', () => {
  const context = contextFor({ ...dev, payloadDraft: true, liveDraft: true });
  assert.equal(context, DRAFT_CHECK_CONTEXT);
  assert.notEqual(context, REQUIRED_CHECK_CONTEXT);
  assert.equal(context, checkContextForTier('draft'));
});

test('context: draft to ready on the same SHA moves the result to the required context', () => {
  // First run: opened as a draft. The result lands on the draft context only, so the required
  // context has no result at all for this SHA and cannot be satisfied by it.
  assert.equal(contextFor({ ...dev, payloadDraft: true, liveDraft: true }), DRAFT_CHECK_CONTEXT);
  // ready_for_review on the same head: the payload and the live state both say ready.
  assert.equal(contextFor({ ...dev, payloadDraft: false, liveDraft: false }), REQUIRED_CHECK_CONTEXT);
  // A stale draft payload that races the transition still resolves from the live state.
  assert.equal(contextFor({ ...dev, payloadDraft: true, liveDraft: false }), REQUIRED_CHECK_CONTEXT);
});

test('context: ready PRs into dev and every PR into master report under the required context', () => {
  assert.equal(contextFor({ ...dev, payloadDraft: false, liveDraft: false }), REQUIRED_CHECK_CONTEXT);
  for (const draft of [true, false]) {
    assert.equal(contextFor({ eventName: 'pull_request', baseRef: 'master', payloadDraft: draft, liveDraft: draft }), REQUIRED_CHECK_CONTEXT);
  }
  assert.equal(contextFor({ eventName: 'workflow_dispatch', baseRef: '' }), REQUIRED_CHECK_CONTEXT);
});

test('context: a missing or unreadable tier fails closed onto the required context', () => {
  for (const liveDraft of [null, undefined, 'maybe']) {
    assert.equal(contextFor({ ...dev, payloadDraft: true, liveDraft }), REQUIRED_CHECK_CONTEXT);
  }
  // The tier output itself missing (the `changes` job failed or was skipped) is not 'draft'.
  for (const tier of ['', undefined, null, 'bogus', 'Draft']) {
    assert.equal(requiredJobContext(tier), REQUIRED_CHECK_CONTEXT);
    assert.equal(checkContextForTier(tier), REQUIRED_CHECK_CONTEXT);
  }
  // ...and the aggregator then rejects it rather than reporting success there.
  assert.throws(() => validateJobResults({ changes: { result: 'success' } }, ['changes'], { tier: '' }), /Unknown validation tier: missing/);
  assert.throws(() => validateJobResults({ changes: { result: 'success' } }, ['changes'], { tier: undefined }), /Unknown validation tier: missing/);
});

test('context: failed, cancelled and missing jobs are never accepted in either tier', () => {
  for (const tier of ['draft', 'full']) {
    for (const fullRun of [false, true]) {
      for (const result of ['failure', 'cancelled', undefined]) {
        const needs = { guardrails: { result: 'success' }, flutter_quality: { result } };
        assert.throws(
          () => validateJobResults(needs, ['guardrails', 'flutter_quality'], { tier, fullRun }),
          /Required job results were not acceptable: flutter_quality/,
          `${tier}/${fullRun}/${result}`,
        );
      }
    }
  }
  assert.throws(() => validateJobResults({ guardrails: { result: 'success' } }, ['guardrails', 'flutter_quality'], { tier: 'full' }), /flutter_quality: missing/);
});

test('context: the aggregator step fails the job for a missing tier or a cancelled dependency', () => {
  const script = resolve(dirname(fileURLToPath(import.meta.url)), 'validate_job_results.mjs');
  const run = (needs, tier) => spawnSync(process.execPath, [script], {
    env: { ...process.env, NEEDS_JSON: JSON.stringify(needs), EXPECTED_JOBS: 'guardrails', TIER: tier, FULL_RUN: 'false', GITHUB_STEP_SUMMARY: '', GITHUB_OUTPUT: '' },
    encoding: 'utf8',
  });
  assert.equal(run({ guardrails: { result: 'success' } }, 'full').status, 0);
  assert.notEqual(run({ guardrails: { result: 'success' } }, '').status, 0);
  assert.notEqual(run({ guardrails: { result: 'cancelled' } }, 'full').status, 0);
  assert.notEqual(run({ guardrails: { result: 'failure' } }, 'draft').status, 0);
});

test('context: the workflow reserves the required name for non-draft tiers and nothing else uses it', () => {
  const content = workflow('pr-validation.yml');
  assert.equal(requiredJobContext('draft'), DRAFT_CHECK_CONTEXT);
  assert.notEqual(DRAFT_CHECK_CONTEXT, REQUIRED_CHECK_CONTEXT);
  assert.ok(!DRAFT_CHECK_CONTEXT.startsWith(REQUIRED_CHECK_CONTEXT), 'a prefix match must not let the draft context pass for the required one');
  // No other job may be named like the required context, or a draft run could still publish it.
  const names = [...content.matchAll(/\n    name: (.+)/g)].map((m) => m[1]);
  assert.equal(names.filter((name) => name.includes(REQUIRED_CHECK_CONTEXT)).length, 1, 'exactly one job may carry the required name');
  // The aggregate must run even when its dependencies fail, so the context always resolves.
  const required = content.slice(content.indexOf('\n  required:'));
  assert.match(required, /if:\s*\$\{\{ always\(\) \}\}/);
});

// ---- Browser-test module names ----------------------------------------------

// flutter_tools 3.44.2 flutter_web_platform.dart:391 (_handleStaticArtifact) answers any URL containing
// `host.dart.js` with the harness bundle, so a compiled `*host.dart` library never loads and the browser
// suite stalls at "loading" (see the W6-A bisect). Keep every lib/ and test/ file off that suffix.
test('browser test modules never end in host.dart (flutter_tools serves host.dart.js from the harness)', () => {
  const offenders = [];
  const walk = (directory) => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (/host\.dart$/.test(entry.name)) offenders.push(path.slice(repositoryRoot.length + 1));
    }
  };
  walk(resolve(repositoryRoot, 'lib'));
  walk(resolve(repositoryRoot, 'test'));
  assert.deepEqual(offenders, [], 'rename these to *mount.dart or similar; a *host.dart module never loads in a browser test');
});
