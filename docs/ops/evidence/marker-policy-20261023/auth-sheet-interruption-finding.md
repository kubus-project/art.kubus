# Auth return: pending-action sheet interruption (v0.8.5, 2026-10-23)

Scope: exact app artifact local 6a885b2d (release-mode, development config), backend 88d792ff, real disposable PostGIS
database (migrated with `src/db/migrate.js`), real public artwork row, no response mocks, Chromium 1280x800.
Synthetic accounts only; credentials are not recorded here.

## Result
| Case | Behaviour |
|---|---|
| Walletless account, no dismissal | Sheet shown over the artwork; address = entity; stable for 15 s |
| Walletless, Not now immediately / after 5 s | Stays on the artwork, address = entity, no Home content |
| Walletless via SSR-proxied entry, and with the artwork served only by a mocked GET | Same: sheet over the artwork |
| Wallet-linked account ("Continue without wallet") | **Sheet appears, then disappears about 1.4 s later with no user action; never returns.** 3/3 with 40 ms sampling |

The earlier observation (signed-in Home under the sheet while the URL stayed on the entity) was **not reproduced** in
any of five configurations. It is not attributed.

## Root cause of the reproduced defect
The confirmation sheet opens 450 ms after the intent is restored. For a wallet-linked account the final post-auth route
replacement lands later; the artwork's real screen mounts (its `POST /view` fires in the same millisecond the sheet is
last seen) and removes the sheet's route. `showModalBottomSheet` completes with `null` for a removed route exactly as it
does for a barrier tap; the host read `null` as "Not now" and `PendingActionProvider.cancel()` cleared the stored intent.
The visitor lands on the right entity but is never offered the action. A 3 s delay on shell warm-up reads in the walletless
path did not reproduce it, so slow reads alone are not the trigger.

## Fix (topic fix/085-pending-sheet-interrupt-20261023)
`PopScope` distinguishes any pop (buttons, barrier, back, drag) from a route removal. A removal keeps the intent and
re-offers the sheet over the replacement screen, at most three presentations, then leaves it pending (not discarded).
Verified: widget tests 11/11 (two new interruption tests failed before the fix with `pending == null`), analyzer clean,
and in a real browser on the fixed build the sheet reappears and stays; pressing Like sent exactly one
`POST /api/artworks/{id}/like` (200) and the visitor stayed on the entity. No automatic replay.
Limit: a programmatic `Navigator.pop` of the sheet is indistinguishable from a visitor pop; no post-auth path pops routes.
