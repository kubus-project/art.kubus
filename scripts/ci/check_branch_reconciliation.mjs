#!/usr/bin/env node
// Guards against unreconciled release ancestry: after a `dev -> master` release
// merge, the resulting merge commit must be reconciled back into `dev`. If it is
// not, `master` accumulates commits that are not ancestors of `dev` and the two
// protected branches diverge. This check treats any nonzero "commits only on
// the base branch" count as requiring reconciliation before ordinary work.
//
// The count uses `--cherry-pick`, so a hotfix reconciled into `dev` by
// cherry-pick (a patch-equivalent commit with a different SHA) is treated as
// reconciled and does not keep the guard red. Genuine unreconciled ancestry
// (a release merge that never returned to `dev`) still counts.
//
// See docs/engineering/branching-and-deployment.md ("Post-release reconciliation").
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const DEFAULT_BASE_REF = 'origin/master';
const DEFAULT_HEAD_REF = 'origin/dev';

/**
 * Turn a `git rev-list --left-right --count <base>...<head>` result into a
 * reconciliation verdict. `behind` is the number of commits reachable from the
 * base (master) but not the head (dev) — the commits that still need to be
 * reconciled into the head.
 *
 * @param {{behind:number, ahead:number, baseRef?:string, headRef?:string}} input
 */
export function evaluateReconciliation({
  behind,
  ahead,
  baseRef = DEFAULT_BASE_REF,
  headRef = DEFAULT_HEAD_REF,
}) {
  for (const [label, value] of [['behind', behind], ['ahead', ahead]]) {
    if (!Number.isInteger(value) || value < 0) {
      throw new Error(`reconciliation ${label} count must be a non-negative integer`);
    }
  }
  const reconciled = behind === 0;
  const message = reconciled
    ? `OK: ${headRef} is 0 behind and ${ahead} ahead of ${baseRef}; release ancestry is reconciled.`
    : `${baseRef} has ${behind} commit(s) not reconciled into ${headRef}. Merge the release `
      + `merge commit back into ${headRef} with a merge commit (no squash, no rebase) before `
      + 'continuing ordinary development.';
  return { reconciled, behind, ahead, message };
}

/**
 * Read the left/right divergence counts between two refs. `run` is injectable
 * so the parsing contract can be exercised without a live repository.
 */
export function countLeftRight(baseRef, headRef, run = defaultRun) {
  const raw = run('git', ['rev-list', '--left-right', '--cherry-pick', '--count', `${baseRef}...${headRef}`]);
  const parts = String(raw).trim().split(/\s+/);
  if (parts.length !== 2) {
    throw new Error(`unexpected rev-list output: ${JSON.stringify(raw)}`);
  }
  const [behind, ahead] = parts.map((value) => Number.parseInt(value, 10));
  return { behind, ahead };
}

function defaultRun(command, args) {
  return execFileSync(command, args, { encoding: 'utf8' });
}

function main() {
  const baseRef = process.env.RECONCILE_BASE_REF || DEFAULT_BASE_REF;
  const headRef = process.env.RECONCILE_HEAD_REF || DEFAULT_HEAD_REF;
  const { behind, ahead } = countLeftRight(baseRef, headRef);
  const result = evaluateReconciliation({ behind, ahead, baseRef, headRef });
  if (!result.reconciled) {
    console.error(result.message);
    process.exit(1);
  }
  console.log(result.message);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
