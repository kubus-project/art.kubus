import 'dart:async';

import 'package:flutter/material.dart';
import '../../config/config.dart';
import '../../widgets/app_loading.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/avatar_widget.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/platform_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/user_service.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/creator_display_format.dart';
import '../../utils/search_suggestions.dart';
import '../../utils/user_profile_navigation.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/glass_components.dart';

class _ProfileListCacheEntry {
  final List<Map<String, dynamic>> entries;
  final DateTime fetchedAt;

  const _ProfileListCacheEntry({
    required this.entries,
    required this.fetchedAt,
  });
}

// Helper methods for ProfileScreen
class ProfileScreenMethods {
  static const Duration _prefetchCacheTtl = Duration(minutes: 2);

  static final Map<String, _ProfileListCacheEntry> _followersCache =
      <String, _ProfileListCacheEntry>{};
  static final Map<String, _ProfileListCacheEntry> _followingCache =
      <String, _ProfileListCacheEntry>{};
  static final Map<String, String> _followersErrors = <String, String>{};
  static final Map<String, String> _followingErrors = <String, String>{};

  static final Map<String, Future<List<Map<String, dynamic>>>>
      _followersFetchInFlight = <String, Future<List<Map<String, dynamic>>>>{};
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _followingFetchInFlight = <String, Future<List<Map<String, dynamic>>>>{};

  static final Map<String, Future<void>> _profilePrefetchInFlight =
      <String, Future<void>>{};
  static final Map<String, DateTime> _profilePrefetchedAt =
      <String, DateTime>{};

  static String _canonicalWallet(String walletAddress) {
    return WalletUtils.canonical(walletAddress);
  }

  static bool _isFresh(DateTime fetchedAt) {
    return DateTime.now().difference(fetchedAt) <= _prefetchCacheTtl;
  }

