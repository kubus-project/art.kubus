# 0.8.3 profile and artwork identity evidence

This evidence combines the earlier owner and visitor captures with new paired baseline/current browser runs. The captures use local immutable Flutter web artifacts and deterministic API/media fixtures. A fixture JWT is placed in browser local storage; no live account or backend mutation is involved.

The paired baseline is source `febffbe5b97b605a2fd04d9b48301c5fc13929ce`
(`main.dart.js` SHA256 `5D56D5D9C1580465A01EA90385B63370E6D14FAB51383FAE929E05EE452A2D0C`).
The paired current artifact is combined validation source
`90200b56eca0226bcc407de2027f3342b41fdf57`, including this PR's production
changes at `a6eaa287c290ed68f967d7ec81eaeb4f4d3ec01a`
(`main.dart.js` SHA256 `81A438299DD35B78C59DD79E53ED65D094710CEE46FBEF72D83F8D86D36C03CC`).
Machine-readable browser results are retained in [reports](reports/profile-after.json).
The source head `a6eaa287c290ed68f967d7ec81eaeb4f4d3ec01a` passed all required CI;
subsequent evidence commits require their own exact-head validation.

## Owner profile: baseline and current

At 390 px, Chromium and Firefox were run in dark theme with reduced motion and an `en-US` browser context. The same fixture-authenticated Community author was opened in both artifacts. In the baseline, the author route showed the visitor surface with Follow and Message. In the current artifact, canonical account resolution opened the signed-in owner surface with Edit profile, More options, and avatar editing. The mobile destination is the Profile tab.

| Capture | Evidence |
| --- | --- |
| [Baseline mobile owner click, Chromium](screenshots/mobile-owner-baseline-chromium-dark.png) | Baseline routes this clicked account to visitor actions. |
| [Current mobile owner click, Chromium](screenshots/mobile-owner-current-chromium-dark.png) | Current routes the same account to owner actions. |
| [Baseline desktop Community entry, Chromium](screenshots/desktop-community-baseline-chromium-dark.png) | Fresh 1440 px session showing Community before author navigation. |
| [Baseline desktop owner, Chromium](screenshots/desktop-owner-baseline-chromium-dark.png) | Owner profile opened inside the desktop shell. |
| [Current desktop owner, Chromium](screenshots/desktop-owner-current-chromium-dark.png) | Same desktop owner route with avatar-edit affordance. |

The desktop author-to-owner route already worked in the baseline and still works in the current artifact; this evidence does not claim a desktop routing correction. Chromium and Firefox reports cover both 390 and 1440 px. Current cases had no page errors or horizontal overflow.

## Recorded artist and return navigation

The artwork fixture stores the recorded artist separately from the uploader and sets `metadata.artistUserId` to the owner account ID. The baseline artwork detail shows the artist byline as plain text; the current detail exposes an accessible `Recorded Artist` button that navigates in-app to that artist's canonical profile. This preserves recorded cultural authorship and does not infer a relationship from the uploader.

| Capture | Evidence |
| --- | --- |
| [Baseline artwork, Chromium](screenshots/artwork-baseline-chromium-light.png) | Artist byline is not actionable. The baseline semantic lookup for a `Recorded Artist` button timed out. |
| [Current artwork, Chromium](screenshots/artwork-current-chromium-light.png) | Byline is an in-app button. |
| [Current artist-to-owner navigation, Chromium](screenshots/artist-to-owner-current-chromium-light.png) | The button opens the canonical owner profile with Edit profile. |
| [Current desktop Back result, Chromium](screenshots/artwork-back-current-desktop-chromium-light.png) | After visiting the artist profile, the in-app Back control returns to Artwork detail. |

The artwork comparison used Chromium at 390 and 1440 px, light theme, reduced motion, and an `en-US` browser context. Current cases had no page errors or horizontal overflow. The 1440 px Back check passed. Mobile correctly lands on the Profile tab; this pass did not assert a mobile Back control.

## Slovenian owner screen

A fresh current-artifact run covered 390 and 1440 px in both Chromium and Firefox, dark theme, normal motion, and a `sl-SI` browser context. The app was explicitly started with `?lang=sl`; navigation then used the visible localized Community control (`Skupnost` on mobile and `Poveži` in the desktop shell) before opening the fixture author. Every resulting owner action snapshot contained `Uredi profil`; the screenshots visibly show Slovenian controls and translated profile labels.

| Capture | Evidence |
| --- | --- |
| [Mobile owner, Chromium, Slovenian](screenshots/mobile-owner-current-chromium-dark-sl.png) | Profile tab with `Uredi profil` and Slovenian labels. |
| [Desktop owner, Chromium, Slovenian](screenshots/desktop-owner-current-chromium-dark-sl.png) | Desktop shell with `Uredi profil` and Slovenian labels. |

All four current Slovenian cases completed without page errors or horizontal overflow. Full browser reports and semantic snapshots are in `output/qa/identity-sl/mobile/` and `output/qa/identity-sl/desktop/`. Initial route-only probes are retained at `output/qa/identity-sl/` and `output/qa/identity-sl-route/`; they opened the default Map/Home surfaces, so the author control was absent. They are excluded from the four successful owner cases.

## Earlier captures and evidence limits

The earlier owner matrix recorded 16 browser/theme/browser-locale/motion contexts, and separate desktop captures started in Community. Those captures remain in `screenshots/`. The historical filename `mobile-owner-profile-firefox-dark-sl.png` is English UI: its `sl` suffix does not prove Slovenian translation. Treat the earlier locale dimension as browser-context coverage only. The independent Flutter profile visual matrix recorded 47 widget-rendered checks; those checks do not establish browser acceptance.

The corrected artist-owner browser pass was separately recorded as eight Chromium/Firefox cases at 390 and 1440 px in both themes. A focused identity/navigation/art-discovery suite was separately reported as 35 passing tests. Neither result substitutes for the rendered evidence above.

The baseline/current browser runner, reports and semantic snapshots are under `output/qa/identity-browser-baseline-current/`. Slovenian reports and snapshots are under `output/qa/identity-sl/`. These fixture runs do not prove live authentication, backend persistence, production deployment, or physical-device behavior. No original user reference screenshots were available in this session, so this set cannot be assessed against those missing references.

