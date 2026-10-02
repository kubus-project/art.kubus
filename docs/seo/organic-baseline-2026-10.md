# Organic search baseline (Search Console, October 2026)

The measurement baseline for the organic funnel, and the handoff for the next
SEO phase. Figures are from the Search Console exports supplied by the owner on
2026-10-02; this page records them and does not re-pull them. Nothing here
changes index policy, canonicals or production data.

## Baseline

Latest 28-day report:

| | Clicks | Impressions | CTR | Avg. position |
| --- | --- | --- | --- | --- |
| 28 days | 32 | 3,039 | ~1.05% | ~9.9 |
| First 14 days | 13 | 1,171 | ~1.1% | |
| Last 14 days | 19 | 1,868 | ~1.0% | |
| Latest 7 recorded days | 14 | 931 | ~1.5% | |
| Latest 24 hours | 5 | 220 | ~2.27% | |

Impressions rose ~60% from the first to the second fortnight and the most recent
week converts impressions to clicks better than the month does. This is real,
growing organic traffic. It is **not** large enough to infer conversion quality
from registrations: zero registrations from ~32 clicks is not a failed channel.
The funnel to measure is

```
search entry -> entity / city / map view -> meaningful discovery
  -> protected action attempt -> activation gate -> account created
  -> pending action completed
```

The event map for each step is in
[`../analytics/campaign-activation-contract.md`](../analytics/campaign-activation-contract.md).

## Pages that already rank

| Page | Clicks | Impressions | CTR | Position |
| --- | --- | --- | --- | --- |
| `/en/ljubljana/` | 5 | 111 | 4.5% | ~7.7 |
| `/en/zagreb/` | 3 | 54 | 5.56% | ~5.7 |
| `art.kubus.site` root | 2 | 71 | 2.82% | ~4.2 |
| `/en/slovenia/` | 2 | 16 | 12.5% | ~5.9 |
| `/en/celje/` | 0 (28 days; 1 click in the latest 24 h) | ~102 | 0% | ~8.6 |

Ranking with no clicks over the window: `/en/murals-near-me/` (44 impressions,
position ~7.95), `/sl/murali-v-blizini/` (39, ~8.4), `/sl/ljubljana/` (27,
~6.15), `/sl/javna-umetnost/` (22, ~5.9), `/en/public-art/` (22, ~9). Artwork
entity pages carry a large share of all impressions at a materially weaker CTR
than the best city/discovery pages.

## Query data limitation

The query export exposes only a minority of impressions and almost none of the
clicks, because Google suppresses low-volume queries (about 31 of the 32 clicks
have no visible query). Visible queries (for example "art galleries in celje",
"ljubljana art", "public art map", "murali", "art murals near me") are examples,
**not** the click source, and must not be presented as what drives the hidden
clicks. This work does not record search queries in the app and does not
reconstruct the suppressed ones.

## What not to do from this data

- Do not create more indexed URLs because conversion is low. The index is already
  large: 18,114 public entities, 18,111 passing index policy, 9,049 linked
  marker/artwork pairs where both sides are independently index-eligible, and
  18,102 EN/SL entity pairs whose stored title/description are
  fallback-equivalent.
- Do not mass-deindex or re-canonicalise artwork/marker pairs in a product or
  CTR change.
- The next SEO phase is **index quality, canonical consolidation and
  localization quality**, not more URLs.

## Handoff: artwork/marker canonical ownership

- An **artwork** is the cultural entity; a **marker** is its spatial
  representation.
- If a marker has no independent semantic identity, the artwork is the likely
  canonical owner of the pair.
- The audit to date has **not** established a meaningful standalone-marker cohort
  (markers that are not a representation of an artwork and merit their own
  indexable page). That has to be measured before any policy change.
- A later index-quality rollout must be **staged with metrics and a rollback**
  (impressions, clicks and indexed-page count per cohort before and after), not
  a single mass `301`/`308`/`noindex`.
- No canonical or index-policy change belongs in the guest-first entry PR or in a
  CTR copy pass.
