import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/category_accent_color.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../../models/user.dart';
import '../../../services/user_service.dart';
import '../../../models/achievements.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/block_list_service.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../community/community_interactions.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../core/conversation_navigator.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/artist_badge.dart';
import '../../../widgets/institution_badge.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../screens/community/post_detail_screen.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/socket_service.dart';
import '../../../screens/community/profile_screen_methods.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../components/desktop_widgets.dart';
import '../../art/art_detail_screen.dart';

/// Desktop user profile screen - viewing another user's profile
/// Clean card-based layout with follow/message actions
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

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _followButtonController;
  late ScrollController _scrollController;

  User? user;
  bool isLoading = true;
  List<CommunityPost> _posts = [];
  bool _postsLoading = true;
  int _currentPage = 1;
  bool _isLastPage = false;
  bool _loadingMore = false;
  String? _postsError;

  bool _artistDataLoading = false;
  bool _artistDataLoaded = false;
  bool _artistDataRequested = false;
  List<Map<String, dynamic>> _artistArtworks = [];
  List<Map<String, dynamic>> _artistCollections = [];

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _followButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });

    _animationController.forward();
    _loadUser();

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
    _animationController.dispose();
    _followButtonController.dispose();
    _scrollController.dispose();
    try {
      Provider.of<WalletProvider>(context, listen: false).removeListener(_onWalletChanged);
    } catch (_) {}
    try {
      SocketService().removePostListener(_handleIncomingPost);
    } catch (_) {}
    super.dispose();
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    try {
      if (user == null) return;
      final incomingAuthor = (data['walletAddress'] ?? data['author'] ?? data['authorWallet'])?.toString();
      if (incomingAuthor == null) return;
      if (!WalletUtils.equals(incomingAuthor, user!.id)) return;

      final id = (data['id'] ?? data['postId'] ?? data['post_id'])?.toString();
      if (id == null) return;
      if (_posts.any((p) => p.id == id)) return;

      try {
        final post = await BackendApiService().getCommunityPostById(id);
        if (!mounted) return;
        setState(() => _posts.insert(0, post));
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
        await CommunityService.loadSavedInteractions(_posts, walletAddress: _currentWalletAddress());
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to refresh post interactions on wallet change: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    if (isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.isDarkMode
            ? Theme.of(context).scaffoldBackgroundColor
            : const Color(0xFFF8F9FA),
        body: const Center(child: AppLoading()),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: themeProvider.isDarkMode
            ? Theme.of(context).scaffoldBackgroundColor
            : const Color(0xFFF8F9FA),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.person_off_outlined,
            title: 'User not found',
            description: 'This profile may have been deleted or doesn\'t exist',
          ),
        ),
      );
    }

    final daoProvider = Provider.of<DAOProvider>(context);
    final DAOReview? daoReview = daoProvider.findReviewForWallet(user!.id);
    final isArtist = user!.isArtist || (daoReview != null && daoReview.isArtistApplication && daoReview.isApproved);
    final isInstitution = user!.isInstitution || (daoReview != null && daoReview.isInstitutionApplication && daoReview.isApproved);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: _animationController,
              curve: animationTheme.fadeCurve,
            ),
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: themeProvider.accentColor,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isLarge ? 32 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(themeProvider, isArtist, isInstitution),
                    const SizedBox(height: 32),
                    _buildProfileCard(themeProvider, isArtist, isInstitution),
                    const SizedBox(height: 24),
                    _buildStatsCards(themeProvider, isLarge),
                    const SizedBox(height: 24),
                    _buildActionButtons(themeProvider),
                    const SizedBox(height: 24),
                    if (isArtist || isInstitution) ...[
                      _buildCreatorHighlights(themeProvider, isArtist, isInstitution),
                      const SizedBox(height: 24),
                    ],
                    _buildAchievementsSection(themeProvider),
                    const SizedBox(height: 24),
                    _buildPostsSection(themeProvider),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, bool isArtist, bool isInstitution) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Back',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  user!.name,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isArtist) ...[
                const SizedBox(width: 12),
                const ArtistBadge(),
              ],
              if (isInstitution) ...[
                const SizedBox(width: 12),
                const InstitutionBadge(),
              ],
            ],
          ),
        ),
        DesktopActionButton(
          label: 'Share',
          icon: Icons.share_outlined,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile shared!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          isPrimary: false,
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _showMoreOptions,
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'More options',
        ),
      ],
    );
  }

  Widget _buildProfileCard(ThemeProvider themeProvider, bool isArtist, bool isInstitution) {
    final coverImageUrl = _normalizeMediaUrl(user!.coverImageUrl);
    final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty;

    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (hasCoverImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    coverImageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeProvider.accentColor.withValues(alpha: 0.3),
                              themeProvider.accentColor.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeProvider.accentColor.withValues(alpha: 0.3),
                    themeProvider.accentColor.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          Transform.translate(
            offset: const Offset(0, -50),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 4,
                    ),
                  ),
                  child: AvatarWidget(
                    wallet: user!.id,
                    avatarUrl: user!.profileImageUrl,
                    radius: 50,
                    enableProfileNavigation: false,
                    heroTag: widget.heroTag,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        user!.name,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user!.username,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user!.bio,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Joined ${user!.joinedDate}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeProvider themeProvider, bool isLarge) {
    return DesktopGrid(
      minCrossAxisCount: 2,
      maxCrossAxisCount: isLarge ? 4 : 2,
      childAspectRatio: 2.5,
      children: [
        DesktopStatCard(
          label: 'Posts',
          value: _formatCount(user!.postsCount),
          icon: Icons.article_outlined,
        ),
        DesktopStatCard(
          label: 'Followers',
          value: _formatCount(user!.followersCount),
          icon: Icons.people_outline,
          onTap: () async {
            try {
              await _loadUserStats();
            } catch (_) {}
            if (!mounted) return;
            ProfileScreenMethods.showFollowers(context, walletAddress: user!.id);
          },
        ),
        DesktopStatCard(
          label: 'Following',
          value: _formatCount(user!.followingCount),
          icon: Icons.person_add_outlined,
          onTap: () async {
            try {
              await _loadUserStats();
            } catch (_) {}
            if (!mounted) return;
            ProfileScreenMethods.showFollowing(context, walletAddress: user!.id);
          },
        ),
        DesktopStatCard(
          label: 'Achievements',
          value: (user!.achievementProgress.where((p) => p.isCompleted).length).toString(),
          icon: Icons.emoji_events_outlined,
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(parent: _followButtonController, curve: Curves.easeInOut),
            ),
            child: DesktopActionButton(
              label: user!.isFollowing ? 'Following' : 'Follow',
              icon: user!.isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined,
              onPressed: _toggleFollow,
              isPrimary: !user!.isFollowing,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DesktopActionButton(
            label: 'Message',
            icon: Icons.mail_outlined,
            onPressed: _openConversation,
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorHighlights(ThemeProvider themeProvider, bool isArtist, bool isInstitution) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: isInstitution ? 'Institution Highlights' : 'Artist Portfolio',
          subtitle: isInstitution
              ? 'Featured exhibitions and programs'
              : 'Latest artworks and collections',
          icon: isInstitution ? Icons.business : Icons.palette,
        ),
        const SizedBox(height: 16),
        if (_artistDataLoading && !_artistDataLoaded)
          DesktopCard(
            child: Container(
              height: 200,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          )
        else if (_artistArtworks.isEmpty && _artistCollections.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.image_outlined,
              title: 'No content available',
              description: isInstitution
                  ? 'No exhibitions or programs to display yet'
                  : 'No artworks or collections to display yet',
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._artistArtworks.map((artwork) => _buildShowcaseCard(
                      imageUrl: _extractImageUrl(artwork, ['imageUrl', 'image']),
                      title: artwork['title'] ?? 'Untitled',
                      subtitle: artwork['category'] ?? 'Artwork',
                      artworkId: (artwork['id'] ?? artwork['artwork_id'])?.toString(),
                    )),
                ..._artistCollections.map((collection) => _buildShowcaseCard(
                      imageUrl: _extractImageUrl(collection, ['thumbnailUrl', 'coverImage']),
                      title: collection['name'] ?? 'Collection',
                      subtitle: '${collection['artworksCount'] ?? 0} artworks',
                    )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShowcaseCard({String? imageUrl, required String title, required String subtitle, String? artworkId}) {
    return GestureDetector(
      onTap: artworkId != null ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtDetailScreen(artworkId: artworkId),
          ),
        );
      } : null,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        child: DesktopCard(
          padding: EdgeInsets.zero,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  _normalizeMediaUrl(imageUrl) ?? '',
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.image_outlined, size: 48),
                  ),
                ),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Center(child: Icon(Icons.image_outlined, size: 48)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAchievementsSection(ThemeProvider themeProvider) {
    final progress = user?.achievementProgress ?? [];
    final achievementsToShow = allAchievements.take(6).toList();
    if (achievementsToShow.isEmpty) return const SizedBox.shrink();

    final completedCount = progress.where((p) => p.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Achievements',
          subtitle: '$completedCount of ${allAchievements.length} unlocked',
          icon: Icons.emoji_events_outlined,
        ),
        const SizedBox(height: 16),
        if (progress.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              title: 'No achievements yet',
              description: '${user!.name} hasn\'t unlocked any achievements',
              icon: Icons.emoji_events,
            ),
          )
        else
          DesktopGrid(
            minCrossAxisCount: 2,
            maxCrossAxisCount: 3,
            childAspectRatio: 1.2,
            children: achievementsToShow.map((achievement) {
              final achievementProgress = progress.firstWhere(
                (p) => p.achievementId == achievement.id,
                orElse: () => AchievementProgress(
                  achievementId: achievement.id,
                  currentProgress: 0,
                  isCompleted: false,
                ),
              );
              return _buildAchievementCard(achievement, achievementProgress);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement, AchievementProgress progress) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final requiredProgress = achievement.requiredProgress > 0 ? achievement.requiredProgress : 1;
    final ratio = (progress.currentProgress / requiredProgress).clamp(0.0, 1.0);
    final isCompleted = progress.isCompleted || ratio >= 1.0;
    final accent = CategoryAccentColor.resolve(context, achievement.category);

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(achievement.icon, color: accent, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.points}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            achievement.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted ? 'Completed' : '${progress.currentProgress}/$requiredProgress',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? themeProvider.accentColor
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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

  Widget _buildPostsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Posts',
          subtitle: 'Recent activity from ${user!.name}',
          icon: Icons.article_outlined,
        ),
        const SizedBox(height: 16),
        if (_postsLoading)
          DesktopCard(
            child: Container(
              height: 200,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          )
        else if (_postsError != null)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.cloud_off,
              title: 'Could not load posts',
              description: _postsError!,
              showAction: true,
              actionLabel: 'Try again',
              onAction: _loadPosts,
            ),
          )
        else if (_posts.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              title: 'No posts yet',
              description: '${user!.name} hasn\'t shared any posts so far',
              icon: Icons.article,
            ),
          )
        else
          Column(
            children: [
              ..._posts.map((post) => _buildPostCard(post, themeProvider)),
              if (_loadingMore)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                )
              else if (_isLastPage)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: Text(
                    'No more posts',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildPostCard(CommunityPost post, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DesktopCard(
        enableHover: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  wallet: post.authorId,
                  avatarUrl: post.authorAvatar,
                  radius: 20,
                  enableProfileNavigation: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.authorName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.authorIsArtist) ...[
                            const SizedBox(width: 8),
                            const ArtistBadge(fontSize: 9, padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                          ],
                          if (post.authorIsInstitution) ...[
                            const SizedBox(width: 8),
                            const InstitutionBadge(fontSize: 9, padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPostTime(post.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: post.isLiked
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  post.likeCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: post.isLiked
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 24),
                Icon(
                  Icons.comment_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  post.commentCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Future<void> _handleRefresh() async {
    await _loadUser(showFullScreenLoader: false);
  }

  Future<void> _loadUser({bool showFullScreenLoader = true}) async {
    if (showFullScreenLoader) setState(() => isLoading = true);

    User? loadedUser;
    try {
      if (widget.username != null) {
        loadedUser = await UserService.getUserByUsername(widget.username!);
      } else {
        loadedUser = await UserService.getUserById(widget.userId, forceRefresh: true);
      }
    } catch (e) {
      debugPrint('Failed to fetch user: $e');
    }

    if (!mounted) return;
    setState(() {
      user = loadedUser;
      isLoading = false;
    });

    if (user == null) return;

    try {
      UserService.fetchAndUpdateUserStats(user!.id);
    } catch (_) {}

    await _loadUserStats(skipFollowersOverwrite: true);
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
      final posts = await BackendApiService().getCommunityPosts(
        page: _currentPage,
        limit: pageSize,
        authorWallet: user!.id,
      );

      try {
        await CommunityService.loadSavedInteractions(posts, walletAddress: _currentWalletAddress());
      } catch (_) {}

      setState(() {
        _posts = posts;
        _postsLoading = false;
        _isLastPage = posts.length < pageSize;
      });

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
      final more = await BackendApiService().getCommunityPosts(
        page: _currentPage,
        limit: pageSize,
        authorWallet: user!.id,
      );

      try {
        await CommunityService.loadSavedInteractions(more, walletAddress: _currentWalletAddress());
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
        if (_currentPage > 1) _currentPage -= 1;
      });
    }
  }

  Future<void> _loadUserStats({bool skipFollowersOverwrite = false}) async {
    final profile = user;
    if (profile == null) return;

    try {
      final stats = await BackendApiService().getUserStats(profile.id);
      if (!mounted) return;

      setState(() {
        final fetchedPosts = int.tryParse(stats['postsCount']?.toString() ?? '0') ?? 0;
        final fetchedFollowers = int.tryParse(stats['followersCount']?.toString() ?? '0') ?? 0;
        final fetchedFollowing = int.tryParse(stats['followingCount']?.toString() ?? '0') ?? 0;

        var resolvedFollowers = fetchedFollowers;
        var resolvedFollowing = fetchedFollowing;

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

  Future<void> _toggleFollow() async {
    if (user == null) return;

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
      debugPrint('Failed to toggle follow: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('401')
                ? 'Please sign in to follow creators'
                : 'Could not update follow status',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newFollowState ? 'Following ${user!.name}' : 'Unfollowed ${user!.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await _loadUserStats();
    try {
      if (user != null) UserService.setUsersInCache([user!]);
    } catch (_) {}
  }

  Future<void> _openConversation() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final chatAuth = chatProvider.isAuthenticated;

    try {
      final conv = await chatProvider.createConversation('', false, [user!.id]);
      if (conv != null) {
        if (!mounted) return;
        final preloaded = chatProvider.getPreloadedProfileMapsForConversation(conv.id);
        final rawMembers = (preloaded['members'] as List<dynamic>?)?.cast<String>() ?? <String>[];
        final members = rawMembers.isNotEmpty ? rawMembers : <String>[user!.id];
        final avatars = Map<String, String?>.from((preloaded['avatars'] as Map<String, String?>?) ?? <String, String?>{});
        if (!avatars.containsKey(members.first) || (avatars[members.first]?.isEmpty ?? true)) {
          avatars[members.first] = user!.profileImageUrl;
        }
        final names = Map<String, String?>.from((preloaded['names'] as Map<String, String?>?) ?? <String, String?>{});
        if (!names.containsKey(members.first) || (names[members.first]?.isEmpty ?? true)) {
          names[members.first] = user!.name;
        }
        await ConversationNavigator.openConversationWithPreload(
          context,
          conv,
          preloadedMembers: members,
          preloadedAvatars: avatars,
          preloadedDisplayNames: names,
        );
      } else {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                chatAuth
                    ? 'Could not open conversation'
                    : 'Please log in to message this user',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to open conversation: $e')),
        );
      }
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
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _confirmBlockUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Profile Link'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile link copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBlockUser() {
    final targetWallet = WalletUtils.canonical(user?.id ?? widget.userId);
    if (targetWallet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to block user')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Block ${user?.name ?? targetWallet}?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'They won\'t be able to see your profile or posts.',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await BlockListService().blockWallet(targetWallet);
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to block user: $e')),
                );
                return;
              }

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Blocked ${user?.name ?? targetWallet}'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => BlockListService().unblockWallet(targetWallet),
                  ),
                ),
              );
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Report ${user?.name ?? ''}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Spam'),
              onTap: () => _submitReport('Spam'),
            ),
            ListTile(
              title: const Text('Inappropriate content'),
              onTap: () => _submitReport('Inappropriate content'),
            ),
            ListTile(
              title: const Text('Harassment'),
              onTap: () => _submitReport('Harassment'),
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () => _submitReport('Other'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport(String reason) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report submitted ($reason). Thank you.')),
    );
  }

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final isCreator = (user?.isArtist ?? false) || (user?.isInstitution ?? false);
    if (!isCreator) return;
    if (_artistDataLoading && !force) return;
    if (_artistDataRequested && !force) return;

    _artistDataRequested = true;
    await _loadArtistData(user!.id, force: force);
  }

  Future<void> _loadArtistData(String walletAddress, {bool force = false}) async {
    if (!mounted) return;
    setState(() => _artistDataLoading = true);

    try {
      final api = BackendApiService();
      final artworks = await api.getArtistArtworks(walletAddress, limit: 6);
      final collections = await api.getCollections(walletAddress: walletAddress, limit: 6);

      if (!mounted) return;
      setState(() {
        _artistArtworks = artworks;
        _artistCollections = collections;
        _artistDataLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load artist showcase data: $e');
      if (mounted) setState(() => _artistDataLoaded = true);
    } finally {
      if (mounted) setState(() => _artistDataLoading = false);
    }
  }

  String? _extractImageUrl(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
