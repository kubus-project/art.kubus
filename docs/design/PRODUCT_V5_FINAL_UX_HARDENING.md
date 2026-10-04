# PRODUCT v5: final 0.8.0 UX hardening

The last visual pass before the 0.8.0 release. It follows the tile system
([PRODUCT_V5_TILE_SYSTEM_INVENTORY.md](PRODUCT_V5_TILE_SYSTEM_INVENTORY.md)) and
fixes the places where the shipped screens still did not read as one authored
product: the public profile, Home entity cards, the Artist Studio, the DAO hub,
kubus Node, account entry and the map marker face.

Evidence screenshots are in
[`docs/evidence/product-v5-final-hardening/`](../evidence/product-v5-final-hardening/).
They are produced by the opt-in matrices listed at the end of this file, from
fixtures only (no network, no production data).

## What changed, by surface

### Public profile

One identity hero (`ProfileIdentityHero`): the cover, an avatar that overlaps its
lower edge, a glass identity plate with name, full handle, role and verification,
and Follow / Message inside the hero. Below it the order is practice and bio,
portfolio (an artist's work or an institution's programme), public art the
account added, a **bounded** preview of recent posts (two on a phone, three on a
wider column, then "View all posts"), achievements, and the large `KubusStatCard`
composition last. Posts are bounded on purpose: an unbounded feed above the stats
would make the bottom of the page unreachable.

Fixed in the visual pass:

- Sections on the public profile padded horizontally *again* inside a page column
  that already pads, so the portfolio and events sat a full gutter inside the hero,
  bio and stats. They now share the page gutter.
- The artist's events showed "Events" as a header and then again as the section's
  own title. One header now carries the subtitle.
- The desktop posts section printed "Posts" twice. `ProfilePostsPreviewSection`
  has a `showHeading` switch and the desktop host turns it off.
- The avatar fallback showed the wallet's first character ("7") in a 14 px label.
  `AvatarWidget.displayName` now drives the initials, and profile-sized avatars
  scale their label with the mark.

### Home entity cards

`KubusEntityCard` is the one preview grammar for artworks, artists, institutions,
events and collections, on Home rails, the profile portfolio and the studio
gallery. Image-led where there is media; where there is none the card is a
**role field**: the entity's own accent in the ground and in the scrim, with its
glyph, instead of the neutral grey wash it used to fade to. Identity cards carry
the account's avatar or logo against the cover.

### Artist Studio and the artwork editor

The gallery is an image-led adaptive grid (390 px: one column, 768: two, 1440:
four, 1920: five). The editor has exactly one chrome owner, chosen by the caller
with `ArtworkEditChrome` (`standalone` owns an AppBar, `workspace` owns the single
creator-shell header, `bodyOnly` owns nothing), so there is one title and one back
affordance.

### DAO

Header numbers stay `KubusStatCard`, proposals stay content. The earlier pass
printed Treasury, Delegation, Voting history and Create proposal as action tiles
directly under tabs of the same names, which is the same navigation twice. They
are gone. The one thing that is a task and not a place, **Create proposal**, is
offered as an action tile when there is nothing to vote on, gated exactly as its
tab is.

### kubus Node

- **Discoverable.** A desktop destination after Digital editions, and a card on
  the mobile capability strip that already carries Studio, Hub, DAO and
  Marketplace. Not a sixth bottom tab. Both follow the `availabilityNodes`
  rollout flag.
- **Its own identity, no wallet gate.** `web3NodeAccent` is distinct from the
  wallet's colour, and opening Node never routes through wallet onboarding:
  pairing a Node is runtime ownership against the account, not a signing action.
  A wallet is still required wherever an action genuinely needs wallet authority.
- **One front door.** My Nodes had five controls that all meant "connect". It now
  has one primary action (Connect a Node, the one-time handoff) and one quiet
  alternative for a Node that cannot be scanned. States say only what is true:
  looking, Nodes on this account (each with its reachability and a Connect that is
  disabled when the Node cannot be reached), a failed lookup said as itself and
  never as "no Nodes", and the empty state.
- **No implementation leakage.** Nothing in the normal path mentions
  `NODE_GUI_TOKEN`, a shell command or an operator token (a test asserts it).
  Operator identity and credentials remain under Security & Setup, Advanced
  operator setup, as recovery.
- **Hosted in the desktop shell with `embedded: true`**, so the shell is the single
  chrome owner and the dashboard keeps refresh in its own header.

### Account entry (auth)

