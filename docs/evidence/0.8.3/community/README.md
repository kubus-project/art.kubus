# Community media and Art tab evidence (0.8.3)

This packet records rendered browser checks against local production web artifacts, using deterministic API and media fixtures. The Art-tab video run used immutable artifact `C:\kubus-build\083-web-3f6ee7bd`; its source report is `output/playwright/083-art-video-corrected/report.json`. The hashtag-state run used `C:\kubus-build\083-web-c5e1c419`; its source report is `output/playwright/083-art-hashtag-states/report.json`. The four geometry reports (`output/playwright/083-shapes-v2/{portrait,landscape,square,ultrawide}/report.json`) each name `C:\kubus-build\083-community\build\web` as their `webRoot`, so they are recorded separately as a mutable local build artifact rather than attributed to either immutable artifact. This evidence does not establish live backend acceptance, deployment, or release readiness.

## Video geometry, playback, and fullscreen

The four shape reports are under `output/playwright/083-shapes-v2/{portrait,landscape,square,ultrawide}/report.json`. Chromium and Firefox each exercised all four shapes in light and dark themes, English (US), reduced motion. At the fresh 390 px viewport, each browser/shape run recorded active unmuted fixture playback (`paused=false`, `readyState=4`), continued playback, and successful fullscreen entry. The seven widths (320, 360, 390, 430, 768, 1440, and 1920 px) are resized layout/overflow captures only; playback and fullscreen were not rerun at every width, and wide viewport resizing can cross back into the app shell. These checks used fixture media (portrait 180Ã—320, landscape 320Ã—180, square 240Ã—240, ultrawide 420Ã—180), not user uploads or a live service.

Representative rendered captures:

| Shape | Capture |
| --- | --- |
| Portrait | ![Portrait video playback in Chromium, dark theme](portrait-chromium-dark-action.png) |
| Landscape | ![Landscape video playback in Firefox, light theme](landscape-firefox-light-action.png) |
| Square | ![Square video playback in Chromium, light theme](square-chromium-light-action.png) |
| Ultrawide | ![Ultrawide video playback in Firefox, dark theme](ultrawide-firefox-dark-action.png) |

The Art-tab video route was checked at a fresh 390 px viewport in Chromium and Firefox against immutable artifact `C:\kubus-build\083-web-3f6ee7bd`. Both runs report active, unmuted fixture playback with no browser errors; see `output/playwright/083-art-video-corrected/report.json`. This report does not claim fullscreen or playback at the other resized widths.

![Art-tab video playing in Chromium](art-video-chromium-dark-action.png)

## Hashtag contrast and interaction states

`output/playwright/083-rerun-art-hashtag/report.json` records Chromium and Firefox light and dark theme captures of normal, hover, keyboard focus, and selected/filter states at 390 px, using immutable artifact `C:\kubus-build\083-web-90200b56`. The earlier Firefox attempt in `083-art-hashtag-states` failed because the chip was outside the visible/semantic target; the corrected rerun passes in both Firefox themes. The following representative set shows Chromium and Firefox light-theme states:

| State | Capture |
| --- | --- |
| Normal | ![Normal hashtag chip](hashtag-chromium-light-normal.png) |
| Hover | ![Hovered hashtag chip](hashtag-chromium-light-hover.png) |
| Keyboard focus | ![Focused hashtag chip](hashtag-chromium-light-focus.png) |
| Selected/filter | ![Selected hashtag filter](hashtag-chromium-light-selected.png) |
| Firefox normal | ![Firefox normal hashtag chip](hashtag-firefox-light-normal.png) |
| Firefox hover | ![Firefox hovered hashtag chip](hashtag-firefox-light-hover.png) |
| Firefox keyboard focus | ![Firefox focused hashtag chip](hashtag-firefox-light-focus.png) |
| Firefox selected/filter | ![Firefox selected hashtag filter](hashtag-firefox-light-selected.png) |

## Community media hosts

Corrected host checks use the immutable artifact `C:\kubus-build\083-web-90200b56` and deterministic local fixtures. The post-detail report is `output/playwright/083-host-post-detail/report.json`; profile posts after the Posts action are `output/083-profile-stage-diagnostic/report.json`; the fresh group-feed run is `output/playwright/083-group-feed-final/report.json`. The group route was reached through the Groups tab and accessible “Open group feed” action. The browser recorded `GET /api/groups?page=1&limit=20` followed by `GET /api/groups/{fixture-id}/posts?page=1&limit=30`; the screen showed heading “Fixture Group”, then the Visitor Artist portrait post and its media player. These routes and response shapes match `BackendApiService.listCommunityGroups` and `getGroupPosts` and the `CommunityGroupSummary` parser. Mixed video/image carousel playback is `output/playwright/083-mixed-media-stage/report.json`, and the corrected quoted/repost fixture is `output/playwright/083-quoted-media-corrected/report.json`. Chromium and Firefox at fresh dark 390 px showed active, unmuted video advancing for two seconds, and fullscreen controls changed to “Exit full screen” in each report. The mixed initial accessibility tree identifies `Media 1 of 2`, but the portrait video was visibly narrow inside a square 225×225 stage in this pre-fix artifact. A focused carousel fix now sizes active video slides from each URL's initially captured aspect and preserves the established image policy; rebuilt-artifact visual acceptance is pending. The quoted tree identifies the outer “Quoted art video” and nested “Original portrait video” by Visitor Artist; its compact stage does not expose a separate Media N of N label. These host reports establish fixture playback at 390 px only; they do not establish live backend behavior or playback at all widths.

![Mixed-media carousel video playing in Chromium](mixed-video-chromium-dark-action.png)
![Quoted original video playing in Firefox](quoted-video-firefox-dark-action.png)

## Limits and provenance

- The fixture runs block or stub write requests and do not submit Community content. API payloads and media are deterministic; no authenticated live Art feed was validated here.
- Cold legacy videos without a stored or supplied geometry hint still use the stable 16:9 fallback. Physical-device playback and audio acceptance remain pending.
- The user's three reported screenshots were not available in the workspace. Existing `G:/WorkingDATA/art.kubus/output/playwright/community-083-before-*` images are worker captures and are not treated as user-provided or approved baseline evidence.
- This packet includes a small sample of rendered screenshots; the source reports and full width/theme/browser captures remain in the checkout's `output/playwright` directories.
