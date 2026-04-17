# Task
Finish the partially implemented Flutter UI/UX design pass for the earlier mobile/shared design plan.

# Scope
- Audit and finish Flutter UI, localization, spacing, alignment, hierarchy, scanability, and accessibility issues in the mandated design files.
- Primary implementation target: `lib/screens/web3/marketplace/marketplace.dart`.
- Secondary implementation targets where the audit found concrete unfinished work: `lib/screens/web3/wallet/wallet_home.dart`, `lib/screens/community/community_screen.dart`, `lib/screens/web3/dao/governance_hub.dart`, and `lib/screens/web3/institution/institution_hub.dart`.
- Directly required support files: localization ARBs/generated accessors and the local collectibles provider method needed to replace the marketplace fake remove-from-sale flow.

# Non-Goals
- No backend work.
- No email infrastructure work.
- No desktop navigation rewrite.
- No unrelated screen rewrites.
- No reimplementation of completed auth grouping, messages header, desktop left navigation, or already-finished institution hierarchy work unless a regression is directly found.

# Audit Summary
- `docs/SCREENS.md`: COMPLETE. Current screen map reflects the mobile/desktop split and recent hierarchy notes.
- `lib/screens/web3/marketplace/marketplace.dart`: PARTIAL at audit, COMPLETE after implementation. Missing localized value/rarity/status labels, consistent browse section hierarchy, readable card typography, unified spacing/gutters, themed detail/listing/mint surfaces, real remove-from-sale behavior, localized date/detail fallbacks, and accessibility labels/tooltips were all addressed.
- `lib/screens/web3/wallet/wallet_home.dart`: PARTIAL at audit, COMPLETE after implementation. Mobile actions were cramped and governance-vote transaction color used a purple accent outside an AI/system role; action grouping now wraps into a stable grid and the vote color uses the theme primary role.
- `lib/screens/community/community_screen.dart`: PARTIAL at audit, COMPLETE after implementation. Composer/search picker/art feed areas retained hardcoded visible strings, mojibake separators, ad hoc spacing, and uneven action grouping; the touched leftovers are now localized and the visible separator/action spacing is normalized.
- `lib/screens/community/messages_screen.dart`: COMPLETE. Existing header work landed; no regression found and no implementation edits were needed.
- `lib/screens/web3/institution/institution_hub.dart`: PARTIAL at audit, COMPLETE after implementation. Raw DAO review status fallback was replaced with localized status labels.
- `lib/screens/web3/dao/governance_hub.dart`: PARTIAL at audit, COMPLETE after implementation. Raw proposal enum type labels and DAO review status fallbacks were replaced with localized display helpers.
- `lib/screens/home_screen.dart`: COMPLETE. Current home hierarchy, localization, search, Web3 card strip, and rails are coherent for this pass.
- `lib/screens/auth/sign_in_screen.dart`: COMPLETE. Auth grouping/progressive disclosure is implemented and visible copy is localization-driven.
- `lib/widgets/auth_methods_panel_sections.dart`: COMPLETE. Auth method panel follows the newer progressive disclosure pattern.
- `lib/l10n/app_en.arb`: PARTIAL at audit, COMPLETE after implementation. New marketplace/community/governance/institution keys were added.
- `lib/l10n/app_sl.arb`: PARTIAL at audit, COMPLETE after implementation. Matching Slovenian keys and directly touched copy were added.