Account entry is a legitimate atmospheric surface. Sign in, Register, Forgot,
Reset, Verify and Secure account share one `AuthAtmosphere`, a restrained
`KubusAtmosphere` (family teal from one corner, information blue from the
opposite one, full bleed, no glyph) over the plain ground, so the family is one
place and the form keeps ordinary contrast. Five screens previously carried their
own older animated gradient and the shell itself had drifted to a flat colour.

### Map marker face

The category silhouettes are the semantic language and are unchanged (rounded
square, diamond, arch, pill, hexagon, capsule, portal hex, circle; asserted in a
test). The face is what changed:

- the body carries a restrained directional field (slightly lighter at the upper
  left, slightly deeper at the lower right);
- the glyph is large and sized per silhouette (a diamond or a pill has far less
  room than a hexagon) and is painted with a tonal gradient from the category
  colour rather than flat black or white;
- the theme polarity is kept (light glyph on the light map, dark on the dark one)
  but is a starting point: the tint must clear 3.2:1 against the body, and where a
  category colour cannot carry that polarity (amber, yellow) the opposite is used.
  A test sweeps every category in both themes;
- a mixed cluster's central body is its dominant category's silhouette, not a
  generic circle, with the other categories orbiting as pips that use the same
  treatment; a single-category cluster takes the same field and a larger glyph;
- a cover is still the photograph clipped inside the same silhouette.

Cluster icon ids move to renderer `v3`. Icons are rendered once per distinct id
and cached, never per frame or during a gesture; rendering one now costs about
1.8 ms where it cost 1.0 ms. LOD thresholds, the cluster architecture, the cover
work gate, anchors and the hover/selection scales are unchanged.

## Last-mile polish (after #223 merged)

- **Shadow-safe action strips.** Every horizontal strip of `KubusActionTile`
  (Home Web3, Home quick actions, desktop Home quick actions) now uses one
  `KubusShadowSafeStrip`: vertical room is padding inside the viewport, the
  sideways room is an outer clip inflated by 14 px (never past the page gutter),
  and the last tile has 14 px of trailing room. The first tile stays on the
  content edge and the lift is unchanged. Tests cover the first and last tile
  at 320, 390, 768 and 1440 px.
- **Post author avatar.** `ProfileIdentityData.avatarInitialsSource` takes the
  display name, then the username, then the handle, and never a wallet or a
  shortened wallet, so a post card no longer shows "7". Avatars still do not
  fetch profiles for a display-only identity.
- **200 % text scale.** `a11y200-*` captures: sign in, register, forgot, verify
  (light and dark), My Nodes (no node, discovered), the Node home, the operator
  setup screen (the Advanced / Recovery path) and the Node capability entry.
  No render error or overflow in any of them. Buttons keep their own text size.
  The operator screen's section tabs scroll sideways by design. The paired-node
  "Technical details" disclosure needs a paired fixture and was not captured.
- **Map QA, phone theme switch.** Not a user-facing bug. On the real GPU the
  product layers are back within 2.5 s of the switch. On SwiftShader the phone
  viewport needs up to about 17 s, and the check waited a fixed 4.5 s. The check
  now waits for the layers (45 s ceiling) and records the time. It failed
  identically on dev, whose tree equals #223's head.
- **Map QA, 1440 dark cover latency.** A flake: it passed on two consecutive
  reruns (first cover after about 2.2 and 3.8 s). It depends on API and image
  timing, not on the renderer.
- **Map performance.** Same fixture, dev against this branch, five runs per
  cell. Real GPU (RTX 3080 Ti): p95 16.8 ms in both at 1440 and 390, p99 33.4,
  `_render` p95 3.4 / 2.8 ms, `readPixels` 86 vs 89 calls (cover reads, not
  gesture reads). SwiftShader: p95 83.3 vs 83.2 ms at 1440 and 116.7 vs 116.6 ms
  at 390, within run-to-run spread. Marker faces are generated once per id and
  cached.

## Known limits of the evidence

- Fixtures cannot load network imagery (`flutter test` answers every HTTP request
  with 400), so cover and artwork photographs appear as the no-media role field.
  The marker sheet uses a generated stand-in photograph, so a cover clipped inside
  each silhouette is shown. Real production media was not visually tested.
- No physical Android device was available and the emulator pacing run was not
  repeated for this pass, so there is no physical-device evidence; the map
  numbers above are desktop Chromium on a real GPU and on software GL.
- The 200 % captures are Flutter-rendered fixtures, not a 200 % browser zoom.

## How to regenerate the evidence

```
KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_final_hardening_visual_matrix_test.dart
KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_marker_face_visual_test.dart
KUBUS_RUN_VISUAL_QA=1 flutter test test/qa/profile_visual_matrix_test.dart
KUBUS_RUN_VISUAL_QA=1 flutter test test/qa/home_rail_visual_matrix_test.dart
```
