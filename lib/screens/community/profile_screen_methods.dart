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
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/glass_components.dart';

// Helper methods for ProfileScreen
class ProfileScreenMethods {
  static void showFollowers(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    // Prefetch stats so parent UI can update counts before showing list
    (() async {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final resolvedWallet = (targetWallet != null && targetWallet.isNotEmpty)
          ? targetWallet
          : (profileProvider.currentWalletAddress ?? walletProvider.currentWalletAddress);

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        return;
      }

      try {
        try {
          await profileProvider.refreshStats(
            forceRefresh: true,
            walletAddress: resolvedWallet,
          );
        } catch (_) {}
        try {
          await UserService.fetchAndUpdateUserStats(resolvedWallet);
        } catch (_) {}
      } catch (_) {}
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: !isDesktopLike,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (context) => _FollowersBottomSheet(walletAddress: resolvedWallet),
      );
    })();
  }

  static void showFollowing(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    // Prefetch stats so parent UI can update counts before showing list
    (() async {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final resolvedWallet = (targetWallet != null && targetWallet.isNotEmpty)
          ? targetWallet
          : (profileProvider.currentWalletAddress ?? walletProvider.currentWalletAddress);

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        return;
      }

      try {
        try {
          await profileProvider.refreshStats(
            forceRefresh: true,
            walletAddress: resolvedWallet,
          );
        } catch (_) {}
        try {
          await UserService.fetchAndUpdateUserStats(resolvedWallet);
        } catch (_) {}
      } catch (_) {}
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: !isDesktopLike,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (context) => _FollowingBottomSheet(walletAddress: resolvedWallet),
      );
    })();
  }

  static void showArtworks(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    (() async {
      final artworkProvider = Provider.of<ArtworkProvider>(context, listen: false);
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final resolvedWallet = (targetWallet != null && targetWallet.isNotEmpty)
          ? targetWallet
          : (profileProvider.currentWalletAddress ?? walletProvider.currentWalletAddress);

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        return;
      }

      try {
        await artworkProvider.loadArtworksForWallet(resolvedWallet, force: true);
      } catch (_) {}

      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: !isDesktopLike,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (context) => _ArtworksBottomSheet(walletAddress: resolvedWallet),
      );
    })();
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

  const _FollowersBottomSheet({this.walletAddress});

  @override
  State<_FollowersBottomSheet> createState() => _FollowersBottomSheetState();
}

