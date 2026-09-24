# Wave 2B visual acceptance — PRODUCT v5

This is the refreshed Wave 2B visual evidence after the PRODUCT v5 token foundation. It supersedes the pre-v5 screenshots in `output/playwright/wave2b/` for current acceptance review.

## Capture identity

- App source commit rendered: `c23c776b748627e81bb6c0d0e8d40d09612deefe` (`2026-09-24`)
- Stack base at capture: `749a1e73092fce3a39ff9edc2a5cb80d0a4a254b` (PR #179)
- Captured: `2026-09-24T08:12:56.524Z`
- Browsers: Chromium and Firefox, 71 matrix cases each
- Screenshots: 294 PNGs; `visual-matrix.json` records the cases and uses screenshot names relative to this directory
- Local preview: `http://127.0.0.1:4184`; fixture API responses are public-only local data
- Preview Flutter web bundle SHA-256: `c662332761d9dc81d57ef48d946359d0f2c7f43e92f784f6c36438edfe2c0843`
- Fixture identity: synthetic public-only local preview fixtures. The IDs in the matrix are fixture IDs, not production records. These screenshots do not establish production entity behavior.

The artifact can be recaptured from the same local public preview and built app with:

```powershell
$env:SEO_PREVIEW_URL='http://127.0.0.1:4184'
$env:QA_ARTIFACT_DIR='output/playwright/wave2b-v5-c23c776b'
$env:WAVE2B_SOURCE_SHA='c23c776b748627e81bb6c0d0e8d40d09612deefe'
$env:WAVE2B_BROWSERS='chromium,firefox'
node scripts/qa/wave2b_visual_acceptance.mjs
```

## Matrix covered

`visual-matrix.json` is the machine-readable record. It contains 142 cases: 70 SSR with JavaScript disabled, 62 exact Flutter takeovers, four EN/SL long-text responsive groups, two slow/failed Flutter groups, two 195 CSS-pixel simulations, and two browser-zoom attempts. The 195 CSS-pixel simulation at DPR 2 is explicitly not browser zoom.

- Artwork: EN and SL, 390×844 and 1440×900, both themes, SSR and Flutter, Chromium and Firefox.
- Artwork breakpoints: 900, 1024, 1280 and 1440 CSS pixels; the separate widget route regression tests cover 390, 899, 900 and 901.
- Long EN/SL titles and attribution: 320, 360, 390 and 430 CSS pixels in both browsers.
- Profile/artist and institution profile: representative compact and desktop routes, EN/SL and light/dark, SSR and Flutter.
- Event and exhibition: representative compact and desktop routes, SSR and Flutter.
- Collection, post, marker and collectible: public-route SSR smoke only. A production collectible fixture does not exist in the Wave 1 audit, so the collectible route is synthetic smoke evidence only.
- Slow Flutter, blocked Flutter bundle, reduced motion, keyboard focus, takeover accessibility ownership and direct canonical-route behavior are represented in the matrix.

Every row records source SHA, browser, viewport, theme, locale, entity type and fixture ID, fixture scope, SSR/Flutter state, JavaScript state, reduced-motion preference, zoom mode, route and screenshot references. The two after-takeover keyboard-focused screenshots are linked from the matching artwork takeover rows.

Selected paired review files:

- Artwork desktop, EN/light/Chromium: [SSR](artwork-en-1440-light-ssr-chromium.png) / [Flutter](artwork-en-1440-light-flutter-chromium.png)
- Artwork mobile, EN/light/Chromium: [SSR](artwork-en-390-light-ssr-chromium.png) / [Flutter](artwork-en-390-light-flutter-chromium.png)
- Artwork mobile, SL/dark/Firefox: [SSR](artwork-sl-390-dark-ssr-firefox.png) / [Flutter](artwork-sl-390-dark-flutter-firefox.png)
- Artist desktop, EN/light/Chromium: [SSR](artist-profile-en-1440-light-ssr-chromium.png) / [Flutter](artist-profile-en-1440-light-flutter-chromium.png)
- Institution mobile, EN/light/Chromium: [SSR](institution-profile-en-390-light-ssr-chromium.png) / [Flutter](institution-profile-en-390-light-flutter-chromium.png)
- Event mobile, EN/light/Chromium: [SSR](event-en-390-light-ssr-chromium.png) / [Flutter](event-en-390-light-flutter-chromium.png)
- Exhibition mobile, EN/light/Chromium: [SSR](exhibition-en-390-light-ssr-chromium.png) / [Flutter](exhibition-en-390-light-flutter-chromium.png)

## Artwork acceptance

| Check | Result | Evidence and observed delta |
| --- | --- | --- |
| A. Media remains the dominant anchor | PASS | At desktop 1440, SSR media is approximately x=136, y=99, 638×648; Flutter is approximately x=136, y=100, 634×632. At 390, both media frames begin at x=16 and y≈69 and remain the first visual anchor. |
| B. Title hierarchy and location stay comparable | PASS | Desktop title begins around x=832, y=137 in SSR and x=828, y=123 in Flutter. The ~4 px horizontal and ~14 px vertical difference keeps the title in the same right-hand context column and at comparable prominence. Mobile title/byline begin at the same point after the media. |
| C. Cultural artist attribution stays consistent | PASS | Both frames identify Maja Novak as the artist. Flutter's concise “by Maja Novak” is the same cultural attribution; no profile/account identity replaces it. |
| D. Page stays on the same datum | PASS | Desktop media left edge has 0 px horizontal shift in the reviewed pair; the primary content edge remains about x=136 and the shell/header rule about x=112. The former persistent-rail offset is absent in route-bound public-entry mode. |
| E. Compact pages have no unintended horizontal clipping | PASS | Browser metrics report document/body widths equal to the viewport, Flutter bounds x=0 through viewport width, and zero overflow offenders at 320, 360, 390 and 430 for long EN and SL content, in both browsers. The 390 canonical route selects `ArtDetailScreen`; desktop begins at 900. |
| F. Flutter feels like the same entity screen becoming interactive | PASS | Media, identity, attribution, location and reading surface remain in the same composition. Flutter adds native actions while retaining the artwork anchor. Its action cluster is richer and appears before the description; SSR exposes a map link after the description. This is an additive interaction difference, not a shell-induced content shift. |

The measured tolerance for this comparison is perceptual rather than pixel-perfect: keep the media and title in the same columns, with no shell-driven horizontal displacement; small vertical and media-size differences up to about 20 CSS pixels are acceptable when the identity order and first-frame anchor remain stable. The observed artwork pair is inside that tolerance.

## Other public-entry review

- **Artist profile — PASS.** The artist identity and public cover retain the SSR left-identity/right-media arrangement at desktop (cover x≈832 in SSR and x≈829 in Flutter). Flutter adds the handle/artist role and follow/message controls without replacing the artist identity.
- **Institution profile — PASS.** Institution name, role/context, location and description precede the same cover on compact and desktop. Flutter adds the existing profile handle and follow/message actions; the compact cover begins at approximately the same position as SSR.
- **Event — PASS with additive-action difference.** Title and date/place/context order remain stable, and desktop keeps the poster in the same right-hand media region. On compact, Flutter's poster starts about 70 CSS pixels earlier than SSR; its metadata and description remain in the same order. Flutter exposes its available native actions around the media, while SSR supplies the plain map link.
- **Exhibition — MINOR parity difference, non-blocking.** Desktop identity/media geometry is aligned. Compact Flutter adds related content before the cover, so its cover begins lower than the SSR cover; identity, date/place and description remain ahead of it. This is an additive related-content section and does not displace the title or media column.
- **Collection, post, marker, collectible — route smoke only.** The matrix does not claim a Flutter presentation pass for these types. The collectible case is synthetic because Wave 1 measured no public production collectibles.

## Handoff, failure and accessibility

- JavaScript-disabled pages remain readable and actionable.
- During slow Flutter loading, SSR remains visible and accessible until exact entity readiness. When the Flutter bundle is blocked, the server document remains visible and the Flutter host stays hidden.
- At exact takeover, the server document becomes inert/hidden from the accessibility tree. The focused keyboard screenshots show a visible focus outline; the matrix checks the semantic action after ownership changes.
- Reduced-motion preference is enabled for the matrix; the takeover is not dependent on an animated transition.
- The canonical path remains the requested entity path. No redirect or path rewrite was observed.

### Real 200% browser zoom

**REAL 200% BROWSER ZOOM UNVERIFIED.** The harness attempted the browser shortcut in Chromium and Firefox and checked `innerWidth`, DPR and `visualViewport.scale`; neither automation browser reported a zoom change. The separate 195×422 CSS viewport simulation is not equivalent and is not represented as a zoom pass. A manual headed-browser check remains the only environment-limited visual acceptance item.

## Desktop public-entry shell

The original ~108 px desktop displacement came from the ordinary persistent navigation rail reserving horizontal space after Flutter takeover. The current implementation uses the existing route-bound canonical public-entry state for the exact requested entity, and suppresses that rail reservation during its first entity frame. It does not infer public entry from width, referrer, user agent or a timer. The route state test covers activation and return to ordinary shell behavior. The ordinary app shell and routing architecture remain in place.

## Superseded evidence and handoff

The 56-case screenshots in `output/playwright/wave2b/` predate PRODUCT v5 and are retained only as history. See its README notice before using those files.

Wave 1 measured 9,048 public artworks and 9,049 public markers; all 9,049 markers link to artwork, and all 9,049 pairs were independently index-eligible. No standalone semantic markers were identified. Canonical/index ownership remediation remains a later policy-package handoff and is not changed here.

No indexing policy, canonical ownership, Android App Links, map architecture, production data, deployment state or merge state was changed by this visual pass.