  static List<Map<String, dynamic>> _cloneRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>>? prefetchedFollowersForWallet(
    String walletAddress, {
    bool allowStale = true,
  }) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return null;
    final cached = _followersCache[canonicalWallet];
    if (cached == null) return null;
    if (!allowStale && !_isFresh(cached.fetchedAt)) {
      return null;
    }
    return _cloneRows(cached.entries);
  }

  static List<Map<String, dynamic>>? getCachedFollowers(
    String walletAddress, {
    bool allowStale = true,
  }) {
    return prefetchedFollowersForWallet(
      walletAddress,
      allowStale: allowStale,
    );
  }

  static List<Map<String, dynamic>>? prefetchedFollowingForWallet(
    String walletAddress, {
    bool allowStale = true,
  }) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return null;
    final cached = _followingCache[canonicalWallet];
    if (cached == null) return null;
    if (!allowStale && !_isFresh(cached.fetchedAt)) {
      return null;
    }
    return _cloneRows(cached.entries);
  }

  static List<Map<String, dynamic>>? getCachedFollowing(
    String walletAddress, {
    bool allowStale = true,
  }) {
    return prefetchedFollowingForWallet(
      walletAddress,
      allowStale: allowStale,
    );
  }

  static bool isFollowersLoading(String walletAddress) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return false;
    return _followersFetchInFlight.containsKey(canonicalWallet);
  }

  static bool isFollowingLoading(String walletAddress) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return false;
    return _followingFetchInFlight.containsKey(canonicalWallet);
  }

  static String? followersErrorForWallet(String walletAddress) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return null;
    return _followersErrors[canonicalWallet];
  }

  static String? followingErrorForWallet(String walletAddress) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return null;
    return _followingErrors[canonicalWallet];
  }

  static bool isFollowersCacheStale(String walletAddress) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return true;
    final cached = _followersCache[canonicalWallet];
    if (cached == null) return true;
    return !_isFresh(cached.fetchedAt);
  }

  static bool isFollowingCacheStale(String walletAddress) {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return true;
    final cached = _followingCache[canonicalWallet];
    if (cached == null) return true;
    return !_isFresh(cached.fetchedAt);
  }

  static Future<List<Map<String, dynamic>>> fetchFollowersForWallet(
    String walletAddress, {
    bool force = false,
  }) async {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final cached = _followersCache[canonicalWallet];
    if (!force && cached != null && _isFresh(cached.fetchedAt)) {
      return _cloneRows(cached.entries);
    }

    final existingInFlight = _followersFetchInFlight[canonicalWallet];
    if (existingInFlight != null) {
      return existingInFlight;
    }

    final future = (() async {
      try {
        final rows = await BackendApiService()
            .getFollowers(walletAddress: canonicalWallet);
        final normalizedRows = _cloneRows(rows);
        _followersCache[canonicalWallet] = _ProfileListCacheEntry(
          entries: normalizedRows,
          fetchedAt: DateTime.now(),
        );
        _followersErrors.remove(canonicalWallet);
        return _cloneRows(normalizedRows);
      } catch (e) {
        _followersErrors[canonicalWallet] = e.toString();
        rethrow;
      } finally {
        _followersFetchInFlight.remove(canonicalWallet);
      }
    })();

    _followersFetchInFlight[canonicalWallet] = future;
    return future;
  }

  static Future<List<Map<String, dynamic>>> prefetchFollowers(
    String walletAddress, {
    bool force = false,
  }) {
    return fetchFollowersForWallet(walletAddress, force: force);
  }

  static Future<List<Map<String, dynamic>>> fetchFollowingForWallet(
    String walletAddress, {
    bool force = false,
  }) async {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final cached = _followingCache[canonicalWallet];
    if (!force && cached != null && _isFresh(cached.fetchedAt)) {
      return _cloneRows(cached.entries);
    }

    final existingInFlight = _followingFetchInFlight[canonicalWallet];
    if (existingInFlight != null) {
      return existingInFlight;
    }

    final future = (() async {
      try {
        final rows = await BackendApiService()
            .getFollowing(walletAddress: canonicalWallet);
        final normalizedRows = _cloneRows(rows);
        _followingCache[canonicalWallet] = _ProfileListCacheEntry(
          entries: normalizedRows,
          fetchedAt: DateTime.now(),
        );
        _followingErrors.remove(canonicalWallet);
        return _cloneRows(normalizedRows);
      } catch (e) {
        _followingErrors[canonicalWallet] = e.toString();
        rethrow;
      } finally {
        _followingFetchInFlight.remove(canonicalWallet);
      }
    })();

    _followingFetchInFlight[canonicalWallet] = future;
    return future;
  }

  static Future<List<Map<String, dynamic>>> prefetchFollowing(
    String walletAddress, {
    bool force = false,
  }) {
    return fetchFollowingForWallet(walletAddress, force: force);
  }

  static Future<void> prefetchOtherUserProfileData(
    BuildContext context, {
    required String walletAddress,
    bool force = false,
    bool prefetchStatsSnapshot = true,
  }) async {
    final canonicalWallet = _canonicalWallet(walletAddress);
    if (canonicalWallet.isEmpty) return;

    if (!force) {
      final inFlight = _profilePrefetchInFlight[canonicalWallet];
      if (inFlight != null) {
        await inFlight;
        return;
      }

      final lastPrefetchedAt = _profilePrefetchedAt[canonicalWallet];
      final followersCached = _followersCache.containsKey(canonicalWallet);
      final followingCached = _followingCache.containsKey(canonicalWallet);
      if (lastPrefetchedAt != null &&
          _isFresh(lastPrefetchedAt) &&
          followersCached &&
          followingCached) {
        return;
      }
    }

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final artworkProvider =
        Provider.of<ArtworkProvider>(context, listen: false);

    final currentWallet = (walletProvider.currentWalletAddress ??
            profileProvider.currentWalletAddress)
        ?.trim();
    final includePrivate = currentWallet != null &&
        currentWallet.isNotEmpty &&
        WalletUtils.equals(currentWallet, canonicalWallet);

    Future<void> runPrefetch() async {
      if (prefetchStatsSnapshot) {
        try {
          await profileProvider.refreshStats(
            forceRefresh: force,
            walletAddress: canonicalWallet,
          );
        } catch (_) {}
        try {
          await UserService.fetchAndUpdateUserStats(canonicalWallet);
        } catch (_) {}
      }

      await Future.wait<void>([
        (() async {
          try {
            await fetchFollowersForWallet(canonicalWallet, force: force);
          } catch (_) {}
        })(),
        (() async {
          try {
            await fetchFollowingForWallet(canonicalWallet, force: force);
          } catch (_) {}
        })(),
        (() async {
          try {
            await artworkProvider.loadArtworksForWallet(
              canonicalWallet,
              force: force,
              includePrivateForWallet: includePrivate,
            );
          } catch (_) {}
        })(),
      ]);
    }

    final inFlight = runPrefetch();
    _profilePrefetchInFlight[canonicalWallet] = inFlight;
    try {
      await inFlight;
      _profilePrefetchedAt[canonicalWallet] = DateTime.now();
    } finally {
      _profilePrefetchInFlight.remove(canonicalWallet);
    }
  }

  static void showFollowers(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final resolvedWallet = (targetWallet != null && targetWallet.isNotEmpty)
        ? targetWallet
        : (profileProvider.currentWalletAddress ??
            walletProvider.currentWalletAddress);

    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      return;
    }

    // Kick off data prep before opening; modal opens immediately with cache.
    try {
      unawaited(prefetchFollowers(resolvedWallet));
    } catch (_) {}
    final prefetchedFollowers = getCachedFollowers(resolvedWallet);

    // Open immediately; do not block UI on best-effort refresh.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: !isDesktopLike,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowersBottomSheet(
        walletAddress: resolvedWallet,
        initialFollowers: prefetchedFollowers,
      ),
    );
  }

  static void showFollowing(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final resolvedWallet = (targetWallet != null && targetWallet.isNotEmpty)
        ? targetWallet
        : (profileProvider.currentWalletAddress ??
            walletProvider.currentWalletAddress);

    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      return;
    }

    try {
      unawaited(prefetchFollowing(resolvedWallet));
    } catch (_) {}
    final prefetchedFollowing = getCachedFollowing(resolvedWallet);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: !isDesktopLike,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowingBottomSheet(
        walletAddress: resolvedWallet,
        initialFollowing: prefetchedFollowing,
      ),
    );
  }

  static void showArtworks(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    final artworkProvider =
        Provider.of<ArtworkProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final resolvedWallet = (targetWallet != null && targetWallet.isNotEmpty)
        ? targetWallet
        : (profileProvider.currentWalletAddress ??
            walletProvider.currentWalletAddress);

    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      return;
    }

    // Prime wallet-keyed artworks cache before modal open (non-blocking).
    final currentWallet = (walletProvider.currentWalletAddress ??
            profileProvider.currentWalletAddress)
        ?.trim();
    final includePrivate = currentWallet != null &&
        currentWallet.isNotEmpty &&
        WalletUtils.equals(currentWallet, resolvedWallet);
    try {
      unawaited(
        artworkProvider.loadArtworksForWallet(
          resolvedWallet,
          force: false,
          includePrivateForWallet: includePrivate,
        ),
      );
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: !isDesktopLike,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArtworksBottomSheet(walletAddress: resolvedWallet),
    );
  }

  static void showCollections(BuildContext context) {
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: !isDesktopLike,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CollectionsBottomSheet(),
    );
  }
}

