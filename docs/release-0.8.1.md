# art.kubus 0.8.1

A corrective release for visible problems that survived 0.8.0: the map's
markers and covers, Home artist and institution covers, the profile header,
the account-security screens, the governance numbers and the kubus Node
entries. It also closes the last gaps in opening public links without an
account, and keeps a page's authorship and title truthful once the app takes
over from the server-rendered page. The Node connection did not change.

## The map

- **The world reads as a distributed map.** Markers no longer collapse into a
  few giant groups when you zoom out: far out the groups are small and
  regional, so you can see where the archive is (Europe, other continents,
  isolated records) and they split into regions, countries, cities and
  neighbourhoods as you approach. A group never spans an unreasonably large
  area, so Lisbon and Ljubljana are never one dot, and a lonely marker stays
  its own dot.
- **Far out, the map shows the whole archive, not a slice of it.** Below zoom 8
  (world, continent, region) the map is drawn from exact counts that the server
  aggregates for what is on screen, instead of the few hundred markers nearest
  the centre (which left a Europe view with one group near Vienna while the
  archive spans Spain to Poland). Each dot is the true number of records in its
  area, so dense places read as dense and distant places are not lost. A
  response is a few kilobytes instead of hundreds, and from zoom 8 the detailed
  markers take over. An open marker is never absorbed into a dot. Filters that
  depend on your own data (favourites, AR, discovery, search) use the detailed
  markers, and so does an older server that does not offer the overview.
- **Every marker in view gets its cover.** From city-approach scale (zoom 12.5)
  all eligible markers in the viewport show their artwork cover, not only the
  few nearest the centre. They load a few at a time while the map is still,
  spread across the whole view, and the selected marker (from zoom 10) always
  goes first. Wide (landscape) covers are downloaded with enough width to fill
  the marker face without looking soft.
- **Bounded and cancellable.** Visible covers are never evicted before they are
  drawn, offscreen ones go first, a cover that is no longer wanted stops
  downloading, and decoded image size and download concurrency are capped.
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

- **A shared profile link reads in the same order.** The page you land on from a
  shared link or a search result follows the same hierarchy as the in-app
  profile: identity, work or programme, posts, recognition, then the closing
  statistics (previously the statistics came before the posts on phones and the
  achievements before the posts on computers).
- **My profile reads like your public profile.** Your identity and practice,
  then your work or programme, your posts, your recognition and the closing
  statistics come first; the account tools (account health, saved items,
  performance) are their own block at the end instead of interrupting the
  profile.
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
- On a computer, every tile answers the pointer again with the kubus lift: the
  surface rises 2 px with a soft accent shadow, its colour and edge strengthen
  and the symbol moves slightly inward and grows. That includes the compact
  settings and support rows and the expressive statistic tiles; the text moves
  with the surface and never shifts inside it. With reduced motion turned on,
  nothing moves and only the colour, edge and shadow respond.

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
- A shared map place opens on its exact marker and only then replaces the
  server-rendered page: the map flies to the marker, selects it and opens its
  card. Before, the static page could stay on top of the map for good
  (computers every time, phones for tall cards), because the marker was selected
  while the camera was still flying and was then dismissed as if you had moved
  the map, and a tall card was never counted as open.

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
- `GET /api/art-markers/overview` returns the exact, public marker counts per
  map area for the far zoom levels (art-kubus-backend#76), and the dependency
  advisories published since (proxy-addr, compression, jayson) are cleared.
- Collectibles: the stable collectible address is the artwork record ID. Older
  mint-address links resolve to it with a single, non-cacheable redirect;
  a mint shared by several public records, or belonging to a private or
  inactive record, is a 404 (#75, migration 097 adds the lookup index).
