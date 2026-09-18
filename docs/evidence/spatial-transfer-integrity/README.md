# Spatial transfer integrity — A/B/C acceptance evidence

**Date:** 2026-09-18 · **Status:** BLOCKED — real device acceptance only

Every claim below is labelled with how it was obtained. The categories are not
interchangeable and are never blurred:

| Label | Means |
|---|---|
| `AUTOMATED` | A test in this repository |
| `REAL NODE` | The owner's node, or its exact build, actually executed |
| `REAL DEVICE` | A Samsung Galaxy S22 Ultra actually captured |
| `REAL GPU` | An RTX 3080 Ti actually ran |
| `PRODUCTION` | A published release, installed |

---

## Root cause

**The container healthcheck was deleting live capture uploads.**

`runCli` swept orphaned capture directories *before* dispatching any command.
The agent's healthcheck is `node dist/src/index.js status`, every 30 seconds —
a second process, whose in-memory draft map is necessarily empty. Every upload
in flight therefore looked orphaned to it and was removed recursively.

The serving process never found out. Its accounting for a draft lives in
memory, so later writes recreated the directory tree and `commitDraft`
certified a package of 83 files over a directory holding 11.

This is why the failure looked like a Nerfstudio problem: the first file
uploaded was the first file deleted, so the adapter hit `ENOENT` on frame 0.

### `REAL NODE` — the two failed captures, as found

Read from `kubus-node_node-state` read-only, before anything was changed.

| | fresh `7773f051-86d6-4292-979e-c4113c808097` | old `4e70e6f1-077d-4735-a5cc-6102c66340cf` |
|---|---|---|
| art.kubus record | `5fa5b0a1-eb16-5154-b40b-7894aae52f92` | `9c077e3a-dedd-53d4-a0f2-bf3b5bc4817b` |
| Node record | 83 files / 2,855,476 B / `stored` | 36 files / 1,241,905 B / `stored` |
| Actually on disk | 11 payload files / 341,939 B | 17 payload files |
| Draft opened | 19:19:03.427Z | 19:15:56.539Z |
| **Directory birth** | **19:19:51.718985153** | **19:16:14.519607028** |
| Commit written | 19:19:58.699 | 19:16:30.239 |
| Jobs produced | 2 × `ENOENT` | 3 × `capture_dataset_invalid` |

