# Economic and Reward UX Inventory

## Audit method

The pre-edit baseline is app `dev` commit `94c9ad6c3539b8cd4cf6beb2ce1a4959713d2cfe`. A tracked-source `git grep -I -n -i -E 'kub8|token.?reward|reward.?tokens?|reward|actual.?rewards?' origin/dev -- .` returned **1,351 matching lines in 146 files**. The value-free path/line/matched-term index is [ECONOMIC_UX_REFERENCE_INDEX.csv](ECONOMIC_UX_REFERENCE_INDEX.csv). It includes localization and generated localization, documentation, tests, and assets; it is a search index, not 1,351 distinct product features. Review snippets in the named source files to reclassify a line when code semantics change.

The inventory separates explicit token economics from recognition and legacy fields. It does not infer that a configured number was actually paid, nor does source search establish production balances or user counts.

## Classification

| Class | Current references and meaning | Disposition |
| --- | --- | --- |
| Artwork-presentation bug / legacy | `lib/models/artwork.dart` stores/serializes `rewards`; `actualRewards` aliases it. Desktop artwork detail and desktop map detail rendered this as a KUB8 stat; nearby list/grid rendered it as a KUB8 value and nearby sorting ranked by it. | Preserve model/API compatibility; remove these cultural-browsing presentations and the rewards sort. Deprecate presentation access. No schema migration. |
| Real KUB8 economic surfaces | Wallet send/receive/swap and token identity; DAO/governance; marketplace/collectible prices; explicitly configured promotion payment; verified attendance responses carrying `result.kub8.awardedAmount`; configured achievement `kub8Reward`/legacy `tokenReward`; POAP `rewardKub8`/explicit reward amount; staking/availability and node rewards. | Preserve where the source contract explicitly denominates KUB8. Do not turn these into contribution points. A configured/eligible reward is not described as paid before its transaction/claim confirms it. |
| Infrastructure / service cost | Spatial processing `estimatedCostKub8`, availability/node economics, validator or infrastructure reward configuration. | Keep within the spatial/network/availability service context. Do not expose as artwork cultural value. |
| Contribution recognition | Discovery updates `ArtworkStatus`, `discoveredAt`, `discoveryCount`, autosaves, and calls the backend discovery-count endpoint. No typed contribution-points award is returned or applied. | No points copy or reward amount is shown for opening/discovering a URL. Define a future non-transferable recognition contract; do not create a client ledger. |
| Legacy / unused config | `AppConfig.dailyLoginReward`, `artworkUploadReward`, and `artworkDiscoveryReward` have declarations but no active call sites in this app baseline. `kub8PerAttendanceReward` is also not consumed by the attendance presentation path; the UI instead reads an explicit backend attendance result. | Treat as legacy configuration, not active payout evidence. Daily login reward remains unused; no retention award is added. Remove only through a separate backend/config compatibility review. |
| Ambiguous generic notification amount | `showRewardNotification(amount, reason)` hard-coded KUB8 without receiving a currency. Push `reward` payloads pass only an amount/reason. NFT minting locally called it with a hard-coded 50 after saving a local collectible; the call itself did not transfer KUB8. | Do not assert a KUB8 amount or contribution points without a typed server-confirmed award. Remove the misleading mint notification call; keep the NFT mint-success notification. Generic reward notice omits untyped amount/unit. |
| Explicit achievement KUB8 | `AchievementService` definitions contain `tokenReward` and submit `kub8Reward`; achievements screen/profile preview display configured/returned rewards. | Retain KUB8 semantics where the award source is explicit. Do not re-label as contribution points. Ensure claim/award result language distinguishes configured from confirmed. |
| Tests/docs/localized copy | Test fixtures, old documentation, ARB text, generated localization code, and marker/promo art account for many of the line matches. | Keep accurate tests and product references. Update user-facing copy only where it claims an unsupported unit or artwork value. Generated localization files are regenerated from ARB sources. |

## Confirmed current call sites

- `lib/screens/desktop/art/desktop_artwork_detail_screen.dart`: `actualRewards` was displayed as a detail statistic. This is an artwork-presentation bug.
- `lib/screens/desktop/desktop_map_screen.dart`: selected artwork details repeated the same statistic. This is an artwork-presentation bug; map composition itself is out of scope.
- `lib/widgets/map/nearby/kubus_nearby_art_panel_items.dart`: list and grid each displayed `artwork.rewards` as KUB8. Remove those labels while retaining image, title, artist, and distance.
- `lib/widgets/map/nearby/kubus_nearby_art_panel_body.dart` and `...types.dart`: reward sorting uses the legacy field and a “recognition” label. Remove that misleading sort; nearest/newest/popular remain.
- `lib/services/push_notification_service.dart`: discovery notices append a KUB8 amount even though discovery is a count update. Generic reward notice has no currency argument. Achievement notices are separate and have an explicit KUB8 model.
- `lib/services/nft_minting_service.dart`: the local mint flow displayed `+50 KUB8` through the generic reward notice without a token transfer operation. Keep mint-success notification; do not claim this payout.

## Artist support

No current backend/API contract safely binds cultural artist attribution to an authorized payment recipient. See [ARTIST_SUPPORT_CONTRACT.md](ARTIST_SUPPORT_CONTRACT.md). Support is not visible in this pass, and existing generic wallet send features are unchanged.

## Residual migration debt

`Artwork.rewards` and its `actualRewards` alias remain serialized until a backend/API migration can safely remove them. Legacy config constants remain defined but unused. Generic backend reward events still require a currency/award-type discriminator and a confirmed result before an amount can be presented. A future contribution-points ledger needs a distinct non-transferable unit and server event. None of that backend/economic work is implemented here.
