# PRODUCT v5 semantic visual system (Wave 5A-S)

Wave 4 simplified PRODUCT (flat surfaces, no nested glass). Wave 5A-R gave
it back its character (ghost glyphs, contextual fields, hub header bands).
Together they left one habit behind: the same idea was often said two or
three times on one surface, usually as a small icon box next to a label
that already named it, beside a large glyph that named it again.

This page is the contract for that pass. It amends the "Contextual icons"
and "Stats" sections of `PRODUCT_V5_ART_DIRECTION_RESTORATION.md` and
`PRODUCT_V5_CHARACTER_REBALANCE.md`. It describes what is implemented; it
changes appearance and composition only. Navigation, data, backend calls,
role resolution and DAO behaviour are unchanged.

## The rule

**One semantic idea, one primary expression.**

Every element on a surface carries one of these roles:

| Role | Says | Typical expression |
| --- | --- | --- |
| Content | the thing itself | value, title, body text, media |
| Identity | what kind of thing / where | one glyph, one colour, one label |
| Status | the current state | status line, chip, check, warning icon |
| Affordance | what you can do | button, arrow, chevron, link |
| Progress | how far along | stepper, readiness bar, count |
| Atmosphere | mood, never information | contextual field, cropped ghost glyph |

Two elements may sit together when they carry **different** roles
(`ARTIST` + verified check: role + verification; a title + an arrow:
destination + navigation). Two elements carrying the **same** role for the
same thing are a duplicate: keep the stronger one and remove the other.

## Icons

- An icon must add information the text beside it does not. Search, back,
  arrows, chevrons, expand/collapse, upload, warning, verified, map/location
  and per-item category glyphs in lists all qualify.
- A small icon tile next to a heading that already names the section does
  not qualify. Section headings are typographic (Sofia Sans weight/size and
  spacing carry the hierarchy).
- A status chip owns its state icon. A header beside it does not repeat it.
- An icon-only control or badge carries a semantic label, because there it
  is the only expression.

## Ghost glyphs

`KubusGhostGlyph` is atmosphere that doubles as identity, so it is the
*only* identity layer where it appears:

- cropped past the trailing edge, low opacity, behind the content;
- wrapped in `IgnorePointer` + `ExcludeSemantics` (never announced, never
  tappable);
- never under a value or label it could obscure; a bounded `extent` keeps
  it in the corner on tall cards;
- never paired with a small foreground copy of the same symbol.

## Components

### `KubusActionTile` (destination shortcut)

| Layout | Composition |
| --- | --- |
| Stacked (phone grid) | title at the bottom-start, destination ghost glyph top-end, destination field; no foreground icon box |
| Inline (desktop strip) | title + arrow; no destination icon |

- No coloured hover glow; hover answers inside the tile only.
- Inline width: content-sized up to `KubusActionTile.inlineMaxWidth`
  (280 px x text scale); a narrower parent always wins; long titles wrap to
  two lines inside the cap. Stacked tiles ignore the cap.
- Speaks its title as a button.

### `KubusStatCard` (metric tile)

- Expressive (centred grid): value, label, and the metric ghost glyph as the
  single identity layer. No foreground metric icon.
- Dense (standard row): one compact context tile leads the row, because a
  cropped glyph is illegible at that size. No ghost glyph.
- The value is primary and never ellipsised (it scales down if wider than
  the tile); the label wraps. Hover moves the glyph and field, never the
  value. Reduced motion keeps the brightening and drops the drift.

### Analytics overview (not a destination tile)

Analytics metrics are data, so they are not `KubusActionTile`s.

| Card | Identity | Selection | Layout |
| --- | --- | --- | --- |
| Lead (selected metric) | metric ghost glyph in the trailing corner | accent border | label, value (34 px), trend + period, stacked in flow |
| Supporting | 8 px colour key before the label (the chart series colour) | border on hover | label (2 lines), value (20 px) with trend at the trailing end |

- No icon tiles on either card.
- Supporting cards sit in **measured rows** (`IntrinsicHeight` per row),
  not an aspect-ratio grid, so 200 % text grows the row instead of pushing
  the value out. Columns come from the width the overview actually gets:
  3 from 840 px, 2 from 520 px, else 1.
- The trend arrow scales with the text it qualifies.

### Dashboard headers (Studio, Institution Hub, DAO, Marketplace)

- `KubusDashboardHeader` is the page title: notion, title, lede, ghost glyph.
  No icon tile next to the title.
