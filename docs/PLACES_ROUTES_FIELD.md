# Places, routes and Ljubljana field evidence

Status: future data/product contract, not an approved migration or publication rule. Roadmap gates: `PRODUCT_UX_SEO_PROGRAM.md` Waves 1, 9 and 11; packages: `AGENT_EXECUTION_PLAN.md`. Reviewed 2026-09-22.

## Current truth and first audit

Open-data ingestion covers many cities; this does not make every city an editorial page. First inspect the actual backend city/place representations, imported source fields, current Ljubljana/Maribor routes, editorial city highlights and index policy. Preserve proven existing city URLs. The Wave 1 read-only extract must identify what exists, its quality and its owner before proposing schema or thresholds.

## Future first-class place model

Conceptual hierarchy: country → region → city → neighbourhood → site/place. A place may need localized names, stable canonical slug, geometry and centroid, parent, mapped artwork count, verified artwork count, artist count, institution count, route count and editorial/review state. These are desired capabilities, **not assertions that columns exist**. The audit records actual fields and gaps. Do not blindly commit this schema.

Publication maturity is conceptual: DATA ONLY → MAPPED → INDEXABLE → EDITORIAL → FIELD VERIFIED → PILOT. Quality and demand decide promotion; broad ingestion alone does not. Proposed entity quality tiers are likewise conceptual: PUBLIC, INDEXABLE, STRONG, EDITORIAL/FIELD VERIFIED. Do not hardcode these names in DB or mass-deindex until Wave 1 correlates quality, GSC visibility, clicks and use.

## Routes after places

Cultural routes become first-class PRODUCT entities only after stable place ownership. Candidate fields: title, city/place, curator, description, distance, duration, mode, start/end, artworks, institutions, events, accessibility, `verified_at` and translations. Audit existing route/walking navigation models before schema or URL design. No route canonical is approved here.

Intended journey: search/editorial city guide on `art.kubus.site` → PRODUCT route → start walk → PRODUCT map → artwork → artist/institution → save/follow/contribute. Preserve referrer and UTM through this funnel. The guide remains editorial; the active route and entity records belong to PRODUCT.

## Ljubljana reference programme

Start field operations when core PRODUCT contribution/correction is coherent; a dedicated Field Mode waits for several real sessions and observed repeated friction. Per artwork/place record existence, coordinates, artist attribution, title, category, condition, photographs, source/provenance, signage, institution/place relation, neighbourhood and last verified date. Keep evidence reviewer and source distinct from uploader and artwork artist.

Capture levels: 0 verify; 1 document; 2 spatial capture; 3 immersive/aligned capture. Not every mural needs a splat. Select sculpture, installation, architectural object, context-heavy or ephemeral work and sites where temporal comparison matters. The existing `kubus.capture/1` → reconstruction → `kubus.spatial/1` path remains the technical basis. Field sessions produce a reviewed reference dataset and product friction log before any new mode or spatial delivery sizing.
