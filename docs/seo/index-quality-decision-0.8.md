# Index quality: decision record for 0.8.0

Status: decision record, 2026-10-03. Nothing here changes index policy,
canonicals, sitemaps or production data. It states what is already live, what
0.8.0 deliberately does not change, and the controlled experiment that follows
the release.

## What is live

The ownership policy v1 (art.kubus-backend `docs/seo/INDEX_OWNERSHIP_CANONICAL_POLICY_V1.md`,
evidence in `docs/audits/index-ownership-2026-09/`) is deployed:

- **An artwork is the cultural entity.** It owns its title, description, artist,
  image and provenance, and it is the indexable unit.
- **A marker is the spatial representation of that artwork** unless it is
  independently semantic. Today every public marker links to a public artwork
  and none is independent, so marker routes stay reachable (map context,
  coordinates, sharing, App Links) but declare the artwork as canonical and are
  out of the sitemap. A canonical never points at a non-indexable target.
- **Slovenian routes with no translated content are not separate documents.**
  They canonicalize to the English entity and reciprocal alternates are only
  emitted when a translation exists.
- Profiles, posts, collections, events and exhibitions are indexed only when
  they carry their own substance (policy sections 5 to 8).

Verified live on 2026-10-03: `/en/map/<markerId>` answers 200 with
`rel=canonical` set to `/en/artworks/<artworkId>`; `/sl/umetnine/<id>` for an
untranslated artwork canonicalizes to the English URL; and the sitemap index
lists only artwork, profile and collection sitemaps.

`organic-baseline-2026-10.md` quotes the earlier audit (about 18,114 public
entities, 18,111 passing the index gate, 9,049 artwork and marker pairs that
could both have been eligible). Those are the pre-policy counts: policy v1 is
what resolved those pairs, and that page's warning against re-canonicalizing
them describes a change that has already been made and observed. The numbers
below come from the same audit (art.kubus-backend repository,
`docs/audits/index-ownership-2026-09/output/metrics.csv`, measured
2026-09-27) and are not a current index count.

## What 0.8.0 does not do

No mass de-indexing, no new `noindex` rules and no canonical changes ship with
0.8.0. Search Console reacts to canonical and indexing changes over weeks, a
release week is the wrong moment to add a second source of change, and a drop in
impressions could not be attributed to either. The planned 0.8.0 SEO work
(public renderer, takeover, structured data, sitemaps, the Celje snippet
experiment, acquisition copy) is what ships.

## Post-release controlled experiment

Candidates come from the audit cohorts (artworks by metadata richness):

| Cohort | Description | Count (2026-09-27) |
| --- | --- | --- |
| C1 | title, image, description, artist | 3,956 |
| C2 | title, image, description, no artist | 3,968 |
| C3 | title, image, artist, no description | 654 |
| C4 | title and image only | 470 |

The cohorts partition the 9,048 public, active, non-collectible artworks (the
9,049 above counts markers, one of which belongs to a hidden artwork). The 1,649
artworks whose description is shared by five or more artworks (templated text)
are a second, overlapping view: they sit inside C1 and C2, because those
cohorts require a description. The question is whether thin, near-duplicate
artwork pages dilute the site, not whether any page should be removed.

Proposed order, each step only after the previous one has been observed for 28
days and the owner has approved it:

1. Enrich first: add substance to the templated-description artworks (policy
   follow-up 5). No indexing change.
2. C4 (470 URLs): `noindex, follow` and removal from the sitemap, in one change.
3. C3 (654 URLs).
4. Whatever of the templated-description set is still templated after step 1,
   de-duplicated against the URLs already handled, in batches of at most 1,000
   URLs, largest shared-description groups first.

Every step is reversible by a single revert of the policy module, because
routes, redirects and the database do not change.

## Rollback criteria

Measured in Search Console with the cohort as a page group, against the 28 days
before the change. The baseline at release is 32 clicks and 3,039 impressions
over 28 days (CTR about 1.05%, average position about 9.9); that is small, so
no criterion is read from a single week and none is read from clicks alone.

Two checks per step: a provisional one at 14 days and the decisive one at 28
days, which is also the end of the observation window before the next step.
Because the baseline is small, a trigger only counts when it is larger than
noise: it must exceed both the percentage below and a volume floor of at least
10 clicks or 400 impressions in absolute terms, and it must still hold at the
following weekly reading.

Revert the step if any of these holds:

- at 14 or 28 days, clicks or impressions for the pages **not** in the cohort
  have fallen by more than 25% against the baseline (the change is hurting what
  it should not touch);
- at 28 days, the site's total clicks have fallen by more than 25% and the
  cohort cannot explain more than half of the fall;
- at 28 days, "Crawled, currently not indexed" or "Duplicate, Google chose
  different canonical" has not fallen for the cohort (the change did not do what
  it was for);
- at 14 or 28 days, the 404 rate or the sitemap submitted-versus-indexed ratio
  has moved outside what the change should cause.

Do not call this finished by chasing Search Console: it is a bounded experiment
with a stop rule, not a release requirement.