- On mobile the app bar carries actions only. The hub title (and any Lab
  marker) is said once, by the header.
- The lede adds information; it does not restate the title
  (DAO: "Experimental decision-making for artists, institutions, and
  cultural participation").

## Profiles

- Role pills (`ArtistBadge`, `InstitutionBadge`) are the role word in the
  role colour. No brush/building glyph inside the pill. The icon-only
  variant (dense headers) keeps the glyph and announces the role.
- Verification, relationship and activity indicators stay: they are other
  information.
- Empty sections are heading + one `EmptyStateCard`. No `DesktopCard`
  around an `EmptyStateCard` or around a `KubusStatCard`.
- The bio inside the mobile identity card is plain text, not a framed box;
  artist facts render only when there are some.
- Empty saved artworks: the empty state carries the one action (Saved
  items); the header has no subtitle repeating the empty description and
  there is no second "View all".
- "Profile badges" / "Wallet badges" and "Account health" headings are
  typographic; every badge or notice under them has its own glyph.

## Wallet

Ownership is explicit:

| Concern | Owner (desktop) | Owner (mobile) |
| --- | --- | --- |
| Signer / session state | header status line | identity panel |
| Network | header network selector | identity panel |
| Refresh | header action | none (unchanged; loads on open) |
| Receive / Send / Swap | quick actions (rail or inline row) | Actions section |
| Custody status | rail from 1200 px, else after the asset list | side column / own panel |
| Balances summary | balance hero (KUB8 lead, SOL) | balance hero |
| Token inventory | Assets tab | "Wallet tokens" section |

- The header has no subtitle: it would repeat the signer state and network.
- Action tiles keep their action subtitle; they do not restate the signer
  state (tapping still runs the guard that explains it).
- The mobile balance hero summarises; the inventory is its own section and
  is the only place each token is listed. KUB8 canonical-mint resolution,
  metadata-image-first avatars, lattice fallback and impostor handling are
  unchanged.
- `WalletCustodyStatusPanel`: title + one state chip. No state icon tile
  beside the title (the chip owns the icon).

## Duplicate CTA rule

Within one workspace composition there is one primary action for one
intent.

- Artist Studio / Institution Hub (mobile): the application panel owns the
  review CTA and is state-aware (apply, pending, resubmit). The locked
  surface explains the lock ("Institution Hub is locked" + what unlocks)
  without a button.
- Desktop (no application panel): the locked surface carries the CTA,
  except while a review is pending.
- Artwork editor: an empty cover slot offers one "Upload cover" button. The
  header's replace action appears only once a cover exists.

## Repeated-heading rule

One primary title per page. A secondary heading must add information.

- Desktop Web3 onboarding: the step list is headed by the flow name only
  when no step already carries it (DAO step 1 is "Community governance",
  so the panel title is dropped).
- Mobile hubs: app bar title removed where the dashboard header shows it.

## Container discipline

A container needs a reason: grouping, interaction boundary, media boundary,
status boundary, or hero/context field. Not allowed: card in card, empty
state card in a section card, glass in glass, panel in a tinted panel.

The marketplace empty state sits on the same page gutter (32 px) and starts
where the first result row would, not centred in the window.

## Utility surfaces

Settings, forms, search, messages and public detail stay flat and quiet
(the 5A-R contrast is kept). Settings sections are `title + children`, no
icon or colour per section.

## Responsive and text-scale contract

- Checked at 320, 390, 1280/1440 px and 1.0x, 1.3x, 2.0x text.
- No fixed heights for text-bearing tiles; measured extents or intrinsic
  rows.
- Numbers scale down rather than ellipsise; labels wrap (2 lines, 3 at
  large text).
- Touch never depends on hover. Reduced motion is respected.

## Copy

Slovenian strings that had lost their diacritics were corrected
(`homeRailsUnavailable*`, institution application fields,
`marketplaceSettingsShowArOnlyTitle`, `communityGroupPickerJoinFirstToast`).
Tone and meaning unchanged.

## Evidence

- `test/design/product_v5_semantic_contract_test.dart`: analytics 200 %
  matrix, one identity layer, role badges, wallet ownership, single CTA,
  editor upload, DAO title, profile nesting.
- `test/widgets/common/kubus_action_tile_test.dart`,
  `kubus_stat_card_test.dart`: component contracts.
- `test/qa/product_v5_semantic_visual_matrix_test.dart`: 51-scene
  BEFORE/AFTER matrix with real Sofia Sans and Space Mono
  (`KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after`).