// ==================== Followers Bottom Sheet ====================
class _FollowersBottomSheet extends StatefulWidget {
  final String? walletAddress;
  final List<Map<String, dynamic>>? initialFollowers;

  const _FollowersBottomSheet({
    this.walletAddress,
    this.initialFollowers,
  });

  @override
  State<_FollowersBottomSheet> createState() => _FollowersBottomSheetState();
}

class _FollowersBottomSheetState extends State<_FollowersBottomSheet> {
  List<Map<String, dynamic>>? _followers;
  bool _isLoading = true;
  String? _error;
  bool _didWarmProfileCache = false;

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _boolOrFalse(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    return false;
  }

  String? _resolveWalletAddress() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final explicitWallet = widget.walletAddress?.trim();
    final resolvedWallet = (explicitWallet != null && explicitWallet.isNotEmpty)
        ? explicitWallet
        : (profileProvider.currentWalletAddress ??
            walletProvider.currentWalletAddress);
    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      return null;
    }
    return WalletUtils.canonical(resolvedWallet);
  }

  @override
  void initState() {
    super.initState();
    _followers = widget.initialFollowers
        ?.map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    _isLoading = _followers == null;

    final resolvedWallet = _resolveWalletAddress();
    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      _followers = const <Map<String, dynamic>>[];
      _isLoading = false;
      return;
    }

    final shouldRefresh = _followers == null ||
        ProfileScreenMethods.isFollowersCacheStale(resolvedWallet);

    Future(() async {
      if (shouldRefresh) {
        await _loadFollowers(
          showLoader: _followers == null,
          force: _followers == null,
        );
        return;
      }

      if (_followers != null && _followers!.isNotEmpty) {
        try {
          await _warmProfileCache(_followers!);
        } catch (_) {}
      }
    });
  }

  Future<void> _loadFollowers({
    bool showLoader = true,
    bool force = false,
  }) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final resolvedWallet = _resolveWalletAddress();

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        setState(() {
          _followers = [];
          _isLoading = false;
        });
        return;
      }

      final followers = await ProfileScreenMethods.prefetchFollowers(
        resolvedWallet,
        force: force,
      );

      if (!mounted) return;
      setState(() {
        _followers = followers;
        _error = null;
        _isLoading = false;
      });

      // Best-effort cache warm so list rows and subsequent profile opens have
      // full profile data without waiting for per-row network fetches.
      try {
        Future(() async {
          await _warmProfileCache(followers);
        });
      } catch (_) {}
    } catch (e) {
      AppConfig.debugPrint(
          'ProfileScreenMethods._FollowersBottomSheet: error loading followers: $e');
      if (!mounted) return;
      if (_followers != null && _followers!.isNotEmpty && !showLoader) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = l10n.userProfileFollowersLoadFailedMessage;
        _isLoading = false;
        _followers = _followers ?? [];
      });
    }
  }

  Future<void> _warmProfileCache(List<Map<String, dynamic>> entries) async {
    if (_didWarmProfileCache) return;
    _didWarmProfileCache = true;

    final wallets = <String>[];
    for (final row in entries) {
      final w = _stringOrNull(
        row['walletAddress'] ?? row['wallet_address'] ?? row['id'],
      );
      if (w != null && w.isNotEmpty) wallets.add(w);
    }
    if (wallets.isEmpty) return;

    try {
      await UserService.getUsersByWallets(wallets, forceRefresh: false);
    } catch (_) {}

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    final contentHeight = (MediaQuery.of(context).size.height * 0.5)
        .clamp(160.0, 760.0)
        .toDouble();

    final titleCount = _followers != null ? ' (${_followers!.length})' : '';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: BackdropGlassSheet(
        showBorder: false,
        showHandle: false,
        padding: EdgeInsets.zero,
        backgroundColor: theme.colorScheme.surface,
        enableBlur: !isDesktopLike,
        child: Column(
          children: [
            KubusSheetHeader(
              title: '${l10n.userProfileFollowersStatLabel}$titleCount',
              showHandle: !isDesktopLike,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SizedBox(
              height: contentHeight,
              child: _isLoading
                  ? const AppLoading()
                  : _error != null
                      ? _buildErrorState(theme, _error!)
                      : _followers!.isEmpty
                          ? _buildEmptyState(
                              theme,
                              l10n.userProfileNoFollowersTitle,
                              l10n.userProfileNoFollowersDescription,
                            )
                          : _buildFollowersList(theme, themeProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowersList(ThemeData theme, ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    // Keep modal list cards on the opaque path for reliability across
    // mobile/desktop/web scrolling compositors.
    const enableCardBlur = false;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _followers!.length,
      itemBuilder: (context, index) {
        final follower = _followers![index];
        final rawUsername = _stringOrNull(follower['username']) ?? '';
        final username = rawUsername.startsWith('@')
            ? rawUsername.substring(1).trim()
            : rawUsername;
        final mapDisplayName = _stringOrNull(
          follower['displayName'] ??
              follower['display_name'] ??
              follower['name'],
        );
        final walletAddress = _stringOrNull(
              follower['walletAddress'] ??
                  follower['wallet_address'] ??
                  follower['id'],
            ) ??
            '';
        final cachedUser = walletAddress.isNotEmpty
            ? UserService.getCachedUser(walletAddress)
            : null;

        final mapIsVerified =
            _boolOrFalse(follower['isVerified'] ?? follower['is_verified']);
        final isVerified = mapIsVerified || (cachedUser?.isVerified ?? false);

        final mapAvatarUrl = _stringOrNull(
          follower['profileImageUrl'] ??
              follower['avatar'] ??
              follower['avatarUrl'] ??
              follower['avatar_url'],
        );

        final displayName = mapDisplayName ?? cachedUser?.name;
        final avatarUrl = mapAvatarUrl ?? cachedUser?.profileImageUrl;
        final cachedUsername = (cachedUser?.username ?? '').trim();
        final resolvedUsername =
            username.isNotEmpty ? username : cachedUsername;

        final formatted = CreatorDisplayFormat.format(
          fallbackLabel: walletAddress.isNotEmpty
              ? maskWallet(walletAddress)
              : l10n.commonUnknownArtist,
          displayName: displayName,
          username: resolvedUsername,
          wallet: walletAddress,
        );
        final subtitle = formatted.secondary ??
            (walletAddress.isNotEmpty ? maskWallet(walletAddress) : null);

        final canNavigate = walletAddress.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
          child: LiquidGlassCard(
            borderRadius: BorderRadius.circular(KubusRadius.md),
            enableBlur: enableCardBlur,
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.xs,
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: !canNavigate
                    ? null
                    : () {
                        Navigator.pop(context);
                        UserProfileNavigation.open(
                          context,
                          userId: walletAddress,
                          username: resolvedUsername,
                        );
                      },
                contentPadding: EdgeInsets.zero,
                leading: AvatarWidget(
                  wallet: walletAddress,
                  avatarUrl: avatarUrl,
                  radius: 28,
                  enableProfileNavigation: canNavigate,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        formatted.primary,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: themeProvider.accentColor,
                      ),
                    ],
                  ],
                ),
                subtitle: subtitle == null
                    ? null
                    : Text(
                        subtitle,
                        style: KubusTypography.inter(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: KubusTypography.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: KubusTypography.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: KubusTypography.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _loadFollowers(showLoader: true, force: true),
              child: Text(
                l10n.commonRetry,
                style: KubusTypography.inter(
                  color: Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Following Bottom Sheet ====================
class _FollowingBottomSheet extends StatefulWidget {
  final String? walletAddress;
  final List<Map<String, dynamic>>? initialFollowing;

  const _FollowingBottomSheet({
    this.walletAddress,
    this.initialFollowing,
  });

  @override
  State<_FollowingBottomSheet> createState() => _FollowingBottomSheetState();
}

class _FollowingBottomSheetState extends State<_FollowingBottomSheet> {
  List<Map<String, dynamic>>? _following;
  bool _isLoading = true;
  String? _error;
  bool _didWarmProfileCache = false;

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _boolOrFalse(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    return false;
  }

  String? _resolveWalletAddress() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final explicitWallet = widget.walletAddress?.trim();
    final resolvedWallet = (explicitWallet != null && explicitWallet.isNotEmpty)
        ? explicitWallet
        : (profileProvider.currentWalletAddress ??
            walletProvider.currentWalletAddress);
    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      return null;
    }
    return WalletUtils.canonical(resolvedWallet);
  }

  @override
  void initState() {
    super.initState();
    _following = widget.initialFollowing
        ?.map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    _isLoading = _following == null;

    final resolvedWallet = _resolveWalletAddress();
    if (resolvedWallet == null || resolvedWallet.isEmpty) {
      _following = const <Map<String, dynamic>>[];
      _isLoading = false;
      return;
    }

    final shouldRefresh = _following == null ||
        ProfileScreenMethods.isFollowingCacheStale(resolvedWallet);

    Future(() async {
      if (shouldRefresh) {
        await _loadFollowing(
          showLoader: _following == null,
          force: _following == null,
        );
        return;
      }

      if (_following != null && _following!.isNotEmpty) {
        try {
          await _warmProfileCache(_following!);
        } catch (_) {}
      }
    });
  }

  Future<void> _loadFollowing({
    bool showLoader = true,
    bool force = false,
  }) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final resolvedWallet = _resolveWalletAddress();

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        setState(() {
          _following = [];
          _isLoading = false;
        });
        return;
      }

      final following = await ProfileScreenMethods.prefetchFollowing(
        resolvedWallet,
        force: force,
      );

      if (!mounted) return;
      setState(() {
        _following = following;
        _error = null;
        _isLoading = false;
      });

      try {
        Future(() async {
          await _warmProfileCache(following);
        });
      } catch (_) {}
    } catch (e) {
      AppConfig.debugPrint(
          'ProfileScreenMethods._FollowingBottomSheet: error loading following: $e');
      if (!mounted) return;
      if (_following != null && _following!.isNotEmpty && !showLoader) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = l10n.userProfileFollowingLoadFailedMessage;
        _isLoading = false;
        _following = _following ?? [];
      });
    }
  }

  Future<void> _warmProfileCache(List<Map<String, dynamic>> entries) async {
    if (_didWarmProfileCache) return;
    _didWarmProfileCache = true;

    final wallets = <String>[];
    for (final row in entries) {
      final w = _stringOrNull(
        row['walletAddress'] ?? row['wallet_address'] ?? row['id'],
      );
      if (w != null && w.isNotEmpty) wallets.add(w);
    }
    if (wallets.isEmpty) return;

    try {
      await UserService.getUsersByWallets(wallets, forceRefresh: false);
    } catch (_) {}

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    final contentHeight = (MediaQuery.of(context).size.height * 0.5)
        .clamp(160.0, 760.0)
        .toDouble();

    final titleCount = _following != null ? ' (${_following!.length})' : '';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: BackdropGlassSheet(
        showBorder: false,
        showHandle: false,
        padding: EdgeInsets.zero,
        backgroundColor: theme.colorScheme.surface,
        enableBlur: !isDesktopLike,
        child: Column(
          children: [
            KubusSheetHeader(
              title: '${l10n.userProfileFollowingStatLabel}$titleCount',
              showHandle: !isDesktopLike,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SizedBox(
              height: contentHeight,
              child: _isLoading
                  ? const AppLoading()
                  : _error != null
                      ? _buildErrorState(theme, _error!)
                      : _following!.isEmpty
                          ? _buildEmptyState(
                              theme,
                              l10n.userProfileNoFollowingTitle,
                              l10n.userProfileNoFollowingDescription,
                            )
                          : _buildFollowingList(theme, themeProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingList(ThemeData theme, ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    const enableCardBlur = false;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _following!.length,
      itemBuilder: (context, index) {
        final user = _following![index];
        final rawUsername = _stringOrNull(user['username']) ?? '';
        final username = rawUsername.startsWith('@')
            ? rawUsername.substring(1).trim()
            : rawUsername;
        final mapDisplayName = _stringOrNull(
          user['displayName'] ?? user['display_name'] ?? user['name'],
        );
        final walletAddress = _stringOrNull(
              user['walletAddress'] ?? user['wallet_address'] ?? user['id'],
            ) ??
            '';
        final cachedUser = walletAddress.isNotEmpty
            ? UserService.getCachedUser(walletAddress)
            : null;

        final mapIsVerified =
            _boolOrFalse(user['isVerified'] ?? user['is_verified']);
        final isVerified = mapIsVerified || (cachedUser?.isVerified ?? false);

        final mapAvatarUrl = _stringOrNull(
          user['profileImageUrl'] ??
              user['avatar'] ??
              user['avatarUrl'] ??
              user['avatar_url'],
        );

        final displayName = mapDisplayName ?? cachedUser?.name;
        final avatarUrl = mapAvatarUrl ?? cachedUser?.profileImageUrl;
        final cachedUsername = (cachedUser?.username ?? '').trim();
        final resolvedUsername =
            username.isNotEmpty ? username : cachedUsername;

        final formatted = CreatorDisplayFormat.format(
          fallbackLabel: walletAddress.isNotEmpty
              ? maskWallet(walletAddress)
              : l10n.commonUnknownArtist,
          displayName: displayName,
          username: resolvedUsername,
          wallet: walletAddress,
        );
        final subtitle = formatted.secondary ??
            (walletAddress.isNotEmpty ? maskWallet(walletAddress) : null);

        final canNavigate = walletAddress.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
          child: LiquidGlassCard(
            borderRadius: BorderRadius.circular(KubusRadius.md),
            enableBlur: enableCardBlur,
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.xs,
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: !canNavigate
                    ? null
                    : () {
                        Navigator.pop(context);
                        UserProfileNavigation.open(
                          context,
                          userId: walletAddress,
                          username: resolvedUsername,
                        );
                      },
                contentPadding: EdgeInsets.zero,
                leading: AvatarWidget(
                  wallet: walletAddress,
                  avatarUrl: avatarUrl,
                  radius: 28,
                  enableProfileNavigation: canNavigate,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        formatted.primary,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: themeProvider.accentColor,
                      ),
                    ],
                  ],
                ),
                subtitle: subtitle == null
                    ? null
                    : Text(
                        subtitle,
                        style: KubusTypography.inter(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: KubusTypography.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: KubusTypography.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: KubusTypography.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _loadFollowing(showLoader: true, force: true),
              child: Text(
                l10n.commonRetry,
                style: KubusTypography.inter(
                  color: Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Artworks Bottom Sheet ====================
class _ArtworksBottomSheet extends StatelessWidget {
  final String walletAddress;

  const _ArtworksBottomSheet({required this.walletAddress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    const enableCardBlur = false;
    final operationKey =
        'load_artworks_wallet_${WalletUtils.canonical(walletAddress)}';
    final contentHeight = (MediaQuery.of(context).size.height * 0.6)
        .clamp(180.0, 900.0)
        .toDouble();

    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final userArtworks = artworkProvider.artworksForWallet(walletAddress);
        final isLoading = artworkProvider.isLoading(operationKey);

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: BackdropGlassSheet(
            showBorder: false,
            showHandle: false,
            padding: EdgeInsets.zero,
            backgroundColor: theme.colorScheme.surface,
            enableBlur: !isDesktopLike,
            child: Column(
              children: [
                KubusSheetHeader(
                  title:
                      '${l10n.userProfileArtworksTitle} (${userArtworks.length})',
                  showHandle: !isDesktopLike,
                  trailing: KubusGlassIconButton(
                    icon: Icons.close,
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(
                  height: contentHeight,
                  child: (isLoading && userArtworks.isEmpty)
                      ? const AppLoading()
                      : userArtworks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.artistGalleryEmptyTitle,
                                    style: KubusTypography.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: userArtworks.length,
                              itemBuilder: (context, index) {
                                final artwork = userArtworks[index];
                                return GestureDetector(
                                  onTap: () {
                                    openArtwork(context, artwork.id,
                                        source: 'profile_methods');
                                  },
                                  child: LiquidGlassCard(
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.lg),
                                    enableBlur: enableCardBlur,
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(
                                                    KubusRadius.lg),
                                              ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  theme.colorScheme
                                                      .primaryContainer
                                                      .withValues(alpha: 0.34),
                                                  theme.colorScheme
                                                      .surfaceContainerHigh
                                                      .withValues(alpha: 0.18),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: theme.colorScheme.outline
                                                    .withValues(alpha: 0.12),
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.image_outlined,
                                                size: 32,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.58),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(
                                              KubusSpacing.sm),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                artwork.title,
                                                style: KubusTypography.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(
                                                  height: KubusSpacing.xxs),
                                              Text(
                                                l10n.userProfileLikesLabel(
                                                    artwork.likesCount),
                                                style: KubusTypography.inter(
                                                  fontSize: 12,
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Collections Bottom Sheet ====================
class _CollectionsBottomSheet extends StatelessWidget {
  const _CollectionsBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: BackdropGlassSheet(
        showBorder: false,
        showHandle: false,
        padding: EdgeInsets.zero,
        backgroundColor: theme.colorScheme.surface,
        enableBlur: !isDesktopLike,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KubusSheetHeader(
              title: l10n.userProfileCollectionsTitle,
              showHandle: !isDesktopLike,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KubusSpacing.xl),
              child: LiquidGlassCard(
                borderRadius: BorderRadius.circular(KubusRadius.lg),
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: Column(
                  children: [
                    Icon(
                      Icons.collections_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.userProfileNoCollectionsTitle,
                      style: KubusTypography.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.userProfileNoCollectionsDescription,
                      style: KubusTypography.inter(
                        fontSize: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
