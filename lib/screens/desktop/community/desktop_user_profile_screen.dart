import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
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
import '../../../providers/stats_provider.dart';
import '../../../providers/app_refresh_provider.dart';
import '../../../core/conversation_navigator.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/user_activity_status_line.dart';
import '../../../widgets/artist_badge.dart';
import '../../../widgets/institution_badge.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/profile_artist_info_fields.dart';
import '../../../screens/community/post_detail_screen.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/socket_service.dart';
import '../../../screens/community/profile_screen_methods.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../components/desktop_widgets.dart';
import '../art/desktop_artwork_detail_screen.dart';
import '../../art/collection_detail_screen.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final isWide = screenWidth >= 1400;

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
            title: l10n.userProfileNotFound,
            description: l10n.userProfileNotFoundDescription,
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(themeProvider, isArtist, isInstitution, l10n),
                        const SizedBox(height: 20),
                        _buildProfileCard(themeProvider, isArtist, isInstitution, l10n),
                        const SizedBox(height: 16),
                        // Stats and action buttons in a row on wide screens
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildStatsCards(themeProvider, isLarge, l10n)),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 320,
                                child: _buildActionButtons(themeProvider, l10n),
                              ),
                            ],
                          )
                        else ...[
                          _buildStatsCards(themeProvider, isLarge, l10n),
                          const SizedBox(height: 16),
                          _buildActionButtons(themeProvider, l10n),
                        ],
                        const SizedBox(height: 20),
                        // Two-column layout for wide screens
                        if (isWide)
                          _buildTwoColumnLayout(
                            themeProvider: themeProvider,
                            isArtist: isArtist,
                            isInstitution: isInstitution,
                            l10n: l10n,
                          )
                        else
                          _buildSingleColumnContent(
                            themeProvider: themeProvider,
                            isArtist: isArtist,
                            isInstitution: isInstitution,
                            l10n: l10n,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Two-column layout for wide desktop screens (>=1400px)
  Widget _buildTwoColumnLayout({
    required ThemeProvider themeProvider,
    required bool isArtist,
    required bool isInstitution,
    required AppLocalizations l10n,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Achievements (narrower)
        SizedBox(
          width: 380,
          child: _buildAchievementsSection(themeProvider, l10n),
        ),
        const SizedBox(width: 24),
        // Right column: Content sections + Posts (wider)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isArtist) ...[
                _buildArtistPortfolioSection(themeProvider, l10n),
                const SizedBox(height: 16),
                _buildArtistCollectionsSection(themeProvider, l10n),
                const SizedBox(height: 16),
              ] else if (isInstitution) ...[
                _buildInstitutionHighlightsSection(themeProvider, l10n),
                const SizedBox(height: 16),
              ],
              _buildPostsSection(themeProvider, l10n),
            ],
          ),
        ),
      ],
    );
  }

  /// Single column layout for narrower screens (<1400px)
  Widget _buildSingleColumnContent({
    required ThemeProvider themeProvider,
    required bool isArtist,
    required bool isInstitution,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isArtist) ...[
          _buildArtistPortfolioSection(themeProvider, l10n),
          const SizedBox(height: 16),
          _buildArtistCollectionsSection(themeProvider, l10n),
          const SizedBox(height: 16),
        ] else if (isInstitution) ...[
          _buildInstitutionHighlightsSection(themeProvider, l10n),
          const SizedBox(height: 16),
        ],
        _buildAchievementsSection(themeProvider, l10n),
        const SizedBox(height: 16),
        _buildPostsSection(themeProvider, l10n),
      ],
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, bool isArtist, bool isInstitution, AppLocalizations l10n) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: l10n.commonBack,
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
          label: l10n.userProfileShareTooltip,
          icon: Icons.share_outlined,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.userProfileSharedToast),
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
          tooltip: l10n.userProfileMoreTooltip,
        ),
      ],
    );
  }

  Widget _buildProfileCard(ThemeProvider themeProvider, bool isArtist, bool isInstitution, AppLocalizations l10n) {
    final coverImageUrl = _normalizeMediaUrl(user!.coverImageUrl);
    final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty;
    const avatarRadius = 44.0;

    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Compact cover image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: hasCoverImage ? 120 : 70,
                  width: double.infinity,
                  decoration: hasCoverImage
                      ? null
                      : BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeProvider.accentColor.withValues(alpha: 0.3),
                              themeProvider.accentColor.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                  child: hasCoverImage
                      ? Image.network(
                          coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
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
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Horizontal profile info layout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AvatarWidget(
                    wallet: user!.id,
                    avatarUrl: user!.profileImageUrl,
                    radius: avatarRadius,
                    enableProfileNavigation: false,
                    heroTag: widget.heroTag,
                  ),
                ),
                const SizedBox(width: 16),
                // Name, username, bio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user!.name,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                      const SizedBox(height: 4),
                      Text(
                        user!.username,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      UserActivityStatusLine(
                        walletAddress: user!.id,
                        textAlign: TextAlign.start,
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (user!.bio.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          user!.bio,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.4,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      ProfileArtistInfoFields(
                        fieldOfWork: user!.fieldOfWork,
                        yearsActive: user!.yearsActive,
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.userProfileJoinedLabel(user!.joinedDate),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeProvider themeProvider, bool isLarge, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCols = screenWidth >= 1400 ? 4 : (isLarge ? 4 : 2);

    return DesktopGrid(
      minCrossAxisCount: 2,
      maxCrossAxisCount: maxCols,
      childAspectRatio: screenWidth >= 1400 ? 2.8 : 2.5,
      spacing: 12,
      children: [
        DesktopStatCard(
          label: l10n.userProfilePostsStatLabel,
          value: _formatCount(user!.postsCount),
          icon: Icons.article_outlined,
        ),
        DesktopStatCard(
          label: l10n.userProfileFollowersStatLabel,
          value: _formatCount(user!.followersCount),
          icon: Icons.people_outline,
          onTap: () async {
            try {
              await _loadUserStats(forceRefresh: true);
            } catch (_) {}
            if (!mounted) return;
            ProfileScreenMethods.showFollowers(context, walletAddress: user!.id);
          },
        ),
        DesktopStatCard(
          label: l10n.userProfileFollowingStatLabel,
          value: _formatCount(user!.followingCount),
          icon: Icons.person_add_outlined,
          onTap: () async {
            try {
              await _loadUserStats(forceRefresh: true);
            } catch (_) {}
            if (!mounted) return;
            ProfileScreenMethods.showFollowing(context, walletAddress: user!.id);
          },
        ),
        DesktopStatCard(
          label: l10n.userProfileAchievementsTitle,
          value: (user!.achievementProgress.where((p) => p.isCompleted).length).toString(),
          icon: Icons.emoji_events_outlined,
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeProvider themeProvider, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(parent: _followButtonController, curve: Curves.easeInOut),
            ),
            child: DesktopActionButton(
              label: user!.isFollowing ? l10n.userProfileFollowingButton : l10n.userProfileFollowButton,
              icon: user!.isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined,
              onPressed: _toggleFollow,
              isPrimary: !user!.isFollowing,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DesktopActionButton(
            label: l10n.userProfileMessageButtonLabel,
            icon: Icons.mail_outlined,
            onPressed: _openConversation,
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildArtistPortfolioSection(ThemeProvider themeProvider, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileArtistPortfolioTitle,
          subtitle: l10n.userProfileArtistPortfolioDesktopSubtitle,
          icon: Icons.palette,
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
        else if (_artistArtworks.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.image_outlined,
              title: l10n.userProfileNoCreatorContentTitle,
              description: l10n.userProfileNoArtistContentDescription,
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistArtworks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildArtworkShowcaseCard(_artistArtworks[index], l10n),
            ),
          ),
      ],
    );
  }

  Widget _buildArtistCollectionsSection(ThemeProvider themeProvider, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileCollectionFallbackTitle,
          subtitle: 'Curated sets of work',
          icon: Icons.collections_outlined,
        ),
        const SizedBox(height: 16),
        if (_artistDataLoading && !_artistDataLoaded)
          DesktopCard(
            child: Container(
              height: 180,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          )
        else if (_artistCollections.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.collections_outlined,
              title: 'No collections yet',
              description: 'This creator hasn\'t created any collections.',
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistCollections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildCollectionShowcaseCard(_artistCollections[index], l10n),
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionHighlightsSection(ThemeProvider themeProvider, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileInstitutionHighlightsTitle,
          subtitle: l10n.userProfileInstitutionHighlightsDesktopSubtitle,
          icon: Icons.museum,
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
              icon: Icons.museum_outlined,
              title: l10n.userProfileNoCreatorContentTitle,
              description: l10n.userProfileNoInstitutionContentDescription,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_artistArtworks.isNotEmpty) ...[
                Text(
                  'Featured Works',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _artistArtworks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) => _buildArtworkShowcaseCard(_artistArtworks[index], l10n),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_artistCollections.isNotEmpty) ...[
                Text(
                  'Collections',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _artistCollections.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) => _buildCollectionShowcaseCard(_artistCollections[index], l10n),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildArtworkShowcaseCard(Map<String, dynamic> data, AppLocalizations l10n) {
    final imageUrl = _extractImageUrl(data, ['imageUrl', 'image', 'previewUrl', 'coverImage', 'mediaUrl']);
    final title = (data['title'] ?? data['name'] ?? l10n.commonUntitled).toString();
    final category = (data['category'] ?? data['medium'] ?? l10n.commonArtwork).toString();
    final artworkId = (data['id'] ?? data['artwork_id'] ?? data['artworkId'])?.toString();
    final likesCount = data['likesCount'] ?? data['likes'] ?? 0;
    
    return GestureDetector(
      onTap: artworkId != null ? () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DesktopArtworkDetailScreen(artworkId: artworkId, showAppBar: true)),
        );
      } : null,
      child: MouseRegion(
        cursor: artworkId != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: SizedBox(
          width: 220,
          child: DesktopCard(
            padding: EdgeInsets.zero,
            enableHover: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: imageUrl != null
                      ? Image.network(
                          _normalizeMediaUrl(imageUrl) ?? '',
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(160, Icons.image_outlined),
                        )
                      : _buildPlaceholderImage(160, Icons.image_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likesCount',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionShowcaseCard(Map<String, dynamic> data, AppLocalizations l10n) {
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
    final description = (data['description'] ?? '').toString();
    final collectionId =
        (data['id'] ?? data['collection_id'] ?? data['collectionId'])?.toString();
    
    return SizedBox(
      width: 200,
      child: DesktopCard(
        padding: EdgeInsets.zero,
        enableHover: true,
        onTap: (collectionId != null && collectionId.isNotEmpty)
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CollectionDetailScreen(collectionId: collectionId),
                  ),
                );
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: imageUrl != null
                  ? Image.network(
                      _normalizeMediaUrl(imageUrl) ?? '',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(120, Icons.collections_outlined),
                    )
                  : _buildPlaceholderImage(120, Icons.collections_outlined),
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
                    l10n.userProfileArtworksCountLabel(count as int),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(double height, IconData icon) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Center(child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.4))),
    );
  }

  Widget _buildAchievementsSection(ThemeProvider themeProvider, AppLocalizations l10n) {
    final progress = user?.achievementProgress ?? [];
    final achievementsToShow = allAchievements.take(6).toList();
    if (achievementsToShow.isEmpty) return const SizedBox.shrink();

    final completedCount = progress.where((p) => p.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileAchievementsTitle,
          subtitle: l10n.userProfileAchievementsProgressLabel(completedCount, allAchievements.length),
          icon: Icons.emoji_events_outlined,
        ),
        const SizedBox(height: 16),
        if (progress.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              title: l10n.userProfileAchievementsEmptyTitle(user!.name),
              description: l10n.userProfileAchievementsEmptyDescription,
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
    final l10n = AppLocalizations.of(context)!;
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
            isCompleted ? l10n.userProfileAchievementCompletedLabel : '${progress.currentProgress}/$requiredProgress',
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

  Widget _buildPostsSection(ThemeProvider themeProvider, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfilePostsTitle,
          subtitle: l10n.userProfileRecentActivitySubtitle(user!.name),
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
              title: l10n.userProfilePostsLoadFailedTitle,
              description: _postsError!,
              showAction: true,
              actionLabel: l10n.commonRetry,
              onAction: _loadPosts,
            ),
          )
        else if (_posts.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              title: l10n.userProfileNoPostsTitle,
              description: l10n.userProfileNoPostsDescription(user!.name),
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
                    l10n.userProfileNoMorePostsLabel,
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
                        _formatPostTime(AppLocalizations.of(context)!, post.timestamp),
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
        _postsError = l10n.userProfilePostsLoadMoreFailedDescription;
        if (_currentPage > 1) _currentPage -= 1;
      });
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
        debugPrint('DesktopUserProfileScreen._loadUserStats: $e');
      }
    }
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
      debugPrint('Failed to toggle follow: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('401')
                ? l10n.userProfileSignInToFollowToast
                : l10n.userProfileFollowUpdateFailedToast,
          ),
          backgroundColor: theme.colorScheme.error,
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newFollowState
                ? l10n.userProfileNowFollowingToast(user!.name)
                : l10n.userProfileUnfollowedToast(user!.name),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      try {
        context.read<AppRefreshProvider>().triggerCommunity();
        context.read<AppRefreshProvider>().triggerProfile();
      } catch (_) {}
    }

    await _loadUserStats(forceRefresh: true);
    try {
      if (user != null) UserService.setUsersInCache([user!]);
    } catch (_) {}
  }

  Future<void> _openConversation() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final chatAuth = chatProvider.isAuthenticated;
    final l10n = AppLocalizations.of(context)!;

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
                    ? l10n.userProfileConversationOpenFailedToast
                    : l10n.userProfileMessageLoginRequiredToast,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('DesktopUserProfileScreen: failed to open conversation: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.userProfileConversationOpenGenericErrorToast)));
    }
  }

  void _showMoreOptions() {
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(l10n.userProfileMoreOptionsBlockUser),
              onTap: () {
                Navigator.pop(context);
                _confirmBlockUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: Text(l10n.userProfileMoreOptionsReportUser),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.userProfileMoreOptionsCopyLink),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.userProfileLinkCopiedToast),
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
    final l10n = AppLocalizations.of(context)!;
    final targetWallet = WalletUtils.canonical(user?.id ?? widget.userId);
    if (targetWallet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userProfileUnableToBlockToast)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.userProfileBlockDialogTitle(user?.name ?? targetWallet),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.userProfileBlockDialogDescription,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await BlockListService().blockWallet(targetWallet);
              } catch (e) {
                debugPrint('DesktopUserProfileScreen: failed to block user: $e');
                if (!mounted) return;
                Navigator.pop(context);
                messenger.showSnackBar(SnackBar(content: Text(l10n.userProfileBlockFailedToast)));
                return;
              }

              if (!mounted) return;
              Navigator.pop(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.userProfileBlockedToast(user?.name ?? targetWallet)),
                  action: SnackBarAction(
                    label: l10n.commonUndo,
                    onPressed: () => BlockListService().unblockWallet(targetWallet),
                  ),
                ),
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
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.userProfileReportDialogTitle(user?.name ?? ''),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.userProfileReportReasonSpam),
              onTap: () => _submitReport(l10n),
            ),
            ListTile(
              title: Text(l10n.userProfileReportReasonInappropriate),
              onTap: () => _submitReport(l10n),
            ),
            ListTile(
              title: Text(l10n.userProfileReportReasonHarassment),
              onTap: () => _submitReport(l10n),
            ),
            ListTile(
              title: Text(l10n.userProfileReportReasonOther),
              onTap: () => _submitReport(l10n),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport(AppLocalizations l10n) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.userProfileReportSubmittedToast)),
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

  String _formatPostTime(AppLocalizations l10n, DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 7) return l10n.commonWeeksAgo((diff.inDays / 7).floor());
    if (diff.inDays > 0) return l10n.commonDaysAgo(diff.inDays);
    if (diff.inHours > 0) return l10n.commonHoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return l10n.commonMinutesAgo(diff.inMinutes);
    return l10n.commonJustNow;
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
