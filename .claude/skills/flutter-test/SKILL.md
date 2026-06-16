---
name: flutter-test
description: Run the art.kubus Flutter test suite (or a subset) correctly under puro, avoiding the secure-storage fake-async hang. Use to run, debug, or narrow Flutter tests.
disable-model-invocation: true
---

# flutter-test

The Flutter app uses the **puro** env `artkubus`. Always invoke the toolchain
through `puro` so you get the pinned SDK, not whatever is on PATH.

## Common runs

Whole suite (from the `art.kubus` project root):
```bash
puro flutter test
```

A single file or directory (preferred while iterating — much faster):
```bash
puro flutter test test/l10n/app_localizations_locale_guard_test.dart
puro flutter test test/widgets/
```

By name:
```bash
puro flutter test --plain-name "guards invalid locale tags"
```

With coverage (writes `coverage/lcov.info`):
```bash
puro flutter test --coverage
```

## Gotcha: secure-storage hangs under fake_async

`flutter_secure_storage` does real platform-channel / async work that **hangs
inside `fakeAsync` / `FakeAsync` test zones**. Symptom: a test that pumps fake
time never completes and the run appears stuck.

When a test touches secure storage:
- Use a **fake/in-memory secure-storage implementation**, or stub the channel,
  instead of the real plugin.
- Drive it with `tester.pumpAndSettle()` / real async, not `fakeAsync`.
- If you must keep `fakeAsync`, inject the storage so no real channel call runs
  inside the zone.

## Debugging a failure
1. Re-run just the failing file with `--plain-name` to isolate the case.
2. Check whether it imports/initializes secure storage, presence, or wallet
   providers that expect platform channels — those need fakes in widget tests.
3. Run `puro flutter analyze <path>` to rule out a compile/lint cause.
