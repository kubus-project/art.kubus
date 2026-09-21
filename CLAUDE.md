# art.kubus — Claude Code entrypoint

Last updated: 2026-09-21.

Read this file first, then `AGENTS.md`. The implementation rules in `AGENTS.md`
remain binding; this file records the current cross-repository product/design
programme so Claude agents do not optimize against stale July-era UI assumptions.

## Current programme

The next major work is a staged **public-entry + SEO + UI/UX consolidation**.
Do not treat it as a generic visual refresh.

Canonical planning documents:

1. `docs/PRODUCT_UX_SEO_PROGRAM.md` — ordered programme and agent waves.
2. `docs/DESIGN_SYSTEM_V2.md` — current design-family direction.
3. `docs/APP_NATIVE_PUBLIC_ENTRY.md` — app.kubus.site entity-entry contract.
4. `docs/seo-public-pages.md` — current renderer / technical SEO architecture.
5. `docs/seo/domain-ownership.md` — domain and route ownership.
6. `docs/public-entry-access-policy.md` — public-read vs authenticated-action boundary.
7. `docs/engineering/branching-and-deployment.md` — branch/CI/deployment governance.

## Visual reference branches

Do not use the old public-site `master` layouts as the redesign target.

The current reference work is:

- `kubus-project/art.kubus.site@redesign/a1-foundation`
  - WORLD / spatial-first direction;
  - Sofia Sans + Space Mono;
  - flat structural surfaces, hairlines, asymmetric editorial composition;
  - MapLibre globe, camera-continuity QA, canonical marker sprites;
  - marker LOD: dot → canonical icon → cover image at high zoom.
- `kubus-project/kubus.site@redesign/k1-foundation`
  - TIME direction;
  - same family typography / semantic structural roles;
  - no generic marketing cards, glass-first surfaces, bento layouts or decorative gradients.
- `kubus-project/kubus-node`
  - INFRASTRUCTURE/operator surface;
  - functional density is allowed, but it remains part of the same family.

The app is the PRODUCT surface. It should share the family grammar without
copying an editorial website layout.

## Priority order

1. Ground and audit existing SEO/public-entry/data quality.
2. Redesign canonical `app.kubus.site` entity entry so the semantic first frame
   already looks and behaves like the app.
3. Make canonical web URLs open the native app directly where platform link
   verification allows it.
4. Bring the app map to the WORLD model: globe + coherent marker LOD + cover
   markers at close zoom, reusing the art.kubus.site implementation contract
   rather than inventing another renderer model.
5. Run a complete screen/task-flow UI/UX audit and then perform the deep polish.
6. Only after that, consolidate QA/moderation/editorial/governance systems across
   admin and in-app DAO surfaces.

## Hard rules for the programme

- Preserve semantic server-rendered entity HTML for crawlability and real HTTP
  status codes. The goal is to make it **indistinguishable from the app's first
  public frame**, not to delete SEO HTML.
- No generic SEO bridge page, marketing header/footer, or duplicate
  "Explore/Open in app" experience before the actual entity.
- The canonical localized entity URL remains the browser URL during web
  takeover and is also the platform-native deep-link URL.
- No user-agent cloaking.
- No second map/marker system. Reuse `KubusMapController`,
  `MapLayersManager`, canonical marker assets and shared data contracts.
- No broad screen restyling before the audit has classified KEEP / REFINE /
  REDESIGN / MERGE / REMOVE.
- Do not preserve obsolete pre-launch flows merely for compatibility. Replace
  cleanly when the new contract is proven and tested.
- Visual changes require screenshot evidence on desktop + mobile and Chromium +
  Firefox for web-facing work.
