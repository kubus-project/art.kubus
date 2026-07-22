import assert from 'node:assert/strict';
import test from 'node:test';

import { countLeftRight, evaluateReconciliation } from './check_branch_reconciliation.mjs';

test('reconciled when no commits are unique to the base branch', () => {
  const result = evaluateReconciliation({ behind: 0, ahead: 12 });
  assert.equal(result.reconciled, true);
  assert.match(result.message, /0 behind and 12 ahead/);
  assert.match(result.message, /reconciled/);
});

test('unreconciled when the base branch has commits absent from the head', () => {
  const result = evaluateReconciliation({ behind: 6, ahead: 11 });
  assert.equal(result.reconciled, false);
  assert.match(result.message, /6 commit\(s\) not reconciled/);
  assert.match(result.message, /merge commit \(no squash, no rebase\)/);
});

test('custom ref labels surface in the guidance', () => {
  const result = evaluateReconciliation({
    behind: 1,
    ahead: 0,
    baseRef: 'origin/production',
    headRef: 'origin/main',
  });
  assert.match(result.message, /origin\/production has 1 commit\(s\)/);
  assert.match(result.message, /into origin\/main/);
});

test('rejects malformed divergence counts', () => {
  assert.throws(() => evaluateReconciliation({ behind: -1, ahead: 0 }));
  assert.throws(() => evaluateReconciliation({ behind: 1.5, ahead: 0 }));
  assert.throws(() => evaluateReconciliation({ behind: 0, ahead: Number.NaN }));
});

test('countLeftRight parses git rev-list --left-right --count output', () => {
  const fakeRun = (command, args) => {
    assert.equal(command, 'git');
    assert.deepEqual(args, ['rev-list', '--left-right', '--count', 'origin/master...origin/dev']);
    return '6\t11\n';
  };
  assert.deepEqual(countLeftRight('origin/master', 'origin/dev', fakeRun), { behind: 6, ahead: 11 });
});

test('countLeftRight rejects unexpected output shape', () => {
  assert.throws(() => countLeftRight('a', 'b', () => 'not-two-numbers'));
});
