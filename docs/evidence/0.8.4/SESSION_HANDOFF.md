# 0.8.4 session handoff

Read this first when resuming. Detailed state: [integration-ledger.md](integration-ledger.md)
and [scope-matrix.md](scope-matrix.md). Security findings are never written here; they
live in the private draft advisory and `C:/kubus-build/_private/security/`.

```text
DATE: 2026-10-19 (session art-kubus-87, Opus coordinator, Haiku-first brief)
CURRENT PHASE: Milestone 1 (security #315 + backend #94) closing; CI tier #322 open
DEV SHA: 2190782e   MASTER SHA: 841d92a3   (unchanged since 2026-10-18)
OPEN PRS (this program): #315 security (draft, remote 7b828fa8, local 37b4f0a5),
  #318 fallback (draft, CLEAN), #312 startup (draft, remote 4d4733ec, local 94f637b9),
  #322 CI tier (draft, 758578c3), backend #93 Orbit (draft), backend #94 passkey (draft, 01ffd59)
AGENT DEFINITIONS: G:/WorkingDATA/art.kubus/.claude/agents/{haiku-scout,haiku-implementer,
  sonnet-reviewer}.md (load in a fresh session launched from G:/WorkingDATA/art.kubus;
  until then use general-purpose + model override)
DIRTY FILES: G:/kubus-build-084/badges (36-file uncommitted role-badge implementation:
  ProfileIdentityRoles + KubusIdentityAvatar surfaces; untested), G:/kubus-build-084/video
  (untracked scripts/qa/community_video_sizing_qa.mjs), C:/kubus-build/084-candidate (kept)
UNPUSHED: security 37b4f0a5 (10 commits over remote + dev merge), perf 94f637b9,
  video, badges, a11y, dialogs, map (never pushed; bundle backup on G:)
SECURITY: review-4 client P1/P2 corrections all committed; final independent review of
  b1a2d708..37b4f0a5 running; findings private (C:/kubus-build-084/_private/security/)
OWNER DECISIONS OPEN: one security policy decision (see the private review only);
  merges of every PR (classifier denies gh pr merge)
NEXT THREE ACTIONS:
  1. Adjudicate the final security review, push security -> #315 (one push).
  2. After #322 merges, push a11y/dialogs/map as drafts (cheap tier).
  3. Badges: commit + focused tests + rendered QA of the in-flight diff; then video QA.
```

## Traps carried forward

- Flutter SDK is `C:/dev/flutter` (3.44.2), not on the Bash PATH.
- `dart format lib` rewrites ~150 files; format only changed files.
- `gen-l10n` drops the `_supportedLocaleName` / locale guard; run the bump-l10n skill.
- Bash `git show origin/dev:path` needs `MSYS_NO_PATHCONV=1`.
- `gh pr merge` is denied by the permission classifier; the owner merges.
- The production API returns 403 to local origins; browser harnesses must rewrite
  `QA_API_ORIGIN` or mock.
- Node test of `maplibre_runtime_atmosphere` needs `--experimental-vm-modules`.
