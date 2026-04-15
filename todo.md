# Other-user profile modal prefetch todo

- [x] Recreate `progress.md` and `todo.md` with live tracking
- [x] Run subagent audit: viewed-user data-flow
- [x] Run subagent audit: modal render/state ownership
- [x] Run subagent audit: validation/regression review
- [x] Add/confirm keyed viewed-user social cache helpers (followers/following + loading/error getters)
- [x] Ensure prefetch is triggered on viewed profile open (mobile + desktop) and guarded against loops
- [x] Ensure pull-to-refresh/profile reload forces coherent refresh (stats + followers + following + artworks)
- [x] Keep modal open behavior immediate with prefetched shared state as primary path
- [x] Add mobile artworks stat/tap affordance for parity with desktop modal path
- [x] Reconfirm desktop artworks stat uses `ArtworkProvider.artworksForWallet(...).length` and opens artworks modal
- [x] Verify modal card reliability path (no blank shells in scrollable modal content)
- [x] Run format/analyze/focused tests
- [x] Update `progress.md` validation + final status
