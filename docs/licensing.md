# Licensing overview

This page is a human-readable summary. It does not replace the actual license texts, which control.

## art.kubus ecosystem

```
art.kubus ecosystem
│
├── art.kubus Flutter client (this repository)   MPL-2.0
├── public protocol / SDKs                       Apache-2.0 where marked
├── kubus-node                                    AGPL-3.0-only (kubus-project/kubus-node)
├── art.kubus-backend                             separate repository / separate licensing decision
├── third-party software                          respective upstream licenses
├── official branding                             no trademark rights granted by the software licenses
└── artwork / user / institutional content        outside the software licenses; governed separately
```

## art.kubus (this repository)

- **Application source:** MPL-2.0 — see [`../LICENSE`](../LICENSE) and [`../NOTICE`](../NOTICE).
- **Explicit protocol/SDK components:** Apache-2.0 where marked. This repository refers to such files as "designated public platform API artifacts" (see [`OPEN_PLATFORM.md`](OPEN_PLATFORM.md), [`../LICENSE_ASSETS.md`](../LICENSE_ASSETS.md), [`../NOTICE`](../NOTICE)). Only files explicitly marked/documented as Apache-2.0 carry that license; everything else in the client is MPL-2.0.
- **Third-party software:** respective upstream licenses — see [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
- **Backend submodule:** `backend/` is a separate repository (`art.kubus-backend`) with its own, separate licensing terms. It is not MPL-2.0 and is not covered by this document.
- **Branding:** not granted by MPL-2.0 or Apache-2.0 — see [`../TRADEMARK.md`](../TRADEMARK.md).
- **User content:** not covered by the source-code license. Artwork, photographs, profile images, exhibition/institution media, and other user- or institution-supplied content are governed by Terms of Service and content policy, not by MPL-2.0/Apache-2.0. See [`OPEN_PLATFORM.md`](OPEN_PLATFORM.md).

## Why MPL-2.0

MPL-2.0 is file-level copyleft: modifications to MPL-covered files that are distributed as part of a build remain subject to MPL-2.0 (source of those specific files must be made available), while separate software can be combined with the application (e.g. linked, or included alongside it) without automatically becoming MPL-covered itself. This keeps the official client open while allowing proprietary software to integrate around it. This is a summary, not legal advice — the license text in [`../LICENSE`](../LICENSE) controls.

## kubus-node

See the [kubus-node repository](https://github.com/kubus-project/kubus-node)'s `docs/licensing.md` for its own overview. In short: kubus-node (the network node/runtime) is AGPL-3.0-only, so that improvements to network-operated deployments of the node remain open to the users interacting with them.
