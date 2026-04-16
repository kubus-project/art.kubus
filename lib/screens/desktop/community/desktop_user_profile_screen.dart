import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../utils/category_accent_color.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../../models/user.dart';
import '../../../services/user_service.dart';
import '../../../models/achievement_progress.dart';
import '../../../services/achievement_service.dart' as achievement_svc;
import '../../../services/backend_api_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../services/block_list_service.dart';
import '../../../utils/artwork_navigation.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../community/community_interactions.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/app_refresh_provider.dart';
import '../../../providers/artwork_provider.dart';
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
import '../../../widgets/detail/shared_section_widgets.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/user_profile_navigation.dart';
import '../components/desktop_widgets.dart';
import '../../art/collection_detail_screen.dart';
import '../desktop_shell.dart';
import '../../../config/config.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../activity/advanced_analytics_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import '../../../widgets/common/kubus_glass_icon_button.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/community/community_author_role_badges.dart';

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
  int _publicStreetArtAddedCount = 0;
  List<Map<String, dynamic>> _artistArtworks = [];
  List<Map<String, dynamic>> _artistCollections = [];

  String? _currentWalletAddress() {
    try {
      return Provider.of<WalletProvider>(context, listen: false)
          .currentWalletAddress;
    } catch (_) {
      return null;
    }
  }

  bool _canOpenAnalyticsForViewedUser() {
    final viewedWallet = user?.id.trim() ?? '';
    final viewerWallet = _currentWalletAddress()?.trim() ?? '';
    return viewedWallet.isNotEmpty &&
        WalletUtils.equals(viewerWallet, viewedWallet);
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
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
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
      Provider.of<WalletProvider>(context, listen: false)
          .removeListener(_onWalletChanged);
    } catch (_) {}
    try {
      SocketService().removePostListener(_handleIncomingPost);
    } catch (_) {}
    super.dispose();
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    try {
      if (user == null) return;
      final incomingAuthor =
          (data['walletAddress'] ?? data['author'] ?? data['authorWallet'])
              ?.toString();
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
        await CommunityService.loadSavedInteractions(_posts,
            walletAddress: _currentWalletAddress());
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
    final isCommunityOverlay =
        DesktopProfilePresentationScope.maybeOf(context) ==
            DesktopProfilePresentation.communityOverlay;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = !isCommunityOverlay && screenWidth >= 1200;
    final isWide = !isCommunityOverlay && screenWidth >= 1400;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: AppLoading()),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
    final isArtist = user!.isArtist ||
        (daoReview != null &&
            daoReview.isArtistApplication &&
            daoReview.isApproved);
    final isInstitution = user!.isInstitution ||
        (daoReview != null &&
            daoReview.isInstitutionApplication &&
            daoReview.isApproved);

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
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isCommunityOverlay ? KubusSpacing.lg : (isLarge ? 32 : 24),
                  isCommunityOverlay ? KubusSpacing.lg : 0,
                  isCommunityOverlay ? KubusSpacing.lg : (isLarge ? 32 : 24),
                  isCommunityOverlay
                      ? KubusSpacing.xl
                      : KubusSpacing.lg + KubusSpacing.sm,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isCommunityOverlay ? 860 : 1600,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isCommunityOverlay)
                          _buildOverlayHeader(
                            themeProvider,
                            isArtist,
                            isInstitution,
                            l10n,
                          )
                        else ...[
                          const SizedBox(height: 20),
                          _buildHeader(
                              themeProvider, isArtist, isInstitution, l10n),
                        ],
                        const SizedBox(height: KubusSpacing.lg),
                        _buildProfileCard(
                            themeProvider, isArtist, isInstitution, l10n),
                        const SizedBox(height: 16),
                        // Stats and action buttons in a row on wide screens
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _buildStatsCards(
                                      themeProvider, isLarge, l10n)),
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
              _buildAddedPublicArtSection(themeProvider, l10n),
              const SizedBox(height: 16),
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
        _buildAddedPublicArtSection(themeProvider, l10n),
        const SizedBox(height: 16),
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

  Widget _buildHeader(ThemeProvider themeProvider, bool isArtist,
      bool isInstitution, AppLocalizations l10n) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            // When this screen is shown inside DesktopShellScope (in-shell stack),
            // we must pop the shell stack instead of the app Navigator.
            final shellScope = DesktopShellScope.of(context);
            if (shellScope?.canPop ?? false) {
              shellScope!.popScreen();
              return;
            }
            Navigator.of(context).maybePop();
          },
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
                  style: KubusTextStyles.heroTitle.copyWith(
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
            final targetWallet = user?.id.toString().trim();
            if (targetWallet == null || targetWallet.isEmpty) return;
            ShareService().showShareSheet(
              context,
              target: ShareTarget.profile(
                  walletAddress: targetWallet, title: user?.name),
              sourceScreen: 'desktop_user_profile',
            );
          },
          isPrimary: false,
        ),
        const SizedBox(width: 12),
        if (AppConfig.isFeatureEnabled('analytics') &&
            _canOpenAnalyticsForViewedUser()) ...[
          DesktopActionButton(
            label: l10n.navigationScreenAnalytics,
            icon: Icons.analytics_outlined,
            onPressed: () {
              final wallet = user?.id.toString().trim() ?? '';
              if (wallet.isEmpty) return;
              _openAnalyticsDialog(wallet);
            },
            isPrimary: false,
          ),
          const SizedBox(width: 12),
        ],
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

  Widget _buildOverlayHeader(
    ThemeProvider themeProvider,
    bool isArtist,
    bool isInstitution,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final username = user?.username.trim() ?? '';

    final actions = <Widget>[
      KubusGlassIconButton(
        icon: Icons.share_outlined,
        tooltip: l10n.userProfileShareTooltip,
        onPressed: () {
          final targetWallet = user?.id.toString().trim();
          if (targetWallet == null || targetWallet.isEmpty) return;
          ShareService().showShareSheet(
            context,
            target: ShareTarget.profile(
              walletAddress: targetWallet,
              title: user?.name,
            ),
            sourceScreen: 'desktop_user_profile',
          );
        },
      ),
      if (AppConfig.isFeatureEnabled('analytics') &&
          _canOpenAnalyticsForViewedUser())
        KubusGlassIconButton(
          icon: Icons.analytics_outlined,
          tooltip: l10n.navigationScreenAnalytics,
          onPressed: () {
            final wallet = user?.id.toString().trim() ?? '';
            if (wallet.isEmpty) return;
            _openAnalyticsDialog(wallet);
          },
        ),
      KubusGlassIconButton(
        icon: Icons.more_horiz,
        tooltip: l10n.userProfileMoreTooltip,
        onPressed: _showMoreOptions,
      ),
      KubusGlassIconButton(
        icon: Icons.close,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ];

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      borderRadius: BorderRadius.circular(KubusRadius.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusScreenHeaderBar(
            padding: EdgeInsets.zero,
            compact: true,
            title: user!.name,
            subtitle: username.isEmpty ? null : '@$username',
            actions: actions,
          ),
          if (isArtist || isInstitution) ...[
            const SizedBox(height: KubusSpacing.sm),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.xs,
              children: [
                if (isArtist) const ArtistBadge(),
                if (isInstitution) const InstitutionBadge(),
              ],
            ),
          ],
          const SizedBox(height: KubusSpacing.sm),
          UserActivityStatusLine(
            walletAddress: user!.id,
            textAlign: TextAlign.start,
            textStyle: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
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
                'Open the unified analytics experience and choose the context to land on first.',
                style: KubusTypography.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline, color: scheme.primary),
                title: Text(
                  l10n.profileAnalyticsProfileTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Profile reach, follower growth, views, and public signals.',
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
                  'Community posting and engagement metrics in the same analytics surface.',
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

  Widget _buildProfileCard(ThemeProvider themeProvider, bool isArtist,
      bool isInstitution, AppLocalizations l10n) {
    final coverImageUrl = _normalizeMediaUrl(user!.coverImageUrl);
    final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty;
    const avatarRadius = 44.0;
    const avatarCornerRadiusFactor = AvatarWidget.defaultCornerRadiusFactor;
    const avatarRingPadding = 4.0;

    final avatarRingShapeRadius = AvatarWidget.shapeRadiusFor(
      radius: avatarRadius + avatarRingPadding,
      cornerRadiusFactor: avatarCornerRadiusFactor,
    );

    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Compact cover image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KubusRadius.lg),
                ),
                child: Container(
                  height: hasCoverImage ? 228 : 156,
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
                                    themeProvider.accentColor
                                        .withValues(alpha: 0.3),
                                    themeProvider.accentColor
                                        .withValues(alpha: 0.1),
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(KubusRadius.lg),
                      ),
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
            padding: const EdgeInsets.all(KubusSpacing.md),
            child: LiquidGlassCard(
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.9),
                      borderRadius:
                          BorderRadius.circular(avatarRingShapeRadius),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .shadowColor
                              .withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(avatarRingPadding),
                      child: AvatarWidget(
                        wallet: user!.id,
                        avatarUrl: user!.profileImageUrl,
                        radius: avatarRadius,
                        borderWidth: 0,
                        borderColor: Colors.transparent,
                        cornerRadiusFactor: avatarCornerRadiusFactor,
                        enableProfileNavigation: false,
                        heroTag: widget.heroTag,
                      ),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.md),
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
                                style: KubusTextStyles.screenTitle.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isArtist) ...[
                              const SizedBox(width: KubusSpacing.sm),
                              const ArtistBadge(),
                            ],
                            if (isInstitution) ...[
                              const SizedBox(width: KubusSpacing.sm),
                              const InstitutionBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: KubusSpacing.xs),
                        Text(
                          user!.username,
                          style: KubusTextStyles.profileHandle.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(
                            height: KubusSpacing.xs +
                                KubusSpacing.xs +
                                KubusSpacing.xxs),
                        UserActivityStatusLine(
                          walletAddress: user!.id,
                          textAlign: TextAlign.start,
                          textStyle: KubusTextStyles.detailCaption.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        if (user!.bio.isNotEmpty) ...[
                          const SizedBox(
                              height: KubusSpacing.sm + KubusSpacing.xxs),
                          Text(
                            user!.bio,
                            style: KubusTextStyles.detailBody.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(
                            height: KubusSpacing.sm + KubusSpacing.xxs),
                        ProfileArtistInfoFields(
                          fieldOfWork: user!.fieldOfWork,
                          yearsActive: user!.yearsActive,
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        Text(
                          l10n.userProfileJoinedLabel(user!.joinedDate),
                          style: KubusTextStyles.detailCaption.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
      ThemeProvider themeProvider, bool isLarge, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCols = screenWidth >= 1400 ? 4 : (isLarge ? 4 : 2);
    final artworksCount = Provider.of<ArtworkProvider>(context, listen: true)
        .artworksForWallet(user!.id)
        .length;

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
          color: _profileStatAccentForIcon(Icons.article_outlined),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
        ),
        DesktopStatCard(
          label: l10n.userProfileFollowersStatLabel,
          value: _formatCount(user!.followersCount),
          icon: Icons.people_outline,
          color: _profileStatAccentForIcon(Icons.people_outline),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
          onTap: () {
            ProfileScreenMethods.showFollowers(
              context,
              walletAddress: user!.id,
            );
          },
        ),
        DesktopStatCard(
          label: l10n.userProfileFollowingStatLabel,
          value: _formatCount(user!.followingCount),
          icon: Icons.person_add_outlined,
          color: _profileStatAccentForIcon(Icons.person_add_outlined),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
          onTap: () {
            ProfileScreenMethods.showFollowing(
              context,
              walletAddress: user!.id,
            );
          },
        ),
        DesktopStatCard(
          label: l10n.userProfileArtworksTitle,
          value: _formatCount(artworksCount),
          icon: Icons.palette_outlined,
          color: _profileStatAccentForIcon(Icons.palette_outlined),
          centeredWatermarkAlignment: Alignment.center,
          centeredWatermarkScale: 0.84,
          onTap: () {
            ProfileScreenMethods.showArtworks(
              context,
              walletAddress: user!.id,
            );
          },
        ),
      ],
    );
  }

  Color _profileStatAccentForIcon(IconData icon) {
    final roles = KubusColorRoles.of(context);
    final codePoint = icon.codePoint;

    if (codePoint == Icons.palette.codePoint ||
        codePoint == Icons.palette_outlined.codePoint) {
      return roles.web3ArtistStudioAccent;
    }
    if (codePoint == Icons.article.codePoint ||
        codePoint == Icons.article_outlined.codePoint) {
      return roles.statBlue;
    }
    if (codePoint == Icons.people.codePoint ||
        codePoint == Icons.people_outline.codePoint) {
      return roles.statCoral;
    }
    if (codePoint == Icons.person_add.codePoint ||
        codePoint == Icons.person_add_outlined.codePoint) {
      return roles.statTeal;
    }

    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildActionButtons(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(
                  parent: _followButtonController, curve: Curves.easeInOut),
            ),
            child: DesktopActionButton(
              label: user!.isFollowing
                  ? l10n.userProfileFollowingButton
                  : l10n.userProfileFollowButton,
              icon: user!.isFollowing
                  ? Icons.person_remove_outlined
                  : Icons.person_add_outlined,
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

  Widget _buildAddedPublicArtSection(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    return DesktopCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            child: Icon(
              Icons.streetview,
              color: themeProvider.accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profilePerformancePublicStreetArtAddedTitle,
                  style: KubusTextStyles.detailCardTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  l10n.userProfileArtistHighlightsSubtitle(user!.name),
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCount(_publicStreetArtAddedCount),
            style: KubusTextStyles.statValue.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistPortfolioSection(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileArtistPortfolioTitle,
          subtitle: l10n.userProfileArtistPortfolioDesktopSubtitle,
          icon: Icons.palette,
        ),
        const SizedBox(height: KubusSpacing.md),
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
              separatorBuilder: (_, __) =>
                  const SizedBox(width: KubusSpacing.md),
              itemBuilder: (context, index) =>
                  _buildArtworkShowcaseCard(_artistArtworks[index], l10n),
            ),
          ),
      ],
    );
  }

  Widget _buildArtistCollectionsSection(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    final name = (user?.name ?? '').trim();
    final labelName = name.isEmpty ? widget.userId.trim() : name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileCollectionsTitle,
          subtitle: l10n.userProfileCollectionsDesktopSubtitle,
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
              title: l10n.userProfileNoCollectionsTitle,
              description: l10n.userProfileNoCollectionsYetLabel(labelName),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artistCollections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) =>
                  _buildCollectionShowcaseCard(_artistCollections[index], l10n),
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionHighlightsSection(
      ThemeProvider themeProvider, AppLocalizations l10n) {
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
                  style: KubusTypography.inter(
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
                    itemBuilder: (context, index) =>
                        _buildArtworkShowcaseCard(_artistArtworks[index], l10n),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_artistCollections.isNotEmpty) ...[
                Text(
                  'Collections',
                  style: KubusTypography.inter(
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
                    itemBuilder: (context, index) =>
                        _buildCollectionShowcaseCard(
                            _artistCollections[index], l10n),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildArtworkShowcaseCard(
      Map<String, dynamic> data, AppLocalizations l10n) {
    final imageUrl = _extractImageUrl(
        data, ['imageUrl', 'image', 'previewUrl', 'coverImage', 'mediaUrl']);
    final title =
        (data['title'] ?? data['name'] ?? l10n.commonUntitled).toString();
    final category =
        (data['category'] ?? data['medium'] ?? l10n.commonArtwork).toString();
    final artworkId =
        (data['id'] ?? data['artwork_id'] ?? data['artworkId'])?.toString();
    final likesCount = data['likesCount'] ?? data['likes'] ?? 0;

    return SharedShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: category,
      footer: '$likesCount',
      onTap: artworkId != null
          ? () {
              openArtwork(context, artworkId, source: 'desktop_user_profile');
            }
          : null,
      width: 220,
      imageHeight: 160,
      titleStyle: KubusTypography.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      subtitleStyle: KubusTypography.inter(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      footerStyle: KubusTypography.inter(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildCollectionShowcaseCard(
      Map<String, dynamic> data, AppLocalizations l10n) {
    final imageUrl = _extractImageUrl(data, [
      'thumbnailUrl',
      'coverImage',
      'coverImageUrl',
      'cover_image_url',
      'coverUrl',
      'cover_url',
      'image',
    ]);
    final title =
        (data['name'] ?? l10n.userProfileCollectionFallbackTitle).toString();
    final count = data['artworksCount'] ?? data['artworks_count'] ?? 0;
    final description = (data['description'] ?? '').toString();
    final collectionId =
        (data['id'] ?? data['collection_id'] ?? data['collectionId'])
            ?.toString();

    return SharedShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: l10n.userProfileArtworksCountLabel(count as int),
      footer: description.isNotEmpty ? description : null,
      onTap: (collectionId != null && collectionId.isNotEmpty)
          ? () {
              _openDesktopShellAwareScreen(
                CollectionDetailScreen(collectionId: collectionId),
              );
            }
          : null,
      width: 200,
      imageHeight: 120,
      placeholderIcon: Icons.collections_outlined,
      titleStyle: KubusTypography.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      subtitleStyle: KubusTypography.inter(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      footerStyle: KubusTypography.inter(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildAchievementsSection(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    final progress = user?.achievementProgress ?? [];
    final achievementsToShow = achievement_svc
        .AchievementService.achievementDefinitions.values
        .take(6)
        .toList();
    if (achievementsToShow.isEmpty) return const SizedBox.shrink();

    final progressById = <String, AchievementProgress>{
      for (final entry in progress) entry.achievementId: entry,
    };
    final completedCount = achievement_svc
        .AchievementService.achievementDefinitions.values
        .where((achievement) {
      final current = progressById[achievement.id];
      final required =
          achievement.requiredCount > 0 ? achievement.requiredCount : 1;
      return (current?.isCompleted ?? false) ||
          (current != null && current.currentProgress >= required);
    }).length;
    final totalAchievements =
        achievement_svc.AchievementService.achievementDefinitions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.userProfileAchievementsTitle,
          subtitle: l10n.userProfileAchievementsProgressLabel(
              completedCount, totalAchievements),
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
              final achievementProgress = progressById[achievement.id] ??
                  AchievementProgress(
                    achievementId: achievement.id,
                    currentProgress: 0,
                    isCompleted: false,
                  );
              return _buildAchievementCard(achievement, achievementProgress);
            }).toList(),
          ),
      ],
    );
  }

  String _categoryForAchievement(achievement_svc.AchievementDefinition def) {
    if (def.isPOAP) return 'Events';
    switch (def.type) {
      case achievement_svc.AchievementType.firstDiscovery:
      case achievement_svc.AchievementType.artExplorer:
      case achievement_svc.AchievementType.artMaster:
      case achievement_svc.AchievementType.artLegend:
        return 'Discovery';
      case achievement_svc.AchievementType.firstARView:
      case achievement_svc.AchievementType.arEnthusiast:
      case achievement_svc.AchievementType.arPro:
        return 'AR';
      case achievement_svc.AchievementType.firstNFTMint:
      case achievement_svc.AchievementType.nftCollector:
      case achievement_svc.AchievementType.nftTrader:
        return 'NFT';
      case achievement_svc.AchievementType.firstPost:
      case achievement_svc.AchievementType.influencer:
      case achievement_svc.AchievementType.communityBuilder:
        return 'Community';
      case achievement_svc.AchievementType.firstLike:
      case achievement_svc.AchievementType.popularCreator:
      case achievement_svc.AchievementType.firstComment:
      case achievement_svc.AchievementType.commentator:
        return 'Social';
      case achievement_svc.AchievementType.firstTrade:
      case achievement_svc.AchievementType.smartTrader:
      case achievement_svc.AchievementType.marketMaster:
        return 'Trading';
      case achievement_svc.AchievementType.earlyAdopter:
      case achievement_svc.AchievementType.betaTester:
      case achievement_svc.AchievementType.artSupporter:
        return 'Special';
      case achievement_svc.AchievementType.eventAttendee:
      case achievement_svc.AchievementType.galleryVisitor:
      case achievement_svc.AchievementType.workshopParticipant:
        return 'Events';
      case achievement_svc.AchievementType.streetArtSpotter:
      case achievement_svc.AchievementType.streetArtScout:
      case achievement_svc.AchievementType.streetArtCurator:
      case achievement_svc.AchievementType.streetArtPatron:
        return AppLocalizations.of(context)!
            .userProfileAchievementCategoryStreetArt;
    }
  }

  IconData _iconForAchievement(achievement_svc.AchievementDefinition def) {
    if (def.isPOAP) return Icons.verified;
    switch (def.type) {
      case achievement_svc.AchievementType.firstDiscovery:
      case achievement_svc.AchievementType.artExplorer:
      case achievement_svc.AchievementType.artMaster:
      case achievement_svc.AchievementType.artLegend:
        return Icons.explore_outlined;
      case achievement_svc.AchievementType.firstARView:
      case achievement_svc.AchievementType.arEnthusiast:
      case achievement_svc.AchievementType.arPro:
        return Icons.view_in_ar;
      case achievement_svc.AchievementType.firstNFTMint:
      case achievement_svc.AchievementType.nftCollector:
      case achievement_svc.AchievementType.nftTrader:
        return Icons.token;
      case achievement_svc.AchievementType.firstPost:
      case achievement_svc.AchievementType.influencer:
      case achievement_svc.AchievementType.communityBuilder:
        return Icons.forum_outlined;
      case achievement_svc.AchievementType.firstLike:
      case achievement_svc.AchievementType.popularCreator:
        return Icons.favorite_border;
      case achievement_svc.AchievementType.firstComment:
      case achievement_svc.AchievementType.commentator:
        return Icons.chat_bubble_outline;
      case achievement_svc.AchievementType.firstTrade:
      case achievement_svc.AchievementType.smartTrader:
      case achievement_svc.AchievementType.marketMaster:
        return Icons.swap_horiz;
      case achievement_svc.AchievementType.earlyAdopter:
      case achievement_svc.AchievementType.betaTester:
      case achievement_svc.AchievementType.artSupporter:
        return Icons.auto_awesome;
      case achievement_svc.AchievementType.eventAttendee:
      case achievement_svc.AchievementType.galleryVisitor:
      case achievement_svc.AchievementType.workshopParticipant:
        return Icons.event_available;
      case achievement_svc.AchievementType.streetArtSpotter:
      case achievement_svc.AchievementType.streetArtScout:
      case achievement_svc.AchievementType.streetArtCurator:
      case achievement_svc.AchievementType.streetArtPatron:
        return Icons.streetview;
    }
  }

  Widget _buildAchievementCard(
    achievement_svc.AchievementDefinition achievement,
    AchievementProgress progress,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final required =
        achievement.requiredCount > 0 ? achievement.requiredCount : 1;
    final ratio = (progress.currentProgress / required).clamp(0.0, 1.0);
    final isCompleted = progress.isCompleted || ratio >= 1.0;
    final accent = CategoryAccentColor.resolve(
      context,
      _categoryForAchievement(achievement),
    );

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(_iconForAchievement(achievement),
                    color: accent, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: Text(
                  '+${achievement.tokenReward}',
                  style: KubusTypography.inter(
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
            style: KubusTypography.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? l10n.userProfileAchievementCompletedLabel
                : '${progress.currentProgress}/$required',
            style: KubusTypography.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? themeProvider.accentColor
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? themeProvider.accentColor : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection(
      ThemeProvider themeProvider, AppLocalizations l10n) {
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
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                )
              else if (_isLastPage)
                Container(
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.userProfileNoMorePostsLabel,
                    style: KubusTypography.inter(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
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
          _openDesktopShellAwareScreen(PostDetailScreen(post: post));
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
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              post.authorName,
                              style: KubusTypography.inter(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          CommunityAuthorRoleBadges(
                            post: post,
                            fontSize: 9,
                            iconOnly: true,
                            spacing: 8,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPostTime(
                            AppLocalizations.of(context)!, post.timestamp),
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post.content,
              style: KubusTypography.inter(
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
                borderRadius: BorderRadius.circular(KubusRadius.md),
                child: Image.network(
                  MediaUrlResolver.resolveDisplayUrl(post.imageUrl) ??
                      _normalizeMediaUrl(post.imageUrl) ??
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
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  post.likeCount.toString(),
                  style: KubusTypography.inter(
                    fontSize: 14,
                    color: post.isLiked
                        ? themeProvider.accentColor
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 24),
                Icon(
                  Icons.comment_outlined,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  post.commentCount.toString(),
                  style: KubusTypography.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
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
    await _loadUser(
      showFullScreenLoader: false,
      forceModalPrefetch: true,
    );
  }

  Future<void> _loadUser({
    bool showFullScreenLoader = true,
    bool forceModalPrefetch = false,
  }) async {
    if (showFullScreenLoader) setState(() => isLoading = true);

    final targetId = widget.userId.trim();

    if (widget.username == null && targetId.isNotEmpty) {
      try {
        final cached = UserService.getCachedUser(targetId);
        if (cached != null) {
          setState(() {
            user = cached;
            isLoading = false;
          });

          try {
            Future(() async {
              final fresh = await UserService.getUserById(
                targetId,
                forceRefresh: true,
              );
              if (!mounted) return;
              if (fresh != null && WalletUtils.equals(fresh.id, targetId)) {
                setState(() {
                  user = fresh;
                });
              }
            });
          } catch (_) {}
        }
      } catch (_) {}
    }

    User? loadedUser;
    try {
      if (widget.username != null) {
        loadedUser = await UserService.getUserByUsername(widget.username!);
      } else {
        loadedUser = await UserService.getUserById(
          targetId,
          forceRefresh: false,
        );
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
      final prefetchFuture = ProfileScreenMethods.prefetchOtherUserProfileData(
        context,
        walletAddress: user!.id,
        force: forceModalPrefetch,
        prefetchStatsSnapshot: false,
      );
      if (forceModalPrefetch) {
        await prefetchFuture;
      } else {
        unawaited(prefetchFuture);
      }
    } catch (_) {}

    try {
      UserService.fetchAndUpdateUserStats(user!.id);
    } catch (_) {}

    await _loadUserStats(forceRefresh: true);
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
        await CommunityService.loadSavedInteractions(posts,
            walletAddress: _currentWalletAddress());
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
        await CommunityService.loadSavedInteractions(more,
            walletAddress: _currentWalletAddress());
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

  Future<void> _loadUserStats(
      {bool skipFollowersOverwrite = false, bool forceRefresh = false}) async {
    final profile = user;
    if (profile == null) return;

    try {
      final statsProvider = context.read<StatsProvider>();
      final snapshot = await statsProvider.ensureSnapshot(
        entityType: 'user',
        entityId: profile.id,
        metrics: const [
          'posts',
          'followers',
          'following',
          'publicStreetArtAdded'
        ],
        scope: 'public',
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        final counters = snapshot?.counters ?? const <String, int>{};
        final fetchedPosts = counters['posts'] ?? 0;
        final fetchedFollowers = counters['followers'] ?? 0;
        final fetchedFollowing = counters['following'] ?? 0;
        final fetchedStreetArtAdded = counters['publicStreetArtAdded'] ?? 0;

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
        _publicStreetArtAddedCount = fetchedStreetArtAdded;
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
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('401')
                ? l10n.userProfileSignInToFollowToast
                : l10n.userProfileFollowUpdateFailedToast,
          ),
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

    if (mounted) {
      messenger.showKubusSnackBar(
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
    if (!mounted) return;
    try {
      unawaited(ProfileScreenMethods.prefetchOtherUserProfileData(
        context,
        walletAddress: user!.id,
        force: true,
        prefetchStatsSnapshot: false,
      ));
    } catch (_) {}
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
        final preloaded =
            chatProvider.getPreloadedProfileMapsForConversation(conv.id);
        final rawMembers =
            (preloaded['members'] as List<dynamic>?)?.cast<String>() ??
                <String>[];
        final members = rawMembers.isNotEmpty ? rawMembers : <String>[user!.id];
        final avatars = Map<String, String?>.from(
            (preloaded['avatars'] as Map<String, String?>?) ??
                <String, String?>{});
        if (!avatars.containsKey(members.first) ||
            (avatars[members.first]?.isEmpty ?? true)) {
          avatars[members.first] = user!.profileImageUrl;
        }
        final names = Map<String, String?>.from(
            (preloaded['names'] as Map<String, String?>?) ??
                <String, String?>{});
        if (!names.containsKey(members.first) ||
            (names[members.first]?.isEmpty ?? true)) {
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
          messenger.showKubusSnackBar(
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
      messenger.showKubusSnackBar(SnackBar(
          content: Text(l10n.userProfileConversationOpenGenericErrorToast)));
    }
  }

  void _showMoreOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
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
                ScaffoldMessenger.of(context).showKubusSnackBar(
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
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.userProfileUnableToBlockToast)),
      );
      return;
    }

    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          l10n.userProfileBlockDialogTitle(user?.name ?? targetWallet),
          style: KubusTypography.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.userProfileBlockDialogDescription,
          style: KubusTypography.inter(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
                debugPrint(
                    'DesktopUserProfileScreen: failed to block user: $e');
                if (!mounted) return;
                Navigator.pop(context);
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.userProfileBlockFailedToast)));
                return;
              }

              if (!mounted) return;
              Navigator.pop(context);
              messenger.showKubusSnackBar(
                SnackBar(
                  content: Text(
                      l10n.userProfileBlockedToast(user?.name ?? targetWallet)),
                  action: SnackBarAction(
                    label: l10n.commonUndo,
                    onPressed: () =>
                        BlockListService().unblockWallet(targetWallet),
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
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          l10n.userProfileReportDialogTitle(user?.name ?? ''),
          style: KubusTypography.inter(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.userProfileReportReasonSpam),
              onTap: () => _submitReport(
                  dialogContext, l10n.userProfileReportReasonSpam),
            ),
            ListTile(
              title: Text(l10n.userProfileReportReasonInappropriate),
              onTap: () => _submitReport(
                  dialogContext, l10n.userProfileReportReasonInappropriate),
            ),
            ListTile(
              title: Text(l10n.userProfileReportReasonHarassment),
              onTap: () => _submitReport(
                  dialogContext, l10n.userProfileReportReasonHarassment),
            ),
            ListTile(
              title: Text(l10n.userProfileReportReasonOther),
              onTap: () => _submitReport(
                  dialogContext, l10n.userProfileReportReasonOther),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(BuildContext dialogContext, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final targetWallet = WalletUtils.canonical(user?.id ?? widget.userId);

    Navigator.pop(dialogContext);

    if (targetWallet.isEmpty) {
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    try {
      await CommunityService.reportUser(targetWallet, reason,
          details: user?.name);
      if (!mounted) return;
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.userProfileReportSubmittedToast)));
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
    }
  }

  Future<void> _maybeLoadArtistData({bool force = false}) async {
    final isCreator =
        (user?.isArtist ?? false) || (user?.isInstitution ?? false);
    if (!isCreator) return;
    if (_artistDataLoading && !force) return;
    if (_artistDataRequested && !force) return;

    _artistDataRequested = true;
    await _loadArtistData(user!.id, force: force);
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
