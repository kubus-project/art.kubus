import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../utils/wallet_utils.dart';
import '../../utils/kubus_color_roles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/themeprovider.dart';
import '../../providers/web3provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/media_url_resolver.dart';
import '../../community/community_interactions.dart';
import '../web3/wallet/wallet_home.dart';
import '../web3/achievements/achievements_page.dart';
import '../settings_screen.dart';
import '../activity/saved_items_screen.dart';
import 'profile_screen_methods.dart';
import '../activity/view_history_screen.dart';
import '../collab/invites_inbox_screen.dart';
import '../../models/achievements.dart';
import 'profile_edit_screen.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/user_activity_status_line.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/empty_state_card.dart';
import 'post_detail_screen.dart';
import '../art/art_detail_screen.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';
import '../../models/dao.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Future<List<CommunityPost>>? _postsFuture;
  bool _didScheduleDataFetch = false;
  bool _artistDataRequested = false;
  bool _artistDataLoading = false;
  bool _artistDataLoaded = false;
  List<Map<String, dynamic>> _artistArtworks = [];
  List<Map<String, dynamic>> _artistCollections = [];
  List<Map<String, dynamic>> _artistEvents = [];
  bool _profilePrefsListenerAttached = false;
  String? _failedCoverImageUrl;
  
  // Privacy settings state
  bool _showActivityStatus = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
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
      // Trigger a background refresh of aggregated stats (followers/following/posts)
      // so the counts on the profile header update shortly after open.
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: themeProvider.accentColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _buildProfileHeader(isArtist: isArtist, isInstitution: isInstitution),
                      SliverToBoxAdapter(child: SizedBox(height: 24)),
                      _buildStatsSection(),
                      SliverToBoxAdapter(child: SizedBox(height: 28)),
                      if (isArtist) ...[
                        SliverToBoxAdapter(child: _buildArtistHighlightsGrid()),
                        SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                      SliverToBoxAdapter(
                        child: isInstitution
                            ? _buildInstitutionHighlightsSection()
                            : _buildAchievementsSection(),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: _buildPerformanceStats()),
                      SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: _buildPostsSection()),
                      if (isArtist) ...[
                        SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverToBoxAdapter(child: _buildArtistEventsShowcase()),
                      ],
                      SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader({required bool isArtist, required bool isInstitution}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 375;
          bool isVerySmallScreen = constraints.maxWidth < 320;
          
          final coverImageUrl = _normalizeMediaUrl(profileProvider.currentUser?.coverImage);
          final coverUrlIsKnownBad = coverImageUrl != null && coverImageUrl == _failedCoverImageUrl;
          final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty && !coverUrlIsKnownBad;
          final coverHeight = hasCoverImage ? 160.0 : 100.0;
          final dpr = MediaQuery.of(context).devicePixelRatio;
          final cacheWidth = (constraints.maxWidth * dpr).round();
          final cacheHeight = (coverHeight * dpr).round();
          
          return Column(
            children: [
              // Cover Image Section
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover image or gradient background
                  SizedBox(
                    width: double.infinity,
                    height: coverHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Base background (always present)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
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
                        ),

                        // Cover image layer (explicit Image widget so we can downscale/catch errors)
                        if (hasCoverImage)
                          Image.network(
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
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: const SizedBox.expand(),
                              );
                            },
                          ),

                        // Gradient overlay for better text readability
                        if (hasCoverImage)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Top bar with title and actions
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Profile',
                                    style: GoogleFonts.inter(
                                      fontSize: isVerySmallScreen ? 24 : isSmallScreen ? 26 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: hasCoverImage
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface,
                                      shadows: hasCoverImage
                                          ? [
                                              Shadow(
                                                offset: const Offset(0, 1),
                                                blurRadius: 3,
                                                color: Colors.black.withValues(alpha: 0.5),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TopBarIcon(
                                      icon: Icon(
                                        Icons.share_outlined,
                                        color: hasCoverImage
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        size: isSmallScreen ? 22 : 24,
                                      ),
                                      onPressed: () => _shareProfile(),
                                      tooltip: 'Share',
                                    ),
                                    const SizedBox(width: 8),
                                    TopBarIcon(
                                      icon: Icon(
                                        Icons.inbox_outlined,
                                        color: hasCoverImage
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        size: isSmallScreen ? 22 : 24,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const InvitesInboxScreen()),
                                        );
                                      },
                                      tooltip: 'Invites',
                                    ),
                                    const SizedBox(width: 8),
                                    TopBarIcon(
                                      icon: Icon(
                                        Icons.settings_outlined,
                                        color: hasCoverImage
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        size: isSmallScreen ? 22 : 24,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                        );
                                      },
                                      tooltip: 'Settings',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar positioned at bottom of cover, overlapping
                  Positioned(
                    bottom: -(isVerySmallScreen ? 40.0 : isSmallScreen ? 45.0 : 50.0),
                    left: 0,
                    right: 0,
                    child: Center(
                        child: AvatarWidget(
                          wallet: profileProvider.currentUser?.walletAddress ?? '',
                          avatarUrl: profileProvider.currentUser?.avatar,
                          radius: isVerySmallScreen ? 40 : isSmallScreen ? 45 : 50,
                          enableProfileNavigation: false,
                          showStatusIndicator: _showActivityStatus,
                        ),
                    ),
                  ),
                ],
              ),
              // Spacing for avatar overflow
              SizedBox(height: isVerySmallScreen ? 48 : isSmallScreen ? 53 : 58),
              // Rest of profile content
              Container(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
                child: Column(
                  children: [
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          profileProvider.currentUser?.displayName ?? profileProvider.currentUser?.username ?? 'Art Enthusiast',
                          style: GoogleFonts.inter(
                            fontSize: isVerySmallScreen ? 20 : isSmallScreen ? 22 : 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isArtist) ...[
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        const ArtistBadge(),
                      ],
                      if (isInstitution) ...[
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        const InstitutionBadge(),
                      ],
                    ],
                  ),
                ),
                if (profileProvider.currentUser?.username != null && profileProvider.currentUser?.displayName != null) ...[  
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  Text(
                    '@${profileProvider.currentUser!.username}',
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 6),
                UserActivityStatusLine(
                  walletAddress: profileProvider.currentUser?.walletAddress ?? '',
                  textAlign: TextAlign.center,
                  textStyle: GoogleFonts.inter(
                    fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 13 : 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                if (web3Provider.isConnected) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16, 
                      vertical: isSmallScreen ? 6 : 8
                    ),
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeProvider.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      web3Provider.formatAddress(web3Provider.walletAddress),
                      style: GoogleFonts.robotoMono(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.accentColor,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Connect wallet to see profile',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: isSmallScreen ? 12 : 16),
                if (profileProvider.currentUser?.bio != null && profileProvider.currentUser!.bio.isNotEmpty)
                  Text(
                    profileProvider.currentUser!.bio,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: isSmallScreen ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Center(
                    child: EmptyStateCard(
                      icon: Icons.person_outline,
                      title: 'No bio yet',
                      description: 'Tap "Edit Profile" to add a short bio about yourself.',
                      showAction: true,
                      actionLabel:
                          AppLocalizations.of(context)!.settingsEditProfileTileTitle,
                      onAction: _editProfile,
                    ),
                  ),
                SizedBox(height: isSmallScreen ? 20 : 24),
                isSmallScreen 
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _editProfile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 14 : 16),
                              elevation: 2,
                              shadowColor: themeProvider.accentColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.settingsEditProfileTileTitle,
                              style: GoogleFonts.inter(
                                fontSize: isVerySmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.accentColor,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () {
                              _showMoreOptions();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 14 : 16),
                            ),
                            child: Text(
                              'More Options',
                              style: GoogleFonts.inter(
                                fontSize: isVerySmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.accentColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _editProfile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                              shadowColor: themeProvider.accentColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.settingsEditProfileTileTitle,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.accentColor,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              _showMoreOptions();
                            },
                            icon: Icon(
                              Icons.more_horiz,
                              color: themeProvider.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final profileProvider = Provider.of<ProfileProvider>(context);
          final isSmallScreen = constraints.maxWidth < 360;
          final walletAddress = profileProvider.currentUser?.walletAddress;
          
          return Container(
            margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
            padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildInlineStat(
                      label: 'Posts',
                      value: profileProvider.formattedPostsCount,
                      isCompact: isSmallScreen,
                    ),
                    _buildInlineStat(
                      label: 'Followers',
                      value: profileProvider.formattedFollowersCount,
                      isCompact: isSmallScreen,
                      onTap: () => ProfileScreenMethods.showFollowers(
                        context,
                        walletAddress: walletAddress,
                      ),
                    ),
                    _buildInlineStat(
                      label: 'Following',
                      value: profileProvider.formattedFollowingCount,
                      isCompact: isSmallScreen,
                      onTap: () => ProfileScreenMethods.showFollowing(
                        context,
                        walletAddress: walletAddress,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Artworks',
                        profileProvider.formattedArtworksCount,
                        Icons.palette,
                        isSmallScreen: isSmallScreen,
                        onTap: () => ProfileScreenMethods.showArtworks(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Collections',
                        profileProvider.formattedCollectionsCount,
                        Icons.collections,
                        isSmallScreen: isSmallScreen,
                        onTap: () => ProfileScreenMethods.showCollections(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {bool isSmallScreen = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: isSmallScreen ? 16 : 18,
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 7 : 8,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineStat({
    required String label,
    required String value,
    bool isCompact = false,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isCompact ? 12 : 13,
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: content,
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final daoProvider = Provider.of<DAOProvider>(context, listen: false);
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
        await daoProvider.loadReviewForWallet(wallet, forceRefresh: true);
      } catch (e) {
        debugPrint('ProfileScreen: DAO review refresh failed: $e');
      }
      try {
        await profileProvider.loadProfile(wallet);
      } catch (e) {
        debugPrint('ProfileScreen: profile reload failed: $e');
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

  Future<String?> _resolveCurrentWallet() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress;
    if (wallet != null && wallet.isNotEmpty) {
      return wallet;
    }
    final prefs = await SharedPreferences.getInstance();
    final storedWallet = prefs.getString('wallet_address');
    if (storedWallet != null && storedWallet.isNotEmpty) {
      return storedWallet;
    }
    return null;
  }

  Future<List<CommunityPost>> _loadUserPosts({String? walletOverride}) async {
    final wallet = walletOverride ?? await _resolveCurrentWallet();
    if (wallet == null || wallet.isEmpty) {
      return [];
    }
    try {
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        authorWallet: wallet,
      );
      await CommunityService.loadSavedInteractions(
        posts,
        walletAddress: wallet,
      );
      return posts;
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      rethrow;
    }
  }

  Widget _buildPostsSection() {
    final future = _postsFuture ?? _loadUserPosts();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<List<CommunityPost>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posts',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildErrorCard(
                  message: 'Could not load your posts.',
                  onRetry: () {
                    setState(() {
                      _postsFuture = _loadUserPosts();
                    });
                  },
                ),
              ],
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posts',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildEmptyStateCard(
                  title: 'No posts yet',
                  description: 'Share your perspective with the community to see it here.',
                  icon: Icons.article,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Posts',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildPostCard(posts[index]);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorCard({required String message, required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
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

  Widget _buildPostCard(CommunityPost post) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  wallet: post.authorId,
                  avatarUrl: post.authorAvatar,
                  radius: 18,
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
                      Text(
                        _formatRelativeTime(post.timestamp),
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
            const SizedBox(height: 12),
            Text(
              post.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: post.isLiked
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  post.likeCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: post.isLiked
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  post.commentCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
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

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress ?? '';
    if (wallet.isEmpty) {
      return;
    }
    DAOReview? review;
    try {
      review = Provider.of<DAOProvider>(context, listen: false).findReviewForWallet(wallet);
    } catch (_) {}
    final isArtist = _hasArtistRole(profileProvider, review);
    final isInstitution = _hasInstitutionRole(profileProvider, review);
    if (!(isArtist || isInstitution)) {
      return;
    }
    if (_artistDataLoading && !force) {
      return;
    }
    if (_artistDataRequested && !force) {
      return;
    }
    _artistDataRequested = true;
    await _loadArtistData(wallet, force: force);
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
      if (!mounted) return;
      setState(() {
        _artistDataLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _artistDataLoading = false;
        });
      }
    }
  }

  Widget _buildArtistEventsShowcase() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildShowcaseSection(
            title: 'Upcoming events',
            items: _artistEvents,
            emptyLabel: 'Plan an event or workshop to engage your audience.',
            builder: _buildEventCard,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistHighlightsGrid() {
    return Padding(
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
            'Keep your artworks and collections front and center.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Artworks',
            items: _artistArtworks,
            emptyLabel: 'Upload your first artwork to showcase it here.',
            builder: _buildArtworkCard,
          ),
          const SizedBox(height: 24),
          _buildShowcaseSection(
            title: 'Collections',
            items: _artistCollections,
            emptyLabel: 'Create a collection to curate your story.',
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionHighlightsSection() {
    return Padding(
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
            'Promote upcoming programs and featured collections.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: 'Events',
            items: _artistEvents,
            emptyLabel: 'Share your next exhibition or gathering here.',
            builder: _buildEventCard,
          ),
          const SizedBox(height: 24),
          _buildShowcaseSection(
            title: 'Collections',
            items: _artistCollections,
            emptyLabel: 'Curate institutional collections to highlight.',
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (_artistDataLoading && !_artistDataLoaded)
          Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: const CircularProgressIndicator(strokeWidth: 2),
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
    final imageUrl = _extractImageUrl(data, ['imageUrl', 'image', 'previewUrl', 'coverImage', 'mediaUrl']);
    final title = (data['title'] ?? data['name'] ?? 'Untitled').toString();
    final medium = (data['category'] ?? data['medium'] ?? 'Digital art').toString();
    final artworkId = (data['id'] ?? data['artwork_id'] ?? data['artworkId'])?.toString();
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: artworkId != null ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtDetailScreen(artworkId: artworkId),
          ),
        );
      } : null,
      child: _buildShowcaseCard(
        imageUrl: imageUrl,
        title: title,
        subtitle: medium,
        footer: '${data['likesCount'] ?? data['likes'] ?? 0} likes',
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, ['thumbnailUrl', 'coverImage', 'image']);
    final title = (data['name'] ?? 'New Collection').toString();
    final count = data['artworksCount'] ?? data['artworks_count'] ?? 0;
    return _buildShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: '$count artworks',
      footer: (data['description'] ?? 'Curated by you').toString(),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data) {
    final imageUrl = _extractImageUrl(data, ['bannerUrl', 'image']);
    final title = (data['title'] ?? 'Event').toString();
    final date = _formatDateLabel(data['startDate'] ?? data['start_date']);
    final location = (data['location'] ?? 'TBA').toString();
    return _buildShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: date,
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
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              child: const Center(child: Icon(Icons.image_not_supported)),
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
                const SizedBox(height: 8),
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

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }

  String _formatCount(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }


  Widget _buildAchievementsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Consumer2<TaskProvider, ConfigProvider>(
        builder: (context, taskProvider, configProvider, child) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final accent = themeProvider.accentColor;
        if (!configProvider.useMockData) {
          // Show real achievement data when mock data is disabled
          final achievements = taskProvider.achievementProgress;
          
          // Get the first 6 achievements to display
          final displayAchievements = allAchievements.take(6).toList();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent, width: 1),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.commonViewAll,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              achievements.isEmpty
                ? _buildEmptyStateCard(
                    title: 'No Achievements Yet',
                    description: 'Start exploring to unlock achievements',
                    icon: Icons.emoji_events,
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: displayAchievements.map((achievement) {
                      final progress = achievements.firstWhere(
                        (p) => p.achievementId == achievement.id,
                        orElse: () => AchievementProgress(
                          achievementId: achievement.id,
                          currentProgress: 0,
                          isCompleted: false,
                        ),
                      );
                      return _buildAchievementBadge(
                        achievement.title,
                        achievement.icon,
                        progress.isCompleted,
                      );
                    }).toList(),
                  ),
            ],
          );
        } else {
          // Show mock data when mock data is enabled
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent, width: 1),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.commonViewAll,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAchievementBadge('First AR Explorer', Icons.visibility, true),
                  _buildAchievementBadge('Gallery Explorer', Icons.explore, true),
                  _buildAchievementBadge('Art Curator', Icons.folder_special, true),
                  _buildAchievementBadge('Social Butterfly', Icons.share, false),
                  _buildAchievementBadge('AR Master', Icons.auto_awesome, false),
                  _buildAchievementBadge('Art Influencer', Icons.trending_up, false),
                ],
              ),
            ],
          );
        }
        },
      ),
    );
  }

  Widget _buildAchievementBadge(String title, IconData icon, bool unlocked) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? themeProvider.accentColor.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? themeProvider.accentColor.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: unlocked
                ? themeProvider.accentColor
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: unlocked
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Consumer2<ProfileProvider, ArtworkProvider>(
        builder: (context, profileProvider, artworkProvider, child) {
          final stats = profileProvider.currentUser?.stats;
          final viewHistory = artworkProvider.viewHistoryEntries;
          final viewedCount = viewHistory.length;
          final discoveries = stats?.artworksDiscovered ?? 0;
          final created = stats?.artworksCreated ?? 0;
          final followers = stats?.followersCount ?? profileProvider.followersCount;
          final following = stats?.followingCount ?? profileProvider.followingCount;
          final nftsOwned = stats?.nftsOwned ?? 0;

          final hasData = stats != null || viewedCount > 0;
          if (!hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildEmptyStateCard(
                  icon: Icons.analytics,
                  title: 'No Stats Yet',
                  description: 'Interact with artworks, collections, and community to see insights.',
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildPerformanceCard('Artworks viewed', _formatCount(viewedCount), Icons.visibility, null),
              const SizedBox(height: 12),
              _buildPerformanceCard('Discoveries', _formatCount(discoveries), Icons.location_on, null),
              const SizedBox(height: 12),
              _buildPerformanceCard('Created / Owned', '${_formatCount(created)} / ${_formatCount(nftsOwned)}', Icons.auto_fix_high, null),
              const SizedBox(height: 12),
              _buildPerformanceCard('Followers / Following', '${_formatCount(followers)} / ${_formatCount(following)}', Icons.group, null),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPerformanceCard(String title, String value, IconData icon, String? change) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (change != null)
            Builder(
              builder: (context) {
                final positiveColor = KubusColorRoles.of(context).positiveAction;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: positiveColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: positiveColor,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );

    // Make KUB8-related cards tappable to open wallet
    if (title.contains('KUB8')) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WalletHome()),
          );
        },
        child: cardContent,
      );
    }
    
    return cardContent;
  }

  // Navigation and interaction methods
  void _shareProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Share Profile',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.link, 'Copy Link'),
                _buildShareOption(Icons.qr_code, 'QR Code'),
                _buildShareOption(Icons.share, 'Social'),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() async {
    final navigator = Navigator.of(context);
    final result = await navigator.push(
      MaterialPageRoute(
        builder: (context) => const ProfileEditScreen(),
      ),
    );
    
    // Reload profile if changes were saved
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

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionItem(Icons.bookmark, 'Saved Items', () {
              Navigator.pop(context);
              _navigateToSavedItems();
            }),
            _buildOptionItem(Icons.history, 'View History', () {
              Navigator.pop(context);
              _navigateToViewHistory();
            }),
            _buildOptionItem(Icons.help, 'Help & Support', () {
              Navigator.pop(context);
              _navigateToHelpSupport();
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        color: Provider.of<ThemeProvider>(context).accentColor,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }

  // Navigation methods for menu options
  void _navigateToSavedItems() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
    );
  }

  void _navigateToViewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ViewHistoryScreen()),
    );
  }


  
  
  Future<void> _loadPrivacySettings() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    try {
      final prefsModel = profileProvider.preferences;
      setState(() {
        _showActivityStatus = prefsModel.showActivityStatus;
      });
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showActivityStatus = prefs.getBool('show_activity_status') ?? true;
      });
    }
  }

  void _navigateToHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpOption(Icons.description, 'Documentation'),
            _buildHelpOption(Icons.chat_bubble_outline, 'Contact Support'),
            _buildHelpOption(Icons.bug_report, 'Report a Bug'),
            _buildHelpOption(Icons.info_outline, 'About art.kubus'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(IconData icon, String title) {
    return ListTile(
      leading: Icon(
        icon,
        color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14),
      ),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        _handleHelpOptionTap(title);
      },
    );
  }
  
  void _handleHelpOptionTap(String option) {
    switch (option) {
      case 'Documentation':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening documentation...'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Visit',
              onPressed: () {
                // In production, open https://docs.art-kubus.io
              },
            ),
          ),
        );
        break;
      case 'Contact Support':
        _showContactSupportDialog();
        break;
      case 'Report a Bug':
        _showReportBugDialog();
        break;
      case 'About art.kubus':
        _showAboutDialog();
        break;
    }
  }
  
  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contact Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get help from our support team:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildContactOption(Icons.email, 'Email', 'support@art-kubus.io'),
            const SizedBox(height: 12),
            _buildContactOption(Icons.chat, 'Live Chat', 'Available Mon-Fri 9AM-5PM'),
            const SizedBox(height: 12),
            _buildContactOption(Icons.public, 'Website', 'https://art.kubus.site'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactOption(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Provider.of<ThemeProvider>(context).accentColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _showReportBugDialog() {
    final bugController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report a Bug',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Describe the issue you encountered:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bugController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter bug description...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bug report submitted. Thank you!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text('Submit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'About art.kubus',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.palette,
                size: 40,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'art.kubus',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0+1',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AR art platform connecting artists and institutions through blockchain technology.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 kubus Project',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
}
