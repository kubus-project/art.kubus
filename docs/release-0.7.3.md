# art.kubus 0.7.3

Release 0.7.3 updates the frontend version to `0.7.3+26080401`.

## Highlights

- Fixes SEO artwork deep links so a detail response is retained while the
  artwork collection refreshes, preventing valid public artwork pages from
  falling back to an erroneous not-found state.
- Hardens the guest activation and post-auth flow: analytics consent is
  rechecked before Meta events, activation prompts have a deployment-level
  kill switch, and non-replayable actions cannot restore stale intents.
- Preserves comment-specific authentication copy and telemetry without
  persisting comment drafts across authentication.

## Validation

The release candidate passed Flutter analysis and tests, Android and iOS
release compilation, the exact web-artifact browser smoke test, production
routing checks, and a successful staging promotion from `dev`.
