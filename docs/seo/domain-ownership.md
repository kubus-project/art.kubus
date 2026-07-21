# Domain and route ownership

Authoritative cross-repository ownership model. Any new public page must be
placed under exactly one owner below. If two domains could plausibly own a
surface, this file decides it.

Last updated: 2026-07-21.

---

## kubus.site — research and artistic project

Repository: `kubus-project/kubus.site` (Vue 3 + Vite SPA, LiteSpeed).

Owns the broader kubus project as an entity distinct from the art.kubus
product: journal, monograph, manifesto, history, projects, contact, research
writing and project lineage.

Route surface (finite, declared in `src/router/index.ts` and mirrored by the
`public/.htaccess` allowlist):

```
/            /journal       /journal/:slug    /monograph
/manifesto   /history       /projects         /contact
```

Rules:

- Must **not** be redirected wholesale into art.kubus. It is a separate entity.
- Anything outside the route surface returns a real `404` via `404.html`.
- Advertises only its own sitemap.
- Web3/AR/blockchain terminology appears only on pages that actually discuss it,
  never in site-wide metadata.

## art.kubus.site — acquisition and explanation

Repository: `kubus-project/art.kubus.site` (generated static EN/SL HTML).

Owns search acquisition and product explanation: public-art discovery guides,
city pages, murals and street-art guides, artist and institution participation
guides, the download/distribution page, and SEO/AEO editorial pages.

Rules:

- Localized under `/en/…` and `/sl/…` with reciprocal hreflang.
- **Never re-hosts application entities.** City and guide pages link out to
  canonical `app.kubus.site` entity URLs.
- Editorial content is authored in admin.kubus and fetched at build time, not
  hand-edited in generated HTML.

## app.kubus.site — canonical public entities + the application

Repository: `kubus-project/art.kubus` (`web/` transport) +
`kubus-project/art.kubus-backend` (renderer).

Owns the canonical URL for every public application entity: artworks, profiles,
artists, institutions, events, exhibitions, collections, public posts and public
map records.

```
/                          → 308 /en
/{locale}                  localized public homepage (semantic, no app bundle)
/{locale}/{segment}/{id}   canonical entity document (+ progressive takeover)
/a/{id}, /u/{id}, …        compact aliases → 308 to the localized canonical
/app, /app/*               the interactive application (PWA start_url)
/robots.txt, /sitemap.xml  backend-generated
```

Rules:

- Root is a redirect, never a second indexable homepage.
- Entity documents are server-rendered semantic HTML first; Flutter takes over
  progressively for real browsers. Crawlers must always get the HTML.
- Missing entities and unknown routes return real `404`s, never a shell.
- Compact aliases resolve in exactly one permanent hop. No chains.

## Native store application

Repository: `kubus-project/art.kubus` (Flutter).

Owns public-art discovery: map, artworks, artists, institutions, events,
exhibitions, saved items, community, contributions, ordinary accounts,
notifications.

**Must not contain or advertise** wallet creation or import, WalletConnect,
recovery phrases, crypto transfers, swaps, NFT minting, token rewards, on-chain
governance, or crypto marketplace transactions — in the app, its store listing,
its structured data, or its public deep-link surface.

## Full web platform

Owns everything the native app owns, plus optional advanced capability: wallet
activation, portable identity, wallet management, signing, provenance,
marketplace, NFT functionality, DAO and governance.

Rule: ordinary discovery and account creation must never require a wallet.

---

## Boundary cases

| Surface | Owner | Rationale |
|---|---|---|
| "What is public art?" explainer | art.kubus.site | Acquisition/explanatory content |
| A specific mural's page | app.kubus.site | It is an entity |
| Ljubljana city guide | art.kubus.site | Editorial hub; links to entities |
| Research essay on cultural infrastructure | kubus.site | Project research, not product |
| Download / install page | art.kubus.site | Acquisition |
| The running application | app.kubus.site `/app/*` | Product surface |

## Entity distinction: kubus vs art.kubus

`kubus` (research and artistic project by Rok Černezel) and `art.kubus` (public
art platform) are **separate entities** and must be modelled as such in
structured data. kubus.site references art.kubus as a related work; it does not
merge the two into one `Organization`.

This matters commercially: Search Console shows the bare query `kubus` drawing
604 impressions at position 26 while converting at 0.17%, because it collides
with unrelated entities (a juice brand, a DJ, a festival, hosting companies).
Ambiguous `kubus` demand is therefore **not** a success metric. Qualified demand
is `art kubus` and the public-art/city/mural intent clusters.
