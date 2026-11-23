# Third-party notices

This document identifies components bundled or vendored in this repository that are **not** licensed under MPL-2.0 (or, where applicable, Apache-2.0 for designated public platform API artifacts). It does not relicense any of them, and it does not attempt to reproduce every dependency's license text.

The repository's own root [`LICENSE`](LICENSE) file is MPL-2.0 text only. Because this repository also redistributes files licensed under the Apache License 2.0 (see the Android Gradle wrapper and the bundled Material Symbols fonts below), a full copy of the Apache License, Version 2.0 is kept at [`third_party/licenses/APACHE-2.0.txt`](third_party/licenses/APACHE-2.0.txt) to satisfy that license's requirement to include a copy of the license with any redistribution.

## Bundled/vendored components stored in this repository

| Component | Location | License | Notes |
|---|---|---|---|
| `arcore_flutter_plugin` (local override) | `third_party/arcore_flutter_plugin/` | MIT (see its own `LICENSE`) | Local fork/override of an upstream ARCore Flutter plugin. Not MPL-2.0. Preserve its own `LICENSE`/copyright when modifying. |
| MapLibre GL JS (web bundle) | `web/local/maplibre-gl/` | BSD-style (see `LICENSE.txt` in that directory) | Vendored browser map renderer. Not MPL-2.0. |
| Spark (`@sparkjsdev/spark` 2.4.0) and Three.js (`three` 0.185.1), bundled into the spatial viewer | `assets/spatial_viewer/` (`viewer.bundle.js`, built from `src/viewer.js` and the pinned `package.json` / `package-lock.json`) | MIT (Spark: Copyright 2025 World Labs Technologies, Inc.; Three.js: Copyright 2010-2026 three.js authors) | Gaussian-splat renderer and WebGL library used by the native WebView viewer and the Flutter web viewer. Spark was pinned at 2.1.0 until 2026-11-22, when that release's Rust workspace still declared `license = "Proprietary"`; 2.4.0 declares MIT in `package-lock.json` and its published package, and the upstream repository carries an MIT licence at that tag. License texts: [`third_party/licenses/SPARK-MIT.txt`](third_party/licenses/SPARK-MIT.txt), [`third_party/licenses/THREE-MIT.txt`](third_party/licenses/THREE-MIT.txt). Spark 2.4.0 also inlines fflate (MIT, Copyright (c) 2023 Arjun Barrett; [`third_party/licenses/FFLATE-MIT.txt`](third_party/licenses/FFLATE-MIT.txt)) and embeds a WebAssembly module built from Rust crates (23 crate versions, among them dlmalloc, rustc-demangle and two copies of hashbrown) and the Rust standard library (core, alloc, std), all permissive (MIT, Apache-2.0, Unlicense or Zlib), listed with their licences in [`third_party/licenses/SPARK-WASM-CRATES.txt`](third_party/licenses/SPARK-WASM-CRATES.txt). The notices ship with the artefacts, not only with the repository: `npm run build` (`assets/spatial_viewer/build.mjs`) writes the Spark, Three.js and fflate texts into a `/*!` legal comment at the top of `viewer.bundle.js` and writes all four texts (crate list included) to `assets/spatial_viewer/THIRD_PARTY_LICENSES.txt`, a Flutter asset that the app registers with `LicenseRegistry` so it appears on the in-app licence page (`lib/services/third_party_licenses.dart`). `test/spatial_viewer_asset_contract.test.js` decodes the WebAssembly module out of the bundle and fails when a crate it names has no section in that list. Rebuild with `npm ci && npm run build` in that directory; re-check the licence before any Spark upgrade. |
| Material Symbols fonts | `assets/fonts/` | Apache License 2.0 (Google Material Symbols) | Font files themselves are unaffected by this repository's source-code relicensing. License text: [`third_party/licenses/APACHE-2.0.txt`](third_party/licenses/APACHE-2.0.txt). |
| Gradle wrapper | `android/gradlew`, `android/gradlew.bat` | Apache License 2.0 (Gradle project) | Upstream Gradle wrapper scripts, carrying their own SPDX header. License text: [`third_party/licenses/APACHE-2.0.txt`](third_party/licenses/APACHE-2.0.txt). |
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
