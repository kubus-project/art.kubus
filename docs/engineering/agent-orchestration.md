# Agent orchestration

How AI agents (and people driving them) split, run and close out multi-part
engineering work in the kubus repositories. It is the canonical detail behind
the short "Multi-agent orchestration" sections in `CLAUDE.md` and `AGENTS.md`
of `art.kubus`, `art.kubus-backend` and `admin.kubus`. Branching, CI and
deployment rules stay in
[`branching-and-deployment.md`](branching-and-deployment.md); this file only
adds how work is divided and verified.

Sections marked **Claude Code** describe one harness. Everything else is
model-independent and applies to any agent.

## 1. Coordinator

One agent is the **coordinator** for a programme. It alone:

- owns the plan, the cross-repository integration and the final judgement;
- decides architecture, security-sensitive changes, SQL and schema design,
  state-management bugs that cross components, and merge-conflict resolution;
- merges, deploys, resolves review threads and declares release readiness.

Specialists never merge, deploy, change HA or replication state, resolve a
thread, or publish. A second coordinator on the same programme is a defect:
reconcile the sessions first (section 12), then continue as one.

## 2. Specialists and model routing

Delegate **bounded, independent** work with a concrete deliverable: focused
searches, diff reviews, mechanical edits, targeted tests, CI and log summaries,
documentation checks, screenshot inspection, read-only diagnostics.

Keep with the coordinator: nontrivial design, anything security-sensitive,
complex SQL, production decisions, final acceptance.

**Claude Code:** the coordinator runs the strongest model that the task needs
(Sonnet by default); specialists run a small fast model (Haiku, requested
explicitly with `model: haiku`). Confirm the model a worker actually resolved
to and report any deviation; never substitute an expensive model for every
delegated task, and do not escalate to the largest model automatically.
Escalate only when a specialist returns an inconclusive result twice on the
same question, or the question turns out to be a design decision.

Typical roles (define a role only when it recurs):

| Role | Typical work | Writes? |
|---|---|---|
| Flutter UI / design-system | canonical widgets, dialogs, theme parity, focused widget tests | read-only unless a file is assigned |
| Backend / PostgreSQL / API | query review, disposable-DB tests, schema parity, contract checks | disposable data only |
| Admin / Support | Vue tests, CSRF/session contract, draft preservation | read-only |
| CI / release | PR heads, threads, checks, SHAs, artifact hashes, build logs | read-only |
| Map / media / browser QA | zoom sequences, video geometry, Chromium and Firefox runs | evidence files only |
| Infrastructure | replication, WAL, IPFS, resource pressure | read-only |

## 3. Skills

Use the narrowest existing skill for the job (`/flutter-test`, `/backend-test`,
`/vue-check`, `/verify`, the design-system and visual-QA skills) and read the
skill before relying on it. Do not invent skill names. A worker prompt names
the skill it should use; it does not paste the skill.

## 4. Decomposition and parallelism

Split by independent surface (repository, file set, environment), not by
activity. Two to three concurrent workers is the normal ceiling; add one only
when its output is independent and its cost is justified. Do not spawn a worker
for work that takes one or two tool calls. Never spawn merely to raise
concurrency.

## 5. Ownership and worktrees

Before delegating, write down: role, model, repository, **starting SHA**,
read-only or writable, **exact files owned**, tests to run, expected output and
the completion condition.

- A writable task has exclusive ownership of its files and, when two writers
  coexist, its own git worktree. Writers never share a worktree or a branch.
- Read-only workers may share a worktree but must not run commands that mutate
  it (formatters, `pub get` in a shared tree, test runs that rewrite fixtures).
- Do not delete, reset or overwrite uncommitted work you did not create.
  Worktrees found on disk are somebody's state until proven otherwise.

## 6. Preflight (every session, every repository)

1. `git fetch`, then compare remote heads with any SHA quoted in a brief.
   Briefs go stale; the remote is the truth.
2. `git worktree list`, `git status` in each worktree you will touch, and open
   PRs with their head SHAs and unresolved threads.
3. Check for peer sessions on the same branch (**Claude Code:** `ListAgents`),
   and for recent pushes or reflog entries you did not make. A peer that wakes
   can commit from your worktree.
4. Read the repository's `AGENTS.md`, nested files for the area, and the
   branching guide. Current explicit owner instructions outrank historical
   plans but never bypass security or protected-branch rules.

