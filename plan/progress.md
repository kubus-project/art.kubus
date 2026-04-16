# Task
Finish the previously planned UI/UX hierarchy, spacing, alignment, distribution, and localization cleanup for the scoped mobile/shared, auth/onboarding, and desktop UI files.

# Scope
- Audit all primary files named in the request.
- Finish only missing UI/UX and localization work that is still visible in the current repo state.
- Prioritize mobile/shared screens, then auth/onboarding cleanup, then desktop consistency only where incomplete.
- Keep existing desktop left navigation and desktop hub work intact unless a regression is found.

# Non-Goals
- No backend work.
- No provider initialization rewrites.
- No feature behavior redesign.
- No new legacy compatibility paths.
- No broad refactors outside the named files and allowed support files.
- No replacement of already-complete desktop navigation work.

# Audit Summary
- `lib/screens/desktop/desktop_shell.dart` - COMPLETE. Left-nav route stack, functions panel ownership, localized nav metadata, and desktop routing are already implemented. Missing: no UI work required in this pass.
- `lib/screens/desktop/components/desktop_navigation.dart` - COMPLETE. Localized label keys, expanded/collapsed rail, badges, bottom actions, and Labs adornments already exist. Missing: no UI work required in this pass.
- `lib/screens/home_screen.dart` - PARTIAL. Desktop-guided hierarchy, search, quick actions, stats, Web3 cards, activity, and rails are already structured. Missing: two hardcoded fallback strings remain in discovery/creator rail fallbacks.
- `lib/screens/desktop/community/desktop_community_screen.dart` - COMPLETE. Desktop composition, right-rail sections, composer grouping, tag/person discovery, and localized surface work are already present. Missing: no mobile/shared blocker found.
- `lib/screens/desktop/web3/desktop_artist_studio_screen.dart` - COMPLETE. Split-panel desktop shell, section-aware right rail, localized actions, and desktop utility width are already present. Missing: no UI work required in this pass.
- `lib/screens/desktop/web3/desktop_institution_hub_screen.dart` - COMPLETE. Split-panel desktop shell, verification/action grouping, section-aware side rail, and localized labels are already present. Missing: no UI work required in this pass.
- `lib/screens/desktop/web3/desktop_governance_hub_screen.dart` - COMPLETE. Desktop governance split panel, current-section context, voting power card, quick actions, and localized labels are already present. Missing: no UI work required in this pass.
- `lib/screens/community/community_screen.dart` - PARTIAL. Search, tabs, composer components, art feed, group cards, and post cards are implemented. Missing: groups tab lacks a composed section header, composer tag/mention labels and group picker copy still have hardcoded English, and art/group spacing uses several one-off constants.
- `lib/screens/community/profile_screen.dart` - COMPLETE. Profile header, cover/avatar hierarchy, stats, achievements, artwork/posts sections, and localized labels are already substantially structured. Missing: no concrete scoped edit found that is safer than preserving existing work.
- `lib/screens/community/messages_screen.dart` - PARTIAL. Conversation data, empty state, avatar fallbacks, create dialog, and localization are present. Missing: conversation list still starts abruptly with no composed search/action header when conversations exist.
- `lib/screens/community/conversation_screen.dart` - PARTIAL. Thread behavior, message rendering, member dialogs, and localization are present. Missing: minor visual clutter remains, but no narrow safe edit was identified before the higher-value list/header work.
- `lib/screens/web3/wallet/wallet_home.dart` - PARTIAL. Wallet states, balance, custody, actions, tokens, and transactions are implemented. Missing: dashboard still reads as a vertical utility stack; actions are an equal-weight card, tokens lack an empty state, section headers are inconsistent, and one value label has mojibake text.
- `lib/screens/web3/marketplace/marketplace.dart` - PARTIAL. Marketplace data, tabs, listings, details, and local-first collectibles are implemented. Missing: settings copy, tab labels, section titles, empty states, and browse hierarchy still include hardcoded English and uneven gutters.
- `lib/screens/web3/artist/artist_studio.dart` - PARTIAL. Header, verification card, tabs, role gates, creation flow, and desktop embedding hooks are present. Missing: mobile page header blocks still use dense card stacking; no hardcoded strings were found in the main surface except debug-only logs.
- `lib/screens/web3/dao/governance_hub.dart` - PARTIAL. Header, tabs, proposals, review queue, voting, treasury, and delegation are implemented and mostly localized. Missing: proposal category keys are still stored and displayed as hardcoded English values.
- `lib/screens/web3/institution/institution_hub.dart` - PARTIAL. Header, verification card, tabs, role gates, event/exhibition/analytics flow, and desktop embedding hooks are present. Missing: cross-role blocked copy and application sheet title/action/error still have hardcoded English.
- `lib/screens/auth/sign_in_screen.dart` - COMPLETE. Wallet-first progressive disclosure, email/Google fallbacks, auth shell, and localization are already implemented. Missing: no concrete scoped edit found.
- `lib/screens/auth/register_screen.dart` - COMPLETE. Delegates registration to `AuthMethodsPanel` and should remain untouched. Missing: no work required.
- `lib/widgets/auth_methods_panel.dart` - COMPLETE. Auth success routing, wallet/email/Google flows, and localized shell copy are already implemented. Missing: no concrete scoped edit found.
- `lib/widgets/auth_methods_panel_sections.dart` - COMPLETE. Registration method grouping, alternative disclosure, email shell, inline wallet surface, and localized labels are already implemented. Missing: no work required.
- `lib/widgets/auth_methods_panel_helpers.dart` - COMPLETE. Validation helper copy is localized through callers. Missing: no work required.
- `lib/widgets/auth_entry_shell.dart` - COMPLETE. Shared auth entry shell already has desktop/mobile composition and highlight grouping. Missing: no concrete scoped edit found.
- `lib/screens/onboarding/onboarding_flow_screen.dart` - COMPLETE. Structured onboarding, account mode switch, welcome choices, permissions, wallet backup, and role flow are already implemented with localization. Missing: no concrete scoped edit found.

