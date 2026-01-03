import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/category_accent_color.dart';
import '../../../utils/wallet_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../community/community_interactions.dart';
import '../../web3/achievements/achievements_page.dart';
import '../desktop_settings_screen.dart';
import '../../community/post_detail_screen.dart';
import '../../../models/achievements.dart';
import 'desktop_profile_edit_screen.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/user_activity_status_line.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/profile_artist_info_fields.dart';
import '../../../widgets/detail/detail_shell_components.dart';
import '../../community/profile_screen_methods.dart';
import '../../../widgets/artist_badge.dart';
import '../../../widgets/institution_badge.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../components/desktop_widgets.dart';
import '../art/desktop_artwork_detail_screen.dart';
import '../../art/collection_detail_screen.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../activity/view_history_screen.dart';
import '../../events/event_detail_screen.dart';

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
  bool _profilePrefsListenerAttached = false;

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
    if (!_profilePrefsListenerAttached) {
      profileProvider.addListener(_handleProfilePreferencesChanged);
      _profilePrefsListenerAttached = true;
    }
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
    if (_profilePrefsListenerAttached) {
      Provider.of<ProfileProvider>(context, listen: false)
          .removeListener(_handleProfilePreferencesChanged);
      _profilePrefsListenerAttached = false;
    }
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
    final isWide = screenWidth >= 1400;

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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: DetailSpacing.xl),
                        _buildHeader(themeProvider),
                        const SizedBox(height: DetailSpacing.xl),
                        // Profile card with inline stats on wide screens
                        _buildProfileCard(themeProvider, profileProvider, isArtist, isInstitution),
                        const SizedBox(height: DetailSpacing.lg),
                        _buildStatsCards(themeProvider, profileProvider, isLarge),
                        const SizedBox(height: DetailSpacing.xl),
                        // Two-column layout for wide screens
                        if (isWide)
                          _buildTwoColumnLayout(
                            themeProvider: themeProvider,
                            isArtist: isArtist,
                            isInstitution: isInstitution,
                          )
                        else
                          _buildSingleColumnContent(
                            themeProvider: themeProvider,
                            isArtist: isArtist,
                            isInstitution: isInstitution,
                          ),
                        const SizedBox(height: DetailSpacing.xl),
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Performance + Achievements (narrower)
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPerformanceStatsSection(themeProvider),
              const SizedBox(height: DetailSpacing.lg),
              _buildAchievementsSection(themeProvider),
            ],
          ),
        ),
        const SizedBox(width: DetailSpacing.xl),
        // Right column: Content sections + Posts (wider)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isArtist) ...[
                _buildArtistPortfolioSection(themeProvider),
                const SizedBox(height: DetailSpacing.lg),
                _buildArtistCollectionsSection(themeProvider),
                const SizedBox(height: DetailSpacing.lg),
                _buildArtistEventsSection(themeProvider),
                const SizedBox(height: DetailSpacing.lg),
              ] else if (isInstitution) ...[
                _buildInstitutionEventsSection(themeProvider),
                const SizedBox(height: DetailSpacing.lg),
                _buildInstitutionCollectionsSection(themeProvider),
                const SizedBox(height: DetailSpacing.lg),
              ] else ...[
                _buildViewedArtworksSection(themeProvider),
                const SizedBox(height: DetailSpacing.lg),
              ],
              _buildPostsSection(themeProvider),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isArtist) ...[
          _buildArtistPortfolioSection(themeProvider),
          const SizedBox(height: DetailSpacing.lg),
          _buildArtistCollectionsSection(themeProvider),
          const SizedBox(height: DetailSpacing.lg),
          _buildArtistEventsSection(themeProvider),
          const SizedBox(height: DetailSpacing.lg),
        ] else if (isInstitution) ...[
          _buildInstitutionEventsSection(themeProvider),
          const SizedBox(height: DetailSpacing.lg),
          _buildInstitutionCollectionsSection(themeProvider),
          const SizedBox(height: DetailSpacing.lg),
        ],
        if (!isArtist && !isInstitution) ...[
          _buildViewedArtworksSection(themeProvider),
          const SizedBox(height: DetailSpacing.lg),
        ],
        _buildPerformanceStatsSection(themeProvider),
        const SizedBox(height: DetailSpacing.lg),
        _buildAchievementsSection(themeProvider),
        const SizedBox(height: DetailSpacing.lg),
        _buildPostsSection(themeProvider),
      ],
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
              label: 'Invites',
              icon: Icons.inbox_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvitesInboxScreen()),
                );
              },
              isPrimary: false,
            ),
            const SizedBox(width: 12),
            DesktopActionButton(
              label: 'Settings',
              icon: Icons.settings_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DesktopSettingsScreen()),
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
    const avatarRadius = 44.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth >= 1200;

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
                  height: hasCoverImage ? 140 : 80,
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
                          coverImageUrl,
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
            ],
          ),
          // Compact horizontal layout for profile info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AvatarWidget(
                    wallet: user?.walletAddress ?? '',
                    avatarUrl: user?.avatar,
                    radius: avatarRadius,
                    enableProfileNavigation: false,
                    showStatusIndicator: _showActivityStatus,
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
                              user?.displayName ?? user?.username ?? 'Art Enthusiast',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 22 : 20,
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
                      const SizedBox(height: 6),
                      UserActivityStatusLine(
                        walletAddress: user?.walletAddress ?? '',
                        textAlign: TextAlign.start,
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
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
                      const SizedBox(height: 12),
                      ProfileArtistInfoFields(
                        fieldOfWork: user?.artistInfo?.specialty ?? const <String>[],
                        yearsActive: user?.artistInfo?.yearsActive ?? 0,
                        textAlign: TextAlign.left,
                      ),
                      // Social links
                      if (user?.social.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _buildSocialLinks(user!.social, themeProvider),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: Text(AppLocalizations.of(context)!.settingsEditProfileTileTitle),
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
    final screenWidth = MediaQuery.of(context).size.width;
    // More columns on wider screens for compact horizontal layout
    final maxCols = screenWidth >= 1400 ? 4 : (isLarge ? 4 : 2);

    return DesktopGrid(
      minCrossAxisCount: 2,
      maxCrossAxisCount: maxCols,
      childAspectRatio: screenWidth >= 1400 ? 2.8 : 2.5,
      spacing: 12,
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

  Widget _buildArtistPortfolioSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Portfolio',
          subtitle: 'Your artworks and creative works',
          icon: Icons.palette,
          action: _artistArtworks.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => ProfileScreenMethods.showArtworks(context),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(AppLocalizations.of(context)!.commonViewAll),
                )
              : null,
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
              title: 'No artworks yet',
              description: 'Upload your first artwork to showcase your creative work here.',
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistArtworks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildArtworkShowcaseCard(_artistArtworks[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildArtistCollectionsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Collections',
          subtitle: 'Curated sets of your work',
          icon: Icons.collections_outlined,
          action: _artistCollections.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => ProfileScreenMethods.showCollections(context),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(AppLocalizations.of(context)!.commonViewAll),
                )
              : null,
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
              description: 'Create collections to organize and curate your work.',
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistCollections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildCollectionShowcaseCard(_artistCollections[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildArtistEventsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Events & Exhibitions',
          subtitle: 'Your upcoming and past events',
          icon: Icons.event,
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
        else if (_artistEvents.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.event_outlined,
              title: 'No events yet',
              description: 'Plan exhibitions, workshops, or meetups to engage with collectors.',
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistEvents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildEventShowcaseCard(_artistEvents[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionEventsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Exhibitions & Programs',
          subtitle: 'Your featured exhibitions and events',
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
        else if (_artistEvents.isEmpty)
          DesktopCard(
            child: EmptyStateCard(
              icon: Icons.museum_outlined,
              title: 'No exhibitions yet',
              description: 'Create exhibitions and programs to showcase your institutional activities.',
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistEvents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildEventShowcaseCard(_artistEvents[index], isInstitution: true),
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionCollectionsSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Permanent Collection',
          subtitle: 'Featured works in your collection',
          icon: Icons.account_balance,
          action: _artistCollections.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => ProfileScreenMethods.showCollections(context),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(AppLocalizations.of(context)!.commonViewAll),
                )
              : null,
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
              description: 'Curate collections to highlight your institutional holdings.',
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistCollections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildCollectionShowcaseCard(_artistCollections[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildViewedArtworksSection(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final viewHistory = artworkProvider.viewHistoryEntries.take(10).toList();
        
        // Build list of artworks from view history
        final viewedArtworks = <Map<String, dynamic>>[];
        for (final entry in viewHistory) {
          final artwork = artworkProvider.getArtworkById(entry.artworkId);
          if (artwork != null) {
            viewedArtworks.add({
              'id': artwork.id,
              'title': artwork.title,
              'imageUrl': artwork.imageUrl,
              'artist': artwork.artist,
              'category': artwork.category,
            });
          }
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: 'Recently Viewed',
              subtitle: 'Artworks you\'ve discovered',
              icon: Icons.history,
              action: viewHistory.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ViewHistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('View History'),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            if (viewedArtworks.isEmpty)
              DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.visibility_outlined,
                  title: 'No viewed artworks yet',
                  description: 'Explore the map to discover artworks and build your viewing history.',
                ),
              )
            else
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: viewedArtworks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final artwork = viewedArtworks[index];
                    return _buildShowcaseCard(
                      imageUrl: artwork['imageUrl']?.toString(),
                      title: artwork['title']?.toString() ?? 'Untitled',
                      subtitle: artwork['artist']?.toString() ?? 'Unknown artist',
                      artworkId: artwork['id']?.toString(),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceStatsSection(ThemeProvider themeProvider) {
    return Consumer3<ProfileProvider, ArtworkProvider, StatsProvider>(
      builder: (context, profileProvider, artworkProvider, statsProvider, _) {
        final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
        final stats = profileProvider.currentUser?.stats;
        final viewHistory = artworkProvider.viewHistoryEntries;
        final viewedCount = viewHistory.length;

        const publicMetrics = <String>['artworks', 'nftsMinted'];
        const privateMetrics = <String>['artworksDiscovered'];

        if (wallet.isNotEmpty) {
          statsProvider.ensureSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: publicMetrics,
            scope: 'public',
          );
          statsProvider.ensureSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: privateMetrics,
            scope: 'private',
          );
        }

        final publicSnapshot = wallet.isEmpty
            ? null
            : statsProvider.getSnapshot(
                entityType: 'user',
                entityId: wallet,
                metrics: publicMetrics,
                scope: 'public',
              );
        final privateSnapshot = wallet.isEmpty
            ? null
            : statsProvider.getSnapshot(
                entityType: 'user',
                entityId: wallet,
                metrics: privateMetrics,
                scope: 'private',
              );

        final publicCounters = publicSnapshot?.counters ?? const <String, int>{};
        final privateCounters = privateSnapshot?.counters ?? const <String, int>{};

        final publicLoading = wallet.isNotEmpty &&
            statsProvider.isSnapshotLoading(
              entityType: 'user',
              entityId: wallet,
              metrics: publicMetrics,
              scope: 'public',
            ) &&
            publicSnapshot == null;
        final privateLoading = wallet.isNotEmpty &&
            statsProvider.isSnapshotLoading(
              entityType: 'user',
              entityId: wallet,
              metrics: privateMetrics,
              scope: 'private',
            ) &&
            privateSnapshot == null;

        final discoveriesValue = privateCounters['artworksDiscovered'] ?? stats?.artworksDiscovered;
        final createdValue = publicCounters['artworks'] ?? stats?.artworksCreated;
        final nftsOwnedValue = publicCounters['nftsMinted'] ?? stats?.nftsOwned;

        final discoveriesLabel = privateLoading
            ? '\u2026'
            : discoveriesValue == null
                ? '\u2014'
                : _formatStatCount(discoveriesValue);
        final createdLabel = publicLoading
            ? '\u2026'
            : createdValue == null
                ? '\u2014'
                : _formatStatCount(createdValue);
        final nftsLabel = publicLoading
            ? '\u2026'
            : nftsOwnedValue == null
                ? '\u2014'
                : _formatStatCount(nftsOwnedValue);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: 'Performance',
              subtitle: 'Your activity and engagement metrics',
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: 16),
            DesktopGrid(
              minCrossAxisCount: 2,
              maxCrossAxisCount: 4,
              childAspectRatio: 2.0,
              children: [
                _buildPerformanceStatCard(
                  'Artworks Viewed',
                  _formatStatCount(viewedCount),
                  Icons.visibility_outlined,
                  themeProvider,
                ),
                _buildPerformanceStatCard(
                  'Discoveries',
                  discoveriesLabel,
                  Icons.explore_outlined,
                  themeProvider,
                ),
                _buildPerformanceStatCard(
                  'Created',
                  createdLabel,
                  Icons.create_outlined,
                  themeProvider,
                ),
                _buildPerformanceStatCard(
                  'NFTs Owned',
                  nftsLabel,
                  Icons.token_outlined,
                  themeProvider,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceStatCard(String label, String value, IconData icon, ThemeProvider themeProvider) {
    return DesktopCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: themeProvider.accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
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
    );
  }

  Widget _buildArtworkShowcaseCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, ['imageUrl', 'image', 'previewUrl', 'coverImage', 'mediaUrl']);
    final title = (data['title'] ?? data['name'] ?? 'Untitled').toString();
    final category = (data['category'] ?? data['medium'] ?? 'Artwork').toString();
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

  Widget _buildCollectionShowcaseCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, [
      'thumbnailUrl',
      'coverImage',
      'coverImageUrl',
      'cover_image_url',
      'coverUrl',
      'cover_url',
      'image',
    ]);
    final title = (data['name'] ?? 'Collection').toString();
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
                    '$count artworks',
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

  Widget _buildEventShowcaseCard(Map<String, dynamic> data, {bool isInstitution = false}) {
    final imageUrl = _extractImageUrl(data, [
      'coverUrl',
      'cover_url',
      'bannerUrl',
      'banner_url',
      'image',
    ]);
    final title = (data['title'] ?? 'Event').toString();
    final location = (data['locationName'] ?? data['location'] ?? 'TBA').toString();
    final startDate = data['startsAt'] ?? data['startDate'] ?? data['start_date'];
    final dateLabel = _formatEventDate(startDate);
    final eventId = (data['id'] ?? data['event_id'] ?? data['eventId'])?.toString();
    
    return SizedBox(
      width: isInstitution ? 260 : 220,
      child: DesktopCard(
        padding: EdgeInsets.zero,
        enableHover: true,
        onTap: (eventId != null && eventId.isNotEmpty)
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(eventId: eventId),
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
                      height: isInstitution ? 140 : 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(isInstitution ? 140 : 120, Icons.event),
                    )
                  : _buildPlaceholderImage(isInstitution ? 140 : 120, Icons.event),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildShowcaseCard({String? imageUrl, required String title, required String subtitle, String? artworkId}) {
    return GestureDetector(
      onTap: artworkId != null ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DesktopArtworkDetailScreen(artworkId: artworkId, showAppBar: true),
          ),
        );
      } : null,
      child: SizedBox(
        width: 200,
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
                label: Text(AppLocalizations.of(context)!.commonViewAll),
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
        // Refresh artist data after profile edit
        setState(() {
          _artistDataRequested = false;
          _artistDataLoaded = false;
        });
        await _maybeLoadArtistData(force: true);
      }
    }
  }

  void _handleProfilePreferencesChanged() {
    if (!mounted) return;
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final nextShowStatus = profileProvider.preferences.showActivityStatus;
    if (nextShowStatus != _showActivityStatus) {
      setState(() => _showActivityStatus = nextShowStatus);
    }
  }

  void _shareProfile() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;
    ShareService().showShareSheet(
      context,
      target: ShareTarget.profile(
        walletAddress: wallet,
        title: profileProvider.currentUser?.displayName ?? profileProvider.currentUser?.username,
      ),
      sourceScreen: 'desktop_profile',
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
    return MediaUrlResolver.resolve(url);
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

  String _formatStatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatEventDate(dynamic dateValue) {
    if (dateValue == null) return 'TBA';
    try {
      DateTime date;
      if (dateValue is DateTime) {
        date = dateValue;
      } else {
        date = DateTime.parse(dateValue.toString());
      }
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'TBA';
    }
  }

  Widget _buildSocialLinks(Map<String, String> social, ThemeProvider themeProvider) {
    final links = <Widget>[];
    
    if (social['twitter']?.isNotEmpty == true) {
      links.add(_buildSocialChip(
        icon: Icons.alternate_email,
        label: '@${social['twitter']}',
        color: const Color(0xFF1DA1F2),
      ));
    }
    if (social['instagram']?.isNotEmpty == true) {
      links.add(_buildSocialChip(
        icon: Icons.camera_alt_outlined,
        label: '@${social['instagram']}',
        color: const Color(0xFFE4405F),
      ));
    }
    if (social['website']?.isNotEmpty == true) {
      final website = social['website']!;
      final displayUrl = website.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');
      links.add(_buildSocialChip(
        icon: Icons.language,
        label: displayUrl,
        color: themeProvider.accentColor,
      ));
    }
    
    if (links.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links,
    );
  }

  Widget _buildSocialChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
