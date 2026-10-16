# Globe and location rendered evidence — 0.8.3

The final responsive packet uses immutable combined web source
`90200b56eca0226bcc407de2027f3342b41fdf57`, containing PR #300's production
changes at `1febf6b27527ee9b85965a10c0aa9d50f433b945`.
`main.dart.js` SHA256:
`81A438299DD35B78C59DD79E53ED65D094710CEE46FBEF72D83F8D86D36C03CC`.
The reference build is `febffbe5b97b605a2fd04d9b48301c5fc13929ce`.
These are local production builds, not deployed or owner-accepted releases.

## Root causes and implementation

The existing WebGL fallback CSS used `background-color: var(--kubus-map-fallback)
!important`, overriding the intended inline globe color. A CSS-property-only
probe initially missed this: the screenshot exterior remained pale blue/teal.
The fallback variable is now scoped to the map's exact theme ground, and the
browser check reads the computed value. Inspected 390 px PNG pixels outside
the globe are `(255,255,255)` in light and `(0,0,0)` in dark, in both engines.
The earlier `083-globe-accepted-candidate` matrix is superseded for background
acceptance despite its historical folder name.

The solar model and projected night-region geometry follow the website source
at `art.kubus.site@97471111567fcb9c1fe9e600fac3a2164c99b4ec`. A single decorative,
pointer-transparent pass follows the existing MapLibre camera. Real UTC advances
the subsolar position at a one-second cadence; theme affects the ground only.
Projection retries are bounded, and hidden/local-map/reduced-motion states stop
the repeating solar clock. A reduced-motion state freezes a correct current sun
position and still reprojects it when the camera changes. Presentation activity
is scoped to the current map owner, so disposal of a prior responsive layout
cannot pause its replacement.

Location uses one real point, a contrasting central dot, separate measured
accuracy, a paint-only pulse, and one screen-sized heading symbol. The existing
animator smooths reliable device headings through north. Mobile and native
Android/iOS desktop layouts share the sensor/reliability policy; unsupported web
heading stays absent. Walking course and camera bearing never manufacture device
heading. The unused mobile cone painter was removed.

## Browser verification

[Responsive results](reports/responsive-solar-location.json): **16 contexts,
840 checks, zero failed**, Chromium and Firefox × light/dark × actual EN/SL ×
normal/reduced motion. Each context captures 320, 360, 390, 430, 768, 1440 and
1920 px globe and local-location views. The explicit app language is selected
through `?lang=`, and rendered translated text is asserted. Historical matrices
that set only the browser locale do not prove Slovenian UI coverage.

Checks cover exact computed ground, evolving/static solar coordinates, globe →
local → globe transitions, accuracy/pulse policy, layer rotation, horizontal
overflow and console health. Dateline/north/south polar views retain finite fitted
solar fields. Polar camera probes may show a cropped globe at their requested
zoom; this packet does not claim full-globe framing at every latitude/zoom.

Offscreen checks wait for actual IntersectionObserver delivery, then verify the
solar coordinate remains unchanged over 2.2 seconds and resumes when visible.
An earlier probe sampled before asynchronous visibility delivery and failed;
those results are excluded from the final matrix. Browser tab/background and
native lifecycle acceptance are separate from this renderer visibility probe.

| View | Before / after |
| --- | --- |
| Light globe | [Reference](screenshots/before-light.png) / [Corrected](screenshots/after-light.png) |
| Dark globe | [Reference](screenshots/before-dark.png) / [Corrected, Slovenian](screenshots/after-dark-sl.png) |
| Desktop | [Light, Slovenian](screenshots/desktop-light-sl.png) / [Dark](screenshots/desktop-dark.png) |
| Polar projection | [Rendered field](screenshots/polar-view.png) |

The [reference probe](reports/baseline-negative-controls.json) intentionally fails
new solar/location assertions because those layers are absent in the older build;
its globe screenshots are regression evidence, not passing acceptance or approved
visual baselines. No original user screenshot attachments were available.

## Location motion and direction

[Focused renderer results](reports/location-renderer.json) recorded eight
Chromium/Firefox × theme × motion contexts at 390 px. Browser geolocation supplied
an emulated fix with 15 m accuracy. Over a 450 ms pulse interval the source had
**zero writes**: normal motion changed the paint radius; reduced motion retained
the static dot/pulse policy. No heading appeared on the browser's location data.

- [No-heading reduced-motion fallback](screenshots/reduced-no-heading.png)
- [Synthetic heading east](screenshots/synthetic-heading-east.png)
- [Same heading after map bearing rotation](screenshots/synthetic-heading-bearing.png)
- [Pulse and synthetic heading video](emulated-location-and-synthetic-heading.mp4)

The video shows an emulated location and explicitly injected 0°/90° renderer
headings, including a 90° map bearing. It establishes symbol/pulse presentation;
it does **not** establish physical compass accuracy, heading reliability, GPS
accuracy, device permissions or native lifecycle behavior.

## Tests and remaining gates

32 focused Flutter map/location/style tests, two Node solar/geometry tests and
full combined Flutter analysis passed. The shared required PRODUCT motion gate
also received a bounded measurement fix: CI diagnostics showed ~4.9 s Firefox
screenshots, so a 60 s cap stopped at 12–13 samples. The cap is now 90 s with a
conservative recent capture estimate; the minimum 14 samples, 2.2 s observation
span, painted lift/bob/shadow/exit thresholds and reduced-motion rules remain
unchanged. All six sampler unit tests pass. Required full CI must validate the
final head; a local matrix is not a replacement for it.

Physical Android/iOS heading, approximate/stale GPS, actual permission prompts,
background/foreground and device interaction acceptance remain outstanding.
No physical device was attached during this pass. No merge, deployment, active
0.8.2 release mutation or production acceptance is implied.
