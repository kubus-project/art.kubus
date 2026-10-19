#!/usr/bin/env node
import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Pull-request validation tiers.
//
// draft: an inexpensive tier for draft PRs into dev. It keeps guardrails, path
//        classification, docs checks, analyzer/format/lint, the Flutter unit
//        tests, backend compatibility and the Apache routing contract, and skips
//        the Android build, the iOS build, the release web build with browser
//        smoke and the real-browser PRODUCT motion gate.
// full:  everything the path classifier selects, exactly as before the tiers.
//
// A draft-tier result is never merge evidence. See docs/engineering/branching-and-deployment.md.

// Check-run contexts the aggregate job reports under. Branch protection requires only
// REQUIRED_CHECK_CONTEXT, which a draft-tier run must never produce. These strings are mirrored in
// the `required` job name expression of pr-validation.yml; workflow_contracts.test.mjs keeps them
// identical.
export const REQUIRED_CHECK_CONTEXT = 'PR validation required';
export const DRAFT_CHECK_CONTEXT = 'PR validation (draft tier, not merge evidence)';

// Only an explicit draft tier selects the draft context; anything else (full, missing, unknown)
// reports under the required context, where the aggregator then accepts or rejects it.
export function checkContextForTier(tier) {
  return tier === 'draft' ? DRAFT_CHECK_CONTEXT : REQUIRED_CHECK_CONTEXT;
}

export const DRAFT_SCOPE = 'draft tier: platform builds not run';
export const FULL_SCOPE = 'full tier: every selected job ran';

// Normalises a draft flag from a JSON boolean or its string form. Anything else is unknown.
export function parseDraft(value) {
  if (value === true || value === 'true') return true;
  if (value === false || value === 'false') return false;
  return null;
}

// The live PR state (read from the API when the run starts) is authoritative. The event
// payload only records what was true when the event fired, so a stale payload can neither
// downgrade a PR that has since become ready nor upgrade one that went back to draft.
// When the live state cannot be read the decision fails closed to the full tier.
export function resolveTier({ eventName, baseRef, payloadDraft, liveDraft }) {
  const payload = parseDraft(payloadDraft);
  const live = parseDraft(liveDraft);
  const full = (reason) => ({ tier: 'full', platformBuilds: true, scope: FULL_SCOPE, reason });
  if (eventName !== 'pull_request') return full('not a pull_request event');
  if (baseRef === 'master') return full('PRs into master are release candidates and always run the full tier');
  // Only dev is eligible for the draft tier; any other base fails closed.
  if (baseRef !== 'dev') return full(`PR base ${baseRef || 'unknown'} is not dev, failing closed to the full tier`);
  if (live === null) return full('live draft state unreadable, failing closed to the full tier');
  if (live === false) {
    return full(payload === true ? 'event payload said draft but the PR is now ready for review' : 'PR is ready for review');
  }
  return {
    tier: 'draft',
    platformBuilds: false,
    scope: DRAFT_SCOPE,
    reason: payload === false ? 'event payload said ready but the PR is back in draft' : 'PR is a draft',
  };
}

// Run by the aggregator after all jobs finished: a draft-tier result may only stand while the
// PR is still confirmed to be a draft into dev.
export function assertDraftTierStillValid({ tier, baseRef, liveDraft }) {
  if (tier === 'full') return;
  if (tier !== 'draft') throw new Error(`Unknown validation tier: ${tier || 'missing'}`);
  if (baseRef !== 'dev') throw new Error(`A draft-tier result can only validate a PR into dev, not ${baseRef || 'an unknown base'}.`);
  const live = parseDraft(liveDraft);
  if (live === null) throw new Error('The draft-tier result could not be confirmed: the PR draft state is unreadable.');
  if (live === false) {
    throw new Error('The PR is now ready for review; a draft-tier result is not merge evidence. The ready_for_review run (or a new push) provides the full-tier verdict.');
  }
}

// Returns true, false, or null when the state cannot be established.
export async function fetchLiveDraft({ repository, number, token, fetchImpl = globalThis.fetch, timeoutMs = 15000 }) {
  if (!repository || !number || !token || typeof fetchImpl !== 'function') return null;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(`https://api.github.com/repos/${repository}/pulls/${number}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      signal: controller.signal,
    });
    if (!response?.ok) return null;
    const body = await response.json();
    return typeof body?.draft === 'boolean' ? body.draft : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export function appendOutput(file, values) {
  if (!file) return;
  appendFileSync(file, Object.entries(values).map(([key, value]) => `${key}=${value}\n`).join(''));
}

export function appendSummary(file, lines) {
  if (!file) return;
  appendFileSync(file, `${lines.join('\n')}\n`);
}

async function main() {
  const env = process.env;
  const liveDraft = env.EVENT_NAME === 'pull_request'
    ? await fetchLiveDraft({ repository: env.REPOSITORY, number: env.PR_NUMBER, token: env.GH_TOKEN })
    : undefined;
  const result = resolveTier({
    eventName: env.EVENT_NAME,
    baseRef: env.BASE_REF,
    payloadDraft: env.PAYLOAD_DRAFT,
    liveDraft,
  });
  appendOutput(env.GITHUB_OUTPUT, { tier: result.tier, platform_builds: result.platformBuilds, scope: result.scope });
  appendSummary(env.GITHUB_STEP_SUMMARY, [
    '### Validation tier',
    `- Tier: **${result.tier}** (${result.scope})`,
    `- Reason: ${result.reason}`,
    `- Event payload draft: ${env.PAYLOAD_DRAFT || 'n/a'}; live draft: ${liveDraft ?? 'unknown'}`,
  ]);
  process.stdout.write(`Validation tier: ${result.tier} (${result.reason}).\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
