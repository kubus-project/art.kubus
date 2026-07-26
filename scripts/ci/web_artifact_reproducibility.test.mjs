import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  deterministicWebBuildNumber,
  resolveBuildMetadata,
  resolveWebBuildMetadata,
} from '../resolve_ci_build_metadata.mjs';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const workflowPath = resolve(repositoryRoot, '.github/workflows/web-artifact.yml');

const sourceSha = '9cf05975ab6af6a0f8a5f4eb4f3db30c70828d72';
const sourceDate = '2026-07-25';

test('web metadata is deterministic for an immutable source revision', () => {
  const first = resolveWebBuildMetadata({
    version: '0.7.1',
    buildDate: sourceDate,
    sourceSha,
  });
  const second = resolveWebBuildMetadata({
    version: '0.7.1',
    buildDate: sourceDate,
    sourceSha,
  });

  assert.deepEqual(first, second);
  assert.equal(first.buildNumber, deterministicWebBuildNumber(sourceSha));
  assert.ok(first.buildNumber > 0);
  assert.ok(first.buildNumber < 2100000000);
});

test('web metadata changes with source identity but not CI run identity', () => {
  const sameSource = resolveWebBuildMetadata({
    version: '0.7.1',
    buildDate: sourceDate,
    sourceSha,
  });
  const otherSource = resolveWebBuildMetadata({
    version: '0.7.1',
    buildDate: sourceDate,
    sourceSha: '8cf05975ab6af6a0f8a5f4eb4f3db30c70828d72',
  });

  assert.notEqual(sameSource.buildNumber, otherSource.buildNumber);
  assert.throws(
    () => resolveWebBuildMetadata({ version: '0.7.1', buildDate: sourceDate, sourceSha: 'not-a-sha' }),
    /full lowercase commit SHA/,
  );
});

test('mobile metadata retains its monotonic run-number contract', () => {
  const first = resolveBuildMetadata({ version: '0.7.1', buildDate: sourceDate, runNumber: 1 });
  const second = resolveBuildMetadata({ version: '0.7.1', buildDate: sourceDate, runNumber: 2 });
  assert.equal(second.buildNumber, first.buildNumber + 1);
});

test('web artifact workflow derives all volatile inputs from the source commit', () => {
  const workflow = readFileSync(workflowPath, 'utf8');

  assert.match(workflow, /Resolve deterministic web build metadata/);
  assert.match(workflow, /git show -s --format=%cs "\$SOURCE_SHA"/);
  assert.match(workflow, /git show -s --format=%ct "\$SOURCE_SHA"/);
  assert.match(workflow, /SOURCE_DATE_EPOCH=\$source_epoch/);
  assert.match(workflow, /--mode web/);
  assert.match(workflow, /--source-sha "\$SOURCE_SHA"/);
  assert.match(workflow, /--build-date "\$build_date"/);
  assert.doesNotMatch(workflow, /GITHUB_RUN_NUMBER/);
  assert.match(workflow, /gzip -n -kf6 "\$file"/);
});