class _FollowersBottomSheetState extends State<_FollowersBottomSheet> {
  List<Map<String, dynamic>>? _followers;
  bool _isLoading = true;
  String? _error;

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

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final explicitWallet = widget.walletAddress?.trim();
      final resolvedWallet = (explicitWallet != null && explicitWallet.isNotEmpty)
          ? explicitWallet
          : (profileProvider.currentWalletAddress ?? walletProvider.currentWalletAddress);

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        setState(() {
          _followers = [];
          _isLoading = false;
        });
        return;
      }

      final followers = await BackendApiService().getFollowers(walletAddress: resolvedWallet);
      
      if (!mounted) return;
      setState(() {
        _followers = followers;
        _isLoading = false;
      });
    } catch (e) {
      AppConfig.debugPrint('ProfileScreenMethods._FollowersBottomSheet: error loading followers: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = l10n.userProfileFollowersLoadFailedMessage;
        _isLoading = false;
        _followers = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
      (platform.isWeb && MediaQuery.of(context).size.width >= 900);

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
            Expanded(
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
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    // BackdropFilter-heavy cards inside scrolling lists are prone to rendering
    // issues (especially on web/desktop). Force the card surfaces onto the
    // opaque path in desktop-like layouts for reliability.
    final enableCardBlur = !isDesktopLike;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _followers!.length,
      itemBuilder: (context, index) {
        final follower = _followers![index];
        final rawUsername = _stringOrNull(follower['username']) ?? '';
        final username = rawUsername.startsWith('@') ? rawUsername.substring(1).trim() : rawUsername;
        final displayName = _stringOrNull(
          follower['displayName'] ?? follower['display_name'] ?? follower['name'],
        );
        final walletAddress = _stringOrNull(
              follower['walletAddress'] ??
                  follower['wallet_address'] ??
                  follower['id'],
            ) ??
            '';
        final isVerified = _boolOrFalse(follower['isVerified'] ?? follower['is_verified']);
        final avatarUrl = _stringOrNull(
          follower['profileImageUrl'] ??
              follower['avatar'] ??
              follower['avatarUrl'] ??
              follower['avatar_url'],
        );

        final formatted = CreatorDisplayFormat.format(
          fallbackLabel: walletAddress.isNotEmpty
              ? maskWallet(walletAddress)
              : l10n.commonUnknownArtist,
          displayName: displayName,
          username: username,
          wallet: walletAddress,
        );
        final subtitle = formatted.secondary ?? (walletAddress.isNotEmpty ? maskWallet(walletAddress) : null);

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
                        username: username,
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
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
              onPressed: _loadFollowers,
              child: Text(
                l10n.commonRetry,
                style: KubusTypography.inter(
                  color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
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

  const _FollowingBottomSheet({this.walletAddress});

  @override
  State<_FollowingBottomSheet> createState() => _FollowingBottomSheetState();
}

class _FollowingBottomSheetState extends State<_FollowingBottomSheet> {
  List<Map<String, dynamic>>? _following;
  bool _isLoading = true;
  String? _error;

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

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final explicitWallet = widget.walletAddress?.trim();
      final resolvedWallet = (explicitWallet != null && explicitWallet.isNotEmpty)
          ? explicitWallet
          : (profileProvider.currentWalletAddress ?? walletProvider.currentWalletAddress);

      if (resolvedWallet == null || resolvedWallet.isEmpty) {
        setState(() {
          _following = [];
          _isLoading = false;
        });
        return;
      }

      final following = await BackendApiService().getFollowing(walletAddress: resolvedWallet);
      
      if (!mounted) return;
      setState(() {
        _following = following;
        _isLoading = false;
      });
    } catch (e) {
      AppConfig.debugPrint('ProfileScreenMethods._FollowingBottomSheet: error loading following: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = l10n.userProfileFollowingLoadFailedMessage;
        _isLoading = false;
        _following = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
      (platform.isWeb && MediaQuery.of(context).size.width >= 900);

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
            Expanded(
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
    final platform = Provider.of<PlatformProvider>(context, listen: false);
    final isDesktopLike = platform.isDesktop ||
        (platform.isWeb && MediaQuery.of(context).size.width >= 900);
    final enableCardBlur = !isDesktopLike;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _following!.length,
      itemBuilder: (context, index) {
        final user = _following![index];
        final rawUsername = _stringOrNull(user['username']) ?? '';
        final username = rawUsername.startsWith('@') ? rawUsername.substring(1).trim() : rawUsername;
        final displayName = _stringOrNull(
          user['displayName'] ?? user['display_name'] ?? user['name'],
        );
        final walletAddress = _stringOrNull(
              user['walletAddress'] ??
                  user['wallet_address'] ??
                  user['id'],
            ) ??
            '';
        final isVerified = _boolOrFalse(user['isVerified'] ?? user['is_verified']);
        final avatarUrl = _stringOrNull(
          user['profileImageUrl'] ??
              user['avatar'] ??
              user['avatarUrl'] ??
              user['avatar_url'],
        );

        final formatted = CreatorDisplayFormat.format(
          fallbackLabel: walletAddress.isNotEmpty
              ? maskWallet(walletAddress)
              : l10n.commonUnknownArtist,
          displayName: displayName,
          username: username,
          wallet: walletAddress,
        );
        final subtitle = formatted.secondary ?? (walletAddress.isNotEmpty ? maskWallet(walletAddress) : null);

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
                        username: username,
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
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
              onPressed: _loadFollowing,
              child: Text(
                l10n.commonRetry,
                style: KubusTypography.inter(
                  color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
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

    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final userArtworks = artworkProvider.artworksForWallet(walletAddress);

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
                  title: '${l10n.userProfileArtworksTitle} (${userArtworks.length})',
                  showHandle: !isDesktopLike,
                  trailing: KubusGlassIconButton(
                    icon: Icons.close,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                child: userArtworks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.artistGalleryEmptyTitle,
                            style: KubusTypography.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(KubusRadius.lg),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          theme.colorScheme.primaryContainer
                                              .withValues(alpha: 0.34),
                                          theme.colorScheme.surfaceContainerHigh
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
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.58),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(KubusSpacing.sm),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        artwork.title,
                                        style: KubusTypography.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: KubusSpacing.xxs),
                                      Text(
                                        l10n.userProfileLikesLabel(artwork.likesCount),
                                        style: KubusTypography.inter(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
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
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
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


