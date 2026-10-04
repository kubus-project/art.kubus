# art.kubus 0.8.1

A corrective release for visible problems that survived 0.8.0: the map's
markers and covers, Home artist and institution covers, the profile header,
the account-security screens, the governance numbers and the kubus Node
entries. Nothing about how the app opens, public pages, app links or the
Node connection changed.

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
  still, and are fetched at the size they are drawn.
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
- The profile picture has no extra frame around it.
- A profile without a cover shows a quieter field in its role colour.

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
