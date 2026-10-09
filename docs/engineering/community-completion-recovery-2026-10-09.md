# Community completion recovery, 2026-10-09

Recovered the existing `feat/0.8.2-community-completion` worktree and PR #255.
The clean local branch had one unpushed commit, `7d6784b1`, after remote
`6176094e`. That focus/volume-semantics commit is preserved in the ancestry.

## Review corrections

- The backend probe now sends only `GET /health`, refuses redirects, sends no
  token, and returns UNKNOWN (exit 2). It cannot attest publishing validation,
  revision, migration or HA safety. The former authenticated validator probes
  were unsafe against precisely the incompatible servers they attempted to
  detect. Four regression tests cover permissive servers and redirects.
- Fullscreen entry unmounts inline before pushing. Exit waits for
  `TransitionRoute.completed`, which includes the reverse animation and overlay
  removal, before remounting inline. Playback restoration waits for the next
  composited frame so Chromium's queued detach/pause event cannot override it.
  The controller, position and audio state are retained. Retry also waits for
  teardown. Frame-by-frame tests count offstage views over three animated cycles.
- A controller listener starts the visibility guard only while playing and
  cancels it on every stopped state. Manual/coordinator/offscreen/route/tab/app
  pauses, completion, resumption and disposal have timer-count assertions.

## Accessibility and visual evidence

Flutter 3.44.2's `SemanticIncrementable` temporarily disables the DOM range
input for 500 ms after pointer events. That is pointer arbitration, not the
widget's disabled state. It also labels the wrapper rather than the nested
range input and can omit initial value text for a slider born in pointer mode.
The scoped `community_slider_accessibility.js` copies each marked widget's
localized name and value to its range input. It leaves enabled state, focus,
surrogate numeric range and adjustment actions under Flutter's control.

Chromium verifies unique position/volume names, enabled inputs after debounce,
initial time/0% values, five-second keyboard seeks, five-percent volume keys
and the actual DOM change event used for assistive adjustments. Widget tests
verify focus order, focus color and view-aware semantics action dispatch.
Actual NVDA/VoiceOver spoken output has not been measured.

Reviewed external screenshots cover 320/390/768/1440 px, English/Slovenian,
light/dark, portrait/landscape, initial/playing/paused/seeking/buffering and
expanded views. Controls retain Kubus semantic roles and design tokens.
The prior desktop portrait failure was the harness choosing the first feed
play button rather than the target clip's button. The corrected scenario passes.

## Validation checkpoint before push

- Full Flutter suite: 4,094 passed, 25 skipped, no failures.
- Community enabled: 192 passed, 10 skipped; rollback: 166 passed, 36 skipped.
- Player: 44 passed, including animated handoffs and lifecycle guards.
- Read-only-probe/build-configuration Node tests: 14 passed.
- Flutter analysis: no issues. Release web build succeeds; existing dependency
  wasm dry-run findings remain visible (the deliverable is JavaScript).
- Chromium desktop player: 22/22; mobile visual/player scenarios: 11/11;
  tablet and desktop portrait pass; accessibility: 10/10 checks.
- Existing authenticated isolated composer evidence is retained: desktop dialog
  14/14, desktop inline 10/10, mobile 5/5, group 5/5, preview 4/4 and feed 5/5.
  These use local test accounts, real uploads and disposable PostgreSQL,
  not production create requests.

External artifacts live under `_artifacts/community-completion` outside this
worktree. Private sessions and JWT material are excluded from Git. Pre-recovery
web output is retained as `web-on-before-recovery`.

## Backend promotion gate, measured read-only

On 2026-10-09, both Oracle and Home match all 312 checked tracked files under
`src`, `migrations` and package manifests from backend `ce11d5fc` (#79). Both
return readiness 200. Migration `098_community_post_submissions.sql` is recorded
on both, with the submission ledger and its constraints present. Oracle is
primary, Home's WAL receiver is streaming, and `oracle_home_slot` is active with
reserved WAL. Witness health grants Oracle the lease (term 207). Disk headroom
is 28 GiB on Oracle root, 20 GiB on its database volume, 14 GiB on Home's database
volume. No migrations, reseeding, fencing changes or live create probes ran.

## Integration evidence boundary

Final pushed-SHA CI and actual development deployment must be checked after
push. Local QA does not establish deployed acceptance. The dev workflow's
push expression defaults Community multi-media to true; manual false remains
the rollback. No other disabled flag is activated. Production frontend
deployment, release tags, version changes and the next slice are outside scope.
