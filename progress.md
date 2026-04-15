# Other-user profile modal prefetch shipping fix

## Problem statement
Other-user profile flows still show first-tap dependency in followers/following/artworks modal content. The intended behavior is prefetch-on-profile-open so modal bodies render with visible content immediately on both mobile and desktop.

## Root cause
- Viewed-user social list state was not exposed as an explicit keyed cache contract (loading/error getters missing).
- Mobile other-user profile lacked an artworks stat/tap affordance for parity with desktop modal flow.
- Modal openers kicked off some background work after opening rather than priming shared cache state first.
- Tracking docs were accidentally empty and needed rehydration.

## Exact files changed
- `lib/screens/community/profile_screen_methods.dart`
- `lib/screens/community/user_profile_screen.dart`
- `lib/screens/desktop/community/desktop_user_profile_screen.dart`
- `lib/providers/artwork_provider.dart` (verified canonical source; no code changes required)
- `progress.md`
- `todo.md`

## Implementation log
1. Re-loaded all required instruction files (`AGENTS.md` root + scoped files) and verified constraints.
2. Re-read in-scope files end-to-end to confirm real current state before editing.
3. Restored tracking docs (`progress.md`, `todo.md`) and started a live checklist.
4. Ran required three subagent audits:
	- Viewed-user data flow
	- Modal render/state ownership
	- Validation/regression review
5. Implemented keyed viewed-user social cache helper contract in `profile_screen_methods.dart`:
	- Added loading/error state maps per wallet/list type.
	- Added required helper API methods:
	  - `prefetchFollowers(...)`
	  - `prefetchFollowing(...)`
	  - `getCachedFollowers(...)`
	  - `getCachedFollowing(...)`
	  - `isFollowersLoading(...)`
	  - `isFollowingLoading(...)`
	- Added optional error getters:
	  - `followersErrorForWallet(...)`
	  - `followingErrorForWallet(...)`
6. Updated modal openers so cache priming starts before sheet open:
	- `showFollowers(...)` starts `prefetchFollowers(...)` before opening.
	- `showFollowing(...)` starts `prefetchFollowing(...)` before opening.
	- `showArtworks(...)` starts `ArtworkProvider.loadArtworksForWallet(...)` before opening.
7. Kept modal-owned fetch lifecycle fallback-only:
	- `_FollowersBottomSheet` / `_FollowingBottomSheet` still support controlled fallback refresh when cache is stale/missing.
	- Fallback fetches write into shared keyed cache via `prefetchFollowers(...)` / `prefetchFollowing(...)`.
8. Improved profile-open and refresh coherence on both screens:
	- Mobile + desktop `_loadUser(...)` now support `forceModalPrefetch`.
	- Initial profile open runs prefetch non-blocking.
	- Pull-to-refresh runs forced prefetch (`forceModalPrefetch: true`) to refresh stats/list/modal coherence.
9. Ensured desktop follow error coherence parity:
	- Added missing `_loadUserStats(skipFollowersOverwrite: true)` in desktop follow/unfollow error branch.
10. Added mobile artworks modal parity in stats row:
	 - Added artworks stat count sourced from `ArtworkProvider.artworksForWallet(user!.id).length`.
	 - Added tap handler to open `ProfileScreenMethods.showArtworks(...)`.
11. Preserved reliable modal rendering path (`enableBlur: false` for modal list/grid cards) and existing visual language.
12. Formatted changed Dart files and ran analyzer + tests.

## Validation notes
- `flutter analyze lib/screens/community/profile_screen_methods.dart lib/screens/community/user_profile_screen.dart lib/screens/desktop/community/desktop_user_profile_screen.dart lib/providers/artwork_provider.dart`
  - Result: `No issues found!`
- Task run: `Flutter: Safe test (focused community+desktop)`
  - Result: `All tests passed!` (9 tests)
- `flutter test test/community/profile_modal_prefetch_regression_test.dart`
  - Result: `All tests passed!`

## Final status
- ✅ Completed end-to-end and validated.
