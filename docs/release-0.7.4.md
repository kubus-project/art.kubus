# art.kubus 0.7.4

Release 0.7.4 updates the frontend version to `0.7.4+26081001`.

## Highlights

- Completes desktop Web3 with one capability model for hydrated account state,
  wallet identity, signer readiness, DAO authority, feature flags, and edition
  ownership. Governance now has a native desktop workspace, consistent guest
  and signer gating, real delegation, and server-derived review authority.
- Rebuilds Digital Editions on canonical collectible data with localized
  search, filtering, reset, sorting, grid/list views, details, and supported
  owner listing controls. Unsupported purchase, offer, auction, favorite,
  generic-chain, local-mint, and fabricated-stat behavior has been removed.
- Consolidates Desktop Wallet around one action controller and canonical Owned
  Editions inventory. The unsupported Staking surface and duplicated wallet,
  network, receive, refresh, and custody presentations are removed.
- Stabilizes map browsing across mobile and desktop: Nearby and marker detail
  transitions retain their controllers and suspended browse surfaces, marker
  lists remain growable after deep-link merges, and desktop onboarding and map
  panels remain centered and responsive.
- Completes direct campaign attribution and activation analytics across bare,
  registration, recovered-contribution, and mobile deep-link entries while
  isolating telemetry failures from user contributions. Backend campaign
  coverage, time-series, retention, and contribution-type reporting now use
  bounded, session-consistent queries.
- Hardens backend marker and DAO boundaries. Marker subjects and AR uploads are
  normalized and validated, DAO mutations keep authenticated wallet-signed
  envelopes, and review decisions require an admin/moderator role or explicit
  reviewer allowlist exposed through a read-only authority capability.
- Restores refreshable web app routes and extends the interactive-route,
  revision, routing, SEO, checksum, atomic promotion, and rollback contracts
  used by staging and production deployments.

## Removed unsupported behavior

- Fake Digital Editions Buy Now, offers, auctions, favorites, generic Ethereum
  and Polygon filters, and local mint simulations.
- Fake Wallet Staking and Stake-to-Swap behavior.
- Simulated DAO delegation and privileged controls shown to ineligible users.

## Validation

The implementation candidate passed repository architecture and documentation
guards, Flutter analysis, 2,100 Flutter tests (3 skipped), release web build,
27 web QA tests, backend DAO tests and lint, exact web-artifact browser smoke,
and unsigned Android and iOS release compilation. Staging promoted exact `dev`
SHA `932eaee74ee2b838b68799f5009d25d49bd125c7`; checksum, revision, protected
Basic Auth, localized routing, noindex policy, smoke, and rollback guards all
passed before release preparation.
