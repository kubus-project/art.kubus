# Spatial delivery specification

Technical specification: future `kubus-node`/app architecture, not a statement of current implementation. Product priorities and status belong to [Roadmap](ROADMAP.md). Runtime and publication contracts remain in `kubus-node/docs/SPATIAL.md` and the backend spatial publication policy.

## Recorded implementation snapshot

Reviewed 2026-09-22; revalidate the named runtime and backend sources before
operational decisions. This snapshot is not current deployment evidence.

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

## Validation requirements

Representative field sessions must supply asset sizes, viewer paths, phone memory
and network conditions before delivery is committed. Validation must prove first
meaningful frame, peak memory, bytes transferred, Range/ETag behaviour, capability
expiry, asset integrity, fallback, disk-capacity replication and cleanup using
those assets. Unit tests, Docker smoke, real GPU, physical Android and production
are distinct evidence classes. Product priority and status remain in the
[Roadmap](ROADMAP.md).
