import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/community_interactions_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../utils/achievement_ui.dart';
import '../../../utils/artwork_navigation.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/profile_showcase_normalizer.dart';
import '../../../community/community_interactions.dart';
import '../../web3/achievements/achievements_page.dart';
import '../desktop_settings_screen.dart';
import '../../community/post_detail_screen.dart';
import '../../../models/achievement_progress.dart';
import '../../../services/achievement_service.dart' as achievement_svc;
import 'desktop_profile_edit_screen.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/user_activity_status_line.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/profile_artist_info_fields.dart';
import '../../../widgets/detail/detail_shell_components.dart';
import '../../../widgets/detail/shared_section_widgets.dart';
import '../../community/profile_screen_methods.dart';
import '../../../widgets/artist_badge.dart';
import '../../../widgets/institution_badge.dart';
import '../../../widgets/email_verification_status_badge.dart';
import '../../../widgets/secure_account_banner_card.dart';
import '../../../widgets/wallet_backup_banner_card.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../art/collection_detail_screen.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../activity/view_history_screen.dart';
import '../../events/event_detail_screen.dart';
import '../../../config/config.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../activity/advanced_analytics_screen.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import '../../../widgets/common/kubus_stat_card.dart';
import '../../../widgets/common/kubus_glass_icon_button.dart';
import '../../../widgets/common/kubus_social_link_chip.dart';
import '../../../widgets/community/community_post_card.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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
            await profileProvider.refreshStats(forceRefresh: true);
          } catch (e) {
            AppConfig.debugPrint('ProfileScreen: refreshStats failed: $e');
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
    final isEmbeddedSubScreen = DesktopShellScope.of(context)?.canPop ?? false;
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
      backgroundColor: Colors.transparent,
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
                        _buildHeader(
                          showNavigationChrome: !isEmbeddedSubScreen,
                        ),
                        const SizedBox(height: DetailSpacing.xl),
                        // Profile card with inline stats on wide screens
                        _buildProfileCard(themeProvider, profileProvider,
                            isArtist, isInstitution),
                        const SizedBox(height: DetailSpacing.lg),
                        const SecureAccountBannerCard(
                            bottomSpacing: DetailSpacing.lg),
                        const WalletBackupBannerCard(
                            bottomSpacing: DetailSpacing.lg),
                        _buildStatsCards(
                            themeProvider, profileProvider, isLarge),
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
              _buildPerformanceStatsSection(),
              const SizedBox(height: DetailSpacing.lg),
              _buildAchievementsSection(),
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
        _buildPerformanceStatsSection(),
        const SizedBox(height: DetailSpacing.lg),
        _buildAchievementsSection(),
        const SizedBox(height: DetailSpacing.lg),
        _buildPostsSection(themeProvider),
      ],
    );
  }

  Widget _buildHeader({required bool showNavigationChrome}) {
    final l10n = AppLocalizations.of(context)!;
    final inDesktopShell = DesktopShellScope.of(context) != null;
    final canShowBackButton = Navigator.of(context).canPop() && !inDesktopShell;

    Widget buildActions() {
      return Row(
        children: [
          DesktopActionButton(
            label: l10n.desktopProfileShareProfileLabel,
            icon: Icons.share_outlined,
            onPressed: _shareProfile,
            isPrimary: false,
          ),
          const SizedBox(width: DetailSpacing.md),
          DesktopActionButton(
            label: l10n.profileInvitesTooltip,
            icon: Icons.inbox_outlined,
            onPressed: () {
              final shellScope = DesktopShellScope.of(context);
              if (shellScope != null) {
                shellScope.pushSubScreen(
                  title: l10n.profileInvitesTooltip,
                  child: const InvitesInboxScreen(embedded: true),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvitesInboxScreen(),
                ),
              );
            },
            isPrimary: false,
          ),
          const SizedBox(width: DetailSpacing.md),
          if (AppConfig.isFeatureEnabled('analytics')) ...[
            DesktopActionButton(
              label: l10n.navigationScreenAnalytics,
              icon: Icons.analytics_outlined,
              onPressed: () {
                final wallet = context
                        .read<ProfileProvider>()
                        .currentUser
                        ?.walletAddress ??
                    '';
                if (wallet.trim().isEmpty) return;
                _openAnalyticsDialog(wallet);
              },
              isPrimary: false,
            ),
            const SizedBox(width: DetailSpacing.md),
          ],
          DesktopActionButton(
            label: l10n.navigationScreenSettings,
            icon: Icons.settings_outlined,
            onPressed: () {
              final shellScope = DesktopShellScope.of(context);
              if (shellScope != null) {
                shellScope.pushScreen(
                  const DesktopSettingsScreen(embeddedInShell: true),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DesktopSettingsScreen(),
                ),
              );
            },
            isPrimary: false,
          ),
        ],
      );
    }

    if (!showNavigationChrome) {
      return Align(
        alignment: Alignment.centerRight,
        child: buildActions(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (canShowBackButton)
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: l10n.commonBack,
              ),
            if (canShowBackButton) const SizedBox(width: DetailSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.navigationScreenProfile,
                  style: DetailTypography.screenTitle(context),
                ),
                const SizedBox(height: DetailSpacing.xs),
                Text(
                  l10n.desktopProfileHeaderSubtitle,
                  style: DetailTypography.caption(context),
                ),
              ],
            ),
          ],
        ),
        buildActions(),
      ],
    );
  }

  void _openAnalyticsDialog(String wallet) {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return KubusAlertDialog(
          backgroundColor: scheme.surface,
          title: Text(
            l10n.navigationScreenAnalytics,
            style: KubusTypography.inter(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open the unified analytics experience and start in the context you want to review.',
                style: KubusTypography.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: DetailSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline, color: scheme.primary),
                title: Text(
                  l10n.profileAnalyticsProfileTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Profile reach, follower growth, views, and owned signals.',
                  style: KubusTypography.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openDesktopShellAwareScreen(
                    AdvancedAnalyticsScreen(
                      statType: '',
                      walletAddress: wallet,
                      initialContext: AnalyticsExperienceContext.profile,
                      contexts: const <AnalyticsExperienceContext>[
                        AnalyticsExperienceContext.profile,
                        AnalyticsExperienceContext.community,
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.forum_outlined, color: scheme.secondary),
                title: Text(
                  l10n.profileAnalyticsCommunityTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Community posting, likes, and engagement in the same analytics UI.',
                  style: KubusTypography.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openDesktopShellAwareScreen(
                    AdvancedAnalyticsScreen(
                      statType: '',
                      walletAddress: wallet,
                      initialContext: AnalyticsExperienceContext.community,
                      contexts: const <AnalyticsExperienceContext>[
                        AnalyticsExperienceContext.profile,
                        AnalyticsExperienceContext.community,
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.commonClose,
                style: KubusTypography.inter(color: scheme.primary),
              ),
            ),
          ],
        );
      },
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
    const avatarCornerRadiusFactor = AvatarWidget.defaultCornerRadiusFactor;
    const avatarRingPadding = 4.0;

    final avatarRingShapeRadius = AvatarWidget.shapeRadiusFor(
      radius: avatarRadius + avatarRingPadding,
      cornerRadiusFactor: avatarCornerRadiusFactor,
    );
    final scheme = Theme.of(context).colorScheme;
    final displayName = user?.displayName ?? user?.username ?? 'Art Enthusiast';
    final username = user?.username.trim() ?? '';
    final usernameLabel = username.isEmpty
        ? ''
        : (username.startsWith('@') ? username : '@$username');
    final titleColor = hasCoverImage ? Colors.white : scheme.onSurface;
    final subtitleColor = hasCoverImage
        ? Colors.white.withValues(alpha: 0.78)
        : scheme.onSurface.withValues(alpha: 0.62);

    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KubusRadius.lg),
                ),
                child: Container(
                  height: hasCoverImage ? 228 : 156,
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
                                    themeProvider.accentColor
                                        .withValues(alpha: 0.25),
                                    themeProvider.accentColor
                                        .withValues(alpha: 0.08),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(KubusRadius.lg),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black
                            .withValues(alpha: hasCoverImage ? 0.12 : 0),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.26),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: KubusSpacing.md,
                right: KubusSpacing.md,
                child: KubusGlassIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: AppLocalizations.of(context)!
                      .settingsEditProfileTileTitle,
                  size: KubusHeaderMetrics.actionHitArea,
                  borderRadius: KubusRadius.md,
                  iconColor: hasCoverImage ? Colors.white : scheme.onSurface,
                  tooltipPreferBelow: true,
                  tooltipVerticalOffset: KubusSpacing.sm,
                  onPressed: _editProfile,
                ),
              ),
              Positioned(
                left: KubusSpacing.lg,
                right: KubusSpacing.lg,
                bottom: KubusSpacing.lg,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(
                          avatarRingShapeRadius,
                        ),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.24),
                          width: KubusSizes.hairline + 0.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .shadowColor
                                .withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(avatarRingPadding),
                        child: AvatarWidget(
                          wallet: user?.walletAddress ?? '',
                          avatarUrl: user?.avatar,
                          radius: avatarRadius,
                          borderWidth: 0,
                          borderColor: Colors.transparent,
                          cornerRadiusFactor: avatarCornerRadiusFactor,
                          enableProfileNavigation: false,
                          showStatusIndicator: _showActivityStatus,
                        ),
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: KubusTextStyles.screenTitle.copyWith(
                                    color: titleColor,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isArtist) ...[
                                const SizedBox(
                                  width: KubusSpacing.sm + KubusSpacing.xs,
                                ),
                                const ArtistBadge(),
                              ],
                              if (isInstitution) ...[
                                const SizedBox(
                                  width: KubusSpacing.sm + KubusSpacing.xs,
                                ),
                                const InstitutionBadge(),
                              ],
                            ],
                          ),
                          if (usernameLabel.isNotEmpty) ...[
                            const SizedBox(height: KubusSpacing.xs),
                            Text(
                              usernameLabel,
                              style: KubusTextStyles.profileHandle.copyWith(
                                color: subtitleColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.08),
                  width: KubusSizes.hairline,
                ),
              ),
            ),
            padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EmailVerificationStatusBadge(
                  dense: true,
                  alignment: Alignment.centerLeft,
                  topSpacing: 0,
                ),
                const SizedBox(height: KubusSpacing.sm),
                UserActivityStatusLine(
                  walletAddress: user?.walletAddress ?? '',
                  textAlign: TextAlign.start,
                  textStyle: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                if (web3Provider.isConnected) ...[
                  const SizedBox(height: KubusSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: KubusSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KubusRadius.xl),
                      border: Border.all(
                        color: themeProvider.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      web3Provider.formatAddress(web3Provider.walletAddress),
                      style: KubusTextStyles.detailLabel.copyWith(
                        color: themeProvider.accentColor,
                      ),
                    ),
                  ),
                ],
                if (user?.bio.isNotEmpty == true) ...[
                  const SizedBox(height: KubusSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: KubusSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.1),
                        width: KubusSizes.hairline,
                      ),
                    ),
                    child: Text(
                      user!.bio,
                      style: KubusTextStyles.detailBody.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.78),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: KubusSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm,
                    vertical: KubusSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.08),
                      width: KubusSizes.hairline,
                    ),
                  ),
                  child: ProfileArtistInfoFields(
                    fieldOfWork:
                        user?.artistInfo?.specialty ?? const <String>[],
                    yearsActive: user?.artistInfo?.yearsActive ?? 0,
                    textAlign: TextAlign.left,
                  ),
                ),
                if (user?.social.isNotEmpty == true) ...[
                  const SizedBox(height: KubusSpacing.md),
                  _buildSocialLinks(user!.social, themeProvider),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeProvider themeProvider,
      ProfileProvider profileProvider, bool isLarge) {
    final l10n = AppLocalizations.of(context)!;
    final wallet = profileProvider.currentWalletAddress;
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
          label: l10n.userProfilePostsStatLabel,
          value: profileProvider.formattedPostsCount,
          icon: Icons.article_outlined,
          color: _profileStatAccentForIcon(Icons.article_outlined),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
        ),
        DesktopStatCard(
          label: l10n.userProfileFollowersStatLabel,
          value: profileProvider.formattedFollowersCount,
          icon: Icons.people_outline,
          color: _profileStatAccentForIcon(Icons.people_outline),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
          onTap: () => ProfileScreenMethods.showFollowers(context,
              walletAddress: wallet),
        ),
        DesktopStatCard(
          label: l10n.userProfileFollowingStatLabel,
          value: profileProvider.formattedFollowingCount,
          icon: Icons.person_add_outlined,
          color: _profileStatAccentForIcon(Icons.person_add_outlined),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
          onTap: () => ProfileScreenMethods.showFollowing(context,
              walletAddress: wallet),
        ),
        DesktopStatCard(
          label: l10n.userProfileArtworksTitle,
          value: profileProvider.formattedArtworksCount,
          icon: Icons.palette_outlined,
          color: _profileStatAccentForIcon(Icons.palette_outlined),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
          onTap: () =>
              ProfileScreenMethods.showArtworks(context, walletAddress: wallet),
        ),
      ],
    );
  }

  Widget _buildArtistPortfolioSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final wallet = context.read<ProfileProvider>().currentWalletAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopProfilePortfolioTitle,
          subtitle: l10n.desktopProfilePortfolioSubtitle,
          icon: Icons.palette,
          action: _artistArtworks.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => ProfileScreenMethods.showArtworks(
                    context,
                    walletAddress: wallet,
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(l10n.commonViewAll),
                )
              : null,
        ),
        const SizedBox(height: DetailSpacing.xl),
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
              title: l10n.artistGalleryEmptyTitle,
              description: l10n.profileArtistArtworksEmptyLabel,
            ),
          )
        else
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistArtworks.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DetailSpacing.lg),
              itemBuilder: (context, index) =>
                  _buildArtworkShowcaseCard(_artistArtworks[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildArtistCollectionsSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileCollectionsTitle,
          subtitle: l10n.userProfileCollectionsDesktopSubtitle,
          icon: Icons.collections_outlined,
          action: _artistCollections.isNotEmpty
              ? TextButton.icon(
                  onPressed: () =>
                      ProfileScreenMethods.showCollections(context),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(l10n.commonViewAll),
                )
              : null,
        ),
        const SizedBox(height: DetailSpacing.xl),
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
              title: l10n.userProfileNoCollectionsTitle,
              description: l10n.desktopProfileNoCollectionsDescription,
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistCollections.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DetailSpacing.lg),
              itemBuilder: (context, index) =>
                  _buildCollectionShowcaseCard(_artistCollections[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildArtistEventsSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopProfileEventsTitle,
          subtitle: l10n.desktopProfileEventsSubtitle,
          icon: Icons.event,
        ),
        const SizedBox(height: DetailSpacing.xl),
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
              title: l10n.desktopProfileNoEventsTitle,
              description: l10n.desktopProfileNoEventsDescription,
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistEvents.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DetailSpacing.lg),
              itemBuilder: (context, index) =>
                  _buildEventShowcaseCard(_artistEvents[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionEventsSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopProfileInstitutionProgramsTitle,
          subtitle: l10n.desktopProfileInstitutionProgramsSubtitle,
          icon: Icons.museum,
        ),
        const SizedBox(height: DetailSpacing.xl),
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
              title: l10n.desktopProfileNoExhibitionsTitle,
              description: l10n.desktopProfileNoExhibitionsDescription,
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistEvents.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DetailSpacing.lg),
              itemBuilder: (context, index) => _buildEventShowcaseCard(
                  _artistEvents[index],
                  isInstitution: true),
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionCollectionsSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopProfilePermanentCollectionTitle,
          subtitle: l10n.desktopProfilePermanentCollectionSubtitle,
          icon: Icons.account_balance,
          action: _artistCollections.isNotEmpty
              ? TextButton.icon(
                  onPressed: () =>
                      ProfileScreenMethods.showCollections(context),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(l10n.commonViewAll),
                )
              : null,
        ),
        const SizedBox(height: DetailSpacing.xl),
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
              title: l10n.userProfileNoCollectionsTitle,
              description:
                  l10n.desktopProfilePermanentCollectionEmptyDescription,
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistCollections.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DetailSpacing.lg),
              itemBuilder: (context, index) =>
                  _buildCollectionShowcaseCard(_artistCollections[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildViewedArtworksSection(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final viewHistory =
            artworkProvider.viewHistoryEntries.take(10).toList();

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
              title: l10n.desktopProfileRecentlyViewedTitle,
              subtitle: l10n.desktopProfileRecentlyViewedSubtitle,
              icon: Icons.history,
              action: viewHistory.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () {
                        final shellScope = DesktopShellScope.of(context);
                        if (shellScope != null) {
                          shellScope.pushSubScreen(
                            title: l10n.profileMenuViewHistoryTitle,
                            child: const ViewHistoryScreen(embedded: true),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ViewHistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(l10n.profileMenuViewHistoryTitle),
                    )
                  : null,
            ),
            const SizedBox(height: DetailSpacing.xl),
            if (viewedArtworks.isEmpty)
              DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.visibility_outlined,
                  title: l10n.desktopProfileNoViewedArtworksTitle,
                  description: l10n.desktopProfileNoViewedArtworksDescription,
                ),
              )
            else
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: viewedArtworks.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: DetailSpacing.lg),
                  itemBuilder: (context, index) {
                    final artwork = viewedArtworks[index];
                    return _buildShowcaseCard(
                      imageUrl: artwork['imageUrl']?.toString(),
                      title:
                          artwork['title']?.toString() ?? l10n.commonUntitled,
                      subtitle: artwork['artist']?.toString() ??
                          l10n.commonUnknownArtist,
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

  Widget _buildPerformanceStatsSection() {
    return Consumer3<ProfileProvider, ArtworkProvider, StatsProvider>(
      builder: (context, profileProvider, artworkProvider, statsProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final wallet =
            (profileProvider.currentUser?.walletAddress ?? '').trim();
        final stats = profileProvider.currentUser?.stats;
        final viewHistory = artworkProvider.viewHistoryEntries;
        final viewedCount = viewHistory.length;

        const publicMetrics = <String>[
          'artworks',
          'nftsMinted',
          'publicStreetArtAdded'
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

        final discoveriesValue =
            privateCounters['artworksDiscovered'] ?? stats?.artworksDiscovered;
        final createdValue =
            publicCounters['artworks'] ?? stats?.artworksCreated;
        final nftsOwnedValue = publicCounters['nftsMinted'] ?? stats?.nftsOwned;
        final publicStreetArtAddedValue =
            publicCounters['publicStreetArtAdded'];

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
        final publicStreetArtAddedLabel = publicLoading
            ? '\u2026'
            : publicStreetArtAddedValue == null
                ? '\u2014'
                : _formatStatCount(publicStreetArtAddedValue);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: l10n.profilePerformanceSectionTitle,
              subtitle: l10n.desktopProfilePerformanceSubtitle,
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: DetailSpacing.xl),
            DesktopGrid(
              minCrossAxisCount: 2,
              maxCrossAxisCount: 4,
              childAspectRatio: 2.0,
              children: [
                _buildPerformanceStatCard(
                  l10n.profilePerformanceArtworksViewedTitle,
                  _formatStatCount(viewedCount),
                  Icons.visibility_outlined,
                ),
                _buildPerformanceStatCard(
                  l10n.profilePerformanceDiscoveriesTitle,
                  discoveriesLabel,
                  Icons.explore_outlined,
                ),
                _buildPerformanceStatCard(
                  l10n.desktopProfilePerformanceCreatedTitle,
                  createdLabel,
                  Icons.create_outlined,
                ),
                _buildPerformanceStatCard(
                  l10n.desktopProfilePerformanceNftsOwnedTitle,
                  nftsLabel,
                  Icons.token_outlined,
                ),
                _buildPerformanceStatCard(
                  l10n.profilePerformancePublicStreetArtAddedTitle,
                  publicStreetArtAddedLabel,
                  Icons.streetview,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceStatCard(String label, String value, IconData icon) {
    final mediaQuery = MediaQuery.of(context);
    final desktopDense = mediaQuery.size.width < 1480;
    final highDensity = mediaQuery.devicePixelRatio >= 2.0;
    final accent = _profileStatAccentForIcon(icon);
    final iconBox = desktopDense
        ? KubusChromeMetrics.heroIconBox - KubusSpacing.sm
        : KubusChromeMetrics.heroIconBox;
    final iconSize = highDensity
        ? KubusChromeMetrics.heroIcon - KubusSpacing.xs
        : KubusChromeMetrics.heroIcon;
    final valueFontSize = desktopDense ? 24.0 : 26.0;
    final titleFontSize = desktopDense ? 11.5 : 12.0;

    return KubusStatCard(
      title: label,
      value: value,
      icon: icon,
      layout: KubusStatCardLayout.centered,
      accent: accent,
      centeredWatermarkAlignment: Alignment.center,
      centeredWatermarkScale: desktopDense ? 0.82 : 0.86,
      minHeight: 0,
      padding: const EdgeInsets.all(KubusSpacing.md),
      titleMaxLines: 1,
      iconBoxSize: iconBox,
      iconSize: iconSize,
      titleStyle: KubusTextStyles.statLabel.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: titleFontSize,
      ),
      valueStyle: KubusTextStyles.statValue.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: valueFontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildArtworkShowcaseCard(Map<String, dynamic> data) {
    final card = ProfileArtworkShowcaseData.fromMap(
      data,
      fallbackTitle: 'Untitled',
      fallbackSubtitle: 'Artwork',
    );

    return GestureDetector(
      onTap: card.id != null
          ? () {
              openArtwork(context, card.id!, source: 'desktop_profile');
            }
          : null,
      child: MouseRegion(
        cursor: card.id != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: SizedBox(
          width: 240,
          child: DesktopCard(
            padding: EdgeInsets.zero,
            enableHover: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KubusRadius.lg),
                  ),
                  child: card.imageUrl != null
                      ? Image.network(
                          _normalizeMediaUrl(card.imageUrl) ?? '',
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderImage(180, Icons.image_outlined),
                        )
                      : _buildPlaceholderImage(180, Icons.image_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: KubusTextStyles.detailCardTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        card.subtitle,
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.66),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: KubusSpacing.xs),
                          Text(
                            '${card.likesCount}',
                            style: KubusTextStyles.detailCaption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.66),
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
    final card = ProfileCollectionShowcaseData.fromMap(
      data,
      fallbackTitle: 'Collection',
    );

    return SizedBox(
      width: 220,
      child: DesktopCard(
        padding: EdgeInsets.zero,
        enableHover: true,
        onTap: (card.id != null && card.id!.isNotEmpty)
            ? () {
                _openDesktopShellAwareScreen(
                  CollectionDetailScreen(collectionId: card.id!),
                );
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KubusRadius.lg),
              ),
              child: card.imageUrl != null
                  ? Image.network(
                      _normalizeMediaUrl(card.imageUrl) ?? '',
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(
                          140, Icons.collections_outlined),
                    )
                  : _buildPlaceholderImage(140, Icons.collections_outlined),
            ),
            Padding(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: KubusTextStyles.detailCardTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    '${card.artworkCount} artworks',
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.66),
                    ),
                  ),
                  if ((card.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      card.description!,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
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

  Widget _buildEventShowcaseCard(Map<String, dynamic> data,
      {bool isInstitution = false}) {
    final card = ProfileEventShowcaseData.fromMap(
      data,
      fallbackTitle: 'Event',
      fallbackLocation: 'TBA',
    );
    final dateLabel = _formatEventDate(card.startDate);

    return SizedBox(
      width: isInstitution ? 280 : 240,
      child: DesktopCard(
        padding: EdgeInsets.zero,
        enableHover: true,
        onTap: (card.id != null && card.id!.isNotEmpty)
            ? () {
                _openDesktopShellAwareScreen(
                  EventDetailScreen(eventId: card.id!),
                );
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DetailRadius.lg)),
              child: card.imageUrl != null
                  ? Image.network(
                      _normalizeMediaUrl(card.imageUrl) ?? '',
                      height: isInstitution ? 160 : 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(
                          isInstitution ? 160 : 140, Icons.event),
                    )
                  : _buildPlaceholderImage(
                      isInstitution ? 160 : 140, Icons.event),
            ),
            Padding(
              padding: const EdgeInsets.all(DetailSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: DetailTypography.cardTitle(context).copyWith(
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DetailSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: DetailSpacing.xs),
                      Text(
                        dateLabel,
                        style: DetailTypography.caption(context).copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DetailSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: DetailSpacing.xs),
                      Expanded(
                        child: Text(
                          card.location ?? 'TBA',
                          style: DetailTypography.caption(context).copyWith(
                            fontSize: 12,
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
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DetailRadius.lg)),
      ),
      child: Center(
          child: Icon(icon,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer
                  .withValues(alpha: 0.4))),
    );
  }

  Widget _buildShowcaseCard(
      {String? imageUrl,
      required String title,
      required String subtitle,
      String? artworkId}) {
    return SharedShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      onTap: artworkId != null
          ? () {
              openArtwork(context, artworkId,
                  source: 'desktop_profile_showcase');
            }
          : null,
      width: 220,
      imageHeight: 160,
      titleStyle: DetailTypography.cardTitle(context).copyWith(
        fontSize: 14,
      ),
      subtitleStyle: DetailTypography.caption(context).copyWith(
        fontSize: 12,
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final profileProvider = Provider.of<ProfileProvider>(context);
    if (!profileProvider.preferences.showAchievements) {
      return const SizedBox.shrink();
    }

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final achievements = taskProvider.achievementProgress;
        final progressById = <String, AchievementProgress>{
          for (final progress in achievements) progress.achievementId: progress,
        };
        final displayAchievements = achievement_svc
            .AchievementService.achievementDefinitions.values
            .take(6)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: l10n.userProfileAchievementsTitle,
              subtitle: l10n.desktopProfileAchievementsSubtitle,
              icon: Icons.emoji_events_outlined,
              action: TextButton.icon(
                onPressed: () {
                  final shellScope = DesktopShellScope.of(context);
                  if (shellScope != null) {
                    shellScope.pushScreen(const AchievementsPage());
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AchievementsPage()),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(l10n.commonViewAll),
              ),
            ),
            const SizedBox(height: 16),
            if (achievements.isEmpty)
              DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.emoji_events,
                  title: l10n.profileAchievementsEmptyTitle,
                  description: l10n.userProfileAchievementsEmptyDescription,
                ),
              )
            else
              DesktopGrid(
                minCrossAxisCount: 2,
                maxCrossAxisCount: 3,
                childAspectRatio: 1.25,
                children: displayAchievements.map((achievement) {
                  final progress = progressById[achievement.id] ??
                      AchievementProgress(
                        achievementId: achievement.id,
                        currentProgress: 0,
                        isCompleted: false,
                      );
                  final required = achievement.requiredCount > 0
                      ? achievement.requiredCount
                      : 1;
                  final unlocked = progress.isCompleted ||
                      progress.currentProgress >= required;
                  final progressLabel = unlocked
                      ? '+${achievement.tokenReward} KUB8'
                      : '${progress.currentProgress}/$required';

                  return KubusStatCard(
                    title: achievement.title,
                    value: progressLabel,
                    icon: AchievementUi.iconFor(achievement),
                    layout: KubusStatCardLayout.centered,
                    accent: AchievementUi.accentFor(context, achievement),
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                    minHeight: 0,
                    padding: const EdgeInsets.all(KubusSpacing.md),
                    titleMaxLines: 2,
                    titleStyle: KubusTextStyles.detailCaption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: unlocked ? 0.84 : 0.7),
                    ),
                    valueStyle: KubusTextStyles.detailCardTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
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
    if (codePoint == Icons.article.codePoint ||
        codePoint == Icons.article_outlined.codePoint) {
      return roles.statBlue;
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
    if (codePoint == Icons.streetview.codePoint) {
      return roles.statAmber;
    }
    if (codePoint == Icons.token.codePoint ||
        codePoint == Icons.token_outlined.codePoint) {
      return roles.web3MarketplaceAccent;
    }

    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildPostsSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final future = _postsFuture ?? _loadUserPosts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopProfileYourPostsTitle,
          subtitle: l10n.desktopProfileYourPostsSubtitle,
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
                  title: l10n.userProfilePostsLoadFailedTitle,
                  description: l10n.userProfilePostsLoadFailedDescription,
                  showAction: true,
                  actionLabel: l10n.commonRetry,
                  onAction: () =>
                      setState(() => _postsFuture = _loadUserPosts()),
                ),
              );
            }

            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return DesktopCard(
                child: EmptyStateCard(
                  icon: Icons.article,
                  title: l10n.userProfileNoPostsTitle,
                  description: l10n.profileNoPostsYetDescription,
                ),
              );
            }

            return Column(
              children: posts
                  .map((post) => _buildPostCard(post, themeProvider))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostCard(CommunityPost post, ThemeProvider themeProvider) {
    return CommunityPostCard(
      post: post,
      accentColor: themeProvider.accentColor,
      onOpenPostDetail: (target) {
        _openDesktopShellAwareScreen(PostDetailScreen(post: target));
      },
    );
  }

  // Helper methods
  Future<void> _handleRefresh() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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
      await CommunityService.loadSavedInteractions(posts);
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

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress ?? '';
    if (wallet.isEmpty) return;

    DAOReview? review;
    try {
      review = Provider.of<DAOProvider>(context, listen: false)
          .findReviewForWallet(wallet);
    } catch (_) {}

    final isArtist = _hasArtistRole(profileProvider, review);
    final isInstitution = _hasInstitutionRole(profileProvider, review);
    if (!(isArtist || isInstitution)) return;
    if (_artistDataLoading && !force) return;
    if (_artistDataRequested && !force) return;

    _artistDataRequested = true;
    await _loadArtistData(wallet, force: force);
  }

  Future<void> _loadArtistData(String walletAddress,
      {bool force = false}) async {
    if (!mounted) return;
    setState(() => _artistDataLoading = true);

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
    } finally {
      if (mounted) setState(() => _artistDataLoading = false);
    }
  }

  Future<void> _loadPrivacySettings() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    try {
      final prefsModel = profileProvider.preferences;
      setState(() => _showActivityStatus = prefsModel.showActivityStatus);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() =>
          _showActivityStatus = prefs.getBool('show_activity_status') ?? true);
    }
  }

  Future<void> _refreshProfileAfterEdit() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final wallet = web3Provider.walletAddress.trim();
    if (!web3Provider.isConnected || wallet.isEmpty) {
      return;
    }

    try {
      await profileProvider.loadProfile(wallet);
    } catch (e) {
      debugPrint(
          'DesktopProfileScreen._refreshProfileAfterEdit loadProfile failed: $e');
    }

    if (!mounted) return;
    setState(() {
      _artistDataRequested = false;
      _artistDataLoaded = false;
    });

    try {
      await _maybeLoadArtistData(force: true);
    } catch (e) {
      debugPrint(
          'DesktopProfileScreen._refreshProfileAfterEdit artist reload failed: $e');
    }
  }

  void _editProfile() async {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        ProfileEditScreen(onSaved: _refreshProfileAfterEdit),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );

    if (result == true && mounted) {
      await _refreshProfileAfterEdit();
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
      sourceScreen: 'desktop_profile',
    );
  }

  void _openDesktopShellAwareScreen(Widget screen) {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
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
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'TBA';
    }
  }

  Widget _buildSocialLinks(
      Map<String, String> social, ThemeProvider themeProvider) {
    final links = <Widget>[];

    if (social['twitter']?.isNotEmpty == true) {
      final handle = social['twitter']!.trim().replaceFirst('@', '');
      links.add(KubusSocialLinkChip(
        icon: Icons.alternate_email,
        label: '@$handle',
        color: const Color(0xFF1DA1F2),
        onTap: () => _openSocialUrl('https://x.com/$handle'),
      ));
    }
    if (social['instagram']?.isNotEmpty == true) {
      final handle = social['instagram']!.trim().replaceFirst('@', '');
      links.add(KubusSocialLinkChip(
        icon: Icons.camera_alt_outlined,
        label: '@$handle',
        color: const Color(0xFFE4405F),
        onTap: () => _openSocialUrl('https://instagram.com/$handle'),
      ));
    }
    if (social['website']?.isNotEmpty == true) {
      final website = social['website'] ?? '';
      if (website.isNotEmpty) {
        final hasScheme =
            website.startsWith('http://') || website.startsWith('https://');
        final url = hasScheme ? website : 'https://$website';
        final displayUrl = website
            .replaceAll(RegExp(r'^https?://'), '')
            .replaceAll(RegExp(r'/$'), '');
        links.add(KubusSocialLinkChip(
          icon: Icons.language,
          label: displayUrl,
          color: themeProvider.accentColor,
          onTap: () => _openSocialUrl(url),
        ));
      }
    }

    if (links.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: KubusSpacing.sm + KubusSpacing.xxs,
      runSpacing: KubusSpacing.xs + KubusSpacing.xxs,
      alignment: WrapAlignment.start,
      children: links,
    );
  }

  Future<void> _openSocialUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.commonActionFailedToast),
        ),
      );
    }
  }
}
