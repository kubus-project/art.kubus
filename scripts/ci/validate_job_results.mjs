#!/usr/bin/env node
import { pathToFileURL } from 'node:url';

import {
  DRAFT_SCOPE,
  FULL_SCOPE,
  appendOutput,
  appendSummary,
  assertDraftTierStillValid,
  fetchLiveDraft,
} from './pr_validation_tier.mjs';

// Jobs the draft tier never runs by design (job-level tier gate in pr-validation.yml).
export const TIER_GATED_JOBS = ['web_artifact', 'android', 'ios'];

// One summary line per skipped job, so a skip is visibly "not run by tier" rather than a pass.
export function describeSkippedJobs(needs, expectedJobs, tier) {
  return expectedJobs
    .filter((job) => needs[job]?.result === 'skipped')
    .map((job) => {
      const reason = tier === 'draft' && TIER_GATED_JOBS.includes(job)
        ? 'not run by tier (draft tier: platform builds and browser smoke not run)'
        : 'skipped by path classification';
      return `- \`${job}\`: ${reason}`;
    });
}

// `tier` is the validation tier the run executed. `fullRun` means the run was meant to execute
// every job (master PRs and manual runs): there a skipped job is not proof of anything, so every
// declared job must have succeeded. Otherwise a skip is legitimate (path filter or draft tier).
export function validateJobResults(needs, expectedJobs, { tier = 'full', fullRun = false } = {}) {
  if (tier !== 'full' && tier !== 'draft') throw new Error(`Unknown validation tier: ${tier || 'missing'}`);
  const requireExecution = tier === 'full' && fullRun;
  const failures = [];
  for (const job of expectedJobs) {
    if (!Object.hasOwn(needs, job)) {
      failures.push(`${job}: missing`);
      continue;
    }
    const result = needs[job]?.result;
    if (result === 'success' || (result === 'skipped' && !requireExecution)) continue;
    failures.push(`${job}: ${result || 'missing result'}`);
  }
  if (failures.length) throw new Error(`Required job results were not acceptable: ${failures.join(', ')}`);
}

async function main() {
  const env = process.env;
  const needs = JSON.parse(env.NEEDS_JSON || '{}');
  const expected = (env.EXPECTED_JOBS || '').split(',').map((value) => value.trim()).filter(Boolean);
  const tier = env.TIER || 'full';
  const fullRun = env.FULL_RUN === 'true';
  const scope = tier === 'draft' ? DRAFT_SCOPE : FULL_SCOPE;
  try {
    validateJobResults(needs, expected, { tier, fullRun });
    if (tier === 'draft') {
      // Re-read the live PR state: the result may only stand while the PR is still a draft.
      const liveDraft = await fetchLiveDraft({ repository: env.REPOSITORY, number: env.PR_NUMBER, token: env.GH_TOKEN });
      assertDraftTierStillValid({ tier, baseRef: env.BASE_REF, liveDraft });
    }
  } catch (error) {
    appendSummary(env.GITHUB_STEP_SUMMARY, ['### PR validation required', `- Tier: **${tier}** (${scope})`, `- Verdict: **not accepted** - ${error.message}`]);
    throw error;
  }
  appendOutput(env.GITHUB_OUTPUT, { tier, scope });
  appendSummary(env.GITHUB_STEP_SUMMARY, [
    '### PR validation required',
    `- Tier: **${tier}** (${scope})`,
    ...describeSkippedJobs(needs, expected, tier),
    tier === 'draft'
      ? '- Verdict: draft-tier checks passed. This is NOT merge evidence: Android, iOS, the release web build and browser smoke did not run. Marking the PR ready for review runs the full tier on the same head.'
      : '- Verdict: every declared job succeeded or was legitimately skipped by path classification.',
  ]);
  process.stdout.write(`Aggregate accepted ${expected.length} declared job results (${scope}).\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
