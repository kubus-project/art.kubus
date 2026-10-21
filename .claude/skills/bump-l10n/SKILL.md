---
name: bump-l10n
description: Regenerate Flutter localizations and re-apply the locale-fallback hand patch that gen-l10n drops. Use after editing lib/l10n/*.arb or when the locale guard test fails.
disable-model-invocation: true
---

# bump-l10n

`pubspec.yaml` has `generate: true`, so localizations are generated from
`lib/l10n/app_en.arb` / `app_sl.arb` into `lib/l10n/app_localizations*.dart`.
The generator emits the **stock** base constructor, which drops the project's
hand patch that maps invalid/empty locale tags to the `sl` fallback. The only
source of truth that the patch is present is the guard test passing.

## Steps

1. **Regenerate** from the project root (puro env is `artkubus`):
   ```bash
   puro flutter gen-l10n
   ```

2. **Re-apply the hand patch** with the script (it is idempotent, and CI runs
   the same sequence and fails on any diff):
   ```bash
   dart format lib/l10n/app_localizations*.dart
   node scripts/l10n/locale_guard.mjs --fix
   node scripts/l10n/locale_guard.mjs --check
   ```
   The canonical guard text lives in `scripts/l10n/locale_guard.mjs`. For
   reference, the stock generator produces:
   ```dart
   abstract class AppLocalizations {
     AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

     final String localeName;
   ```
   and the script turns it into the guarded constructor, which maps anything
   other than `en`/`sl` to `sl`:
   ```dart
   abstract class AppLocalizations {
     AppLocalizations(String locale) : localeName = _supportedLocaleName(locale);

     static String _supportedLocaleName(String locale) {
       final normalizedLocale = intl.Intl.canonicalizedLocale(locale.trim());
       return switch (normalizedLocale) {
         'en' || 'sl' => normalizedLocale,
         _ => 'sl',
       };
     }

     final String localeName;
   ```

3. **Verify** — the guard test is the contract, not the helper name:
   ```bash
   puro flutter test test/l10n/app_localizations_locale_guard_test.dart
   ```
   It asserts `AppLocalizationsEn('undefined')`, `AppLocalizationsSl('null')`,
   and `AppLocalizationsEn('')` all yield `localeName == 'sl'`.

4. **Sanity-check** the rest still analyzes clean:
   ```bash
   puro flutter analyze lib/l10n
   ```

## Notes
- Do not commit the unpatched generated file — the guard test will fail in CI.
- If the helper has been refactored to a different name in a future version,
  keep the *behavior* identical and make the guard test pass.
