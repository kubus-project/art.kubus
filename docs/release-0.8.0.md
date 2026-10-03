# art.kubus 0.8.0

art.kubus opens on the map. A first-time visitor lands in public discovery,
looks at art and places, opens an artwork or an artist, and is asked for an
account only when they want to save, follow, comment or contribute. Everything
else in this release serves that: a map that works from the whole world down to
a single street, a redesigned interface, public pages that open in the app, and
the spatial-memory work that was prepared for 0.8.0 earlier.

## Open the map first

- A fresh visit goes straight to public discovery. There is no alpha notice,
  welcome wall, role picker, wallet prompt or startup location and notification
  request in front of it.
- Saving, liking, following and commenting ask for an account and nothing else.
  Composing, messaging and creating markers also ask for a public profile.
  Creator, wallet and DAO actions keep their own, separate requirements. After
  signing in you return to where you were and confirm the action you started,
  which then happens exactly once.
- Going Back from an account step now returns to the page you were on and the
  address bar says so; refreshing there stays on that page.
- Sign-in and registration pages now follow your saved language (and `?lang=`)
  instead of always showing English.

## One map, from the world to a street

- On the web the map is a globe that flattens as you zoom in. On Android and iOS
  the same map is flat, with the same levels of detail.
- Far out you see light dots, closer the kubus marker, and close in a limited
  set of artwork covers. The marker you selected stays visible at every zoom
  level. Search, filters and radius show as chips you can clear one by one.
- Camera, search, filters and selection survive switching between the phone and
  wide layouts, and coming back from an artwork keeps the map as you left it.
- Covers load at the size they are drawn. In the measured browser session, image
  transfer for the same camera path fell from about 3.4 MB to 117–354 KB.
  Frame pacing on a real GPU matched the previous build. Physical-device
  performance was not measured.
- Opening a map link now zooms to the marker on Android; before, the marker was
  selected but the camera could stay at world scale.

## A redesigned interface

- One visual system across the app: Sofia Sans with selective Space Mono,
  a teal-first palette, authored layouts instead of generic card grids, and one
  icon per idea. Light and dark themes, English and Slovenian.
- Slovenian text across the app was corrected (missing diacritics) and kept at
  parity with English.
- An event or exhibition that no longer exists now says so and offers Retry,
  instead of showing an empty page with working-looking Save and Share.
- Destinations look and respond like the rest of the interface. Settings,
  security, account, wallet actions, programme entries, share and support links
  use the same authored tiles as Home instead of generic icon-and-chevron
  cards. With a mouse, tiles lift slightly, strengthen their edge and cast a
  soft shadow in their own colour; settings rows answer more quietly. With
  reduced motion nothing moves, and touch never shows hover.

## Public pages open in the app

- Artwork, artist, institution, event, exhibition, post and collection pages on
  `app.kubus.site` are server-rendered for search engines and readers, then hand
  over to the app without changing the address.
- On Android, localized links such as `/en/artworks/…` or `/sl/umetnine/…` open
  the installed app on the exact page. Collectible links stay in the browser,
  because the app has no public collectible page yet.
- Android verifies these links against an association file published with the
  web app. It lists the signing certificate of the APK published on GitHub.
  Builds distributed through Google Play may be signed with a different
  certificate and need it added before their links verify automatically.

## Spatial memory

- Create a spatial capture of an artwork, review it, and choose where it is
  reconstructed: on a paired kubus Node or on an eligible network GPU.
- Reconstructed results stay unpublished until you decide to publish them, and
  publishing adds only the selected variants to the public archive. Raw captures
  stay on your node.
- Spatial history appears as a timeline on the artwork, with a focused 3D viewer
  and clear processing, failure and recovery states.

## Fixes

- Opening a public link from a cold start selects the requested marker instead of
  an unrelated one.
- Funnel counts: events that should happen once per session (app entry, first map
  engagement) no longer repeat when the page is reloaded.

## Known limits

- Android and iOS use the flat map; the globe is web-only. iOS was verified only
  by a release compile, not at runtime.
- Android behaviour was verified on an emulator, not on a physical device.
- Only Map and Community have their own addresses. Other tabs return to the map
  when the page is refreshed.
- A page opened from inside the app keeps the address of the page it was opened
  from, so a refresh returns there. Opening a page by its own link keeps that
  link.
- Settings, Wallet and Marketplace addresses open the map for signed-out
  visitors.
- When the service is unreachable the map shows no offline notice.
- Signed-in, creator and institution screens were checked through the automated
  test suites and, for the destination tiles and settings, through fixture
  screenshots (`docs/evidence/product-v5-tile-system`), not on production data.

## Verification and deployment

Promotion goes through the repository's protected matrix: Flutter analysis and
tests, release web build with Chromium and Firefox smoke, unsigned Android and
iOS release compilation, backend compatibility, routing, documentation,
provenance and security checks. The mobile release is created only from the
production branch after the documented `dev`-to-`master` promotion.

The backend that accepts the new first-map-interaction event
(art.kubus-backend `30a20b83`) is deployed before the web and mobile builds
that send it; an unknown event name would otherwise be rejected with its whole
batch. Mobile build numbers are derived by CI from the build date and run
number, so the Android versionCode is above the v0.7.4 value of 262220006.
