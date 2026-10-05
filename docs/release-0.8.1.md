# art.kubus 0.8.1

A corrective release for visible problems that survived 0.8.0: the map's
markers and covers, Home artist and institution covers, the profile header,
the account-security screens, the governance numbers and the kubus Node
entries. It also closes the last gaps in opening public links without an
account, and keeps a page's authorship and title truthful once the app takes
over from the server-rendered page. The Node connection did not change.

## The map

- **Groups make more sense far out.** Markers now group across a wider area
  when you are zoomed out and separate gradually as you approach a place. At
  the scale of a region you see a few clear groups instead of dozens of small
  ones (Slovenia at zoom 7: 11 groups where 0.8.0 showed about 25).
- **Artwork covers appear much earlier.** 0.8.0 showed covers only from street
  level (zoom 15). Now:
  - the marker you selected shows its cover from city scale (zoom 10);
  - a few nearby covers appear as you approach a neighbourhood (zoom 12.5);
  - more appear as you get closer, and the full set at street level.

  Covers start downloading just before they are needed, only while the map is
  still, and are fetched at the size they are drawn. Wide (landscape) covers
  are downloaded with enough width to fill the marker face without looking
  soft.
- **Bounded and cancellable.** Cover memory is capped, visible covers are
  loaded ahead of warm-up prefetches, a cover that is no longer wanted stops
  downloading, and the selected marker keeps its cover even when the
  nearby-cover budget is full.
- **A new marker face.** Each category keeps its shape. Inside, the marker is
  now a small piece of the same design language as the app's statistic
  tiles: a lit colour field, the category's symbol large and cropped into the
  corner, and a light edge. A selected marker glows more strongly. Groups
  show their count clearly, and mixed groups lead with the main category.
- **Smoothness.** On a real GPU (desktop and phone-sized windows), frame
  pacing while panning and zooming is unchanged from 0.8.0 (95th percentile
  16.8 ms). The first covers appear about 0.15 s after the map settles.
  Physical-device performance was not measured.

## Home

- Artist and institution cards now show the account's cover image behind
  its picture or logo. The cards never received the cover before; that was
  fixed on the server (art.kubus-backend#73) and in the app.
- Artist cards show the real profile picture instead of a generated one.

## Profiles

- The name, handle and role sit on a compact plate sized to the content, with
  Follow and Message right beside it, instead of a page-wide band with the
  buttons floating at the far edge.
- The role is shown once (the Artist or Institution badge), not twice.
- The profile picture has no extra frame around it, on other people's
  profiles and on your own.
- A profile without a cover shows a quieter field in its role colour.

## Action and statistic tiles

- The large faded symbol on settings rows, support links, Home shortcuts and
  statistic tiles now sits mostly inside its tile, lightly cropped at the
  corner, instead of being pushed so far off the edge that it looked
  accidentally clipped. On settings and support rows it no longer sits under
  the arrow.
- On a computer, pointing at a settings or support row now answers with the
  symbol as well: it moves slightly inward and grows a little, while the row
  itself stays still. Statistic tiles do the same. With reduced motion turned
  on, the symbol stays still and only the colour and edge respond.

## Account security

- Secure account and the sign-in progress (Preparing session … Opening
  workspace) are a single panel on the account background, not a panel inside
  a panel.

## Governance

- Voting power, active proposals and delegates use the same expressive
  statistic tiles as Home and profiles. On a phone, voting power spans the
  width and the other two share a row.

## kubus Node

- kubus Node is now marked as a Lab feature, like Community governance and
  Digital editions: in the desktop navigation, on the Home capability strip
  and in the Node header. It still keeps its own server symbol and still needs
  no wallet.

## Opening public links

- Every public subject opens straight to the exact page for a signed-out
  visitor, with no sign-in, registration, onboarding, role picker or wallet
  setup: artwork, profile or artist, institution, event, exhibition,
  collection, post, map place and public collectible. Sign-in appears only
  when you do something that needs an account, and you return to the same page
  afterwards.
- A public collectible opens without a wallet. Its link is its own stable
  collectible address; likes, comments and saves still go to the artwork behind
  it, and sharing it shares the collectible link, not the artwork's.
- Android: a link that arrives just after the app has started is now opened
  once the app is ready instead of being lost; a link that was already handled
  or replaced is never replayed.
- Someone who already has an account on the device is never treated as a new
  guest because their session expired.

## Page titles and authorship

- A page opened from a search result keeps its descriptive title while the app
  takes over, and the browser tab title then follows the page you are actually
  on (map, settings, another artwork) instead of staying on the first one.
- Authorship matches between the server-rendered page and the app. A person or
  account that only uploaded or imported a work is no longer shown as its
  artist; an unknown artist stays "not recorded", an explicit artist credit
  survives loading, several authors are kept, and an artist wallet that is
  actually recorded still resolves to its profile.

## Backend (art.kubus-backend)

- Home rails carry separate avatar, cover and logo images (#73).
- Dependency audit policy documents the two unreachable upstream advisories
  instead of failing releases (#74).
- Collectibles: the stable collectible address is the artwork record ID. Older
  mint-address links resolve to it with a single, non-cacheable redirect;
  a mint shared by several public records, or belonging to a private or
  inactive record, is a 404 (#75, migration 097 adds the lookup index).
