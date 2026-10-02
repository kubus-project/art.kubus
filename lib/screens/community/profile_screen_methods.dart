import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import '../../config/config.dart';
import '../../widgets/app_loading.dart';
import '../../utils/design_tokens.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/artwork.dart';
import '../../models/profile_identity_data.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/platform_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/profile_package_service.dart';
import '../../services/user_service.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/creator_display_format.dart';
import '../../utils/profile_package_prefetcher.dart';
import '../../utils/profile_identity_navigation.dart';
import '../../utils/search_suggestions.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/profile/profile_people_list.dart';

class _ProfileListCacheEntry {
  final List<Map<String, dynamic>> entries;
  final DateTime fetchedAt;

  const _ProfileListCacheEntry({
    required this.entries,
    required this.fetchedAt,
  });
}

ProfileIdentityData _profileListIdentityFromPayload(
  Map<String, dynamic> user, {
  required String fallbackLabel,
}) {
  return ProfileIdentityData.fromIdentityPayload(
    {'author': user},
    fallbackLabel: fallbackLabel,
  );
}

String? _peopleStringOrNull(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

bool _peopleBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value?.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

/// Maps a followers/following payload row (plus any cached profile) to a
/// list entry. Role context is shown only when a payload or cached profile
/// actually states it.
ProfilePersonEntry _personEntryFromPayload(
  Map<String, dynamic> row,
  AppLocalizations l10n,
) {
  final rawUsername = _peopleStringOrNull(row['username']) ?? '';
  final username = rawUsername.startsWith('@')
      ? rawUsername.substring(1).trim()
      : rawUsername;
  final wallet = _peopleStringOrNull(
          row['walletAddress'] ?? row['wallet_address'] ?? row['id']) ??
      '';
  final cachedUser =
      wallet.isNotEmpty ? UserService.getCachedUser(wallet) : null;
  final displayName = _peopleStringOrNull(
          row['displayName'] ?? row['display_name'] ?? row['name']) ??
      cachedUser?.name;
  final avatarUrl = _peopleStringOrNull(row['profileImageUrl'] ??
          row['avatar'] ??
          row['avatarUrl'] ??
          row['avatar_url']) ??
      cachedUser?.profileImageUrl;
  final resolvedUsername =
      username.isNotEmpty ? username : (cachedUser?.username ?? '').trim();
  final fallback =
      wallet.isNotEmpty ? maskWallet(wallet) : l10n.commonUnknownArtist;
  final formatted = CreatorDisplayFormat.format(
    fallbackLabel: fallback,
    displayName: displayName,
    username: resolvedUsername,
    wallet: wallet,
  );
  final isInstitution =
      _peopleBool(row['isInstitution'] ?? row['is_institution']) ||
          (cachedUser?.isInstitution ?? false);
  final isArtist = _peopleBool(row['isArtist'] ?? row['is_artist']) ||
      (cachedUser?.isArtist ?? false);
  return ProfilePersonEntry(
    wallet: wallet,
    primary: formatted.primary,
    secondary:
        formatted.secondary ?? (wallet.isNotEmpty ? maskWallet(wallet) : null),
    avatarUrl: avatarUrl,
    username: resolvedUsername.isEmpty ? null : resolvedUsername,
    isVerified: _peopleBool(row['isVerified'] ?? row['is_verified']) ||
        (cachedUser?.isVerified ?? false),
    role: isInstitution
        ? ProfilePersonRole.institution
        : (isArtist ? ProfilePersonRole.artist : null),
  );
}

Widget _buildPeopleList(
  BuildContext context, {
  required List<Map<String, dynamic>>? rows,
  required bool isLoading,
  required Object? loadError,
  required String? errorMessage,
  required VoidCallback onRetry,
  required String emptyTitle,
  required String emptyDescription,
}) {
  final l10n = AppLocalizations.of(context)!;
  final safeRows = rows ?? const <Map<String, dynamic>>[];
  final entries = <ProfilePersonEntry>[];
  final rowByWallet = <String, Map<String, dynamic>>{};
  for (final row in safeRows) {
    final entry = _personEntryFromPayload(row, l10n);
    entries.add(entry);
    rowByWallet[entry.wallet] = row;
  }
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  return ProfilePeopleList(
    entries: isLoading && safeRows.isEmpty ? null : entries,
    isLoading: isLoading,
    error: errorMessage == null ? null : (loadError ?? errorMessage),
    onRetry: onRetry,
    emptyTitle: emptyTitle,
    emptyDescription: emptyDescription,
    viewerWallet: profileProvider.currentWalletAddress,
    onOpen: (entry) {
      final row = rowByWallet[entry.wallet];
      if (row == null) return;
      final identity = _profileListIdentityFromPayload(
        row,
        fallbackLabel: entry.primary,
      );
      Navigator.pop(context);
      openProfileIdentity(context, identity);
    },
  );
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
        (() async {
          try {
            final critical = await ProfilePackageService
                .prefetchPublicProfileCriticalPackage(
              canonicalWallet,
              forceRefresh: force,
            );
            if (critical != null) {
              unawaited(
                ProfilePackageService.prefetchPublicProfileExtendedPackage(
                  critical.user.id,
                  forceRefresh: force,
                  user: critical.user,
                ),
              );
            }
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
  Object? _loadError;
  bool _didWarmProfileCache = false;

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
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
        _loadError = e;
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

    for (final wallet in wallets.take(10)) {
      ProfilePackagePrefetcher.prefetchVisible(wallet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: _buildPeopleList(
                context,
                rows: _followers,
                isLoading: _isLoading,
                loadError: _loadError,
                errorMessage: _error,
                onRetry: () => _loadFollowers(showLoader: true, force: true),
                emptyTitle: l10n.userProfileNoFollowersTitle,
                emptyDescription: l10n.userProfileNoFollowersDescription,
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
  Object? _loadError;
  bool _didWarmProfileCache = false;

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
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
        _loadError = e;
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

    for (final wallet in wallets.take(10)) {
      ProfilePackagePrefetcher.prefetchVisible(wallet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: _buildPeopleList(
                context,
                rows: _following,
                isLoading: _isLoading,
                loadError: _loadError,
                errorMessage: _error,
                onRetry: () => _loadFollowing(showLoader: true, force: true),
                emptyTitle: l10n.userProfileNoFollowingTitle,
                emptyDescription: l10n.userProfileNoFollowingDescription,
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

  Widget _buildArtworkCover({
    required BuildContext context,
    required ThemeData theme,
    required Artwork artwork,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final imageUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: artwork.metadata,
      additionalUrls: artwork.galleryUrls,
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(KubusRadius.lg),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: imageUrl == null
            ? _buildArtworkCoverFallback(theme, l10n)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return _buildArtworkCoverFallback(theme, l10n);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildArtworkCoverFallback(theme, l10n),
                      Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: InlineLoading(
                              tileSize: 4, color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildArtworkCoverFallback(
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 32,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.commonNotAvailable,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KubusTypography.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }

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
                                          child: _buildArtworkCover(
                                            context: context,
                                            theme: theme,
                                            artwork: artwork,
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
