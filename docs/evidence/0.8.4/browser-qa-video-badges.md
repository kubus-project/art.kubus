# 0.8.4 browser QA: community video sizing and avatar role badges

Date: 2026-10-19. Build: disposable candidate `chore/084-ui-candidate` `040b3880` =
`origin/dev` `2190782e` + `fix/084-community-video-sizing` + `fix/084-avatar-role-badges`,
release web build (`flutter build web --release`, public build defines, version 0.8.4).
Browser: Chromium (Playwright 1.58.2). No live API: every request is served from local
deterministic fixtures. Raw output (report.json + PNG) is on the build machine under
`G:/kubus-build-084/candidate-ui/output/playwright/`. It isn't committed.

## Video (`scripts/qa/community_video_sizing_qa.mjs`)

Widths 390 and 1440, light theme, motion not reduced. Six cases per mode: portrait 9:16,
portrait 4:5, square, landscape 16:9, ultrawide 21:9, and a mixed carousel.

| Mode | Result | Displayed aspect = source | Letterbox | Max stage-height change |
|---|---|---|---|---|
| bare (legacy post: no stored aspect, no poster) | 12/12 pass | yes, every case | 0 px | one-time adjustment when the first frame reveals the real aspect: portrait 364.5 px @390, 169.4 px @1440; landscape and mixed 0 |
| poster | 12/12 pass | yes | 0 px | 0, except ultrawide 12.7 px @390 / 45.1 px @1440 |

The mixed carousel keeps one stage height (225 px @390, 577.5 px @1440). There were 0
console errors. The single adjustment in bare mode is the designed learn-once behaviour for
legacy media with no metadata. It never reverses (0 reversals).

## Role badges (`scripts/qa/identity_badges_qa.mjs`)

Widths 390 and 1440, light and dark. Four posts whose authors state: artist; institution;
artist + verified; no role.

| Run | Result |
|---|---|
| 390 light, 390 dark, 1440 light, 1440 dark | 16/16 posts pass in each run |

- The badge is present only when the source states a role.
- Accessible labels: "Artist", "Institution", "Artist, Verified". The no-role author has no
  role text.
- The role words are part of the author row's single semantics label.
- Visual spot checks (coordinator): the 390 light feed, 1440 dark institution crop, and 390
  light artist + verified crop show the badge at the avatar's bottom-right corner, legible in
  both themes.

## Not covered

- Firefox and WebKit.
- Reduced motion.
- Real device video decoding (iOS Safari portrait playback).
- Badges on search, messages and share surfaces in the browser. These are covered by widget
  tests only (`test/widgets/identity/identity_surfaces_roles_test.dart`).
