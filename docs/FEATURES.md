# Features

art.kubus is a map-first art platform. Public artworks, their metadata and approved public media form the public cultural archive. A public artwork can be discovered on the map and may be replicated through the platform's publication and availability infrastructure. Draft and private material remain outside that public archive.

## Discovery and public artworks

- MapLibre map with artwork, exhibition and place markers.
- Search, filters, nearby discovery and marker detail views.
- Artwork pages with media, contextual information, discussion and sharing.
- Public, private and draft visibility controls. Public is a publication state, not an optional archive action.
- Profiles, artists, institutions, events and exhibitions provide cultural context around artworks.

## Artwork creation

Artist Studio supports artwork drafts and publication. The creator flow separates:

1. Artwork metadata and media.
2. Visibility and location.
3. Optional AR or spatial layers.
4. Optional attendance records.
5. Optional digital edition series.

Creating or publishing an artwork creates its artwork record. A digital edition is optional and never determines whether an artwork belongs to the cultural archive.

## AR and spatial layers

AR and spatial media are optional interpretive layers. The client can open supported AR experiences on mobile devices and exposes configuration only when the relevant feature flags and media are available. AR, ordinary 3D media and spatial captures are distinct from an artwork's archival record.

Spatial capture and Gaussian processing are coordinated with kubus Node when configured. Private captures and unpublished CID-addressed material are not public archive content. A reviewed, published spatial variant may be included in the public archive according to backend publication policy.

## Community and participation

- Public profiles, follows, posts, comments and direct messages.
- Notifications and recent activity.
- Artwork, event and exhibition context in community views.
- Attendance records for visits or participation where enabled.

Attendance records are separate from artwork records and digital editions.

## Institutions, events and exhibitions

Institution and event tools support programme context, exhibitions, events, linked artworks and attendance configuration. Availability depends on feature flags, account permissions and backend support.

## Digital editions and wallet tools

Wallet features are optional. They can support digital editions, attribution, operator identity and governance-related tools. A wallet is not needed to browse the map, discover public artworks or take part in ordinary community activity.

Digital editions are optional tokenized editions connected to artworks. The current implementation uses internal NFT and collectible identifiers in its services and data model, while user-facing screens call them digital editions. Marketplace availability, transfers, listing and settlement remain feature- and backend-dependent.

## Public archive availability

The public cultural archive contains public artwork records and approved public media or spatial assets. Backend publication state determines canonical public content. kubus Nodes provide optional availability infrastructure through Kubo/IPFS and related replication policy.

Content addressing is not a claim that all platform data is decentralised. Private drafts, profiles, messages, wallet backups and other private account data are not replicated as public archive content.

## Recognition, contribution and KUB8

The platform can show contribution, attendance and availability records. KUB8-related values and node rewards are contribution or pending system records unless a settlement feature explicitly states otherwise. They are not described as live payouts or a guaranteed financial return.

## Local-first behaviour

The client retains local caches for selected data and can use configured backend and public-data fallbacks. Local cache support does not guarantee offline availability of every artwork, digital edition or media asset.

## Feature flags

Many capabilities are gated in `lib/config/config.dart` and by backend configuration. A screen may therefore present a reduced, read-only or unavailable state in a given deployment. See `ARCHITECTURE.md` for the provider and service layout.
