# Slice 4 — Unified Loading Language

Date: 2026-07-11
Status: Executing under the standing UI-overhaul mandate (roadmap item 4).

## Measurement

Branded loading primitives exist — `InlineLoading` (isometric-cube pulse,
determinate + indeterminate, shape/clip aware) and `AppLoading` (splash) —
but **122 raw `CircularProgressIndicator` call sites across 61 files**
bypass them. Same adoption disease slices 1–2 fixed for color/borders.

## Design

1. **Lint rule** `kubus_no_raw_progress_indicator` in `packages/kubus_lints`:
   flags `CircularProgressIndicator(` / `LinearProgressIndicator(` outside
   the loading primitives themselves (`lib/widgets/inline_loading.dart`,
   `lib/widgets/inline_progress.dart`, `lib/widgets/app_loading.dart`).
   Fixture coverage via `expect_lint` in the example package.
2. **Grandfather + ratchet**: extend `scripts/kubus-lint-ratchet.mjs` with
   the new rule regex + allowlist; run `--grandfather`; baseline recorded;
   count may only decrease (same mechanism as slice 1).
3. **Beachhead migration** (highest-visibility spinners → `InlineLoading`):
   guest/main map surfaces, exhibition/event lists, community feed, profile.
   Full burn-down of the remaining files is follow-up work under the same
   ratchet — NOT required in this slice.
4. **Canon docs**: add the loading row to the `kubus_kit.dart` decision
   table and export `InlineLoading`/`InlineProgress` from the barrel.

## Non-goals

Skeleton redesign, prefetch/network (slice 5), splash changes.

## Verification bar

analyze + custom_lint clean; ratchet monotone; full suite +1235 ~1 -1
baseline; visual pass of a migrated loading state via the verify skill.
