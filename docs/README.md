# art.kubus Documentation

This folder contains developer-facing documentation for the **art.kubus Flutter client**, plus notes about the open-platform boundary (what is open vs hosted/proprietary).

If you’re new to the repo, start with `GETTING_STARTED.md`.

## Start here

- **Branching, CI, and deployment**: [`engineering/branching-and-deployment.md`](engineering/branching-and-deployment.md)
- **Current product / SEO / UI-UX programme**: [`PRODUCT_UX_SEO_PROGRAM.md`](PRODUCT_UX_SEO_PROGRAM.md)
- **Current design direction**: [`DESIGN_SYSTEM_V2.md`](DESIGN_SYSTEM_V2.md)
- **Canonical public-entry target**: [`APP_NATIVE_PUBLIC_ENTRY.md`](APP_NATIVE_PUBLIC_ENTRY.md)
- **Setup / run / build**: `GETTING_STARTED.md`
- **What the app does**: `FEATURES.md`
- **Where things live in the UI**: `SCREENS.md`
- **How the client is structured**: `ARCHITECTURE.md`
- **Open platform scope/boundary**: `OPEN_PLATFORM.md`

## Documentation index

| Document | What you’ll find |
|----------|------------------|
| [Getting Started](GETTING_STARTED.md) | Prereqs, running locally, build basics, backend pointers |
| [Features](FEATURES.md) | Feature-level detail and how pieces fit together |
| [Screens](SCREENS.md) | Screen inventory and navigation map |
| [Screenshots](SCREENSHOTS.md) | Where UI screenshots live and how to capture them |
| [Architecture](ARCHITECTURE.md) | Provider-first architecture, boot sequence, key modules |
| [Local Verification](LOCAL_VERIFICATION.md) | Root validation, docs doctor, and Playwright smoke commands |
| [Open Platform](OPEN_PLATFORM.md) | What’s open-source, what’s hosted, and why |
| [Terms of Service (draft)](legal/TERMS_OF_SERVICE.md) | Draft, non-final legal outline (not production terms) |
| [Developer API Terms (draft)](legal/DEVELOPER_API_TERMS.md) | Draft, non-final API terms outline |

## Backend (optional)

This repo also includes a Node/Express backend under `../backend/` for local development / reference.

- Backend overview & setup: `../backend/README.md`

## Platform support (client)

- Android / iOS
- Web
- Windows / macOS / Linux

AR experiences are mobile-focused; web/desktop builds prioritize discovery and community workflows.

## Contributing & policies

- Contribution flow: `../CONTRIBUTING.md`
- Support: `../SUPPORT.md`
- Security: `../SECURITY.md`
- Project guardrails: `../AGENTS.md`

Licensing overview:

- Client code: `../LICENSE` (MPL-2.0) + `../NOTICE`
- Trademarks/branding: `../TRADEMARK.md`
- Assets/content: `../LICENSE_ASSETS.md`
- Full overview: [`licensing.md`](licensing.md)