## 7. Worker lifecycle

- A worker returns once, with the handoff format in section 11.
- Five minutes of inactivity is a **checkpoint** for reassessment, not an
  expiry. Do not send keepalive messages, do not restart a worker merely
  because time passed, and do not kill running builds or tests on an idle-time
  assumption.
- When a worker is needed again: **resume** it if its context is still useful
  (**Claude Code:** `SendMessage` to its id); otherwise start a **fresh** one
  with a short checkpoint (current SHA, findings so far, next action, evidence
  paths) instead of the whole original prompt.
- Retire a worker as soon as it has nothing useful left to do.

## 8. Context and cost discipline

Cost is total tokens across all agents, not the coordinator's alone.

- Search and read narrowly: `rg`, `git diff`, `git show`, line ranges. Do not
  re-read large files or re-run the same tool call.
- Workers send summaries, not logs. Detailed evidence goes to disk, and the
  handoff carries the path.
- Do not repeat finished audits, and do not paste the full programme prompt
  into worker prompts. Short, stable instructions cache better.
- Test progressively: the changed behaviour first, then the module, then the
  analyzer or linter, then required CI, then integrated browser QA. Avoid a
  full mobile build after every small edit.
- Reuse immutable evidence (a build, a screenshot set, a plan) while its source
  SHA and configuration are unchanged. Never skip a required final gate to save
  cost, and never claim a saving that was not measured: report the measures
  applied, plus real metrics when the harness provides them.

## 9. Testing standards

- A passing analyzer is not visual verification. UI changes need inspected
  screenshots or frame sequences at representative widths, themes and locales.
- A regression test must be able to fail for the bug it names. If proving that
  would mean temporarily weakening a guard in the working tree, prove it by
  reading the assertion against the code path and say that the red run was not
  executed; the permission layer may deny the mutation.
- Evidence states its type: live, byte-identical artifact, or local build.

## 10. Merge, deployment and authority

- The coordinator merges after review threads are resolved by actual fixes and
  required CI is green on the exact head. Merges that need explicit owner
  approval wait for it; a denied operation is reported with the exact owner
  action required, never retried through another route.
- Deploy from an exact merged SHA, back up first, keep a rollback artifact,
  and verify the **running** system (revision header, health endpoints, asset
  hashes). A deployment is not claimed from a green pipeline alone.
- Report statuses separately: **implemented, merged, deployed, tested, owner
  accepted, released.** The last two are never inferred.
- Secrets: never request passwords, tokens or mnemonics in chat; never print
  environment values; never write secrets, session cookies, private keys or
  production dumps into docs, memory or evidence. Cut values when inspecting
  environment files.

## 11. Handoff format

Worker reports, 150-400 words (under 150 for simple verification):

```
TASK:
MODEL:
SKILL:
START SHA:
STATUS:
FILES INSPECTED:
FILES MODIFIED:
TESTS:
FINDINGS:
EVIDENCE:
NEXT ACTION:
BLOCKER:
```

Checkpoints between sessions record: branch and head SHAs, open PRs, what is
merged / deployed / tested, what is blocked on whom, the traps found. Volatile
release state belongs in a short handoff file, not in permanent guidance.

## 12. Reconciling parallel sessions

When two sessions did overlapping work: name one coordinator, inventory both
sets of branches and PRs, keep completed work, close duplicates unmerged with a
pointer to the surviving PR, and integrate once. Do not recreate a closed PR's
implementation; inspect its diff only when evidence shows behaviour missing
from the survivor.

## 13. Claude Code specifics

- Project agent definitions live in `.claude/agents/`; define one only when a
  role recurs. Keep tools minimal and say read-only versus writable.
- Project memory (`~/.claude/projects/<workspace>/memory/`) holds durable
  decisions and recurring traps. Keep transient release state in a checkpoint
  note and correct or delete entries that turn out wrong.
- Do not enable experimental agent-team features by default.

## 14. Final acceptance

A programme is ready for owner review only when: every review finding is fixed
and its thread resolved with the fixing SHA; required CI is green on the exact
heads; the running systems report the intended revisions; the user-visible
behaviours were exercised and inspected; documentation and instructions match
the accepted implementation; and the report lists what remains blocked, with
the owner action each blocker needs.
