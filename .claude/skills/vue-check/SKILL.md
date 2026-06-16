---
name: vue-check
description: Lint, type-check, and test the Vue 3 frontends (admin.kubus and art.kubus.site_webpage) before committing or opening a PR. Use to validate frontend changes.
disable-model-invocation: true
---

# vue-check

Two Vue 3 + Vite + TypeScript frontends, each in its own workspace dir:

| Project | Path | Notes |
|---------|------|-------|
| admin dashboard | `../admin.kubus` | Pinia, vue-router, chart.js, Vitest |
| marketing site | `../art.kubus.site_webpage` | Leaflet map, SEO page generation |

Pick the project you changed and run its checks from that directory.

## admin.kubus
```bash
cd ../admin.kubus
npm run lint        # eslint . --ext .ts,.vue
npm run build       # vue-tsc (type-check) && vite build
npm run test        # vitest run
```
To auto-fix lint: `npm run lint:fix`.

## art.kubus.site_webpage
```bash
cd ../art.kubus.site_webpage
npm run lint:check  # eslint without --fix (use `npm run lint` to auto-fix)
npm run test        # vitest run
npm run build       # regenerates SEO pages + sitemap, then vue-tsc --noEmit && vite build
npm run test:seo    # validates generated SEO output (after a build)
```

## Pre-PR checklist
- [ ] `lint` clean (or `lint:fix` applied and reviewed)
- [ ] type-check passes (`vue-tsc` via `build`)
- [ ] `vitest run` green
- [ ] for the site: `ci:seo` (build + SEO output check) passes

## Conventions
- Keep the marketing-site landing on the single page-level backdrop; sections
  stay transparent (no per-section veils/gradients). Don't reintroduce
  per-section gradient overlays on the homepage.
