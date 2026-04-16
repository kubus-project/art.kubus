# Other-User Profile Stats and Modals Todo

- [x] Review repo `AGENTS.md` files before changes.
- [x] Create root tracking files.
- [x] Patch artworks modal card rendering to use actual resolved covers.
- [x] Preserve wallet-keyed `ArtworkProvider.artworksForWallet(viewedWallet)` source.
- [x] Keep follower/following modal cache architecture unchanged.
- [x] Format touched Dart files.
- [x] Run Flutter analysis on touched files.
- [x] Update tracking files with final validation status.

## Follow-up: Other-User follower/following stale stat regression

- [x] Inspect mobile `UserProfileScreen._loadUser()` stats call path.
- [x] Inspect desktop `UserProfileScreen._loadUser()` stats call path.
- [x] Remove `skipFollowersOverwrite: true` from normal `_loadUser()` stats refresh on mobile.
- [x] Remove `skipFollowersOverwrite: true` from normal `_loadUser()` stats refresh on desktop.
- [x] Keep `skipFollowersOverwrite: true` only for explicit optimistic follow/unfollow failure handling.
- [x] Format touched Dart files.
- [x] Run `flutter analyze` on touched files.
- [x] Run focused community+desktop Flutter tests.
- [x] Update `progress.md` and `todo.md` with this fix and validation evidence.