The directory birth times are *later than the draft that created them*. Each
matches, to the nanosecond, the first surviving file's write — the `mkdir
--recursive` that rebuilt the tree after the sweep removed it. Survivors are a
contiguous suffix of upload order in both cases.

Container `RestartCount=0` and a single `kubus node started` in the log, so no
restart was involved. The two sweeps are 217.2 s apart — 7 × the healthcheck's
~31 s effective period (30 s interval plus ~0.8 s execution, from the recorded
health log).

### `AUTOMATED` — reproduced before any fix

`tests/captureStreaming.test.ts`, "a second process must not reclaim a draft
the serving process is filling", failed with exactly the production signature:
the first five files listed in `capture.json`, absent on disk.

### `REAL NODE` — the deployed build, old versus new

The exact `dist` copied out of the container that produced the failure, run on
a working runtime, against a data root holding one live draft:

```
DEPLOYED build 0.8.0-alpha.10   → live draft AFTER real healthcheck: DELETED
FIXED build    0.8.0-alpha.11   → live draft AFTER real healthcheck: PRESENT
```

### `REAL NODE` — the new validator against the real damage

Run against the untouched volume:

```
4e70e6f1  ok=false  capture_package_incomplete  19 of 36 files missing
7773f051  ok=false  capture_package_incomplete  72 of 83 files missing
```

Neither could be committed as `stored` under the new code, and neither can
produce a reconstruction job.

---

## Second, independent defect — the old capture

`4e70e6f1`'s `capture.json` file list contains **no `frames.json` entry at
all**. The canonical frame document is only written when a capture is
finished, so a capture interrupted before that reopens with usable samples and
no manifest. The upload loop's `if (!await file.exists()) continue;` stepped
straight over it and committed anyway.

That capture was recoverable all along: `frames.jsonl` and every image were on
the phone. Nothing was missing except the document that is derived from them.

---

## What changed

### kubus-node — `fix/capture-draft-integrity`

Three layers, so the class of failure cannot return:

1. Only `start` and `gui` sweep. `status` and `doctor` are diagnostics and
   never mutate capture state.
2. A draft directory carries a `.draft.json` activity marker, refreshed on
   every write. A sweep in *any* process skips a directory whose marker is
   fresh, so a live transfer is safe even from a process that cannot see it.
3. `commitDraft` is an integrity boundary, not an accounting one. It re-checks
   every received file against the directory, requires a valid `frames.json`,
   and requires every image, depth and confidence file the manifest references
   to exist and be non-empty.

A refused commit **keeps the draft**, so the phone sends the few files named
instead of restarting a half-gigabyte transfer. `getDraft` reports what the
directory holds rather than what arrived, so a resume re-sends what is gone.

Reconstruction gained the matching precondition: a capture that lost files
after it was stored cannot reach a GPU, and a second Process tap is answered
with the attempt already in flight rather than a second job.

Idempotency no longer resurrects a damaged replica — a stored capture that
fails inspection is replaced by the repair upload, so one local capture still
maps to exactly one durable copy.

Machine-readable rejections: `capture_package_incomplete`,
`capture_frames_missing`, `capture_frame_file_missing`,
`capture_frames_invalid`. Capture-relative paths only; no node filesystem
layout reaches an end-user surface.

### art.kubus — `fix/spatial-transfer-integrity`

- `ensureCanonicalFrames()` rebuilds `frames.json` from the durable
  `frames.jsonl` index, atomically and idempotently. Nothing is invented: a
  capture whose index holds no samples stays unrepairable **and intact**.
- `validateTransferPackage()` requires every file the transfer will send to
  exist and be non-empty, before a draft is opened. A missing required file is
  a typed `SpatialSourceIncomplete`, never a `continue`.
- Both upload loops are now one `SpatialNodeUpload`, so the capture flow and
  the library flow cannot drift.
- Byte-level progress through every transport rung — LAN, remote HTTPS, WebRTC
  direct and relayed. Confirmed bytes and in-flight bytes are held apart; only
  what the node acknowledged is persisted.
- `SpatialTransferMeter` reports no speed without a sample window, no ETA
  without a speed, and a stall instead of a countdown.
- Per-file timeouts are progress-aware: a file is abandoned when it stops
  moving, not when it turns out to be large.
- Failure categories preserved end to end, EN and SL.

### Review round (both PRs)

kubus-node, after review of #21:

- A restart inside the 30-minute grace period no longer strands an abandoned
  upload: the serving process — the one that owns the draft map — re-sweeps
  every 15 minutes. `status` and `doctor` still never touch disk. Ownership is
  re-checked synchronously immediately before each removal; a long single
  file refreshes its marker mid-stream; whole-package `create()` uploads are
  claimed while they are written.
- Repairing a damaged replica validates the replacement first and swaps the
  records in one state write; the old directory goes only afterwards. An
  incomplete or malformed repair, a failed state write, or a job still reading
  the old replica (`409 capture_in_use`) leaves the existing capture untouched
  and the draft resumable. Commits are serialized.
- `frames.json` is untrusted input: `null`, arrays, strings, null or primitive
  frames and mistyped paths are `422 capture_frames_invalid`, never a 500.
- Reconstruction deduplication is atomic per capture; simultaneous requests
  queue exactly one job.
- A discard racing a commit answers `409 capture_draft_committed` instead of
  deleting the committed directory; draft status never waits behind a stuck
  write.

art.kubus, after review of #174:

- A stalled file upload is cancelled at the transport — HTTP (LAN, remote
  HTTPS) closes its connection via `Abortable`; WebRTC (direct, TURN) stops the
  body and sends a Cancel frame — and the failure is reported only once the
  upload has actually stopped. No rung reports bytes after cancellation; a
  retry cannot overlap the abandoned write.
- Stall clock, throughput and ETA start when bytes are due, not during
  preparation; bytes credited from an earlier attempt are not counted as speed.
- A repaired file is counted back into the file total; a resume whose draft
  lookup fails keeps its persisted progress; a job the Node ran and failed is
  `processing_failed`, not "waiting for a processor".
- CI: `setup-android` was pinned to a version whose default package list
  includes the removed `tools` package; the Android job now names
  `platform-tools` explicitly and compiles again.

### art.kubus-backend

**No change.** The defect is entirely phone ↔ node over the local API; the
backend is not on this path. The gitlink is left at `ee3b8806`.

---

## Test results

| Suite | `AUTOMATED` |
|---|---|
| kubus-node `npm test` | 527 passed, 5 skipped, 52 files |
| kubus-node `npm run typecheck` / `npm run build` | clean |
| kubus-node `docker compose config` | valid |
| kubus-node PR CI (quality, Docker smoke, release/npm packages, Windows EXE, installer contract) | green on `91c96c7` |
| art.kubus `flutter test` | 2,984 passed, 5 skipped |
| art.kubus `flutter analyze --fatal-infos --fatal-warnings`, `custom_lint` | clean |
| art.kubus `scripts/architecture_guard.mjs` | passed, 3,722 file checks |
| art.kubus `scripts/kubus-lint-ratchet.mjs --check` | OK, no deltas |
| art.kubus PR CI incl. Android release compile, iOS compile, web build | green on `25fe5077` |

New coverage worth naming:

- A second process must not reclaim a draft the serving process is filling.
- Commit refuses: no `frames.json`; manifest references an absent image; a
  declared optional file absent; an uploaded file emptied or vanished after
  upload; malformed, wrong-schema or empty `frames.json`; a traversal
  `rgbPath`; a frame count contradicting stated metadata.
- A rejected commit leaves a resumable draft, and commits exactly once after
  repair.
- An invalid capture cannot create a `spatial.reconstruct` job; a second
  Process tap returns the in-flight one.
- A damaged replica is replaced, while a genuine lost-response retry still
  converges on the existing capture.
- Legacy capture: `frames.jsonl` + images, no `frames.json` → repaired,
  validated, uploaded. Unrepairable capture → preserved, marked, no fabricated
  manifest. Second repair pass is a no-op.
- A commit the node refuses is repaired, not restarted. A capture missing a
  file on this device never reaches the node.
- Progress: 0 %, mid-transfer, 100 %, ETA suppression, stall, confirmed vs
  in-flight, route labels, EN/SL, screen-reader sentence, 2× text at 320 dp.

---

## `PRODUCTION` — kubus Node 0.8.0-alpha.11

Released by the repository's own `release.yml` from tag `v0.8.0-alpha.11` →
`9bd1eec6b18d848e6429c392f21bfa538a9cd09a` (master, merge of #21).

| | |
|---|---|
| Node image | `ghcr.io/kubus-project/kubus-node@sha256:89a425d8fe4455f2e93da617a7e9588828822ea3a6c82ea9296850a559f76440` — pulled; labels `0.8.0-alpha.11` / `9bd1eec6` |
| Worker image | `ghcr.io/kubus-project/kubus-spatial-worker@sha256:406563413fc8c13a8ea45b29133c8da1d36f91cf7eaf1874f3eab47c7f8db423` |
| Release Compose | sha256 `7c769e2e…1279`, matches the manifest |
| npm | `@kubus/kubus-node@0.8.0-alpha.11` on `edge`, signed provenance |
| GitHub release | pre-release, EXE, Windows ZIP/tar, npm tarball, SBOMs, manifest; every asset matches `SHA256SUMS` |

## `REAL NODE` — the owner's Node, upgraded

The owner's GPU Node runs from the source checkout with the `spatial` profile
(the documented GPU route — see Known limitations for why not the installer).
It was fast-forwarded to `9bd1eec6` and rebuilt; volumes were reused, a backup
of the state volume was taken first.

- Agent reports `0.8.0-alpha.11`; all three containers healthy; the worker sees
  the RTX 3080 Ti.
- Identity preserved, compared field by field before and after: node id
  `2dc017f8-84ef-4ac1-9138-19c11fe3c729`, Ed25519 public key, identity /
  config / worker-key hashes, libp2p peer id, compute identity, the phone's
  pairing credential, 163 pinned CIDs, both damaged capture records. The Node
  re-registered and sent its heartbeat.

### `REAL NODE` — the original failure class, on the upgraded Node

A temporary probe credential streamed a 13-file capture into the serving
process over 85 s (revoked and deleted afterwards):

```
3 real Docker healthchecks and 6 manual `status` runs during the upload
files on disk after each manual healthcheck: 2, 4, 6, 8, 10, 12   (never fewer)
commit 201 stored, validation ok, 12/12 frames
```

The same Node refuses what alpha.10 would have certified:

```
frames.json names rgb/00001.jpg, never uploaded → 422 capture_frame_file_missing,
    draft kept open, jobs 5 → 5