# Locked Plan
- `marketplace.dart`: replace cached `_pages` widgets with a selected-page builder so tab content, filter state, locale, and theme changes rebuild reliably.
- `marketplace.dart`: add shared section/header/grid helpers and apply them to Featured, Trending, Listed for sale, and Owned collection surfaces.
- `marketplace.dart`: replace remaining hardcoded visible labels and raw enum display in listing, detail, rarity, status, mint, AR-required, and owned-collection surfaces with l10n-backed helpers.
- `marketplace.dart`: normalize card typography, badge contrast, detail rows, modal sheet padding, action grouping, and empty/connect-wallet surfaces using theme roles and Kubus spacing/radius tokens.
- `marketplace.dart`: improve listing dialog with localized helper copy, positive-price validation, themed input colors, and a stable action row.
- `marketplace.dart`: wire remove-from-sale to a real local provider method and remove the fake success flow.
- `collectibles_provider.dart`: add `removeCollectibleFromSale` that clears listed state, persists local storage, and notifies listeners.
- `wallet_home.dart`: improve hierarchy for balance/actions/tokens/transactions, make mobile quick actions wrap into a stable two-column grid, and replace the purple governance-vote transaction color.
- `community_screen.dart`: localize remaining hardcoded composer/search picker strings, fix visible mojibake separators, and normalize art feed/header/status/action spacing.
- `governance_hub.dart`: localize proposal card type labels and DAO review status display instead of showing raw enum/status values.
- `institution_hub.dart`: localize DAO review status labels instead of raw status uppercase fallback.
- `app_en.arb` and `app_sl.arb`: add all new marketplace/community/governance/institution keys and improve directly touched copy.
- Generated localization files: regenerate after ARB edits.

# TODO Checklist
- [x] DONE Audit mandatory files and sidecar findings.
- [x] DONE Create this task-specific progress file before implementation edits.
- [x] DONE Implement marketplace selected-page rebuild helper.
- [x] DONE Implement marketplace shared headers/grids and spacing normalization.
- [x] DONE Localize marketplace value, rarity, status, token fallback, property, date, semantic, tooltip, and listing validation copy.
- [x] DONE Restyle marketplace cards, sheets, empty states, read-only banner, and action groups for hierarchy and accessibility.
- [x] DONE Replace marketplace fake remove-from-sale flow with persisted local provider behavior.
- [x] DONE Improve wallet hierarchy/action grid/token and transaction scanability and remove non-system purple transaction color.
- [x] DONE Localize community composer/search picker leftovers and fix art feed separators/spacing.
- [x] DONE Localize governance proposal type and DAO review status display.
- [x] DONE Localize institution review status display.
- [x] DONE Add/update EN and SL l10n keys.
- [x] DONE Regenerate localization files with `puro flutter gen-l10n`.
- [x] DONE Format touched Dart files with `puro dart format`.
- [x] DONE Run static analysis with `puro flutter analyze`.
- [x] DONE Manually inspect touched files after edits.
- [x] DONE Run QA/completion-gate review. The requested QA subagent failed because the subagent service returned a usage-limit error, so the completion gate was performed locally against the locked plan and verification outputs.

# Progress Log
- Created locked design progress file after mandatory file audit and two read-only subagent audits.
- Implemented marketplace selected-page rebuild behavior and normalized Featured, Trending, Listed for sale, and Owned collection composition.
- Added marketplace l10n helpers for display values, rarity/status labels, token labels, property rows, dates, semantics, tooltips, and listing validation.
- Reworked marketplace card/sheet/action/empty-state hierarchy and replaced the fake remove-from-sale flow with persisted local provider behavior.
- Improved wallet quick-action grouping and removed the non-system purple transaction color.
- Localized community composer/search picker leftovers and corrected touched art-feed separator copy.
- Localized governance proposal/review and institution review status fallbacks.
- Regenerated localization files, formatted touched Dart files, fixed async context lints, and reran static analysis cleanly.
- Confirmed `backend/src/services/transactionalEmailService.js` is dirty inside the backend submodule and was not touched for this UI-only pass.

# Verification
- Reviewed all repo `AGENTS.md` files before implementation.
- Audited all mandatory files before creating this progress file.
- Used current-state and marketplace-first subagents before implementation; QA subagent failed with a usage-limit error and was replaced by a local completion-gate review.
- Ran `puro flutter gen-l10n`.
- Ran `puro dart format` on touched Dart files.
- Ran `puro flutter analyze`: `No issues found!`.
- Ran ARB JSON parse and EN/SL key parity check: `en 3236`, `sl 3236`, no missing keys.
- Ran targeted hardcoded-string/regression scans for marketplace, community, wallet, governance, and institution files; no matches for the scoped leftover patterns.
- Ran touched-file TODO/fake-flow scans; no scoped TODO/FIXME/fake success/stub matches.
- Ran bracket-balance sanity checks on touched Dart/provider files; all clean.
- Ran `git diff --check`; no whitespace errors. Git only reported CRLF normalization warnings for touched files.

# Remaining Gaps
Empty.
