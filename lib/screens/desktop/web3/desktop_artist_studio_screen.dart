import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'dart:async';
import '../../../providers/themeprovider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/analytics_filters_provider.dart';
import '../../../providers/desktop_dashboard_state_provider.dart';
import '../../../config/config.dart';
import '../../../models/dao.dart';
import '../../../models/promotion.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/dao_role_verification.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../utils/wallet_utils.dart';
import '../desktop_shell.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../web3/artist/artist_studio.dart';
import '../../web3/artist/artist_portfolio_screen.dart';
import '../../web3/artist/artist_analytics.dart';
import '../../events/exhibition_list_screen.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/forms/kubus_form.dart';
import '../../../widgets/promotion/promotion_builder_sheet.dart';

/// Desktop Artist Studio screen with split-panel layout
/// Left: Mobile artist studio view
/// Right: Quick actions, stats, and analytics
class DesktopArtistStudioScreen extends StatefulWidget {
  const DesktopArtistStudioScreen({super.key});

  @override
  State<DesktopArtistStudioScreen> createState() =>
      _DesktopArtistStudioScreenState();
}

class _DesktopArtistStudioScreenState extends State<DesktopArtistStudioScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  DAOReview? _artistReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';

  String _lastStatsWallet = '';

  void _openArtworkWorkspace() {
    unawaited(CreatorShellNavigation.openArtworkCreatorWorkspace(context));
  }

  void _openCollectionWorkspace() {
    unawaited(CreatorShellNavigation.openCollectionCreatorWorkspace(context));
  }

  void _openExhibitionWorkspace() {
    unawaited(CreatorShellNavigation.openExhibitionCreatorWorkspace(context));
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArtistReviewStatus(forceRefresh: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = _resolveWalletAddress(listen: true);
    final walletChanged = wallet != _lastReviewWallet;
    if (!walletChanged && _hasFetchedReviewForWallet) return;

    if (wallet.isNotEmpty) {
      _loadArtistReviewStatus(forceRefresh: true);
    }

    // StatsProvider.ensureSnapshot() notifies listeners; calling it during build
    // (e.g. from a widget build method) can trigger "setState/markNeedsBuild"
    // exceptions. Schedule the refresh post-frame when the wallet changes.
    final statsWalletChanged = wallet != _lastStatsWallet;
    if (wallet.isEmpty) {
      _lastStatsWallet = '';
    } else if (statsWalletChanged) {
      _lastStatsWallet = wallet;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final statsProvider = context.read<StatsProvider>();
        unawaited(statsProvider.ensureSnapshot(
          entityType: 'user',
          entityId: wallet,
          metrics: _studioMetrics,
          scope: 'public',
        ));
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _resolveWalletAddress({bool listen = false}) {
    final profileProvider = listen
        ? context.watch<ProfileProvider>()
        : context.read<ProfileProvider>();
    final web3Provider =
        listen ? context.watch<Web3Provider>() : context.read<Web3Provider>();
    return WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
  }

  Future<void> _loadArtistReviewStatus({bool forceRefresh = false}) async {
    final wallet = _resolveWalletAddress();
    if (wallet.isEmpty || _reviewLoading) return;
    if (!forceRefresh &&
        _hasFetchedReviewForWallet &&
        wallet == _lastReviewWallet) {
      return;
    }

    final requestedWallet = wallet;
    setState(() {
      _reviewLoading = true;
      _lastReviewWallet = requestedWallet;
    });

    try {
      final daoProvider = context.read<DAOProvider>();
      final review = await daoProvider.loadReviewForWallet(requestedWallet,
          forceRefresh: forceRefresh);
      if (!mounted || requestedWallet != _lastReviewWallet) return;

      setState(() {
        _artistReview =
            review ?? daoProvider.findReviewForWallet(requestedWallet);
        _hasFetchedReviewForWallet = true;
        _reviewLoading = false;
      });
    } catch (e) {
      if (!mounted || requestedWallet != _lastReviewWallet) return;
      setState(() {
        _reviewLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Mobile artist studio view (wrapped)
                Expanded(
                  flex: isLarge ? 2 : 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: ArtistStudio(
                      embedded: true,
                      showVerificationCard: false,
                      onOpenArtworkCreator: _openArtworkWorkspace,
                      onOpenCollectionCreator: _openCollectionWorkspace,
                      onOpenExhibitionCreator: _openExhibitionWorkspace,
                      onTabChanged: (tabIndex) {
                        context
                            .read<DesktopDashboardStateProvider>()
                            .updateArtistStudioSectionFromTabIndex(
                              tabIndex: tabIndex,
                              exhibitionsEnabled:
                                  AppConfig.isFeatureEnabled('exhibitions'),
                            );
                      },
                    ),
                  ),
                ),

                // Right: Quick actions, stats, and analytics
                if (isLarge)
                  SizedBox(
                    width: 380,
                    child: _buildRightPanel(themeProvider),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Side panel hierarchy: status, PRACTICE actions (works, publishing,
  /// exhibitions, collaborations, insights), NUMBERS (real backend counters
  /// only), then INFRASTRUCTURE (paid promotion). No token balance, no
  /// watermark stat grid, no placeholder activity.
  Widget _buildRightPanel(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    const sectionGap = KubusSpacing.xl;
    final dashboardState = context.watch<DesktopDashboardStateProvider>();
    final section = dashboardState.artistStudioSection;

    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _artistReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final isApprovedArtist = verification.isApprovedFor(DaoRoleType.artist);

    String sectionTitle() {
      switch (section) {
        case DesktopArtistStudioSection.gallery:
          return l10n.artistStudioTabGallery;
        case DesktopArtistStudioSection.create:
          return l10n.artistStudioTabCreate;
        case DesktopArtistStudioSection.exhibitions:
          return l10n.artistStudioTabExhibitions;
        case DesktopArtistStudioSection.analytics:
          return l10n.artistStudioTabAnalytics;
      }
    }

    final showExhibitions = AppConfig.isFeatureEnabled('exhibitions');

    final practice = <Widget>[
      if (isApprovedArtist && section == DesktopArtistStudioSection.create) ...[
        KubusButton(
          onPressed: _openArtworkWorkspace,
          icon: Icons.add_photo_alternate_outlined,
          label: l10n.desktopArtistStudioQuickActionCreateArtworkTitle,
          isFullWidth: true,
        ),
        KubusButton(
          onPressed: _openCollectionWorkspace,
          icon: Icons.collections_bookmark_outlined,
          label: l10n.collectionCreatorTitle,
          isFullWidth: true,
          variant: KubusButtonVariant.secondary,
        ),
        if (showExhibitions)
          KubusButton(
            onPressed: _openExhibitionWorkspace,
            icon: AppColorUtils.exhibitionIcon,
            label: l10n.exhibitionCreatorAppBarTitle,
            isFullWidth: true,
            variant: KubusButtonVariant.secondary,
          ),
        KubusActionSidebarTile(
          title: l10n.manageMarkersTitle,
          subtitle: l10n.manageMarkersQuickActionSubtitle,
          icon: Icons.place_outlined,
          semantic: KubusActionSemantic.manage,
          onTap: () {
            unawaited(
              CreatorShellNavigation.openManageMarkersWorkspace(context),
            );
          },
        ),
      ],
      if (isApprovedArtist && section == DesktopArtistStudioSection.gallery)
        KubusActionSidebarTile(
          title: l10n.desktopArtistStudioQuickActionMyGalleryTitle,
          subtitle: l10n.desktopArtistStudioQuickActionMyGallerySubtitle,
          icon: Icons.collections_outlined,
          semantic: KubusActionSemantic.view,
          onTap: () {
            final wallet = _resolveWalletAddress(listen: false);
            DesktopShellScope.of(context)?.pushScreen(
              DesktopSubScreen(
                title: l10n.desktopArtistStudioQuickActionMyGalleryTitle,
                child: ArtistPortfolioScreen(walletAddress: wallet),
              ),
            );
          },
        ),
      if (isApprovedArtist &&
          showExhibitions &&
          section == DesktopArtistStudioSection.exhibitions)
        KubusActionSidebarTile(
          title: l10n.desktopArtistStudioQuickActionExhibitionsTitle,
          subtitle: l10n.desktopArtistStudioQuickActionExhibitionsSubtitle,
          icon: AppColorUtils.exhibitionIcon,
          semantic: KubusActionSemantic.view,
          onTap: () {
            DesktopShellScope.of(context)?.pushScreen(
              DesktopSubScreen(
                title: l10n.desktopArtistStudioQuickActionExhibitionsTitle,
                child: ExhibitionListScreen(
                  embedded: true,
                  canCreate: true,
                  onCreateExhibition: () {
                    _openExhibitionWorkspace();
                  },
                  onOpenExhibition: (exhibition) {
                    unawaited(
                      CreatorShellNavigation.openExhibitionDetailWorkspace(
                        context,
                        exhibitionId: exhibition.id,
                        initialExhibition: exhibition,
                        titleOverride: exhibition.title,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      if (AppConfig.isFeatureEnabled('collabInvites'))
        Consumer<CollabProvider>(
          builder: (context, collabProvider, _) {
            final pending = collabProvider.pendingInviteCount;
            return KubusActionSidebarTile(
              title: l10n.desktopArtistStudioQuickActionInvitesTitle,
              subtitle: pending > 0
                  ? l10n.desktopArtistStudioQuickActionInvitesPendingSubtitle
                  : l10n.desktopArtistStudioQuickActionInvitesSubtitle,
              icon: Icons.inbox_outlined,
              semantic: KubusActionSemantic.invite,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n
                        .desktopArtistStudioQuickActionCollaborationInvitesTitle,
                    child: const InvitesInboxScreen(embedded: true),
                  ),
                );
              },
              trailing: pending > 0 ? KubusCountBadge(count: pending) : null,
            );
          },
        ),
      if (isApprovedArtist && section == DesktopArtistStudioSection.analytics)
        KubusActionSidebarTile(
          title: l10n.desktopArtistStudioQuickActionAnalyticsTitle,
          subtitle: l10n.desktopArtistStudioQuickActionAnalyticsSubtitle,
          icon: Icons.analytics_outlined,
          semantic: KubusActionSemantic.analytics,
          onTap: () {
            DesktopShellScope.of(context)?.pushScreen(
              DesktopSubScreen(
                title: l10n.desktopArtistStudioQuickActionAnalyticsTitle,
                child: const ArtistAnalytics(),
              ),
            );
          },
        ),
      if (section == DesktopArtistStudioSection.analytics)
        _buildAnalyticsTimeframeSelector(
          title: l10n.analyticsTimeframeLabel,
          value: context.watch<AnalyticsFiltersProvider>().artistTimeframe,
          onChanged: (v) =>
              context.read<AnalyticsFiltersProvider>().setArtistTimeframe(v),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.ground,
        border: Border(left: BorderSide(color: roles.rule)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        children: [
          KubusNotionLabel(l10n.studioNotionPractice),
          const SizedBox(height: KubusSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              l10n.desktopArtistStudioOverviewTitle,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: roles.foreground,
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            sectionTitle(),
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildVerificationStatusCard(themeProvider),
          const SizedBox(height: sectionGap),
          if (practice.isNotEmpty) ...[
            KubusPanelSection(
              notion: l10n.desktopArtistStudioQuickActionsTitle,
              children: practice,
            ),
            const SizedBox(height: sectionGap),
          ],
          KubusPanelSection(
            notion: l10n.dashboardNotionNumbers,
            caption: l10n.dashboardNumbersCaption,
            children: [_buildStatsGrid()],
          ),
          if (isApprovedArtist) ...[
            const SizedBox(height: sectionGap),
            KubusPanelSection(
              notion: l10n.dashboardNotionInfrastructure,
              children: [
                KubusActionSidebarTile(
                  title: l10n.desktopArtistStudioPromoteProfileTitle,
                  subtitle: l10n.desktopArtistStudioPromoteProfileSubtitle,
                  icon: Icons.campaign_outlined,
                  semantic: KubusActionSemantic.publish,
                  onTap: _openProfilePromotionFlow,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsTimeframeSelector({
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final normalized = value.trim().toLowerCase();
    final effective =
        AnalyticsFiltersProvider.allowedTimeframes.contains(normalized)
            ? normalized
            : '30d';
    return KubusFormSelect<String>(
      label: title,
      value: effective,
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
      items: AnalyticsFiltersProvider.allowedTimeframes
          .map((tf) => DropdownMenuItem<String>(value: tf, child: Text(tf)))
          .toList(growable: false),
    );
  }

  Future<void> _openProfilePromotionFlow() async {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.read<ProfileProvider>().currentUser;
    final wallet = _resolveWalletAddress(listen: false);
    final entityId = WalletUtils.coalesce(
      walletAddress: profile?.walletAddress,
      wallet: wallet,
    ).trim();
    if (entityId.isEmpty) return;

    await showPromotionBuilderSheet(
      context: context,
      entityType: PromotionEntityType.profile,
      entityId: entityId,
      entityLabel: profile?.displayName ?? l10n.desktopArtistStudioMyProfile,
    );
  }

  Widget _buildVerificationStatusCard(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final wallet = _resolveWalletAddress();
    final daoProvider = context.watch<DAOProvider>();
    final review = _artistReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final isApproved = verification.isApprovedFor(DaoRoleType.artist);
    final isPending = verification.isPendingFor(DaoRoleType.artist);
    final isRejected = verification.isRejectedFor(DaoRoleType.artist);

    var tone = KubusStatusTone.neutral;
    var statusText = l10n.desktopArtistStudioVerificationNotAppliedTitle;
    var statusDescription =
        l10n.desktopArtistStudioVerificationNotAppliedDescription;

    if (_reviewLoading) {
      statusText = l10n.desktopArtistStudioVerificationLoadingTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationLoadingDescription;
    } else if (isApproved) {
      tone = KubusStatusTone.positive;
      statusText = l10n.desktopArtistStudioVerificationApprovedTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationApprovedDescription;
    } else if (isPending) {
      tone = KubusStatusTone.warning;
      statusText = l10n.desktopArtistStudioVerificationPendingTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationPendingDescription;
    } else if (isRejected) {
      tone = KubusStatusTone.negative;
      statusText = l10n.desktopArtistStudioVerificationRejectedTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationRejectedDescription;
    }

    return KubusStatusPanel(
      margin: EdgeInsets.zero,
      title: statusText,
      description: statusDescription,
      tone: tone,
      isLoading: _reviewLoading,
      // No detail line: the real "apply" action lives in the main pane;
      // repeating its button label here read as a dead button.
    );
  }

  /// Real backend counters only (`/api/stats` user snapshot): artworks
  /// created, views and likes received on those artworks. The former
  /// fourth tile ("Sales", KUB8) read `achievementTokensTotal`, which is the
  /// sum of achievement reward definitions, not sales; it is removed.
  Widget _buildStatsGrid() {
    final l10n = AppLocalizations.of(context)!;
    final statsProvider = context.watch<StatsProvider>();
    final wallet = _resolveWalletAddress(listen: true);

    final snapshot = wallet.isEmpty
        ? null
        : statsProvider.getSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: _studioMetrics,
            scope: 'public',
          );
    final isLoading = wallet.isNotEmpty &&
        statsProvider.isSnapshotLoading(
          entityType: 'user',
          entityId: wallet,
          metrics: _studioMetrics,
          scope: 'public',
        ) &&
        snapshot == null;

    final counters = snapshot?.counters ?? const <String, int>{};
    String display(String key) {
      if (isLoading) return '…';
      if (wallet.isEmpty) return '—';
      return (counters[key] ?? 0).toString();
    }

    // One height per row, even when a label wraps to two lines.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: KubusSidebarStatCard(
              title: l10n.desktopArtistStudioStatArtworks,
              value: display('artworks'),
              icon: Icons.collections_outlined,
              accent: KubusColorRoles.of(context).foregroundMuted,
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: KubusSidebarStatCard(
              title: l10n.desktopArtistStudioStatViews,
              value: display('viewsReceived'),
              icon: Icons.visibility_outlined,
              accent: KubusColorRoles.of(context).foregroundMuted,
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: KubusSidebarStatCard(
              title: l10n.desktopArtistStudioStatLikes,
              value: display('likesReceived'),
              icon: Icons.favorite_outline,
              accent: KubusColorRoles.of(context).foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metrics the Studio side panel reads. Only real backend counters.
const List<String> _studioMetrics = <String>[
  'artworks',
  'viewsReceived',
  'likesReceived',
];
