import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/topbar_icon.dart';
import '../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../models/achievements.dart';
import '../services/backend_api_service.dart';
import '../community/community_interactions.dart';
import '../providers/themeprovider.dart';
import '../providers/chat_provider.dart';
import '../core/conversation_navigator.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/empty_state_card.dart';
import 'post_detail_screen.dart';
import '../providers/wallet_provider.dart';
import '../services/socket_service.dart';
import 'profile_screen_methods.dart';

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
      if (incomingAuthor.toLowerCase() != user!.id.toLowerCase()) return;
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

  int _parseStatValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    try {
      return int.parse(value.toString());
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadUserStats({bool skipFollowersOverwrite = false}) async {
    final profile = user;
    if (profile == null) return;
    try {
      final stats = await BackendApiService().getUserStats(profile.id);
      if (!mounted) return;
      setState(() {
        final fetchedPosts = _parseStatValue(stats['postsCount'] ?? stats['posts']);
        final fetchedFollowers = _parseStatValue(stats['followersCount'] ?? stats['followers']);
        final fetchedFollowing = _parseStatValue(stats['followingCount'] ?? stats['following']);

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
      debugPrint('Failed to load user stats: $e');
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

    await _loadUserStats();
    await _loadPosts();
    await _maybeLoadArtistData(force: true);
  }

  Future<void> _loadPosts() async {
    if (user == null) return;
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
        _postsError = 'Failed to load posts';
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (user == null || _isLastPage || _loadingMore) return;
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
        _postsError = 'Failed to load more posts';
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

    _followButtonController.forward().then((_) {
      _followButtonController.reverse();
    });

    final newFollowState = await UserService.toggleFollow(user!.id);
    
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newFollowState 
                ? 'Following ${user!.name}' 
                : 'Unfollowed ${user!.name}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await _loadUserStats();
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
    
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
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
            'Profile',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: Text('User not found'),
        ),
      );
    }

    final isArtist = user!.isArtist;
    final isInstitution = user!.isInstitution;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user!.name,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TopBarIcon(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile shared!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Share',
          ),
          TopBarIcon(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
            tooltip: 'More',
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildProfileHeader(themeProvider),
                const SizedBox(height: 12),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildActionButtons(themeProvider),
                const SizedBox(height: 16),
                if (isArtist) ...[
                  _buildArtistHighlightsGrid(),
                  const SizedBox(height: 24),
                ],
                isInstitution
                    ? _buildInstitutionHighlights()
                    : _buildAchievements(themeProvider),
                const SizedBox(height: 24),
                _buildPostsSection(),
                if (isArtist) ...[
                  const SizedBox(height: 24),
                  _buildArtistEventsShowcase(),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Image (use actual author avatar if available)
          AvatarWidget(
            wallet: user!.id,
            avatarUrl: user!.profileImageUrl,
            radius: 50,
            enableProfileNavigation: false,
            heroTag: widget.heroTag,
          ),
          const SizedBox(height: 16),
          
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
                if (user!.isArtist) ...[
                  const SizedBox(width: 8),
                  _buildArtistBadge(themeProvider),
                ],
                if (user!.isInstitution) ...[
                  const SizedBox(width: 8),
                  _buildInstitutionBadge(themeProvider),
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
          
          // Join Date
          Text(
            user!.joinedDate,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
    child: Row(
        children: [
          _buildInlineStat(label: 'Posts', value: _formatCount(user!.postsCount)),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          _buildInlineStat(label: 'Followers', value: _formatCount(user!.followersCount), onTap: () async {
            try { await _loadUserStats(); } catch (_) {}
            ProfileScreenMethods.showFollowers(context, userId: user!.id);
          }),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          _buildInlineStat(label: 'Following', value: _formatCount(user!.followingCount), onTap: () async {
            try { await _loadUserStats(); } catch (_) {}
            ProfileScreenMethods.showFollowing(context, userId: user!.id);
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

  Widget _buildActionButtons(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  user!.isFollowing ? 'Following' : 'Follow',
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
                      messenger.showSnackBar(const SnackBar(content: Text('Please log in to message this user.')));
                    }
                  } else {
                    if (mounted) {
                      messenger.showSnackBar(const SnackBar(content: Text('Could not open conversation')));
                    }
                  }
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Failed to open conversation: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Icon(Icons.message),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(ThemeProvider themeProvider) {
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
                'Achievements',
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
              title: '${user!.name} hasn\'t unlocked any achievements yet.',
              description: 'Start exploring to unlock achievements',
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
    final requiredProgress = achievement.requiredProgress > 0 ? achievement.requiredProgress : 1;
    final ratio = (progress.currentProgress / requiredProgress).clamp(0.0, 1.0);
    final isCompleted = progress.isCompleted || ratio >= 1.0;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? themeProvider.accentColor.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
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
                  color: achievement.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  achievement.icon,
                  color: achievement.color,
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
                isCompleted ? 'Completed' : '${progress.currentProgress}/$requiredProgress',
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
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.points}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
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
                isCompleted ? themeProvider.accentColor : achievement.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistBadge(ThemeProvider themeProvider) {
    final accent = themeProvider.accentColor;
    return Tooltip(
      message: 'Artist profile',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.brush, size: 14, color: accent),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionBadge(ThemeProvider themeProvider) {
    final accent = themeProvider.accentColor;
    return Tooltip(
      message: 'Institution profile',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_rounded, size: 14, color: accent),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posts',
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
              title: 'Could not load posts',
              description: _postsError!,
              icon: Icons.cloud_off,
              showAction: true,
              actionLabel: 'Try again',
              onActionTap: _loadPosts,
            ) else if (_posts.isEmpty)
            _buildEmptyStateCard(
              title: 'No posts yet',
              description: '${user!.name} hasn\'t shared any posts so far.',
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
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
                                  Text(post.authorName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(_formatPostTime(post.timestamp), style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
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
                child: Text('No more posts', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildArtistHighlightsGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Artist Highlights',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Latest drops from ${user!.name}.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Artworks',
            items: _artistArtworks,
            emptyLabel: '${user!.name} hasn\'t published any artworks yet.',
            builder: _buildArtworkCard,
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Collections',
            items: _artistCollections,
            emptyLabel: '${user!.name} hasn\'t curated collections yet.',
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistEventsShowcase() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upcoming experiences featuring ${user!.name}.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Events',
            items: _artistEvents,
            emptyLabel: 'No upcoming events from ${user!.name} just yet.',
            builder: _buildEventCard,
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionHighlights() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution Highlights',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Programs and collections curated by ${user!.name}.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Events',
            items: _artistEvents,
            emptyLabel: '${user!.name} has no upcoming events yet.',
            builder: _buildEventCard,
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Collections',
            items: _artistCollections,
            emptyLabel: '${user!.name} hasn\'t curated collections yet.',
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) builder,
    required String emptyLabel,
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
            title: 'No $title',
            description: emptyLabel,
            icon: (() {
              final lower = title.toLowerCase();
              if (lower.contains('artwork')) return Icons.image_outlined;
              if (lower.contains('collection')) return Icons.collections_outlined;
              if (lower.contains('event')) return Icons.event;
              if (lower.contains('post') || lower.contains('posts')) return Icons.article;
              return Icons.info_outline;
            })(),
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
    final title = (data['title'] ?? data['name'] ?? 'Untitled').toString();
    final medium = (data['medium'] ?? data['category'] ?? 'Digital').toString();
    final likes = data['likesCount'] ?? data['likes'] ?? 0;
    return _buildShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: medium,
      footer: '$likes likes',
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, ['thumbnailUrl', 'coverImage', 'image']);
    final title = (data['name'] ?? 'Collection').toString();
    final count = data['artworksCount'] ?? data['artworks_count'] ?? 0;
    return _buildShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: '$count artworks',
      footer: (data['description'] ?? 'Curated by ${user!.name}').toString(),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, ['bannerUrl', 'image']);
    final title = (data['title'] ?? 'Event').toString();
    final dateLabel = _formatDateLabel(data['startDate'] ?? data['start_date']);
    final location = (data['location'] ?? 'TBA').toString();
    return _buildShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: dateLabel,
      footer: location,
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
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('ipfs://')) {
      final cid = url.replaceFirst('ipfs://', '');
      return 'https://ipfs.io/ipfs/$cid';
    }
    return url;
  }

  String _formatDateLabel(dynamic value) {
    if (value == null) return 'TBA';
    try {
      final date = value is DateTime ? value : DateTime.parse(value.toString());
      return '${_monthShort(date.month)} ${date.day}, ${date.year}';
    } catch (_) {
      return 'TBA';
    }
  }

  String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  Widget _buildEmptyStateCard({
    required String title,
    required String description,
    IconData icon = Icons.info_outline,
    bool showAction = false,
    String actionLabel = 'Retry',
    Future<void> Function()? onActionTap,
  }) {
    return EmptyStateCard(
      icon: icon,
      title: title,
      description: description,
      showAction: showAction,
      actionLabel: showAction ? actionLabel : null,
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
      final lowerWallet = walletAddress.toLowerCase();
      final filteredEvents = eventsResponse.where((event) {
        final createdBy = (event['createdBy'] ?? event['created_by'] ?? '').toString().toLowerCase();
        final artistIdsRaw = event['artistIds'] ?? event['artist_ids'] ?? [];
        final artistIds = artistIdsRaw is List
            ? artistIdsRaw.map((id) => id.toString().toLowerCase()).toList()
            : <String>[];
        return createdBy == lowerWallet || artistIds.contains(lowerWallet);
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
      if (!mounted) return;
      setState(() {
        _artistDataLoaded = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _artistDataLoading = false;
      });
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionItem(Icons.block, 'Block User', () {
              Navigator.pop(context);
              _showBlockConfirmation();
            }),
            _buildOptionItem(Icons.report, 'Report User', () {
              Navigator.pop(context);
              _showReportDialog();
            }),
            _buildOptionItem(Icons.copy, 'Copy Profile Link', () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile link copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16),
      ),
      onTap: onTap,
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Block ${user!.name}?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'They won\'t be able to see your profile or posts.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Perform block action (placeholder)
              Navigator.pop(context);
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report ${user!.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Why are you reporting this user?',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            _buildReportOption('Spam'),
            _buildReportOption('Inappropriate content'),
            _buildReportOption('Harassment'),
            _buildReportOption('Other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatPostTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for your feedback.'),
            duration: Duration(seconds: 2),
          ),
        );
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