reconstruct 7773f051 → 422 capture_package_incomplete (72 missing), no job
reconstruct 4e70e6f1 → 422 capture_package_incomplete (19 missing), no job
```

---

## Not yet done

**`REAL DEVICE` — none.** No Android device was attached (`adb devices` empty)
for the whole session. The physical path — real ARCore capture → Spatial
Library → Process with My Node → visible byte-level progress → node validation
→ one reconstruction job → RTX 3080 Ti → result imported → opens in the
library — has **not** been run.

**`REAL GPU` — none.** No reconstruction was executed, because there is no
valid real capture to execute one against.


### The two damaged captures

Left in place as evidence. They are unusable by construction — 72 and 19 files
respectively are simply gone from the node, and only the phone can supply
them. The product behaviour that recovers from this state is implemented and
tested: the node refuses to reconstruct them, and the app replaces the replica
from the raw capture if the device still holds it.

---

## Known limitations

- The legacy base64 `POST /local/v1/captures` route is deliberately not an
  integrity boundary. A package arrives there in one request so it cannot be
  half-transferred; anything unusable declared there is caught at
  `JobRuntime.create`, before a GPU is reserved. Documented in `captureStore.ts`.
- `DRAFT_IDLE_GRACE_MS` is 30 minutes and the serving process re-sweeps every
  15, so a directory stranded by a crash is reclaimed within about 45 minutes.
  A draft the *running* process still owns is never reclaimed while it runs; an
  abandoned one is freed at the next restart.
- **The installer path cannot run the GPU worker.** The release Compose puts
  the worker behind the `spatial` profile, which neither the npm CLI nor the
  Windows installer enables, and gives it no GPU device reservation. GPU
  processing therefore still requires the source route
  (`docker compose --profile spatial up`). Pre-existing, not part of this fix;
  needs its own change and release.
- The commit repair makes exactly one attempt. A second refusal is a real
  disagreement about the package and surfaces as one.
- Reconstruction progress within Nerfstudio is still indeterminate. The worker
  does not report measured iteration progress, and none is invented.
