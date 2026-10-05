import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/profile/profile_identity_hero.dart';
import '../../widgets/profile/profile_owner_identity.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_brand_colors.dart';
import '../../utils/keyboard_inset_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/themeprovider.dart';
import '../../providers/web3provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../providers/community_interactions_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/kubus_entity_semantics.dart';
import '../../widgets/common/kubus_entity_card.dart';
import '../../utils/profile_showcase_normalizer.dart';
import '../../utils/app_color_utils.dart';
import '../../community/community_interactions.dart';
import '../web3/wallet/wallet_home.dart';
import '../settings_screen.dart';
import '../activity/saved_items_screen.dart';
import 'profile_screen_methods.dart';
import 'profile_section_order.dart';
import '../activity/view_history_screen.dart';
import '../collab/invites_inbox_screen.dart';
import '../../models/artwork.dart';
import 'profile_edit_screen.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/user_activity_status_line.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/common/kubus_social_link_chip.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/common/kubus_stat_card.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/detail/shared_section_widgets.dart';
import 'post_detail_screen.dart';
import '../../utils/artwork_navigation.dart';
import '../art/collection_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../../widgets/email_verification_status_badge.dart';
import '../../widgets/profile/profile_account_health_section.dart';
import '../../widgets/profile/profile_achievements_preview_section.dart';
import '../../widgets/profile/profile_badges_verification_section.dart';
import '../../models/dao.dart';
import '../../config/config.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/common/kubus_action_tile.dart';
import '../activity/advanced_analytics_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';

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

  /// Captured in `didChangeDependencies` so `dispose` never has to look the
  /// provider up through a deactivated `BuildContext`.
  ProfileProvider? _listenedProfileProvider;
  bool _didScheduleAchievementHydration = false;
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
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    if (_listenedProfileProvider != profileProvider) {
      _listenedProfileProvider
          ?.removeListener(_handleProfilePreferencesChanged);
      profileProvider.addListener(_handleProfilePreferencesChanged);
      _listenedProfileProvider = profileProvider;
    }
    if (!_didScheduleDataFetch) {
      _didScheduleDataFetch = true;
      _postsFuture = _loadUserPosts();
      // Trigger a background refresh of aggregated stats (followers/following/posts)
      // so the counts on the profile header update shortly after open.
      try {
        Future(() async {
          try {
            await profileProvider.refreshStats(forceRefresh: true);
          } catch (e) {
            AppConfig.debugPrint('ProfileScreen: refreshStats failed: $e');
          }
        });
      } catch (_) {}
    }
    if (!_didScheduleAchievementHydration) {
      _didScheduleAchievementHydration = true;
      final taskProvider = context.read<TaskProvider>();
      if (taskProvider.achievementHydrationStatus ==
          AchievementHydrationStatus.idle) {
        Future.microtask(() async {
          try {
            await taskProvider.refreshAchievementsForCurrentUser();
          } catch (e) {
            AppConfig.debugPrint(
                'ProfileScreen: achievements hydration failed: $e');
          }
        });
      }
    }
    _maybeLoadArtistData();
  }

  @override
  void dispose() {
    // Use the reference captured in didChangeDependencies: looking a provider
    // up through `context` here would query a deactivated element.
    _listenedProfileProvider?.removeListener(_handleProfilePreferencesChanged);
    _listenedProfileProvider = null;
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
    final keyboardVisible = KeyboardInsetResolver.isKeyboardVisible(context);
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    final walletAddress = profileProvider.currentUser?.walletAddress ?? '';
    final DAOReview? daoReview = walletAddress.isNotEmpty
        ? daoProvider.findReviewForWallet(walletAddress)
        : null;
    final isArtist = _hasArtistRole(profileProvider, daoReview);
    final isInstitution = _hasInstitutionRole(profileProvider, daoReview);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
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
                      // The public profile's hierarchy (identity, work,
                      // activity, recognition, closing stats), then the
                      // owner's tools as their own secondary block.
                      for (final section in ownerProfileSections)
                        ..._sectionSlivers(
                          section,
                          isArtist: isArtist,
                          isInstitution: isInstitution,
                        ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: DetailSpacing.xxl)),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: keyboardVisible
                              ? KubusSpacing.none
                              : KubusLayout.mainBottomNavBarHeight +
                                  bottomSafeInset,
                        ),
                      ),
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

  /// The slivers of one [ProfileSection] of "My profile".
  List<Widget> _sectionSlivers(
    ProfileSection section, {
    required bool isArtist,
    required bool isInstitution,
  }) {
    const gap = SliverToBoxAdapter(child: SizedBox(height: DetailSpacing.xl));
    switch (section) {
      case ProfileSection.identity:
        return [
          _buildProfileHeader(isArtist: isArtist, isInstitution: isInstitution),
          const SliverToBoxAdapter(child: SizedBox(height: DetailSpacing.xl)),
        ];
      case ProfileSection.work:
        return [
          if (isArtist) ...[
            SliverToBoxAdapter(child: _buildArtistHighlightsGrid()),
            gap,
            SliverToBoxAdapter(child: _buildArtistEventsShowcase()),
            gap,
          ],
          if (isInstitution) ...[
            SliverToBoxAdapter(child: _buildInstitutionHighlightsSection()),
            gap,
          ],
        ];
      case ProfileSection.publicArt:
        // Added public art is shown on the viewed profile; the owner reaches
        // the same records through the Artworks statistic below.
        return const [];
      case ProfileSection.activity:
        return [SliverToBoxAdapter(child: _buildPostsSection()), gap];
      case ProfileSection.recognition:
        return [
          const SliverToBoxAdapter(
            child: ProfileAchievementsPreviewSection(
              mode: ProfileAchievementsPreviewMode.ownProfile,
              padding: EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
          gap,
          const SliverToBoxAdapter(
            child: ProfileBadgesVerificationSection(
              padding: EdgeInsets.symmetric(horizontal: DetailSpacing.lg),
            ),
          ),
          gap,
        ];
      case ProfileSection.stats:
        return [_buildStatsSection()];
      case ProfileSection.ownerTools:
        return [
          const SliverToBoxAdapter(child: SizedBox(height: DetailSpacing.xxl)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DetailSpacing.lg),
              child: Divider(
                height: KubusSizes.hairline,
                thickness: KubusSizes.hairline,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: DetailSpacing.lg)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DetailSpacing.lg),
              child: KubusHeaderText(
                title: AppLocalizations.of(context)!.settingsGroupAccount,
                kind: KubusHeaderKind.section,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: DetailSpacing.md)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: DetailSpacing.lg),
              child: ProfileAccountHealthSection(
                bottomSpacing: DetailSpacing.xl,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildSavedArtworksSection()),
          gap,
          SliverToBoxAdapter(child: _buildPerformanceStats()),
        ];
    }
  }

  /// The owner's header is the public hero ([ProfileIdentityHero]) and
  /// practice block, so "My profile" reads as the same profile implementation
  /// as the viewed one; only the actions differ (editing and the owner's
  /// utilities instead of Follow and Message).
  Widget _buildProfileHeader(
      {required bool isArtist, required bool isInstitution}) {
    final web3Provider = Provider.of<Web3Provider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final user = profileProvider.currentUser;
    const avatarRadius = 42.0;
    final coverImageUrl = _normalizeMediaUrl(user?.coverImage);
    final coverUrlIsKnownBad =
        coverImageUrl != null && coverImageUrl == _failedCoverImageUrl;
    final displayName =
        user?.displayName ?? user?.username ?? l10n.profilePersonaArtEnthusiast;
    final wallet = user?.walletAddress ?? '';

    final utilities = <ProfileOwnerUtility>[
      ProfileOwnerUtility(
        icon: Icons.share_outlined,
        tooltip: l10n.commonShare,
        onPressed: _shareProfile,
      ),
      ProfileOwnerUtility(
        icon: Icons.inbox_outlined,
        tooltip: l10n.profileInvitesTooltip,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvitesInboxScreen()),
        ),
      ),
      if (AppConfig.isFeatureEnabled('analytics'))
        ProfileOwnerUtility(
          icon: Icons.analytics_outlined,
          tooltip: l10n.navigationScreenAnalytics,
          onPressed: () {
            if (wallet.trim().isEmpty) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdvancedAnalyticsScreen(
                  statType: '',
                  walletAddress: wallet,
                  initialContext: AnalyticsExperienceContext.profile,
                  contexts: const <AnalyticsExperienceContext>[
                    AnalyticsExperienceContext.profile,
                    AnalyticsExperienceContext.community,
                  ],
                ),
              ),
            );
          },
        ),
      ProfileOwnerUtility(
        icon: Icons.more_horiz,
        tooltip: l10n.profileMoreOptionsTitle,
        onPressed: _showMoreOptions,
      ),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DetailSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileIdentityHero(
              displayName: displayName,
              handle: user?.username,
              isArtist: isArtist,
              isInstitution: isInstitution,
              coverImageUrl: coverUrlIsKnownBad ? null : coverImageUrl,
              onCoverError: () {
                if (coverImageUrl == null ||
                    _failedCoverImageUrl == coverImageUrl) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _failedCoverImageUrl = coverImageUrl);
                });
              },
              roleLabel: isInstitution
                  ? l10n.settingsRoleInstitutionTitle
                  : isArtist
                      ? l10n.settingsRoleArtistTitle
                      : l10n.navigationScreenProfile,
              avatarRadius: avatarRadius,
              avatar: AvatarWidget(
                wallet: wallet,
                displayName: user?.displayName,
                avatarUrl: user?.avatar,
                radius: avatarRadius,
                borderWidth: 0,
                borderColor: Colors.transparent,
                enableProfileNavigation: false,
                showStatusIndicator: _showActivityStatus,
              ),
              actions: ProfileOwnerActions(
                editLabel: l10n.settingsEditProfileTileTitle,
                onEdit: _editProfile,
                utilities: utilities,
              ),
            ),
            const SizedBox(height: DetailSpacing.lg),
            ProfileOwnerPracticeBlock(
              bio: user?.bio ?? '',
              fieldOfWork: user?.artistInfo?.specialty ?? const <String>[],
              yearsActive: user?.artistInfo?.yearsActive ?? 0,
              emptyBioTitle: l10n.profileNoBioYetTitle,
              editLabel: l10n.settingsEditProfileTileTitle,
              onEdit: _editProfile,
              socialLinks: user?.social.isNotEmpty == true
                  ? _buildSocialLinks(user!.social)
                  : null,
              status: [
                const EmailVerificationStatusBadge(
                  dense: true,
                  alignment: Alignment.centerLeft,
                  topSpacing: 0,
                ),
                UserActivityStatusLine(
                  walletAddress: wallet,
                  textAlign: TextAlign.start,
                  textStyle: KubusTextStyles.detailCaption.copyWith(
                    color: roles.foregroundSubtle,
                  ),
                ),
                Text(
                  web3Provider.hasWalletIdentity
                      ? web3Provider.formatAddress(web3Provider.walletAddress)
                      : l10n.profileConnectWalletToSeeProfileLabel,
                  style: KubusTextStyles.detailCaption.copyWith(
                    fontFamily:
                        web3Provider.hasWalletIdentity ? 'RobotoMono' : null,
                    color: roles.foregroundSubtle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final profileProvider = Provider.of<ProfileProvider>(context);
          final isSmallScreen = constraints.maxWidth < 360;
          final walletAddress = profileProvider.currentWalletAddress;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isSmallScreen ? 2 : 3,
              mainAxisSpacing: KubusSpacing.md,
              crossAxisSpacing: KubusSpacing.md,
              // Measured, not an aspect ratio: the label may wrap and the
              // text scale may be raised.
              mainAxisExtent: KubusStatCard.centeredExtent(
                context,
                valueStyle: _statValueStyle(isSmallScreen),
                titleStyle: _statTitleStyle(isSmallScreen),
                padding: _statPadding(isSmallScreen),
              ),
              children: [
                _buildStatCard(
                  AppLocalizations.of(context)!.userProfilePostsStatLabel,
                  profileProvider.formattedPostsCount,
                  Icons.article_outlined,
                  isSmallScreen: isSmallScreen,
                ),
                _buildStatCard(
                  AppLocalizations.of(context)!.userProfileFollowersStatLabel,
                  profileProvider.formattedFollowersCount,
                  Icons.people_outline,
                  isSmallScreen: isSmallScreen,
                  onTap: () => ProfileScreenMethods.showFollowers(
                    context,
                    walletAddress: walletAddress,
                  ),
                ),
                _buildStatCard(
                  AppLocalizations.of(context)!.userProfileFollowingStatLabel,
                  profileProvider.formattedFollowingCount,
                  Icons.person_add_alt_outlined,
                  isSmallScreen: isSmallScreen,
                  onTap: () => ProfileScreenMethods.showFollowing(
                    context,
                    walletAddress: walletAddress,
                  ),
                ),
                _buildStatCard(
                  AppLocalizations.of(context)!.userProfileArtworksTitle,
                  profileProvider.formattedArtworksCount,
                  Icons.palette,
                  isSmallScreen: isSmallScreen,
                  onTap: () => ProfileScreenMethods.showArtworks(
                    context,
                    walletAddress: walletAddress,
                  ),
                ),
                _buildStatCard(
                  AppLocalizations.of(context)!.userProfileCollectionsTitle,
                  profileProvider.formattedCollectionsCount,
                  Icons.collections,
                  isSmallScreen: isSmallScreen,
                  onTap: () => ProfileScreenMethods.showCollections(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle _statTitleStyle(bool isSmallScreen) =>
      KubusTextStyles.detailCaption.copyWith(
        fontSize: isSmallScreen ? 11 : 12,
      );

  TextStyle _statValueStyle(bool isSmallScreen) =>
      KubusTextStyles.detailCardTitle.copyWith(
        fontSize: isSmallScreen ? 14 : 15,
        fontWeight: FontWeight.w700,
      );

  EdgeInsets _statPadding(bool isSmallScreen) => EdgeInsets.all(
        isSmallScreen ? KubusSpacing.sm : KubusChromeMetrics.compactCardPadding,
      );

  Widget _buildStatCard(String title, String value, IconData icon,
      {bool isSmallScreen = false, VoidCallback? onTap}) {
    return KubusStatCard(
      title: title,
      value: value,
      icon: icon,
      layout: KubusStatCardLayout.centered,
      accent: _profileStatAccentForIcon(icon),
      onTap: onTap,
      minHeight: 0,
      padding: _statPadding(isSmallScreen),
      titleMaxLines: 2,
      titleStyle: _statTitleStyle(isSmallScreen),
      valueStyle: _statValueStyle(isSmallScreen),
    );
  }

  Future<void> _handleRefresh() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final daoProvider = Provider.of<DAOProvider>(context, listen: false);
    final taskProvider = context.read<TaskProvider>();
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
    try {
      await taskProvider.refreshAchievementsForCurrentUser();
    } catch (e) {
      AppConfig.debugPrint('ProfileScreen: achievements refresh failed: $e');
    }

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
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final nextShowStatus = profileProvider.preferences.showActivityStatus;
    if (nextShowStatus != _showActivityStatus) {
      setState(() => _showActivityStatus = nextShowStatus);
    }
  }

  Future<String?> _resolveCurrentWallet() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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
    if (!mounted) return [];
    if (wallet == null || wallet.isEmpty) {
      return [];
    }
    try {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        authorWallet: wallet,
      );
      await CommunityService.loadSavedInteractions(
        posts,
        savedItemsProvider: savedItemsProvider,
      );
      if (mounted) {
        context
            .read<CommunityInteractionsProvider>()
            .hydratePostsFromServer(posts);
      }
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
                  AppLocalizations.of(context)!.userProfilePostsTitle,
                  style: KubusTypography.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildErrorCard(
                  message: AppLocalizations.of(context)!
                      .userProfilePostsLoadFailedDescription,
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
                  AppLocalizations.of(context)!.userProfilePostsTitle,
                  style: KubusTypography.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildEmptyStateCard(
                  title: AppLocalizations.of(context)!.userProfileNoPostsTitle,
                  description: AppLocalizations.of(context)!
                      .profileNoPostsYetDescription,
                  icon: Icons.article,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.userProfilePostsTitle,
                style: KubusTypography.inter(
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

  Widget _buildErrorCard(
      {required String message, required VoidCallback onRetry}) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      backgroundColor:
          Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: KubusTypography.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.commonRetry),
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
    String actionLabel = '',
    Future<void> Function()? onActionTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveActionLabel =
        actionLabel.isNotEmpty ? actionLabel : l10n.commonRetry;
    return EmptyStateCard(
      icon: icon,
      title: title,
      description: description,
      showAction: showAction,
      actionLabel: showAction ? effectiveActionLabel : null,
      onAction: onActionTap != null ? () => onActionTap() : null,
    );
  }

  Widget _buildSavedArtworksSection() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DetailSpacing.lg),
      child: Consumer2<SavedItemsProvider, ArtworkProvider>(
        builder: (context, savedProvider, artworkProvider, _) {
          final savedIds = savedProvider.getSortedSavedIds(type: 'artwork');
          final savedArtworks = savedIds
              .map(artworkProvider.getArtworkById)
              .whereType<Artwork>()
              .take(6)
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KubusHeaderText(
                title: l10n.savedItemsSectionTitle(l10n.savedItemsArtworkLabel),
                // Empty: the empty state below says what to do, once.
                subtitle: savedIds.isEmpty
                    ? null
                    : l10n.savedItemsSummaryCount(savedIds.length),
                kind: KubusHeaderKind.section,
              ),
              const SizedBox(height: KubusSpacing.md),
              if (savedIds.isEmpty)
                EmptyStateCard(
                  icon: Icons.bookmark_border,
                  title: l10n
                      .savedItemsEmptySectionTitle(l10n.savedItemsArtworkLabel),
                  description: l10n.savedItemsEmptySectionDescription(
                      l10n.savedItemsArtworkLabel),
                  showAction: true,
                  actionLabel: l10n.profileMenuSavedItemsTitle,
                  onAction: _navigateToSavedItems,
                )
              else if (savedArtworks.isEmpty)
                KubusStatCard(
                  title:
                      l10n.savedItemsSectionTitle(l10n.savedItemsArtworkLabel),
                  value: l10n.savedItemsSummaryCount(savedIds.length),
                  icon: Icons.bookmarks_outlined,
                  layout: KubusStatCardLayout.centered,
                  onTap: _navigateToSavedItems,
                  minHeight: 96,
                )
              else
                SharedShowcaseSection<Artwork>(
                  title: l10n.profileMenuSavedItemsTitle,
                  items: savedArtworks,
                  itemBuilder: (context, artwork) => KubusEntityCard(
                    variant: KubusEntityCardVariant.media,
                    kind: KubusEntityKind.artwork,
                    imageUrl: artwork.imageUrl,
                    title: artwork.title,
                    subtitle: artwork.artist,
                    meta: l10n.userProfileLikesLabel(artwork.likesCount),
                    onTap: () => openArtwork(
                      context,
                      artwork.id,
                      source: 'profile_saved_artworks',
                    ),
                    width: 200,
                  ),
                  emptyTitle: l10n
                      .savedItemsEmptySectionTitle(l10n.savedItemsArtworkLabel),
                  emptyDescription: l10n.savedItemsEmptySectionDescription(
                      l10n.savedItemsArtworkLabel),
                  emptyIcon: Icons.bookmark_border,
                  listHeight: 210,
                ),
              // The empty state carries its own action to saved items.
              if (savedIds.isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _navigateToSavedItems,
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: Text(l10n.commonViewAll),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return CommunityPostCard(
      post: post,
      accentColor: themeProvider.accentColor,
      onOpenPostDetail: (target) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: target)),
        );
      },
    );
  }

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress ?? '';
    if (wallet.isEmpty) {
      return;
    }
    DAOReview? review;
    try {
      review = Provider.of<DAOProvider>(context, listen: false)
          .findReviewForWallet(wallet);
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

  Future<void> _loadArtistData(String walletAddress,
      {bool force = false}) async {
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
      final collections =
          await api.getCollections(walletAddress: walletAddress, limit: 6);
      final eventsResponse = await api.listEvents(limit: 100);
      final filteredEvents = eventsResponse
          .where((event) => profileEventBelongsToWallet(event, walletAddress))
          .take(6)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

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
            AppLocalizations.of(context)!.userProfileEventsTitle,
            style: KubusTypography.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildShowcaseSection(
            title: AppLocalizations.of(context)!.profileUpcomingEventsTitle,
            items: _artistEvents,
            emptyLabel:
                AppLocalizations.of(context)!.profileUpcomingEventsEmptyLabel,
            emptyIcon: Icons.event_outlined,
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
            AppLocalizations.of(context)!.userProfileArtistHighlightsTitle,
            style: KubusTypography.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.profileArtistHighlightsSubtitle,
            style: KubusTypography.inter(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: AppLocalizations.of(context)!.userProfileArtworksTitle,
            items: _artistArtworks,
            emptyLabel:
                AppLocalizations.of(context)!.profileArtistArtworksEmptyLabel,
            emptyIcon: Icons.image_outlined,
            builder: _buildArtworkCard,
          ),
          const SizedBox(height: 24),
          _buildShowcaseSection(
            title: AppLocalizations.of(context)!.userProfileCollectionsTitle,
            items: _artistCollections,
            emptyLabel: AppLocalizations.of(context)!
                .profileArtistCollectionsEmptyLabel,
            emptyIcon: Icons.collections_outlined,
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
            AppLocalizations.of(context)!.userProfileInstitutionHighlightsTitle,
            style: KubusTypography.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.profileInstitutionHighlightsSubtitle,
            style: KubusTypography.inter(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildShowcaseSection(
            title: AppLocalizations.of(context)!.userProfileEventsTitle,
            items: _artistEvents,
            emptyLabel: AppLocalizations.of(context)!
                .profileInstitutionEventsEmptyLabel,
            emptyIcon: Icons.event_outlined,
            builder: _buildEventCard,
          ),
          const SizedBox(height: 24),
          _buildShowcaseSection(
            title: AppLocalizations.of(context)!.userProfileCollectionsTitle,
            items: _artistCollections,
            emptyLabel: AppLocalizations.of(context)!
                .profileInstitutionCollectionsEmptyLabel,
            emptyIcon: Icons.collections_outlined,
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
    required IconData emptyIcon,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return SharedShowcaseSection<Map<String, dynamic>>(
      title: title,
      items: items,
      itemBuilder: (context, item) => builder(item),
      isLoading: _artistDataLoading && !_artistDataLoaded,
      emptyTitle: l10n.profileShowcaseEmptyTitle(title),
      emptyDescription: emptyLabel,
      emptyIcon: emptyIcon,
      loadingHeight: 160,
      listHeight: 210,
    );
  }

  Widget _buildArtworkCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final card = ProfileArtworkShowcaseData.fromMap(
      data,
      fallbackTitle: l10n.commonUntitled,
      fallbackSubtitle: l10n.profileArtworkMediumFallback,
    );

    return _buildShowcaseCard(
      kind: KubusEntityKind.artwork,
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: card.subtitle,
      meta: l10n.userProfileLikesLabel(card.likesCount),
      onTap: card.id != null
          ? () => openArtwork(context, card.id!, source: 'profile_showcase')
          : null,
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final card = ProfileCollectionShowcaseData.fromMap(
      data,
      fallbackTitle: l10n.profileCollectionFallbackTitle,
    );

    return _buildShowcaseCard(
      kind: KubusEntityKind.collection,
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: l10n.userProfileArtworksCountLabel(card.artworkCount),
      meta: card.description ?? l10n.profileCollectionCuratedByYouFooter,
      onTap: (card.id != null && card.id!.isNotEmpty)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CollectionDetailScreen(collectionId: card.id!),
                ),
              );
            }
          : null,
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final card = ProfileEventShowcaseData.fromMap(
      data,
      fallbackTitle: l10n.profileEventFallbackTitle,
      fallbackLocation: l10n.profileEventLocationTba,
    );
    final date = _formatDateLabel(card.startDate);

    return _buildShowcaseCard(
      kind: KubusEntityKind.event,
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: date,
      meta: card.location ?? l10n.profileEventLocationTba,
      onTap: (card.id != null && card.id!.isNotEmpty)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: card.id!),
                ),
              );
            }
          : null,
    );
  }

  /// One shared entity preview for every showcase rail on this screen: the
  /// media is the subject, the title and its context read off the plate, and
  /// the category accent and glyph come from [KubusEntitySemantics].
  Widget _buildShowcaseCard({
    required KubusEntityKind kind,
    String? imageUrl,
    required String title,
    required String subtitle,
    required String meta,
    VoidCallback? onTap,
  }) {
    return KubusEntityCard(
      variant: KubusEntityCardVariant.media,
      kind: kind,
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      meta: meta,
      onTap: onTap,
      width: 200,
    );
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }

  String _formatDateLabel(dynamic value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null) return l10n.commonTba;
    try {
      final date = value is DateTime ? value : DateTime.parse(value.toString());
      final locale = Localizations.localeOf(context).toLanguageTag();
      return DateFormat.yMMMd(locale).format(date);
    } catch (_) {
      return l10n.commonTba;
    }
  }

  String _formatCount(num value) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return NumberFormat.compact(locale: locale).format(value);
  }

  Widget _buildPerformanceStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Consumer3<ProfileProvider, ArtworkProvider, StatsProvider>(
        builder:
            (context, profileProvider, artworkProvider, statsProvider, child) {
          final wallet =
              (profileProvider.currentUser?.walletAddress ?? '').trim();
          final stats = profileProvider.currentUser?.stats;
          final viewHistory = artworkProvider.viewHistoryEntries;
          final viewedCount = viewHistory.length;

          const publicMetrics = <String>[
            'followers',
            'following',
            'artworks',
            'publicStreetArtAdded',
            'nftsMinted',
          ];
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

          final publicCounters =
              publicSnapshot?.counters ?? const <String, int>{};
          final privateCounters =
              privateSnapshot?.counters ?? const <String, int>{};

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

          final discoveriesValue = privateCounters['artworksDiscovered'] ??
              stats?.artworksDiscovered;
          final createdValue =
              publicCounters['artworks'] ?? stats?.artworksCreated;
          final nftsOwnedValue =
              publicCounters['nftsMinted'] ?? stats?.nftsOwned;
          final publicStreetArtAddedValue =
              publicCounters['publicStreetArtAdded'];

          final discoveriesLabel = privateLoading
              ? '\u2026'
              : discoveriesValue == null
                  ? '\u2014'
                  : _formatCount(discoveriesValue);

          final createdLabel = publicLoading
              ? '\u2026'
              : createdValue == null
                  ? '\u2014'
                  : _formatCount(createdValue);
          final ownedLabel = publicLoading
              ? '\u2026'
              : nftsOwnedValue == null
                  ? '\u2014'
                  : _formatCount(nftsOwnedValue);
          final publicStreetArtAddedLabel = publicLoading
              ? '\u2026'
              : publicStreetArtAddedValue == null
                  ? '\u2014'
                  : _formatCount(publicStreetArtAddedValue);

          final hasData = wallet.isNotEmpty || viewedCount > 0;
          if (!hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.profilePerformanceSectionTitle,
                  style: KubusTypography.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildEmptyStateCard(
                  icon: Icons.analytics,
                  title:
                      AppLocalizations.of(context)!.homeNoStatsAvailableTitle,
                  description: AppLocalizations.of(context)!
                      .homeNoStatsAvailableDescription,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.profilePerformanceSectionTitle,
                style: KubusTypography.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildPerformanceCard(
                  AppLocalizations.of(context)!
                      .profilePerformanceArtworksViewedTitle,
                  _formatCount(viewedCount),
                  Icons.visibility,
                  null),
              const SizedBox(height: 12),
              _buildPerformanceCard(
                  AppLocalizations.of(context)!
                      .profilePerformanceDiscoveriesTitle,
                  discoveriesLabel,
                  Icons.location_on,
                  null),
              const SizedBox(height: 12),
              // Followers/Following intentionally omitted here — the stats
              // grid above already shows both; performance keeps only the
              // metrics that appear nowhere else on the page.
              _buildPerformanceCard(
                  AppLocalizations.of(context)!
                      .profilePerformanceCreatedOwnedTitle,
                  '$createdLabel / $ownedLabel',
                  Icons.auto_fix_high,
                  null),
              const SizedBox(height: 12),
              _buildPerformanceCard(
                  AppLocalizations.of(context)!
                      .profilePerformancePublicStreetArtAddedTitle,
                  publicStreetArtAddedLabel,
                  AppColorUtils.streetArtIcon,
                  null),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPerformanceCard(
      String title, String value, IconData icon, String? change) {
    final compact = MediaQuery.sizeOf(context).width < 375;
    Widget cardContent = KubusStatCard(
      title: title,
      value: value,
      icon: icon,
      layout: KubusStatCardLayout.centered,
      accent: _profileStatAccentForIcon(icon),
      minHeight: 80,
      padding: const EdgeInsets.all(KubusSpacing.md),
      titleMaxLines: 2,
      titleStyle: KubusTextStyles.detailCaption.copyWith(
        fontSize: compact ? 10.5 : 11.5,
      ),
      valueStyle: KubusTextStyles.detailCardTitle.copyWith(
        fontSize: compact ? 15.5 : 16.5,
        fontWeight: FontWeight.w700,
      ),
      change: change,
      isPositiveChange: true,
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

  Color _profileStatAccentForIcon(IconData icon) {
    final roles = KubusColorRoles.of(context);
    final codePoint = icon.codePoint;

    if (codePoint == Icons.palette.codePoint ||
        codePoint == Icons.palette_outlined.codePoint) {
      return roles.web3ArtistStudioAccent;
    }
    if (codePoint == Icons.collections.codePoint ||
        codePoint == Icons.collections_outlined.codePoint) {
      return roles.web3InstitutionAccent;
    }
    if (codePoint == Icons.visibility.codePoint ||
        codePoint == Icons.visibility_outlined.codePoint) {
      return roles.statTeal;
    }
    if (codePoint == Icons.location_on.codePoint ||
        codePoint == Icons.explore.codePoint ||
        codePoint == Icons.explore_outlined.codePoint) {
      return roles.statBlue;
    }
    if (codePoint == Icons.auto_fix_high.codePoint ||
        codePoint == Icons.create.codePoint ||
        codePoint == Icons.create_outlined.codePoint) {
      return roles.statGreen;
    }
    if (codePoint == Icons.group.codePoint ||
        codePoint == Icons.groups.codePoint ||
        codePoint == Icons.people.codePoint ||
        codePoint == Icons.people_outline.codePoint) {
      return roles.statCoral;
    }
    if (codePoint == Icons.person_add.codePoint ||
        codePoint == Icons.person_add_outlined.codePoint) {
      return roles.statTeal;
    }
    if (codePoint == AppColorUtils.streetArtIcon.codePoint) {
      return roles.statAmber;
    }
    if (codePoint == Icons.token.codePoint ||
        codePoint == Icons.token_outlined.codePoint) {
      return roles.web3MarketplaceAccent;
    }

    return Theme.of(context).colorScheme.primary;
  }

  // Navigation and interaction methods
  void _shareProfile() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;
    ShareService().showShareSheet(
      context,
      target: ShareTarget.profile(
        walletAddress: wallet,
        title: profileProvider.currentUser?.displayName ??
            profileProvider.currentUser?.username,
      ),
      sourceScreen: 'profile',
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
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      if (web3Provider.hasWalletIdentity &&
          web3Provider.walletAddress.isNotEmpty) {
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
      builder: (context) => BackdropGlassSheet(
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KubusSheetHeader(
              title: AppLocalizations.of(context)!.profileMoreOptionsTitle,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KubusSpacing.lg,
                0,
                KubusSpacing.lg,
                KubusSpacing.lg,
              ),
              child: Column(
                children: [
                  _buildOptionItem(Icons.settings,
                      AppLocalizations.of(context)!.navigationScreenSettings,
                      () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  }),
                  _buildOptionItem(Icons.bookmark,
                      AppLocalizations.of(context)!.profileMenuSavedItemsTitle,
                      () {
                    Navigator.pop(context);
                    _navigateToSavedItems();
                  }),
                  _buildOptionItem(Icons.history,
                      AppLocalizations.of(context)!.profileMenuViewHistoryTitle,
                      () {
                    Navigator.pop(context);
                    _navigateToViewHistory();
                  }),
                  _buildOptionItem(Icons.help,
                      AppLocalizations.of(context)!.profileMenuHelpSupportTitle,
                      () {
                    Navigator.pop(context);
                    _navigateToHelpSupport();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A profile menu destination: the dense tile, no icon box.
  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: KubusActionTile(
        title: title,
        icon: icon,
        accent: KubusColorRoles.of(context).active,
        layout: KubusActionTileLayout.compact,
        onTap: onTap,
      ),
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
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          title: Text(
            l10n.profileHelpSupportTitle,
            style: KubusTypography.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpOption(
                  Icons.description, _ProfileHelpOption.documentation),
              _buildHelpOption(
                  Icons.chat_bubble_outline, _ProfileHelpOption.contactSupport),
              _buildHelpOption(Icons.bug_report, _ProfileHelpOption.reportBug),
              _buildHelpOption(Icons.info_outline, _ProfileHelpOption.about),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonClose, style: KubusTypography.inter()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpOption(IconData icon, _ProfileHelpOption option) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(
        icon,
        color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
      ),
      title: Text(
        option.label(l10n),
        style: KubusTypography.inter(fontSize: 14),
      ),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        _handleHelpOptionTap(option);
      },
    );
  }

  void _handleHelpOptionTap(_ProfileHelpOption option) {
    final l10n = AppLocalizations.of(context)!;
    switch (option) {
      case _ProfileHelpOption.documentation:
        final messenger = ScaffoldMessenger.of(context);
        // Open docs immediately; avoid a dead SnackBar action.
        () async {
          messenger.showKubusSnackBar(
            SnackBar(
              content: Text(l10n.profileHelpOpeningDocumentationToast),
              duration: const Duration(seconds: 2),
            ),
          );
          final ok = await launchUrl(
            Uri.parse('https://docs.kubus.site'),
            mode: LaunchMode.externalApplication,
          );
          if (!ok && mounted) {
            messenger.showKubusSnackBar(
              SnackBar(content: Text(l10n.commonActionFailedToast)),
            );
          }
        }();
        break;
      case _ProfileHelpOption.contactSupport:
        _showContactSupportDialog();
        break;
      case _ProfileHelpOption.reportBug:
        _showReportBugDialog();
        break;
      case _ProfileHelpOption.about:
        _showAboutDialog();
        break;
    }
  }

  void _showContactSupportDialog() {
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          title: Text(
            l10n.profileContactSupportTitle,
            style: KubusTypography.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileContactSupportSubtitle,
                style: KubusTypography.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildContactOption(Icons.email,
                  l10n.profileContactSupportEmailLabel, 'support@kubus.site'),
              const SizedBox(height: 12),
              _buildContactOption(
                  Icons.chat,
                  l10n.profileContactSupportLiveChatLabel,
                  l10n.profileContactSupportLiveChatAvailability),
              const SizedBox(height: 12),
              _buildContactOption(
                  Icons.public,
                  l10n.profileContactSupportWebsiteLabel,
                  'https://art.kubus.site'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonClose, style: KubusTypography.inter()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactOption(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 20, color: Provider.of<ThemeProvider>(context).accentColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: KubusTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                value,
                style: KubusTypography.inter(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLinks(Map<String, String> social) {
    final links = <Widget>[];

    if (social['twitter']?.isNotEmpty == true) {
      final handle = social['twitter']!.trim().replaceFirst('@', '');
      links.add(
        KubusSocialLinkChip(
          icon: Icons.alternate_email,
          label: '@$handle',
          color: KubusBrandColors.twitterBlue,
          onTap: () => _openSocialUrl('https://x.com/$handle'),
        ),
      );
    }

    if (social['instagram']?.isNotEmpty == true) {
      final handle = social['instagram']!.trim().replaceFirst('@', '');
      links.add(
        KubusSocialLinkChip(
          icon: Icons.camera_alt_outlined,
          label: '@$handle',
          color: KubusBrandColors.instagramPink,
          onTap: () => _openSocialUrl('https://instagram.com/$handle'),
        ),
      );
    }

    if (social['website']?.isNotEmpty == true) {
      final rawWebsite = social['website']!.trim();
      final hasScheme =
          rawWebsite.startsWith('http://') || rawWebsite.startsWith('https://');
      final url = hasScheme ? rawWebsite : 'https://$rawWebsite';
      final displayUrl = rawWebsite
          .replaceAll(RegExp(r'^https?://'), '')
          .replaceAll(RegExp(r'/$'), '');
      links.add(
        KubusSocialLinkChip(
          icon: Icons.language,
          label: displayUrl,
          color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
          onTap: () => _openSocialUrl(url),
        ),
      );
    }

    if (links.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: KubusSpacing.sm + KubusSpacing.xxs,
      runSpacing: KubusSpacing.xs + KubusSpacing.xxs,
      alignment: WrapAlignment.center,
      children: links,
    );
  }

  Future<void> _openSocialUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.commonActionFailedToast),
        ),
      );
    }
  }

  void _showReportBugDialog() {
    final bugController = TextEditingController();

    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          title: Text(
            l10n.profileReportBugTitle,
            style: KubusTypography.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.profileReportBugSubtitle,
                style: KubusTypography.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bugController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.profileReportBugHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel, style: KubusTypography.inter()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Provider.of<ThemeProvider>(context).accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final body = bugController.text.trim();
                navigator.pop();

                final uri = Uri(
                  scheme: 'mailto',
                  path: 'support@kubus.site',
                  query: _encodeQueryParameters(<String, String>{
                    'subject': l10n.profileReportBugEmailSubject,
                    if (body.isNotEmpty) 'body': body,
                  }),
                );

                final ok = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && mounted) {
                  messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.commonActionFailedToast)),
                  );
                }
              },
              child: Text(
                l10n.commonSubmit,
                style: KubusTypography.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          title: Text(
            l10n.profileAboutTitle,
            style: KubusTypography.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Provider.of<ThemeProvider>(context)
                      .accentColor
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
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
                style: KubusTypography.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.profileAboutVersionLabel('1.0.0+1'),
                style: KubusTypography.inter(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.profileAboutDescription,
                textAlign: TextAlign.center,
                style: KubusTypography.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.profileAboutCopyright,
                style: KubusTypography.inter(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonClose, style: KubusTypography.inter()),
            ),
          ],
        );
      },
    );
  }
}

String _encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}

enum _ProfileHelpOption {
  documentation,
  contactSupport,
  reportBug,
  about,
}

extension _ProfileHelpOptionLabels on _ProfileHelpOption {
  String label(AppLocalizations l10n) {
    switch (this) {
      case _ProfileHelpOption.documentation:
        return l10n.profileHelpDocumentationOption;
      case _ProfileHelpOption.contactSupport:
        return l10n.profileHelpContactSupportOption;
      case _ProfileHelpOption.reportBug:
        return l10n.profileHelpReportBugOption;
      case _ProfileHelpOption.about:
        return l10n.profileHelpAboutOption;
    }
  }
}
