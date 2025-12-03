import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/avatar_widget.dart';
import 'package:provider/provider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/user_service.dart';
import 'user_profile_screen.dart';

// Helper methods for ProfileScreen
class ProfileScreenMethods {
  static void showFollowers(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    // Prefetch stats so parent UI can update counts before showing list
    (() async {
      try {
        if (targetWallet == null) {
          try { await Provider.of<ProfileProvider>(context, listen: false).refreshStats(); } catch (_) {}
        } else {
          try { await UserService.fetchAndUpdateUserStats(targetWallet); } catch (_) {}
        }
      } catch (_) {}
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _FollowersBottomSheet(walletAddress: targetWallet),
      );
    })();
  }

  static void showFollowing(BuildContext context, {String? walletAddress}) {
    final targetWallet = walletAddress?.trim();
    // Prefetch stats so parent UI can update counts before showing list
    (() async {
      try {
        if (targetWallet == null) {
          try { await Provider.of<ProfileProvider>(context, listen: false).refreshStats(); } catch (_) {}
        } else {
          try { await UserService.fetchAndUpdateUserStats(targetWallet); } catch (_) {}
        }
      } catch (_) {}
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _FollowingBottomSheet(walletAddress: targetWallet),
      );
    })();
  }

  static void showArtworks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ArtworksBottomSheet(),
    );
  }

  static void showCollections(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
      final explicitWallet = widget.walletAddress?.trim();
      final resolvedWallet = (explicitWallet != null && explicitWallet.isNotEmpty)
          ? explicitWallet
          : walletProvider.currentWalletAddress;

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
      debugPrint('Error loading followers: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load followers';
        _isLoading = false;
        _followers = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Followers${_followers != null ? ' (${_followers!.length})' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
              ? const AppLoading()
                : _error != null
                    ? _buildErrorState(theme, _error!)
                    : _followers!.isEmpty
                        ? _buildEmptyState(theme, 'No Followers Yet', 'Share your profile to gain followers')
                        : _buildFollowersList(theme, themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowersList(ThemeData theme, ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _followers!.length,
      itemBuilder: (context, index) {
        final follower = _followers![index];
        final username = follower['username'] as String? ?? 'anonymous';
        final displayName = (follower['displayName'] ?? follower['display_name'] ?? follower['name']) as String? ?? username;
        final walletAddress = follower['walletAddress'] as String? ?? follower['id'] as String? ?? '';
        final isVerified = follower['isVerified'] as bool? ?? false;
        final avatarUrl = (follower['profileImageUrl'] ?? follower['avatar'] ?? follower['avatarUrl'] ?? follower['avatar_url']) as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: walletAddress,
                    username: username,
                  ),
                ),
              );
            },
            leading: AvatarWidget(
              wallet: walletAddress,
              avatarUrl: avatarUrl,
              radius: 25,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, size: 16, color: themeProvider.accentColor),
                ],
              ],
            ),
            subtitle: Text(
              '@$username',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadFollowers,
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
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
      final explicitWallet = widget.walletAddress?.trim();
      final resolvedWallet = (explicitWallet != null && explicitWallet.isNotEmpty)
          ? explicitWallet
          : walletProvider.currentWalletAddress;

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
      debugPrint('Error loading following: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load following';
        _isLoading = false;
        _following = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Following${_following != null ? ' (${_following!.length})' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
              ? const AppLoading()
                : _error != null
                    ? _buildErrorState(theme, _error!)
                    : _following!.isEmpty
                        ? _buildEmptyState(theme, 'Not Following Anyone', 'Discover artists in the Community tab')
                        : _buildFollowingList(theme, themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingList(ThemeData theme, ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _following!.length,
      itemBuilder: (context, index) {
        final user = _following![index];
        final username = user['username'] as String? ?? 'anonymous';
        final displayName = (user['displayName'] ?? user['display_name'] ?? user['name']) as String? ?? username;
        final walletAddress = user['walletAddress'] as String? ?? user['id'] as String? ?? '';
        final isVerified = user['isVerified'] as bool? ?? false;
        final avatarUrl = (user['profileImageUrl'] ?? user['avatar'] ?? user['avatarUrl'] ?? user['avatar_url']) as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: walletAddress,
                    username: username,
                  ),
                ),
              );
            },
            leading: AvatarWidget(
              wallet: walletAddress,
              avatarUrl: avatarUrl,
              radius: 25,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, size: 16, color: themeProvider.accentColor),
                ],
              ],
            ),
            subtitle: Text(
              '@$username',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadFollowing,
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
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
  const _ArtworksBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final userArtworks = artworkProvider.userArtworks;
          
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Artworks (${userArtworks.length})',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                    ),
                  ],
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
                            'No artworks yet',
                            style: GoogleFonts.inter(
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
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    color: theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 32,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artwork.title,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${artwork.likesCount} likes',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Icon(
            Icons.collections_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Collections Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your NFT collections will appear here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
