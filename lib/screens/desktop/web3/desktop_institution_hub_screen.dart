import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
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
import '../../../models/user_persona.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/dao_role_verification.dart';
import '../../../utils/wallet_utils.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../web3/institution/institution_hub.dart';
import '../../web3/institution/event_creator.dart';
import '../../web3/institution/event_manager.dart';
import '../../web3/institution/institution_analytics.dart';
import '../../events/exhibition_creator_screen.dart';
import '../../events/exhibition_detail_screen.dart';
import '../../events/exhibition_list_screen.dart';
import '../../map_markers/manage_markers_screen.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/kubus_snackbar.dart';
import '../../../widgets/promotion/promotion_builder_sheet.dart';

/// Desktop Institution Hub screen with split-panel layout
/// Left: Mobile institution hub view
/// Right: Quick actions, stats, and analytics
class DesktopInstitutionHubScreen extends StatefulWidget {
  const DesktopInstitutionHubScreen({super.key});

  @override
  State<DesktopInstitutionHubScreen> createState() =>
      _DesktopInstitutionHubScreenState();
}

class _DesktopInstitutionHubScreenState
    extends State<DesktopInstitutionHubScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  DAOReview? _institutionReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';

  void _openEventWorkspace() {
    DesktopShellScope.of(context)?.pushScreen(
      const EventCreator(embedded: true),
    );
  }

  void _openExhibitionWorkspace() {
    DesktopShellScope.of(context)?.pushScreen(
      const ExhibitionCreatorScreen(embedded: true),
    );
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
      _loadInstitutionReviewStatus(forceRefresh: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = _resolveWalletAddress(listen: true);
    final walletChanged = wallet != _lastReviewWallet;
    if (!walletChanged && _hasFetchedReviewForWallet) return;

    if (wallet.isNotEmpty) {
      _loadInstitutionReviewStatus(forceRefresh: true);
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

  String? _institutionPromotionUnavailableReason() {
    final l10n = AppLocalizations.of(context)!;
    final wallet = _resolveWalletAddress();
    if (wallet.isEmpty) {
      return l10n.desktopInstitutionPromotionWalletRequiredReason;
    }

    final daoProvider = context.read<DAOProvider>();
    final review =
        _institutionReview ?? daoProvider.findReviewForWallet(wallet);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );

    if (verification.isApprovedFor(DaoRoleType.artist) ||
        verification.isPendingFor(DaoRoleType.artist)) {
      return l10n.desktopInstitutionPromotionArtistConflictReason;
    }
    if (!verification.isApprovedFor(DaoRoleType.institution)) {
      return l10n.desktopInstitutionPromotionRequiresApprovalReason;
    }
    return null;
  }

  Future<void> _loadInstitutionReviewStatus({bool forceRefresh = false}) async {
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
        _institutionReview =
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
                // Left: Mobile institution hub view (wrapped)
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
                    child: InstitutionHub(
                      embedded: true,
                      showVerificationCard: false,
                      onTabChanged: (tabIndex) {
                        context
                            .read<DesktopDashboardStateProvider>()
                            .updateInstitutionSectionFromTabIndex(
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

  Widget _buildRightPanel(ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const sectionGap = KubusSpacing.lg;
    const sectionHeaderGap = KubusSpacing.sm + KubusSpacing.xs;
    const blockGap = KubusSpacing.md + KubusSpacing.xs;
    final persona = context.watch<ProfileProvider>().userPersona;
    final showCreateActions =
        persona == null || persona == UserPersona.institution;
    final dashboardState = context.watch<DesktopDashboardStateProvider>();
    final section = dashboardState.institutionSection;
    final showExhibitions = AppConfig.isFeatureEnabled('exhibitions');

    // Compute approval status for gating quick actions
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _institutionReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final isApprovedInstitution =
        verification.isApprovedFor(DaoRoleType.institution);
    final hasArtistBadge = verification.isApprovedFor(DaoRoleType.artist);
    final hasConflictingArtistReview =
        verification.isPendingFor(DaoRoleType.artist);
    final canSelfServeInstitutionPromotion =
        isApprovedInstitution && !hasArtistBadge && !hasConflictingArtistReview;
    final roles = KubusColorRoles.of(context);
    final sidebarStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.sidebarBackground,
      tintBase: scheme.surface,
    );

    String sectionTitle() {
      switch (section) {
        case DesktopInstitutionSection.events:
          return l10n.userProfileAchievementCategoryEvents;
        case DesktopInstitutionSection.exhibitions:
          return l10n.artistStudioTabExhibitions;
        case DesktopInstitutionSection.create:
          return l10n.commonCreate;
        case DesktopInstitutionSection.analytics:
          return l10n.desktopArtistStudioQuickActionAnalyticsTitle;
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : scheme.outline.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        blurSigma: sidebarStyle.blurSigma,
        fallbackMinOpacity: sidebarStyle.fallbackMinOpacity,
        showBorder: false,
        backgroundColor: sidebarStyle.tintColor,
        child: ListView(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          children: [
            // Header
            Text(
              l10n.navigationScreenInstitutionHub,
              style:
                  KubusTextStyles.screenTitle.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              sectionTitle(),
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
            const SizedBox(height: sectionGap),

            // Verification status
            _buildVerificationStatusCard(themeProvider),
            const SizedBox(height: blockGap),

            // Quick actions
            Text(
              l10n.desktopArtistStudioQuickActionsTitle,
              style: KubusTextStyles.sectionTitle
                  .copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: sectionHeaderGap),
            if (AppConfig.isFeatureEnabled('collabInvites'))
              Consumer<CollabProvider>(
                builder: (context, collabProvider, _) {
                  final pending = collabProvider.pendingInviteCount;
                  final badge = pending > 0
                      ? FrostedContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.sm,
                            vertical: KubusSpacing.xs,
                          ),
                          borderRadius: BorderRadius.circular(KubusRadius.xl),
                          showBorder: false,
                          backgroundColor: scheme.error
                              .withValues(alpha: isDark ? 0.30 : 0.22),
                          child: Text(
                            pending > 99 ? '99+' : pending.toString(),
                            style: KubusTextStyles.badgeCount
                                .copyWith(color: scheme.onError),
                          ),
                        )
                      : null;

                  return KubusActionSidebarTile(
                    title: l10n.desktopArtistStudioQuickActionInvitesTitle,
                    subtitle: pending > 0
                        ? l10n
                            .desktopArtistStudioQuickActionInvitesPendingSubtitle
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
                    trailing: badge,
                  );
                },
              ),
            if (canSelfServeInstitutionPromotion)
              KubusActionSidebarTile(
                title: l10n.desktopInstitutionPromoteProfileTitle,
                subtitle: l10n.desktopInstitutionPromoteProfileSubtitle,
                icon: Icons.campaign_outlined,
                semantic: KubusActionSemantic.publish,
                onTap: _openInstitutionPromotionFlow,
              ),
            if (section == DesktopInstitutionSection.create &&
                isApprovedInstitution &&
                showCreateActions)
              _buildCreatorWorkspaceLaunchCard(
                title: l10n.desktopArtistStudioQuickActionsTitle,
                subtitle: l10n.desktopInstitutionCreatorWorkspaceSubtitle,
                accent: roles.web3InstitutionAccent,
                children: [
                  if (AppConfig.isFeatureEnabled('events'))
                    FilledButton.tonalIcon(
                      onPressed: _openEventWorkspace,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(l10n.desktopInstitutionCreateEventTitle),
                    ),
                  if (showExhibitions)
                    FilledButton.tonalIcon(
                      onPressed: _openExhibitionWorkspace,
                      icon: const Icon(Icons.museum_outlined),
                      label: Text(l10n.exhibitionCreatorAppBarTitle),
                    ),
                ],
              ),
            if (section == DesktopInstitutionSection.create &&
                isApprovedInstitution &&
                showCreateActions)
              KubusActionSidebarTile(
                title: l10n.manageMarkersTitle,
                subtitle: l10n.manageMarkersQuickActionSubtitle,
                icon: Icons.place_outlined,
                semantic: KubusActionSemantic.manage,
                onTap: () {
                  DesktopShellScope.of(context)?.pushScreen(
                    DesktopSubScreen(
                      title: l10n.manageMarkersTitle,
                      child: const ManageMarkersScreen(embedded: true),
                    ),
                  );
                },
              ),
            if (section == DesktopInstitutionSection.events &&
                isApprovedInstitution)
              KubusActionSidebarTile(
                title: l10n.desktopInstitutionManageEventsTitle,
                subtitle: l10n.desktopInstitutionManageEventsSubtitle,
                icon: Icons.event_note_outlined,
                semantic: KubusActionSemantic.manage,
                onTap: () {
                  DesktopShellScope.of(context)?.pushScreen(
                    DesktopSubScreen(
                      title: l10n.desktopInstitutionManageEventsTitle,
                      child: const EventManager(embedded: true),
                    ),
                  );
                },
              ),
            if (section == DesktopInstitutionSection.exhibitions &&
                isApprovedInstitution &&
                showExhibitions)
              KubusActionSidebarTile(
                title: l10n.desktopInstitutionMyExhibitionsTitle,
                subtitle: l10n.desktopInstitutionMyExhibitionsSubtitle,
                icon: Icons.collections_bookmark_outlined,
                semantic: KubusActionSemantic.view,
                onTap: () {
                  DesktopShellScope.of(context)?.pushScreen(
                    DesktopSubScreen(
                      title: l10n.desktopInstitutionMyExhibitionsTitle,
                      child: ExhibitionListScreen(
                        embedded: true,
                        canCreate: true,
                        onCreateExhibition: () {
                          _openExhibitionWorkspace();
                        },
                        onOpenExhibition: (exhibition) {
                          DesktopShellScope.of(context)?.pushScreen(
                            DesktopSubScreen(
                              title: exhibition.title,
                              child: ExhibitionDetailScreen(
                                exhibitionId: exhibition.id,
                                initialExhibition: exhibition,
                                embedded: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            if (section == DesktopInstitutionSection.analytics &&
                isApprovedInstitution)
              KubusActionSidebarTile(
                title: l10n.desktopArtistStudioQuickActionAnalyticsTitle,
                subtitle: l10n.desktopArtistStudioQuickActionAnalyticsSubtitle,
                icon: Icons.analytics_outlined,
                semantic: KubusActionSemantic.analytics,
                onTap: () {
                  DesktopShellScope.of(context)?.pushScreen(
                    DesktopSubScreen(
                      title: l10n.desktopArtistStudioQuickActionAnalyticsTitle,
                      child: const InstitutionAnalytics(),
                    ),
                  );
                },
              ),
            if (section == DesktopInstitutionSection.analytics) ...[
              const SizedBox(height: KubusSpacing.sm),
              _buildAnalyticsTimeframeSelector(
                title: l10n.analyticsTimeframeLabel,
                value: context
                    .watch<AnalyticsFiltersProvider>()
                    .institutionTimeframe,
                onChanged: (v) => context
                    .read<AnalyticsFiltersProvider>()
                    .setInstitutionTimeframe(v),
              ),
            ],
            const SizedBox(height: sectionGap),

            // Stats
            Text(
              l10n.desktopInstitutionStatsTitle,
              style: KubusTextStyles.sectionTitle
                  .copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: sectionHeaderGap),
            _buildStatsGrid(),
            const SizedBox(height: sectionGap),

            // Upcoming events
            if (section == DesktopInstitutionSection.events) ...[
              Text(
                l10n.profileUpcomingEventsTitle,
                style: KubusTextStyles.sectionTitle
                    .copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: sectionHeaderGap),
              _buildUpcomingEvents(themeProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorWorkspaceLaunchCard({
    required String title,
    required String subtitle,
    required Color accent,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(KubusSpacing.md),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        backgroundColor: accent.withValues(alpha: 0.06),
        showBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              subtitle,
              style: KubusTextStyles.actionTileSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            ...children
                .map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                      child: SizedBox(width: double.infinity, child: child),
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTimeframeSelector({
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final cardStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surfaceContainerHighest,
    );
    final normalized = value.trim().toLowerCase();
    final effective =
        AnalyticsFiltersProvider.allowedTimeframes.contains(normalized)
            ? normalized
            : '30d';

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      blurSigma: cardStyle.blurSigma,
      fallbackMinOpacity: cardStyle.fallbackMinOpacity,
      backgroundColor: cardStyle.tintColor,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: KubusTextStyles.actionTileTitle
                  .copyWith(color: scheme.onSurface),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effective,
              dropdownColor: scheme.surfaceContainerHighest,
              style: KubusTextStyles.actionTileSubtitle
                  .copyWith(color: scheme.onSurface),
              items: AnalyticsFiltersProvider.allowedTimeframes
                  .map(
                    (tf) => DropdownMenuItem<String>(
                      value: tf,
                      child: Text(tf),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next == null) return;
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInstitutionPromotionFlow() async {
    final unavailableReason = _institutionPromotionUnavailableReason();
    if (unavailableReason != null) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(unavailableReason)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }
    final profile = context.read<ProfileProvider>().currentUser;
    final wallet = _resolveWalletAddress(listen: false);
    final entityId = WalletUtils.coalesce(
      walletAddress: profile?.walletAddress,
      wallet: wallet,
    ).trim();
    if (entityId.isEmpty) return;

    await showPromotionBuilderSheet(
      context: context,
      entityType: PromotionEntityType.institution,
      entityId: entityId,
      entityLabel:
          profile?.displayName ?? AppLocalizations.of(context)!.navigationScreenInstitutionHub,
    );
  }

  Widget _buildVerificationStatusCard(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final wallet = _resolveWalletAddress();
    final daoProvider = context.watch<DAOProvider>();
    final review = _institutionReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final isApproved = verification.isApprovedFor(DaoRoleType.institution);
    final isPending = verification.isPendingFor(DaoRoleType.institution);
    final isRejected = verification.isRejectedFor(DaoRoleType.institution);
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;

    Color statusColor = scheme.onSurface.withValues(alpha: 0.6);
    IconData statusIcon = Icons.help_outline;
    String statusText = l10n.desktopInstitutionVerificationNotAppliedTitle;
    String statusDescription =
        l10n.desktopInstitutionVerificationNotAppliedDescription;

    if (_reviewLoading) {
      statusText = l10n.desktopArtistStudioVerificationLoadingTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationLoadingDescription;
    } else if (isApproved) {
      statusColor = roles.positiveAction;
      statusIcon = Icons.verified;
      statusText = l10n.profileEditVerifiedInstitutionTitle;
      statusDescription = l10n.desktopInstitutionVerificationApprovedDescription;
    } else if (isPending) {
      statusColor = roles.warningAction;
      statusIcon = Icons.pending;
      statusText = l10n.desktopArtistStudioVerificationPendingTitle;
      statusDescription = l10n.desktopInstitutionVerificationPendingDescription;
    } else if (isRejected) {
      statusColor = roles.negativeAction;
      statusIcon = Icons.cancel;
      statusText = l10n.desktopArtistStudioVerificationRejectedTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationRejectedDescription;
    }

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: KubusSpacing.xxl,
                height: KubusSpacing.xxl,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: KubusSpacing.lg,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: KubusTextStyles.sectionTitle
                          .copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      statusDescription,
                      style: KubusTextStyles.actionTileSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isApproved && !isPending && wallet.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.md),
            Text(
              l10n.desktopInstitutionVerificationApplyHint,
              style: KubusTextStyles.actionTileSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final statsProvider = context.watch<StatsProvider>();
    final wallet = _resolveWalletAddress(listen: true);

    const metrics = <String>[
      'eventsHosted',
      'visitorsReceived',
      'exhibitionArtworks',
      'achievementTokensTotal',
    ];

    if (wallet.isNotEmpty) {
      unawaited(statsProvider.ensureSnapshot(
        entityType: 'user',
        entityId: wallet,
        metrics: metrics,
        scope: 'public',
      ));
    }

    final snapshot = wallet.isEmpty
        ? null
        : statsProvider.getSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: metrics,
            scope: 'public',
          );
    final isLoading = wallet.isNotEmpty &&
        statsProvider.isSnapshotLoading(
          entityType: 'user',
          entityId: wallet,
          metrics: metrics,
          scope: 'public',
        ) &&
        snapshot == null;

    final counters = snapshot?.counters ?? const <String, int>{};
    final events = wallet.isEmpty ? null : (counters['eventsHosted'] ?? 0);
    final visitors =
        wallet.isEmpty ? null : (counters['visitorsReceived'] ?? 0);
    final artworks =
        wallet.isEmpty ? null : (counters['exhibitionArtworks'] ?? 0);
    final revenue =
        wallet.isEmpty ? null : (counters['achievementTokensTotal'] ?? 0);

    String displayCount(int? value) =>
        isLoading ? '…' : (value?.toString() ?? '—');
    String displayKub8(int? value) =>
        isLoading ? '…' : (value == null ? '—' : '${value.toString()} KUB8');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l10n.userProfileAchievementCategoryEvents,
                displayCount(events),
                Icons.event_outlined,
                roles.web3InstitutionAccent,
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(
              child: _buildStatCard(
                l10n.desktopInstitutionStatVisitors,
                displayCount(visitors),
                Icons.people_outline,
                roles.web3InstitutionAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatArtworks,
                displayCount(artworks),
                Icons.collections_outlined,
                roles.statCoral,
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(
              child: _buildStatCard(
                l10n.desktopInstitutionStatRevenue,
                displayKub8(revenue),
                Icons.attach_money,
                roles.positiveAction,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return KubusSidebarStatCard(
      title: label,
      value: value,
      icon: icon,
      accent: color,
    );
  }

  Widget _buildUpcomingEvents(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final cardStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.primaryContainer,
    );
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      blurSigma: cardStyle.blurSigma,
      fallbackMinOpacity: cardStyle.fallbackMinOpacity,
      backgroundColor: cardStyle.tintColor,
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: KubusSizes.sidebarActionIconBox,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            l10n.desktopInstitutionNoUpcomingEventsLabel,
            style: KubusTextStyles.actionTileTitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
