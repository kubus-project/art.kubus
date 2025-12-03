import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../utils/wallet_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../community/community_interactions.dart';
import '../../web3/achievements/achievements_page.dart';
import '../../settings_screen.dart';
import '../../community/post_detail_screen.dart';
import '../../../models/achievements.dart';
import 'desktop_profile_edit_screen.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/empty_state_card.dart';
import '../../community/profile_screen_methods.dart';
import '../../../widgets/artist_badge.dart';
import '../../../widgets/institution_badge.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../components/desktop_widgets.dart';

/// Desktop profile screen with clean card-based layout
/// Features: Profile header, stats cards, achievements, posts feed
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  Future<List<CommunityPost>>? _postsFuture;
  bool _didScheduleDataFetch = false;
  bool _artistDataRequested = false;
  bool _artistDataLoading = false;
  bool _artistDataLoaded = false;
  List<Map<String, dynamic>> _artistArtworks = [];
  List<Map<String, dynamic>> _artistCollections = [];
  List<Map<String, dynamic>> _artistEvents = [];
  bool _showActivityStatus = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
    _loadPrivacySettings();
    final artworkProvider = context.read<ArtworkProvider>();
    Future.microtask(() {
      try {
        artworkProvider.ensureHistoryLoaded();
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (!_didScheduleDataFetch) {
      _didScheduleDataFetch = true;
      _postsFuture = _loadUserPosts();
      try {
        Future(() async {
          try {
            await profileProvider.refreshStats();
          } catch (e) {
            debugPrint('ProfileScreen: refreshStats failed: $e');
          }
        });
      } catch (_) {}
    }
    _maybeLoadArtistData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _hasArtistRole(ProfileProvider profileProvider, DAOReview? review) {
    if (profileProvider.currentUser?.isArtist ?? false) return true;
    if (review == null) return false;
    return review.isArtistApplication && review.isApproved;
  }

  bool _hasInstitutionRole(ProfileProvider profileProvider, DAOReview? review) {
    if (profileProvider.currentUser?.isInstitution ?? false) return true;
    if (review == null) return false;
    return review.isInstitutionApplication && review.isApproved;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final daoProvider = Provider.of<DAOProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    final walletAddress = profileProvider.currentUser?.walletAddress ?? '';
    final DAOReview? daoReview = walletAddress.isNotEmpty
        ? daoProvider.findReviewForWallet(walletAddress)
        : null;
    final isArtist = _hasArtistRole(profileProvider, daoReview);
    final isInstitution = _hasInstitutionRole(profileProvider, daoReview);

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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isLarge ? 32 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(themeProvider),
                    const SizedBox(height: 32),
                    _buildProfileCard(themeProvider, profileProvider, isArtist, isInstitution),
                    const SizedBox(height: 24),
                    _buildStatsCards(themeProvider, profileProvider, isLarge),
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

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Back',
              ),
            if (Navigator.of(context).canPop()) const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your identity and content',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            DesktopActionButton(
              label: 'Share Profile',
              icon: Icons.share_outlined,
              onPressed: _shareProfile,
              isPrimary: false,
            ),
            const SizedBox(width: 12),
            DesktopActionButton(
              label: 'Settings',
              icon: Icons.settings_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              isPrimary: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    ThemeProvider themeProvider,
    ProfileProvider profileProvider,
    bool isArtist,
    bool isInstitution,
  ) {
    final user = profileProvider.currentUser;
    final web3Provider = Provider.of<Web3Provider>(context);
    final coverImageUrl = _normalizeMediaUrl(user?.coverImage);
    final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty;
    const avatarRadius = 52.0;

    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: hasCoverImage ? 200 : 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: !hasCoverImage
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeProvider.accentColor.withValues(alpha: 0.25),
                              themeProvider.accentColor.withValues(alpha: 0.08),
                            ],
                          )
                        : null,
                  ),
                  child: hasCoverImage
                      ? Image.network(
                          coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    themeProvider.accentColor.withValues(alpha: 0.25),
                                    themeProvider.accentColor.withValues(alpha: 0.08),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ),
              if (hasCoverImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.32),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 24,
                bottom: -avatarRadius + 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AvatarWidget(
                    wallet: user?.walletAddress ?? '',
                    avatarUrl: user?.avatar,
                    radius: avatarRadius,
                    enableProfileNavigation: false,
                    showStatusIndicator: _showActivityStatus,
                    isOnline: web3Provider.isConnected ||
                        !Provider.of<WalletProvider>(context, listen: false).isLocked,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: avatarRadius + 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: avatarRadius * 2 + 8), // align text with avatar edge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user?.displayName ?? user?.username ?? 'Art Enthusiast',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
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
                      if (user?.username != null && user?.displayName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '@${user!.username}',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (web3Provider.isConnected) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: themeProvider.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: themeProvider.accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            web3Provider.formatAddress(web3Provider.walletAddress),
                            style: GoogleFonts.robotoMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.accentColor,
                            ),
                          ),
                        ),
                      ],
                      if (user?.bio != null && user!.bio.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          user.bio,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeProvider themeProvider, ProfileProvider profileProvider, bool isLarge) {
    final wallet = profileProvider.currentUser?.walletAddress;

    return DesktopGrid(
      minCrossAxisCount: 2,
      maxCrossAxisCount: isLarge ? 4 : 2,
      childAspectRatio: 2.5,
      children: [
        DesktopStatCard(
          label: 'Posts',
          value: profileProvider.formattedPostsCount,
          icon: Icons.article_outlined,
        ),
        DesktopStatCard(
          label: 'Followers',
          value: profileProvider.formattedFollowersCount,
          icon: Icons.people_outline,
          onTap: () => ProfileScreenMethods.showFollowers(context, walletAddress: wallet),
        ),
        DesktopStatCard(
          label: 'Following',
          value: profileProvider.formattedFollowingCount,
          icon: Icons.person_add_outlined,
          onTap: () => ProfileScreenMethods.showFollowing(context, walletAddress: wallet),
        ),
        DesktopStatCard(
          label: 'Artworks',
          value: profileProvider.formattedArtworksCount,
          icon: Icons.palette_outlined,
          onTap: () => ProfileScreenMethods.showArtworks(context),
        ),
      ],
    );
  }

  Widget _buildCreatorHighlights(ThemeProvider themeProvider, bool isArtist, bool isInstitution) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: isInstitution ? 'Institution Highlights' : 'Artist Highlights',
          subtitle: isInstitution
              ? 'Your featured exhibitions and programs'
              : 'Your latest artworks and collections',
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
        else if (_artistArtworks.isEmpty && _artistCollections.isEmpty && _artistEvents.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.image_outlined,
              title: 'No content yet',
              description: isInstitution
                  ? 'Create exhibitions and events to showcase them here'
                  : 'Upload artworks and create collections to display them here',
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

  Widget _buildShowcaseCard({String? imageUrl, required String title, required String subtitle}) {
    return Container(
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
    );
  }

  Widget _buildAchievementsSection(ThemeProvider themeProvider) {
    return Consumer2<TaskProvider, ConfigProvider>(
      builder: (context, taskProvider, configProvider, _) {
        final achievements = taskProvider.achievementProgress;
        final displayAchievements = allAchievements.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: 'Achievements',
              subtitle: 'Your progress and milestones',
              icon: Icons.emoji_events_outlined,
              action: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AchievementsPage()),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View All'),
              ),
            ),
            const SizedBox(height: 16),
            if (!configProvider.useMockData && achievements.isEmpty)
              DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.emoji_events,
                  title: 'No Achievements Yet',
                  description: 'Start exploring to unlock achievements',
                ),
              )
            else
              DesktopGrid(
                minCrossAxisCount: 2,
                maxCrossAxisCount: 3,
                childAspectRatio: 1.2,
                children: displayAchievements.map((achievement) {
                  final progress = achievements.firstWhere(
                    (p) => p.achievementId == achievement.id,
                    orElse: () => AchievementProgress(
                      achievementId: achievement.id,
                      currentProgress: 0,
                      isCompleted: false,
                    ),
                  );
                  return _buildAchievementCard(achievement, progress);
                }).toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementCard(Achievement achievement, AchievementProgress progress) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final requiredProgress = achievement.requiredProgress > 0 ? achievement.requiredProgress : 1;
    final ratio = (progress.currentProgress / requiredProgress).clamp(0.0, 1.0);
    final isCompleted = progress.isCompleted || ratio >= 1.0;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: achievement.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(achievement.icon, color: achievement.color, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.points}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
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
                isCompleted ? themeProvider.accentColor : achievement.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection(ThemeProvider themeProvider) {
    final future = _postsFuture ?? _loadUserPosts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Your Posts',
          subtitle: 'Content you\'ve shared with the community',
          icon: Icons.article_outlined,
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CommunityPost>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return DesktopCard(
                child: Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.error_outline,
                  title: 'Could not load posts',
                  description: 'Please try again later',
                  showAction: true,
                  actionLabel: 'Retry',
                  onAction: () => setState(() => _postsFuture = _loadUserPosts()),
                ),
              );
            }

            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.article,
                  title: 'No posts yet',
                  description: 'Share your perspective with the community',
                ),
              );
            }

            return Column(
              children: posts.map((post) => _buildPostCard(post, themeProvider)).toList(),
            );
          },
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
                        _formatRelativeTime(post.timestamp),
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
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final wallet = await _resolveCurrentWallet();

    if (!mounted) return;
    setState(() {
      _postsFuture = _loadUserPosts();
      _artistDataRequested = false;
      _artistDataLoaded = false;
    });

    try {
      await _postsFuture;
    } catch (_) {}

    await _maybeLoadArtistData(force: true);

    if (wallet != null && wallet.isNotEmpty) {
      try {
        await profileProvider.loadProfile(wallet);
      } catch (_) {}
    }
  }

  Future<String?> _resolveCurrentWallet() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress;
    if (wallet != null && wallet.isNotEmpty) return wallet;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('wallet_address');
  }

  Future<List<CommunityPost>> _loadUserPosts({String? walletOverride}) async {
    final wallet = walletOverride ?? await _resolveCurrentWallet();
    if (wallet == null || wallet.isEmpty) return [];
    try {
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        authorWallet: wallet,
      );
      await CommunityService.loadSavedInteractions(posts, walletAddress: wallet);
      return posts;
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      rethrow;
    }
  }

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress ?? '';
    if (wallet.isEmpty) return;

    DAOReview? review;
    try {
      review = Provider.of<DAOProvider>(context, listen: false).findReviewForWallet(wallet);
    } catch (_) {}

    final isArtist = _hasArtistRole(profileProvider, review);
    final isInstitution = _hasInstitutionRole(profileProvider, review);
    if (!(isArtist || isInstitution)) return;
    if (_artistDataLoading && !force) return;
    if (_artistDataRequested && !force) return;

    _artistDataRequested = true;
    await _loadArtistData(wallet, force: force);
  }

  Future<void> _loadArtistData(String walletAddress, {bool force = false}) async {
    if (!mounted) return;
    setState(() => _artistDataLoading = true);

    try {
      final api = BackendApiService();
      final artworks = await api.getArtistArtworks(walletAddress, limit: 6);
      final collections = await api.getCollections(walletAddress: walletAddress, limit: 6);
      final eventsResponse = await api.listEvents(limit: 100);
      final normalizedWallet = WalletUtils.normalize(walletAddress);
      final filteredEvents = eventsResponse.where((event) {
        final createdBy = WalletUtils.normalize((event['createdBy'] ?? event['created_by'] ?? '').toString());
        final artistIdsDynamic = event['artistIds'] ?? event['artist_ids'] ?? [];
        final artistIds = artistIdsDynamic is List
            ? artistIdsDynamic.map((e) => WalletUtils.normalize(e.toString())).toList()
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
      debugPrint('Error loading artist data: $e');
    } finally {
      if (mounted) setState(() => _artistDataLoading = false);
    }
  }

  Future<void> _loadPrivacySettings() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    try {
      final prefsModel = profileProvider.preferences;
      setState(() => _showActivityStatus = prefsModel.showActivityStatus);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _showActivityStatus = prefs.getBool('show_activity_status') ?? true);
    }
  }

  void _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );

    if (result == true && mounted) {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      if (web3Provider.isConnected && web3Provider.walletAddress.isNotEmpty) {
        await profileProvider.loadProfile(web3Provider.walletAddress);
      }
    }
  }

  void _shareProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String? _extractImageUrl(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _normalizeMediaUrl(String? url) {
    if (url == null) return null;
    final candidate = url.trim();
    if (candidate.isEmpty) return null;
    if (candidate.startsWith('data:')) return candidate;
    if (candidate.startsWith('ipfs://')) {
      final cid = candidate.replaceFirst('ipfs://', '');
      return 'https://ipfs.io/ipfs/$cid';
    }
    final base = BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '');
    if (candidate.startsWith('//')) return 'https:$candidate';
    if (candidate.startsWith('/')) return '$base$candidate';
    if (candidate.startsWith('api/')) return '$base/$candidate';
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(candidate);
    if (!hasScheme) {
      return '$base/${candidate.startsWith('/') ? candidate.substring(1) : candidate}';
    }
    return candidate;
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays >= 7) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
