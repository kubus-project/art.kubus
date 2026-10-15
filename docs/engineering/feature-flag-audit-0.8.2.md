# Feature flag audit, 2026-10-09 (0.8.2)

Scope: the user-facing flags that read as "disabled" in the app and its build pipeline. Sources read: `lib/config/config.dart`, `lib/main.dart`, `scripts/prepare_public_build_config.mjs`, and the `web-artifact`, `deploy-development`, `release-production` and `mobile-release` workflows. Deployed values were checked where they can be read without credentials: GitHub environment variables, and the running backend container.

Classes: **A** finished, disabled by accident. **B** finished, waiting on a backend deploy. **C** experimental, intentionally off. **D** security or privacy sensitive, intentionally restricted. **E** diagnostic, must stay off in production.

| Flag | Source default | Build override | Dev / prod pipeline | Backend dependency | Class | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `COMMUNITY_MULTI_MEDIA_ENABLED` | `!isProduction` (release builds off) | `KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED` through `prepare_public_build_config.mjs` | was `false` for push, dispatch and production; now `true`, `false` is the rollback | `art.kubus-backend#79` and migration 098. Verified live on Oracle and Home at `ce11d5fc` | B, now resolved | **Changed.** Pipeline defaults to enabled; Dart default untouched so a build that skips the pipeline cannot reach an old backend by accident |
| `ANALYTICS_APP_ENABLED` | `isProduction` | `KUBUS_ANALYTICS_APP_ENABLED` (default `true` in the script) | enabled in web builds; mobile reads the repo variable | `analytics` ingest, consent-gated | enabled | Not disabled. It is capability, never consent; `ConfigProvider` still needs the user's opt-in |
| `SEO_PUBLIC_PAGES_ENABLED` | `true` | passed `true` by `web-artifact.yml` | enabled | public page renderer on the backend | enabled | No change |
| `PUBLIC_FLUTTER_TAKEOVER_ENABLED` | `true` | passed `true` by `web-artifact.yml` | enabled; production variable `EXPECT_PUBLIC_FLUTTER_TAKEOVER=true` | public entity pages | enabled | No change |
| `META_PIXEL_ENABLED` | `false` | none in the pipeline | off | none; needs a pixel id and consent | D | Leave off. Adds a third-party script, so it needs an explicit owner decision |
| `KUBUS_ENABLE_WEB_SEMANTICS` | `false`, forced `false` by the script | none | off | none | E | Leave off. It only stops the app forcing the accessibility tree on for everyone; a screen reader still switches it on through Flutter's own placeholder, which is how the player's labels were checked |
| `enableGoogleOneTapWeb` (Google One Tap) | `false`, a source constant | none | off | Google client ids exist | C and D | Leave off. A sign-in prompt behaviour change, not part of this task |
| `enableTokenSwap` | `false`, a source constant with a comment that it is deliberate | none | off | wallet settlement | C and D | Leave off. Financial surface |
| `enableIPFS` | `false`, "future feature" | none | off | IPFS client integration | C | Leave off. Gateway URLs are still displayed through `MediaUrlResolver`; this flag gates a client integration, not display |
| `MAP_WEB_PRESERVE_DRAWING_BUFFER` | `false` | `--dart-define` | off | none | E | Leave off. It costs map performance and exists to diagnose WebGL context loss |
| `enableAnonymousMode`, `enableBackgroundMusic` | `false` | none | off | none | C | Not part of this task |

Everything else in `AppConfig` that is a bare constant is already `true`.

## What was changed because of this audit

Only the Community flag. The multi-file picker was merged but unreachable in a public build because every workflow defaulted the flag to `false`, and `deploy-development` turned a push into `inputs.community_multi_media_enabled == true`, which is `false` when there are no inputs. A push to `dev` now builds the enabled variant; only a manual dispatch with the input set to `false` builds the rollback variant. Tests in `scripts/prepare_public_build_config.test.mjs` pin the script default, the three workflow defaults and that expression, and that the artifact records the capability.

## Rollback pairing

With the flag off, composers accept one attachment and **1,000-character** captions, which is what a pre-#79 backend validates. If the backend is ever rolled back, rebuild the frontend with `false` first so the two agree.

## Where the deployed values are known

| Environment | Frontend | API it talks to | Verified |
| --- | --- | --- | --- |
| development (`dev.kubus.site`, behind basic auth) | built by `deploy-development.yml` | `https://api.kubus.site` (repository variable `KUBUS_BACKEND_URL`) | the served artifact is behind credentials that are not available here, so the capability is read from the build artifact's `kubus-community-build.json` in the workflow run, not from the live host |
| production (`app.kubus.site`) | last released build, flag off | `https://api.kubus.site` | not changed by this work |
| backend, Oracle and Home | n/a | n/a | both containers report `GIT_COMMIT=ce11d5fc`; the loaded validator reports limit 2,200 and ten items |
