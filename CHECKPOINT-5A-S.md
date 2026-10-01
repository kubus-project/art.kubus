# Wave 5A-S checkpoint (2026-10-02) — WIP, does not compile yet

Baseline: #202 merged -> dev@82102b87. Branch feat/product-v5-semantic-visual-system.
BEFORE captures: output/qa/product-v5-semantic/before (matrix test/qa/product_v5_semantic_visual_matrix_test.dart).

Done (uncompiled): KubusActionTile no foreground icon/no glow; KubusStatCard expressive/centered no
foreground icon (centeredExtent lost `withIcon`); KubusDashboardHeader no hero icon tile;
DesktopSectionHeader / SharedSectionHeader / SharedSettingsSectionHeader / DesktopCreatorSidebarSection
are typographic only (icon/accent params removed at all call sites via scratchpad strip_args.py).

Fix next: home_screen.dart:1555 drop `withIcon:`; unused imports (desktop_widgets, desktop_home,
exhibition_creator, home_screen, creator_kit, shared_section_widgets, shared_settings_widgets);
settings_screen_p2.dart:141 unused `sectionColor`.

Remaining audit findings (from BEFORE screenshots): analytics lead/support cards (icon boxes,
aspect-ratio grid overflows 30px at 200%); profile ARTIST chip brush icon + nested empty-state
cards; wallet desktop "signing unavailable" said twice + duplicate Refresh, mobile hero repeats
token list; studio/institution status panel duplicates locked state CTA; creator cover "upload" x3;
marketplace empty state not aligned to 32px gutter; DAO onboarding title x3; wallet security
status header icon repeats chip icon; SL diacritics (Domace etc.); tests; design doc; gates.
WORLD worktree: _worktrees/world-camera-performance (fix/world-camera-performance from master@02c490c),
untouched. Camera: storyKeyframes in src/home/storyState.ts, damping in IsometricMap.vue ~840-1022.
NODE: not started (repo node.kubus.site, main@fac6305).