## Reopened Gaps
- ✅ `lib/screens/web3/marketplace/marketplace.dart`: resolved. All reopened visible hardcoded English UI strings in the audited flows were localized (`AR`, `FOR SALE`, `Listed for`, `Owned`, `Properties`, `SOLD OUT`, `by {artist}`, `Description`, card action labels, and mint/AR dialog copy).
- ✅ `lib/screens/web3/dao/governance_hub.dart`: resolved. Proposal categories now use stable internal IDs (`platform_update`, `new_feature`, etc.) while display labels remain localized.
- ✅ `lib/screens/community/community_screen.dart`: resolved. `unavailableMessageFor('Posting')` now uses localized `l10n.communityPostingFeatureLabel`.

## Finishing Plan
- ✅ `lib/screens/web3/marketplace/marketplace.dart`: localized remaining visible hardcoded English copy in cards/details/mint dialogs with no hierarchy/spacing regressions.
- ✅ `lib/screens/web3/dao/governance_hub.dart`: switched proposal categories to stable internal keys and preserved localized display labels + proposal-type mapping.
- ✅ `lib/screens/community/community_screen.dart`: replaced hardcoded `'Posting'` app-mode label with localized copy.
- ✅ `lib/l10n/app_en.arb` + `lib/l10n/app_sl.arb`: added required keys for marketplace/governance/community updates.
- ✅ Regenerated l10n, formatted touched files, ran analyzer, and ran targeted hardcoded-string verification scans.

