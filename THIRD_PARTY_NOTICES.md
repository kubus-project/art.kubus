# Third-party notices

This document identifies components bundled or vendored in this repository that are **not** licensed under MPL-2.0 (or, where applicable, Apache-2.0 for designated public platform API artifacts). It does not relicense any of them, and it does not attempt to reproduce every dependency's license text.

## Bundled/vendored components stored in this repository

| Component | Location | License | Notes |
|---|---|---|---|
| `arcore_flutter_plugin` (local override) | `third_party/arcore_flutter_plugin/` | MIT (see its own `LICENSE`) | Local fork/override of an upstream ARCore Flutter plugin. Not MPL-2.0. Preserve its own `LICENSE`/copyright when modifying. |
| MapLibre GL JS (web bundle) | `web/local/maplibre-gl/` | BSD-style (see `LICENSE.txt` in that directory) | Vendored browser map renderer. Not MPL-2.0. |
| Material Symbols fonts | `assets/fonts/` | Apache License 2.0 (Google Material Symbols) | Font files themselves are unaffected by this repository's source-code relicensing. |
| Brand/marketing images | `assets/images/` (logos, `belilogo*.png`, `logo*.png`, etc.) | All rights reserved by default | Governed by [`LICENSE_ASSETS.md`](LICENSE_ASSETS.md), not MPL-2.0. |
| In-house map styles | `assets/map_styles/` (`kubus_dark.json`, `kubus_light.json`) | First-party, MPL-2.0 (client configuration data) | Not third-party; listed here for completeness since it sits alongside vendored map assets. |

## Flutter/Dart package dependencies

Dependencies declared in `pubspec.yaml` are fetched from pub.dev (or their declared source) and retain their own licenses. This repository does not reproduce their license text here. To inspect the license of any resolved dependency:

- In the running app: Settings → Licenses (uses Flutter's built-in `showLicensePage`, which aggregates license metadata from all resolved packages).
- From the command line: `flutter pub deps` to list resolved packages, then consult each package's page on https://pub.dev for its license.

## Backend submodule

`backend/` is a separate Git submodule pointing to the `art.kubus-backend` repository. It is not part of this repository's source tree or license, has its own licensing terms, and is out of scope for this document.

## Scope

This document does not cover user-uploaded content, artwork, institution media, or other content governed by Terms of Service — see [`docs/licensing.md`](docs/licensing.md) for how the source-code licenses relate to that content.
