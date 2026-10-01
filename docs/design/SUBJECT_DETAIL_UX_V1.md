# Subject Detail UX v1

## Scope and contract

Subject pages present the cultural record first, then the community and archive around it. Desktop and compact layouts share the same meaning and action labels but use different composition. This pass reuses the existing entity providers, contextual authentication, share service, saved-items service, attendance flow, map navigation, comments, AR, capture, POAP, collaboration, and management actions.

This document is a product contract, not a claim that every entity currently supports every action. Only actions backed by an existing provider or service are presented. A future action must not be made interactive with local-only success state.

## Page grammar

1. Subject media or primary identity.
2. Title, cultural creator or organizer where authoritative, and place/date/category context.
3. Social actions that change a user's relationship to the subject.
4. Contextual spatial actions, when valid place data exists.
5. About and compact record facts.
6. Provenance and verification, where those fields exist.
7. Community, spatial archive, related subjects, and deeper tools.

Management, claim, correction, report, capture, AR setup, POAP, and infrastructure controls remain available in their current feature-specific sections or overflow. They do not outrank the subject identity.

## Four interaction domains

| Domain | Meaning | Current product behavior |
| --- | --- | --- |
| Social | Like, save, follow, discuss, share, and a future RSVP/interest relationship | Like/save/follow/comments/share use current providers. Event attendance remains proof-based attendance; it is not relabeled as "Interested". |
| Contribution | Verified cultural record work: discover, verify, correct, document, translate, capture, curate | No general contribution-points ledger or typed award response was found. Discovery currently increments discovery state/count and synchronizes that count; it does not grant the `artworkDiscoveryReward` config value. |
| Support | Intentional support to an eligible artist, institution, or cultural project | Hidden in ordinary public pages. No explicit support recipient contract or artist-support transfer API was found. |
| Infrastructure | Wallet, KUB8, DAO, node and spatial-network economics | Kept in the existing wallet, DAO, marketplace, promotion, node, POAP, and processing surfaces. It is not a subject's intrinsic value. |

Contribution points, if introduced later, are non-transferable recognition. They are not wallet balance, a token, or a decrementing resource. They require a server-confirmed qualifying action and typed amount/unit before UI can claim an award.

## Entity action matrix

| Subject | Primary social | Contextual / spatial | Existing feature-specific actions |
| --- | --- | --- | --- |
| Artwork | Like, save, discuss, share | Show on map, directions; AR only when enabled | Claim/correction, attendance proof, POAP, spatial capture/archive, gallery, collaboration and management remain available below or in existing controls. |
| Event | Save, share | Map/directions when coordinates exist | Verified attendance/POAP, registration/ticket only when its current event data and flow support it; promotion and management stay secondary. No generic RSVP is invented. |
| Exhibition | Save, share; follow only where a curator relationship exists | Map/directions when coordinates exist | Linked works/events, attendance/POAP, promotion and management remain in existing sections. |
| Artist/profile | Existing follow and message actions; share where the current profile identity supports it | Location/website only when public fields exist | Support is hidden until the explicit recipient contract exists. |
| Institution/profile | Existing follow/share and public website/location actions where present | Map/directions when public coordinates exist | No Institution v2 workspace is introduced. |
| Collection | Save and share; artworks remain the central content | None unless a real curator/place action exists | Creator controls remain management actions. |
| Marker | Open linked artwork; map/spatial context | Map and spatial controls | No duplicate generic artwork social surface is invented for the marker representation. Canonical routes are unchanged. |
| Post | Like, comment, save, share | Embedded referenced subjects | Uses existing community interaction services; it is not rendered as an artwork page. |

## Responsive behavior

Desktop uses a readable labeled action row near subject identity. Social actions appear together; spatial actions are a separate group. Directions cannot become a full-column hero CTA. Mobile uses wrapping controls with at least 48 logical pixels of height and explicit labels for the core social actions. It does not require a horizontal scrolling toolbar or a sticky bar competing with the existing bottom navigation.

Selected states use both labels and semantic toggled state; color is additional feedback only. All actions retain keyboard focus and existing contextual authentication.

## Artwork archive and provenance

Prose is an editorial reading surface, not a generic stat card. Image author, image credit/license, source, record contributor, verification, and cultural artist attribution are separate facts. The renderer may show only facts supplied by the public model; it must not infer an artist from a photographer, uploader, wallet, contributor, or import profile.

The spatial archive is state-based. A public spatial record can show its capture/version summary and open the record. Once a successful history read confirms there is no public record, the archive can say so; a capture action is shown only to an eligible authenticated artist/institution under the existing feature gate. Unknown/loading history does not claim that the archive is empty, and a stored nonzero capture count is not overwritten by an empty-history message. Technical network identifiers remain in deeper record details.

## Data and compatibility boundaries

`Artwork.rewards` remains in the model and serialization for compatibility, but it is legacy transport debt. `actualRewards` is a legacy alias. Neither can be presented as an artwork price, bounty, KUB8 balance, or contribution score. Any future removal or migration belongs to a backend contract change.

KUB8 is reserved for explicit token-denominated flows whose source identifies KUB8 (for example configured POAP/achievement awards, marketplace prices, promotion prices, wallet operations, and infrastructure rewards). Ambiguous `amount` fields do not acquire a KUB8 label by UI convention.

## Artist support contract

See [ARTIST_SUPPORT_CONTRACT.md](ARTIST_SUPPORT_CONTRACT.md). No support button is shown until a server-owned public recipient identity, eligibility state, transfer operation, and receipt can be validated. An artwork artist string or associated profile/wallet is not enough.

## Verification expectations

Action layout must remain readable at 320, 360, 390, 430, 899, 900, 1024, 1280, and 1440 logical pixels; long English/Slovenian labels must wrap without horizontal page overflow. Tests should assert actual action semantics and preserve location, attendance, comments, archive, AR, POAP, creator, and management behavior.
