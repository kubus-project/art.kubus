# Spatial delivery after field evidence

Status: future `kubus-node`/app architecture, **not implemented in Wave 0**. Read master `PRODUCT_UX_SEO_PROGRAM.md`, Wave 12 in `AGENT_EXECUTION_PLAN.md`, runtime `kubus-node/docs/SPATIAL.md` and backend spatial publication policy. Reviewed 2026-09-22.

## Current truth

Private `kubus.capture/1` inputs pass through reconstruction to a renderer-neutral `kubus.spatial/1` manifest. The manifest supports `spatial_preview`, `spatial_mobile` and `spatial_archive` roles, with missing variants explicit. The runtime accepts `spatial.optimize` and `spatial.generate_preview` job types but the current optional worker implements reconstruction only; unsupported types fail. It exports Gaussian PLY. The app already has spatial library, capture, detail and a Spark/Three orbit viewer. The GUI API can stream byte ranges, but its current viewer template fetches a complete response as `blob()`. Do not describe streamed/paged LOD as shipped.

## Delivery target

`CAPTURE → MASTER reconstruction → derivatives`:

| Role | Temperature | Purpose | Default delivery |
| --- | --- | --- | --- |
| `spatial_preview` | HOT | Small/fast cards and inspection | broadly available |
| `spatial_mobile` / runtime streamed LOD | WARM | normal PRODUCT viewing | direct paged/streamed renderer URL |
| `spatial_archive` full master PLY | COLD | preservation and reprocessing | explicit retrieval only |

Archive is canonical; it is **not** the normal delivery format. Implement `spatial.optimize` to generate real derivatives; never label one giant PLY as all variants. Spark should receive a direct streamable/paged URL. Remove the giant fetch → `blob()` → object URL → renderer path for ordinary viewing. Where authentication requires it, a short-lived read-only viewer capability endpoint such as `GET /gui/api/spatial/:id/viewer-ticket` may return scoped URLs. Define expiry, audience, variant and revocation before implementation. Support Range/206, ETag, Cache-Control and safe caches; validate private/public publication boundaries.

Capacity-aware replication eventually places manifest/preview broadly (HOT), runtime LOD moderately (WARM) and archive sparsely with preservation guarantees (COLD). Disk capacity and operator policy influence retained classes. Source capture and temporary reconstruction/work directories need explicit retention and cleanup. Do not discard canonical archive or unpublished/private inputs inadvertently.

## Evidence gate

Wave 11 field sessions supply representative asset sizes, viewer paths, phone memory and network conditions. Wave 12 must prove first meaningful frame, peak memory, bytes transferred, Range/ETag behaviour, capability expiry, asset integrity, fallback, disk-capacity replication and cleanup using those assets. Unit tests, Docker smoke, real GPU, physical Android and production are distinct evidence classes.