# TODO Checklist
- [x] `community_screen.dart`: add groups directory header with localized title/subtitle and tokenized spacing.
- [x] `community_screen.dart`: localize composer tag label, tag hint, mention label, and mention hint.
- [x] `community_screen.dart`: localize group picker title, no-joined-groups toast, and no-description fallback.
- [x] `community_screen.dart`: replace audited magic spacing in groups/art feed sections with `KubusSpacing` tokens.
- [x] `wallet_home.dart`: add shared section header helper and apply it to quick actions, tokens, and recent transactions.
- [x] `wallet_home.dart`: make quick actions a restrained grouped control with stable action button dimensions and aligned gutters.
- [x] `wallet_home.dart`: add localized empty token state and replace mojibake approximate-value copy.
- [x] `marketplace.dart`: localize all remaining visible hardcoded strings in cards/details/mint and AR-required dialogs.
- [x] `marketplace.dart`: add browsing subtitles and tokenized grid spacing for featured/trending listings.
- [x] `institution_hub.dart`: localize institution cross-role blocked title/description strings.
- [x] `institution_hub.dart`: localize application sheet title, submit action, and failed submission copy.
- [x] `messages_screen.dart`: add localized conversation list header/action row above non-empty conversation lists.
- [x] `home_screen.dart`: replace hardcoded discovery rail warming and creator fallback strings with localization.
- [x] `governance_hub.dart`: localize proposal category display labels while preserving stable internal category values.
- [x] `community_screen.dart`: replace app-mode unavailable `'Posting'` label path with localized copy.
- [x] `lib/l10n/*`: update English and Slovenian localization sources and generated localization accessors for all added keys.
- [x] Verification: run formatting on touched Dart files.
- [x] Verification: run `flutter analyze` or record blocker.
- [x] Verification: re-open every touched file and mark checklist status accurately.

# Progress Log
- 2026-04-16: Completed preflight by reading all repo `AGENTS.md` files and `docs/SCREENS.md`.
- 2026-04-16: Completed initial audit. Desktop shell/navigation and desktop hub wrappers are already complete; remaining planned work is concentrated in mobile/shared community, wallet, marketplace, institution, messages, and localization files.
- 2026-04-16: Amended locked plan after the audit subagent reported concrete primary-file localization gaps in `home_screen.dart` and `governance_hub.dart`.
- 2026-04-16: Implemented the mobile/shared pass: community group hierarchy and composer localization, wallet dashboard section hierarchy, marketplace browse hierarchy/localization, institution application localization, messages list header, home rail fallbacks, and governance category display cleanup.
- 2026-04-16: QA subagent found three completion-gate localization gaps in community post actions, marketplace collectible stat/detail labels, and institution review-state copy. Patched those gaps and regenerated localization accessors.
- 2026-04-16: Re-ran formatting, localization generation, static analysis, ARB validation, targeted hardcoded-string scans, and `git diff --check`.
- 2026-04-16: Re-audited mandatory files against this plan and reopened false-complete gaps in marketplace copy, governance category IDs, and community posting unavailable label flow.
- 2026-04-16: Implemented final marketplace localization pass for remaining card/detail/mint/AR dialog hardcoded strings and added required EN/SL ARB keys.
- 2026-04-16: Replaced governance category values with stable internal identifiers and updated proposal type mapping to use those IDs.
- 2026-04-16: Localized community unavailable posting feature label and completed final completion-gate QA review.

# Verification
- Checklist status: DONE 19 / PARTIAL 0 / NOT DONE 0.
- `flutter gen-l10n` completed successfully after ARB updates.
- `dart format lib/screens/web3/marketplace/marketplace.dart lib/screens/web3/dao/governance_hub.dart lib/screens/community/community_screen.dart` completed (3 files checked, 1 reformatted).
- `flutter analyze` completed with no issues.
- Targeted scans confirm the reopened strict blockers are no longer present in:
	- `lib/screens/web3/marketplace/marketplace.dart`
	- `lib/screens/web3/dao/governance_hub.dart`
	- `lib/screens/community/community_screen.dart`
- QA completion-gate subagent review: PASS across marketplace hardcoded-copy gate, governance stable-ID gate, community localized-posting-label gate, and EN/SL key parity gate.

# Remaining Gaps
- None.
