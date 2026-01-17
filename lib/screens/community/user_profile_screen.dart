import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../models/achievements.dart';
import '../../services/backend_api_service.dart';
import '../../services/block_list_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/category_accent_color.dart';
import '../../utils/media_url_resolver.dart';
import '../../community/community_interactions.dart';
import '../../providers/themeprovider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/app_refresh_provider.dart';
import '../../core/conversation_navigator.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/user_activity_status_line.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/profile_artist_info_fields.dart';
import '../../widgets/detail/detail_shell_components.dart';
import 'post_detail_screen.dart';
import '../../utils/artwork_navigation.dart';
import '../art/collection_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../../providers/wallet_provider.dart';
import '../../services/socket_service.dart';
import 'profile_screen_methods.dart';
import '../../models/dao.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
 

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final String? heroTag;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
    this.heroTag,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  User? user;
  bool isLoading = true;
  List<CommunityPost> _posts = [];
  bool _postsLoading = true;
  int _currentPage = 1;
  bool _isLastPage = false;
  bool _loadingMore = false;
  String? _postsError;
  late AnimationController _followButtonController;
  late Animation<double> _followButtonAnimation;
  late ScrollController _scrollController;
  bool _artistDataLoading = false;
  bool _artistDataLoaded = false;
  bool _artistDataRequested = false;
  List<Map<String, dynamic>> _artistArtworks = [];
  List<Map<String, dynamic>> _artistCollections = [];
  List<Map<String, dynamic>> _artistEvents = [];
  String? _failedCoverImageUrl;

  String? _currentWalletAddress() {
    try {
      return Provider.of<WalletProvider>(context, listen: false).currentWalletAddress;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _followButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _followButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _followButtonController, curve: Curves.easeInOut),
    );
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
    _loadUser();
    // Listen for incoming posts via socket to update profile feed in real-time
    try {
      (() async {
        await SocketService().connect();
        SocketService().addPostListener(_handleIncomingPost);
      })();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final wp = Provider.of<WalletProvider>(context, listen: false);
        wp.addListener(_onWalletChanged);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _followButtonController.dispose();
    try { Provider.of<WalletProvider>(context, listen: false).removeListener(_onWalletChanged); } catch (_) {}
    try { SocketService().removePostListener(_handleIncomingPost); } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    try {
      if (user == null) return;
      final incomingAuthor = (data['walletAddress'] ?? data['author'] ?? data['authorWallet'])?.toString();
      if (incomingAuthor == null) return;
      // author id stored as wallet string in this profile screen
      if (!WalletUtils.equals(incomingAuthor, user!.id)) return;
      final id = (data['id'] ?? data['postId'] ?? data['post_id'])?.toString();
      if (id == null) return;
      // Avoid duplicates
      if (_posts.any((p) => p.id == id)) return;
      try {
        final post = await BackendApiService().getCommunityPostById(id);
        if (!mounted) return;
        setState(() {
          _posts.insert(0, post);
        });
        // Update posts count optimistically when a new post arrives
        try {
          if (user != null) {
            final updatedPosts = user!.postsCount + 1;
            user = user!.copyWith(postsCount: updatedPosts);
            UserService.setUsersInCache([user!]);
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('Failed to fetch incoming user post $id: $e');
      }
    } catch (e) {
      debugPrint('UserProfile incoming post handler error: $e');
    }
  }

  void _onWalletChanged() async {
    try {
      if (_posts.isNotEmpty) {
        await CommunityService.loadSavedInteractions(
          _posts,
          walletAddress: _currentWalletAddress(),
        );
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to refresh post interactions on wallet change: $e');
    }
  }

  Future<void> _loadUserStats({bool skipFollowersOverwrite = false, bool forceRefresh = false}) async {
    final profile = user;
    if (profile == null) return;
    try {
      final statsProvider = context.read<StatsProvider>();
      final snapshot = await statsProvider.ensureSnapshot(
        entityType: 'user',
        entityId: profile.id,
        metrics: const ['posts', 'followers', 'following'],
        scope: 'public',
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        final counters = snapshot?.counters ?? const <String, int>{};
        final fetchedPosts = counters['posts'] ?? 0;
        final fetchedFollowers = counters['followers'] ?? 0;
        final fetchedFollowing = counters['following'] ?? 0;

        var resolvedFollowers = fetchedFollowers;
        var resolvedFollowing = fetchedFollowing;
        // If caller asked to skip overwriting follower/following counts (e.g., immediately after a follow/unfollow),
        // preserve optimistic local value if it exists to avoid flashing back to stale backend values.
        if (skipFollowersOverwrite && user != null) {
          resolvedFollowers = user!.followersCount;
          resolvedFollowing = user!.followingCount;
        }

        user = profile.copyWith(
          postsCount: fetchedPosts,
          followersCount: resolvedFollowers,
          followingCount: resolvedFollowing,
        );
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserProfileScreen._loadUserStats: $e');
      }
    }
  }

  Future<void> _loadUser({bool showFullScreenLoader = true}) async {
    if (showFullScreenLoader) {
      setState(() {
        isLoading = true;
      });
    }

    User? loadedUser;
    try {
      if (widget.username != null) {
        loadedUser = await UserService.getUserByUsername(widget.username!);
      } else {
        loadedUser = await UserService.getUserById(widget.userId, forceRefresh: true);
      }
    } catch (e) {
      debugPrint('UserProfileScreen._loadUser: failed to fetch user: $e');
    }

    if (!mounted) return;

    setState(() {
      user = loadedUser;
      isLoading = false;
    });

    if (user == null) {
      return;
    }

    // Trigger a background fetch to refresh authoritative stats and update
    // the cached user when it completes. This is non-blocking so the UI
    // remains responsive; _loadUserStats() below will also refresh the UI.
    try {
      UserService.fetchAndUpdateUserStats(user!.id);
    } catch (_) {}

    await _loadUserStats(skipFollowersOverwrite: true, forceRefresh: true);
    await _loadPosts();
    await _maybeLoadArtistData(force: true);
  }

  Future<void> _loadPosts() async {
    if (user == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _postsLoading = true;
      _postsError = null;
      _currentPage = 1;
      _isLastPage = false;
    });

    try {
      const pageSize = 20;
      final posts = await BackendApiService().getCommunityPosts(page: _currentPage, limit: pageSize, authorWallet: user!.id);
      try {
        await CommunityService.loadSavedInteractions(
          posts,
          walletAddress: _currentWalletAddress(),
        );
      } catch (_) {}
      setState(() {
        _posts = posts;
        _postsLoading = false;
        _isLastPage = posts.length < pageSize;
      });
      // Update postsCount from loaded posts to keep UI accurate
      try {
        if (user != null) {
          user = user!.copyWith(postsCount: posts.length);
          UserService.setUsersInCache([user!]);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      setState(() {
        _posts = [];
        _postsLoading = false;
        _postsError = l10n.userProfilePostsLoadFailedDescription;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (user == null || _isLastPage || _loadingMore) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingMore = true;
      _currentPage += 1;
    });

    try {
      const pageSize = 20;
      final more = await BackendApiService().getCommunityPosts(page: _currentPage, limit: pageSize, authorWallet: user!.id);
      try {
        await CommunityService.loadSavedInteractions(
          more,
          walletAddress: _currentWalletAddress(),
        );
      } catch (_) {}
      setState(() {
        _posts.addAll(more);
        _isLastPage = more.length < pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      setState(() {
        _loadingMore = false;
        _postsError = l10n.userProfilePostsLoadMoreFailedDescription;
      });
      // Roll back page counter on failure
      setState(() {
        if (_currentPage > 1) _currentPage -= 1;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUser(showFullScreenLoader: false);
  }

  Future<void> _toggleFollow() async {
    if (user == null) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    _followButtonController.forward().then((_) {
      _followButtonController.reverse();
    });

    bool newFollowState;
    try {
      newFollowState = await UserService.toggleFollow(
        user!.id,
        displayName: user!.name,
        username: user!.username,
        avatarUrl: user!.profileImageUrl,
      );
    } catch (e) {
      debugPrint('UserProfileScreen: failed to toggle follow for ${user!.id}: $e');
      if (!mounted) return;
      final message = e.toString().contains('401')
          ? l10n.userProfileSignInToFollowToast
          : l10n.userProfileFollowUpdateFailedToast;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      await _loadUserStats(skipFollowersOverwrite: true);
      return;
    }
    
    setState(() {
      final currentFollowers = user!.followersCount;
      final updatedFollowers = newFollowState
          ? currentFollowers + 1
          : (currentFollowers > 0 ? currentFollowers - 1 : 0);
      user = user!.copyWith(
        isFollowing: newFollowState,
        followersCount: updatedFollowers,
      );
    });

    // Show feedback
    if (mounted) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            newFollowState 
                ? l10n.userProfileNowFollowingToast(user!.name)
                : l10n.userProfileUnfollowedToast(user!.name),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      try {
        context.read<AppRefreshProvider>().triggerCommunity();
        context.read<AppRefreshProvider>().triggerProfile();
      } catch (_) {}
    }

    await _loadUserStats(forceRefresh: true);
    // Persist updated user in cache so other screens see immediate change
    try {
      if (user != null) UserService.setUsersInCache([user!]);
    } catch (_) {}
    // After toggling follow, schedule a deferred authoritative refresh to pick up backend changes
    try {
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          if (!mounted) return;
          await _loadUserStats();
          try { if (user != null) UserService.setUsersInCache([user!]); } catch (_) {}
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.userProfileTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const AppLoading(),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.userProfileTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(l10n.userProfileNotFound),
        ),
      );
    }

    // Determine artist/institution status from User model + DAO reviews (like profile_screen.dart)
    final daoProvider = Provider.of<DAOProvider>(context);
    final DAOReview? daoReview = daoProvider.findReviewForWallet(user!.id);
    
    final isArtist = user!.isArtist || (daoReview != null && daoReview.isArtistApplication && daoReview.isApproved);
    final isInstitution = user!.isInstitution || (daoReview != null && daoReview.isInstitutionApplication && daoReview.isApproved);

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            user!.name.isNotEmpty ? user!.name : l10n.userProfileTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: l10n.commonMore,
              onPressed: _showMoreOptions,
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: themeProvider.accentColor,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DetailSpacing.xl),
              child: Column(
                children: [
                  _buildProfileHeader(
                    themeProvider,
                    isArtist: isArtist,
                    isInstitution: isInstitution,
                  ),
                  const SizedBox(height: DetailSpacing.md),
                  _buildStatsRow(l10n),
                  const SizedBox(height: DetailSpacing.lg),
                  _buildActionButtons(themeProvider, l10n),
                  const SizedBox(height: DetailSpacing.lg),
                  if (isArtist) ...[
                    _buildArtistHighlightsGrid(l10n),
                    const SizedBox(height: DetailSpacing.xl),
                  ],
                  isInstitution
                      ? _buildInstitutionHighlights(l10n)
                      : _buildAchievements(themeProvider, l10n),
                  const SizedBox(height: DetailSpacing.xl),
                  _buildPostsSection(l10n),
                  if (isArtist) ...[
                    const SizedBox(height: DetailSpacing.xl),
                    _buildArtistEventsShowcase(l10n),
                  ],
                  const SizedBox(height: DetailSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMoreOptions() async {
    final l10n = AppLocalizations.of(context)!;
    final target = ShareTarget.profile(walletAddress: user!.id, title: user!.name);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        final surface = Theme.of(sheetContext).colorScheme.surface;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(vertical: 8),
              backgroundColor: surface.withValues(alpha: 0.65),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: Text(l10n.commonShare, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ShareService().showShareSheet(
                        context,
                        target: target,
                        sourceScreen: 'user_profile',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(l10n.userProfileMoreOptionsBlockUser, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showBlockConfirmation();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report),
                    title: Text(l10n.userProfileMoreOptionsReportUser, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showReportDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(ThemeProvider themeProvider, {required bool isArtist, required bool isInstitution}) {
    final coverImageUrl = _normalizeMediaUrl(user!.coverImageUrl);
    final coverUrlIsKnownBad = coverImageUrl != null && coverImageUrl == _failedCoverImageUrl;
    final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty && !coverUrlIsKnownBad;
    
    return Column(
      children: [
        // Cover Image Section
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover image or gradient background
            Container(
              width: double.infinity,
              height: hasCoverImage ? 160 : 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: !hasCoverImage
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          themeProvider.accentColor.withValues(alpha: 0.3),
                          themeProvider.accentColor.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasCoverImage)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final cacheWidth = (constraints.maxWidth * dpr).round();
                          final cacheHeight = (constraints.maxHeight * dpr).round();
                          return Image.network(
                            coverImageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                            cacheHeight: cacheHeight > 0 ? cacheHeight : null,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) {
                              if (_failedCoverImageUrl != coverImageUrl) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  setState(() => _failedCoverImageUrl = coverImageUrl);
                                });
                              }
                              return const SizedBox.expand();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox.expand();
                            },
                          );
                        },
                      ),
                    if (hasCoverImage)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Avatar positioned at bottom of cover, overlapping
            Positioned(
              bottom: -40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AvatarWidget(
                    wallet: user!.id,
                    avatarUrl: user!.profileImageUrl,
                    radius: 45,
                    enableProfileNavigation: false,
                    heroTag: widget.heroTag,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Spacing for avatar overflow
        const SizedBox(height: 48),
        
        // Name and Username
        Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user!.name,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user!.isVerified) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.verified,
                    color: themeProvider.accentColor,
                    size: 20,
                  ),
                ],
                if (isArtist) ...[
                  const SizedBox(width: 8),
                  const ArtistBadge(),
                ],
                if (isInstitution) ...[
                  const SizedBox(width: 8),
                  const InstitutionBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user!.username,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          UserActivityStatusLine(
            walletAddress: user!.id,
            textAlign: TextAlign.center,
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
           
          // Bio
          Text(
            user!.bio,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ProfileArtistInfoFields(
            fieldOfWork: user!.fieldOfWork,
            yearsActive: user!.yearsActive,
          ),
          const SizedBox(height: 8),
          
          // Join Date
          Text(
            user!.joinedDate,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      );
  }

  Widget _buildStatsRow(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    child: Row(
        children: [
          _buildInlineStat(label: l10n.userProfilePostsStatLabel, value: _formatCount(user!.postsCount)),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          _buildInlineStat(label: l10n.userProfileFollowersStatLabel, value: _formatCount(user!.followersCount), onTap: () async {
            try { await _loadUserStats(); } catch (_) {}
            if (!mounted) return;
            ProfileScreenMethods.showFollowers(context, walletAddress: user!.id);
          }),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          _buildInlineStat(label: l10n.userProfileFollowingStatLabel, value: _formatCount(user!.followingCount), onTap: () async {
            try { await _loadUserStats(); } catch (_) {}
            if (!mounted) return;
            ProfileScreenMethods.showFollowing(context, walletAddress: user!.id);
          }),
        ],
      ),
    );
  }

  Widget _buildInlineStat({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: content,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeProvider themeProvider, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ScaleTransition(
              scale: _followButtonAnimation,
              child: ElevatedButton(
                onPressed: _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: user!.isFollowing 
                      ? Theme.of(context).colorScheme.surface
                      : themeProvider.accentColor,
                  foregroundColor: user!.isFollowing 
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.white,
                  side: user!.isFollowing 
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 1.5,
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: user!.isFollowing ? 0 : 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  user!.isFollowing
                      ? l10n.userProfileFollowingButton
                      : l10n.userProfileFollowButton,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              // navigator variable no longer used; ConversationNavigator handles navigation
              final messenger = ScaffoldMessenger.of(context);
              final chatAuth = chatProvider.isAuthenticated;
              final l10n = AppLocalizations.of(context)!;
              try {
                final conv = await chatProvider.createConversation('', false, [user!.id]);
                if (conv != null) {
                  if (!mounted) return;
                  final preloaded = Provider.of<ChatProvider>(context, listen: false).getPreloadedProfileMapsForConversation(conv.id);
                  // Ensure we pass non-empty members and sensible fallbacks for avatars / display names
                  final rawMembers = (preloaded['members'] as List<dynamic>?)?.cast<String>() ?? <String>[];
                  final members = (rawMembers.isNotEmpty) ? rawMembers : <String>[user!.id];
                  final rawAvatars = (preloaded['avatars'] as Map<String, String?>?) ?? <String, String?>{};
                  final avatars = Map<String, String?>.from(rawAvatars);
                  if (!avatars.containsKey(members.first) || (avatars[members.first] == null || avatars[members.first]!.isEmpty)) {
                    avatars[members.first] = user!.profileImageUrl;
                  }
                  final rawNames = (preloaded['names'] as Map<String, String?>?) ?? <String, String?>{};
                  final names = Map<String, String?>.from(rawNames);
                  if (!names.containsKey(members.first) || (names[members.first] == null || names[members.first]!.isEmpty)) {
                    names[members.first] = user!.name;
                  }
                  await ConversationNavigator.openConversationWithPreload(context, conv, preloadedMembers: members, preloadedAvatars: avatars, preloadedDisplayNames: names);
                } else {
                  // Improve messaging: suggest login if token isn't present
                  // use pre-captured chatAuth variable
                  if (!chatAuth) {
                    if (mounted) {
                      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.userProfileMessageLoginRequiredToast)));
                    }
                  } else {
                    if (mounted) {
                      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.userProfileConversationOpenFailedToast)));
                    }
                  }
                }
              } catch (e) {
                debugPrint('UserProfileScreen: failed to open conversation: $e');
                if (!mounted) return;
                messenger.showKubusSnackBar(SnackBar(content: Text(l10n.userProfileConversationOpenGenericErrorToast)));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                width: 1.5,
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.message),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(ThemeProvider themeProvider, AppLocalizations l10n) {
    final progress = user?.achievementProgress ?? [];
    final achievementsToShow = allAchievements.take(6).toList();

    if (achievementsToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount = progress.where((p) => p.isCompleted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.userProfileAchievementsTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '$completedCount/${allAchievements.length}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: themeProvider.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (progress.isEmpty)
            _buildEmptyStateCard(
              l10n: l10n,
              title: l10n.userProfileAchievementsEmptyTitle(user!.name),
              description: l10n.userProfileAchievementsEmptyDescription,
              icon: Icons.emoji_events,
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: achievementsToShow.map((achievement) {
                final achievementProgress = progress.firstWhere(
                  (p) => p.achievementId == achievement.id,
                  orElse: () => AchievementProgress(
                    achievementId: achievement.id,
                    currentProgress: 0,
                    isCompleted: false,
                  ),
                );
                return _buildAchievementCard(themeProvider, achievement, achievementProgress);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(ThemeProvider themeProvider, Achievement achievement, AchievementProgress progress) {
    final l10n = AppLocalizations.of(context)!;
    final requiredProgress = achievement.requiredProgress > 0 ? achievement.requiredProgress : 1;
    final ratio = (progress.currentProgress / requiredProgress).clamp(0.0, 1.0);
    final isCompleted = progress.isCompleted || ratio >= 1.0;
    final accent = CategoryAccentColor.resolve(context, achievement.category);

    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? themeProvider.accentColor.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  achievement.icon,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  achievement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            achievement.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCompleted
                    ? l10n.userProfileAchievementCompletedLabel
                    : '${progress.currentProgress}/$requiredProgress',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.points}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? themeProvider.accentColor : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.userProfilePostsTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (_postsLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Center(child: CircularProgressIndicator()),
            ) else if (_postsError != null)
            _buildEmptyStateCard(
              l10n: l10n,
              title: l10n.userProfilePostsLoadFailedTitle,
              description: _postsError!,
              icon: Icons.cloud_off,
              showAction: true,
              actionLabel: l10n.commonRetry,
              onActionTap: _loadPosts,
            ) else if (_posts.isEmpty)
            _buildEmptyStateCard(
              l10n: l10n,
              title: l10n.userProfileNoPostsTitle,
              description: l10n.userProfileNoPostsDescription(user!.name),
              icon: Icons.article,
            ) else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final post = _posts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AvatarWidget(wallet: post.authorId, avatarUrl: post.authorAvatar, radius: 18, enableProfileNavigation: false),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          post.authorName,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (post.authorIsArtist) ...[
                                        const SizedBox(width: 6),
                                        ArtistBadge(fontSize: 8, padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                                      ],
                                      if (post.authorIsInstitution) ...[
                                        const SizedBox(width: 6),
                                        InstitutionBadge(fontSize: 8, padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_formatPostTime(l10n, post.timestamp), style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(post.content, style: GoogleFonts.inter(), maxLines: 3, overflow: TextOverflow.ellipsis),
                        if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(post.imageUrl!, fit: BoxFit.cover),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, size: 16, color: post.isLiked ? Provider.of<ThemeProvider>(context).accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Text('${post.likeCount}', style: GoogleFonts.inter(fontSize: 12, color: post.isLiked ? Provider.of<ThemeProvider>(context).accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                            const SizedBox(width: 16),
                            Icon(Icons.comment_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Text('${post.commentCount}', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_loadingMore)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: const SizedBox(width:24, height:24, child: CircularProgressIndicator(strokeWidth:2)),
              )
            else if (_isLastPage)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Text(l10n.userProfileNoMorePostsLabel, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildArtistHighlightsGrid(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.userProfileArtistHighlightsTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.userProfileArtistHighlightsSubtitle(user!.name),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileArtworksTitle,
            items: _artistArtworks,
            emptyLabel: l10n.userProfileNoArtworksYetLabel(user!.name),
            emptyIcon: Icons.image_outlined,
            builder: _buildArtworkCard,
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileCollectionsTitle,
            items: _artistCollections,
            emptyLabel: l10n.userProfileNoCollectionsYetLabel(user!.name),
            emptyIcon: Icons.collections_outlined,
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistEventsShowcase(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.userProfileEventsTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.userProfileEventsSubtitleFeaturing(user!.name),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileEventsTitle,
            items: _artistEvents,
            emptyLabel: l10n.userProfileNoUpcomingEventsYetLabel(user!.name),
            emptyIcon: Icons.event,
            builder: _buildEventCard,
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionHighlights(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.userProfileInstitutionHighlightsTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.userProfileInstitutionHighlightsSubtitle(user!.name),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileEventsTitle,
            items: _artistEvents,
            emptyLabel: l10n.userProfileNoUpcomingEventsYetLabel(user!.name),
            emptyIcon: Icons.event,
            builder: _buildEventCard,
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileCollectionsTitle,
            items: _artistCollections,
            emptyLabel: l10n.userProfileNoCollectionsYetLabel(user!.name),
            emptyIcon: Icons.collections_outlined,
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseSection({
    required AppLocalizations l10n,
    required String title,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) builder,
    required String emptyLabel,
    required IconData emptyIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (_artistDataLoading && !_artistDataLoaded)
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (items.isEmpty)
          _buildEmptyStateCard(
            l10n: l10n,
            title: l10n.userProfileNoItemsTitle(title),
            description: emptyLabel,
            icon: emptyIcon,
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => builder(items[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildArtworkCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, ['imageUrl', 'image', 'previewUrl', 'coverImage']);
    final l10n = AppLocalizations.of(context)!;
    final title = (data['title'] ?? data['name'] ?? l10n.commonUntitled).toString();
    final medium = (data['medium'] ?? data['category'] ?? l10n.commonDigital).toString();
    final likes = data['likesCount'] ?? data['likes'] ?? 0;
    final likesCount = int.tryParse(likes.toString()) ?? 0;
    final artworkId = (data['id'] ?? data['artwork_id'] ?? data['artworkId'])?.toString();
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: artworkId != null ? () {
          openArtwork(context, artworkId, source: 'user_profile');
        } : null,
      child: _buildShowcaseCard(
        imageUrl: imageUrl,
        title: title,
        subtitle: medium,
        footer: l10n.userProfileLikesLabel(likesCount),
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final imageUrl = _extractImageUrl(data, [
      'thumbnailUrl',
      'coverImage',
      'coverImageUrl',
      'cover_image_url',
      'coverUrl',
      'cover_url',
      'image',
    ]);
    final title = (data['name'] ?? l10n.userProfileCollectionFallbackTitle).toString();
    final count = data['artworksCount'] ?? data['artworks_count'] ?? 0;
    final artworksCount = int.tryParse(count.toString()) ?? 0;
    final collectionId =
        (data['id'] ?? data['collection_id'] ?? data['collectionId'])?.toString();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (collectionId != null && collectionId.isNotEmpty)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CollectionDetailScreen(collectionId: collectionId),
                ),
              );
            }
          : null,
      child: _buildShowcaseCard(
        imageUrl: imageUrl,
        title: title,
        subtitle: l10n.userProfileArtworksCountLabel(artworksCount),
        footer: (data['description'] ?? l10n.userProfileCuratedByLabel(user!.name))
            .toString(),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final imageUrl = _extractImageUrl(data, [
      'coverUrl',
      'cover_url',
      'bannerUrl',
      'banner_url',
      'image',
    ]);
    final title = (data['title'] ?? l10n.userProfileEventFallbackTitle).toString();
    final dateLabel = _formatDateLabel(l10n, data['startDate'] ?? data['start_date']);
    final location = (data['location'] ?? l10n.commonTba).toString();
    final eventId = (data['id'] ?? data['event_id'] ?? data['eventId'])?.toString();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (eventId != null && eventId.isNotEmpty)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: eventId),
                ),
              );
            }
          : null,
      child: _buildShowcaseCard(
        imageUrl: imageUrl,
        title: title,
        subtitle: dateLabel,
        footer: location,
      ),
    );
  }

  Widget _buildShowcaseCard({
    String? imageUrl,
    required String title,
    required String subtitle,
    required String footer,
  }) {
    final normalizedImage = _normalizeMediaUrl(imageUrl);
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (normalizedImage != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                normalizedImage,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(child: Icon(Icons.image_outlined)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  footer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _extractImageUrl(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    final images = data['imageUrls'] ?? data['image_urls'] ?? data['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
    }
    return null;
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }

  String _formatDateLabel(AppLocalizations l10n, dynamic value) {
    if (value == null) return l10n.commonTba;
    try {
      final date = value is DateTime ? value : DateTime.parse(value.toString());
      return MaterialLocalizations.of(context).formatMediumDate(date);
    } catch (_) {
      return l10n.commonTba;
    }
  }

  Widget _buildEmptyStateCard({
    required AppLocalizations l10n,
    required String title,
    required String description,
    IconData icon = Icons.info_outline,
    bool showAction = false,
    String? actionLabel,
    Future<void> Function()? onActionTap,
  }) {
    return EmptyStateCard(
      icon: icon,
      title: title,
      description: description,
      showAction: showAction,
      actionLabel: showAction ? (actionLabel ?? l10n.commonRetry) : null,
      onAction: onActionTap != null ? () => onActionTap() : null,
    );
  }

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final isCreator = (user?.isArtist ?? false) || (user?.isInstitution ?? false);
    if (!isCreator) {
      return;
    }
    if (_artistDataLoading && !force) {
      return;
    }
    if (_artistDataRequested && !force) {
      return;
    }
    _artistDataRequested = true;
    await _loadArtistData(user!.id, force: force);
  }

  Future<void> _loadArtistData(String walletAddress, {bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _artistDataLoading = true;
      if (force) {
        _artistArtworks = [];
        _artistCollections = [];
        _artistEvents = [];
      }
    });
    try {
      final api = BackendApiService();
      final artworks = await api.getArtistArtworks(walletAddress, limit: 6);
      final collections = await api.getCollections(walletAddress: walletAddress, limit: 6);
      final eventsResponse = await api.listEvents(limit: 100);
      final normalizedWallet = WalletUtils.normalize(walletAddress);
      final filteredEvents = eventsResponse.where((event) {
        final createdBy = WalletUtils.normalize((event['createdBy'] ?? event['created_by'] ?? '').toString());
        final artistIdsRaw = event['artistIds'] ?? event['artist_ids'] ?? [];
        final artistIds = artistIdsRaw is List
            ? artistIdsRaw.map((id) => WalletUtils.normalize(id.toString())).toList()
            : <String>[];
        return createdBy == normalizedWallet || artistIds.contains(normalizedWallet);
      }).take(6).map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        _artistArtworks = artworks;
        _artistCollections = collections;
        _artistEvents = filteredEvents;
        _artistDataLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load artist showcase data: $e');
      if (mounted) {
        setState(() {
          _artistDataLoaded = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _artistDataLoading = false;
        });
      }
    }
  }

  void _showBlockConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.userProfileBlockDialogTitle(user!.name),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.userProfileBlockDialogDescription,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final targetWallet = WalletUtils.canonical(user?.id ?? widget.userId);
              if (targetWallet.isEmpty) {
                if (!mounted) return;
                Navigator.pop(context);
                messenger.showKubusSnackBar(SnackBar(content: Text(l10n.userProfileUnableToBlockToast)));
                return;
              }

              try {
                await BlockListService().blockWallet(targetWallet);
              } catch (e) {
                debugPrint('UserProfileScreen: failed to block user: $e');
                if (!mounted) return;
                Navigator.pop(context);
                messenger.showKubusSnackBar(SnackBar(content: Text(l10n.userProfileBlockFailedToast)));
                return;
              }

              if (!mounted) return;
              Navigator.pop(context);
              messenger.showKubusSnackBar(
                SnackBar(content: Text(l10n.userProfileBlockedToast(user?.name ?? targetWallet))),
              );
            },
            child: Text(l10n.userProfileBlockButtonLabel),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.userProfileReportDialogTitle(user!.name),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.userProfileReportDialogQuestion,
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            _buildReportOption(dialogContext, l10n.userProfileReportReasonSpam),
            _buildReportOption(dialogContext, l10n.userProfileReportReasonInappropriate),
            _buildReportOption(dialogContext, l10n.userProfileReportReasonHarassment),
            _buildReportOption(dialogContext, l10n.userProfileReportReasonOther),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  String _formatPostTime(AppLocalizations l10n, DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 7) return l10n.commonWeeksAgo((diff.inDays / 7).floor());
    if (diff.inDays > 0) return l10n.commonDaysAgo(diff.inDays);
    if (diff.inHours > 0) return l10n.commonHoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return l10n.commonMinutesAgo(diff.inMinutes);
    return l10n.commonJustNow;
  }

  Widget _buildReportOption(BuildContext dialogContext, String reason) {
    return ListTile(
      title: Text(reason),
      onTap: () async {
        final l10n = AppLocalizations.of(context)!;
        final messenger = ScaffoldMessenger.of(context);
        final targetWallet = WalletUtils.canonical(user?.id ?? widget.userId);

        Navigator.pop(dialogContext);

        if (targetWallet.isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commonActionFailedToast), duration: const Duration(seconds: 2)),
          );
          return;
        }

        try {
          await CommunityService.reportUser(
            targetWallet,
            reason,
            details: user?.name,
          );
          if (!mounted) return;
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.userProfileReportSubmittedToast), duration: const Duration(seconds: 2)),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commonActionFailedToast), duration: const Duration(seconds: 2)),
          );
        }
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
