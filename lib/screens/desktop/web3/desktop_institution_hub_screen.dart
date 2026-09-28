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
import '../../../utils/app_color_utils.dart';
import '../../../utils/dao_role_verification.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../utils/wallet_utils.dart';
import '../desktop_shell.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../web3/institution/institution_hub.dart';
import '../../web3/institution/event_manager.dart';
import '../../web3/institution/institution_analytics.dart';
import '../../events/exhibition_list_screen.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/forms/kubus_form.dart';
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
  String _lastStatsWallet = '';

  void _openEventWorkspace() {
    unawaited(CreatorShellNavigation.openEventCreatorWorkspace(context));
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
          metrics: institutionDashboardMetrics,
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

  /// Side panel hierarchy: status, PROGRAMME actions (events, exhibitions,
  /// create, collaborations, analytics), NUMBERS (real backend counters,
  /// truthfully labelled), then INFRASTRUCTURE (paid promotion).
  ///
  /// There is deliberately no revenue tile. The former "Revenue" tile showed
  /// `achievementTokensTotal` as "N KUB8": that counter is the sum of the
  /// KUB8 reward definitions on achievements the wallet has unlocked
  /// (statsService `SUM(achievements.reward_kub8)`), not income. No backend
  /// field represents institution revenue, so nothing is shown. See
  /// docs/design/PRODUCT_V5_APP_AUDIT.md (Wave 4C, "0 KUB8 Revenue").
  Widget _buildRightPanel(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    const sectionGap = KubusSpacing.xl;
    final persona = context.watch<ProfileProvider>().userPersona;
    final showCreateActions =
        persona == null || persona == UserPersona.institution;
    final dashboardState = context.watch<DesktopDashboardStateProvider>();
    final section = dashboardState.institutionSection;
    final showExhibitions = AppConfig.isFeatureEnabled('exhibitions');

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

    final programme = <Widget>[
      if (section == DesktopInstitutionSection.create &&
          isApprovedInstitution &&
          showCreateActions) ...[
        if (AppConfig.isFeatureEnabled('events'))
          KubusButton(
            onPressed: _openEventWorkspace,
            icon: Icons.event_outlined,
            label: l10n.desktopInstitutionCreateEventTitle,
            isFullWidth: true,
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
      if (section == DesktopInstitutionSection.events && isApprovedInstitution)
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
          icon: AppColorUtils.exhibitionIcon,
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
      if (section == DesktopInstitutionSection.analytics)
        _buildAnalyticsTimeframeSelector(
          title: l10n.analyticsTimeframeLabel,
          value: context.watch<AnalyticsFiltersProvider>().institutionTimeframe,
          onChanged: (v) => context
              .read<AnalyticsFiltersProvider>()
              .setInstitutionTimeframe(v),
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
          KubusNotionLabel(l10n.institutionNotionProgramme),
          const SizedBox(height: KubusSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              l10n.navigationScreenInstitutionHub,
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
          if (programme.isNotEmpty) ...[
            KubusPanelSection(
              notion: l10n.desktopArtistStudioQuickActionsTitle,
              children: programme,
            ),
            const SizedBox(height: sectionGap),
          ],
          KubusPanelSection(
            notion: l10n.dashboardNotionNumbers,
            caption: l10n.dashboardNumbersCaption,
            children: [_buildStatsGrid()],
          ),
          if (canSelfServeInstitutionPromotion) ...[
            const SizedBox(height: sectionGap),
            KubusPanelSection(
              notion: l10n.dashboardNotionInfrastructure,
              children: [
                KubusActionSidebarTile(
                  title: l10n.desktopInstitutionPromoteProfileTitle,
                  subtitle: l10n.desktopInstitutionPromoteProfileSubtitle,
                  icon: Icons.campaign_outlined,
                  semantic: KubusActionSemantic.publish,
                  onTap: _openInstitutionPromotionFlow,
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
      entityLabel: profile?.displayName ??
          AppLocalizations.of(context)!.navigationScreenInstitutionHub,
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

    var tone = KubusStatusTone.neutral;
    var statusText = l10n.desktopInstitutionVerificationNotAppliedTitle;
    var statusDescription =
        l10n.desktopInstitutionVerificationNotAppliedDescription;

    if (_reviewLoading) {
      statusText = l10n.desktopArtistStudioVerificationLoadingTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationLoadingDescription;
    } else if (isApproved) {
      tone = KubusStatusTone.positive;
      statusText = l10n.profileEditVerifiedInstitutionTitle;
      statusDescription =
          l10n.desktopInstitutionVerificationApprovedDescription;
    } else if (isPending) {
      tone = KubusStatusTone.warning;
      statusText = l10n.desktopArtistStudioVerificationPendingTitle;
      statusDescription = l10n.desktopInstitutionVerificationPendingDescription;
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
      detail: (!isApproved && !isPending && wallet.isNotEmpty)
          ? l10n.desktopInstitutionVerificationApplyHint
          : null,
    );
  }

  /// Real programme counters from the `/api/stats` user snapshot:
  /// published events owned, views of the institution's event and
  /// exhibition pages (`analytics_events` 'view' rows, not physical
  /// visitors), and distinct artworks in its exhibitions.
  Widget _buildStatsGrid() {
    final l10n = AppLocalizations.of(context)!;
    final statsProvider = context.watch<StatsProvider>();
    final wallet = _resolveWalletAddress(listen: true);

    final snapshot = wallet.isEmpty
        ? null
        : statsProvider.getSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: institutionDashboardMetrics,
            scope: 'public',
          );
    final isLoading = wallet.isNotEmpty &&
        statsProvider.isSnapshotLoading(
          entityType: 'user',
          entityId: wallet,
          metrics: institutionDashboardMetrics,
          scope: 'public',
        ) &&
        snapshot == null;

    final counters = snapshot?.counters ?? const <String, int>{};
    String display(String key) {
      if (isLoading) return '…';
      if (wallet.isEmpty) return '—';
      return (counters[key] ?? 0).toString();
    }

    final muted = KubusColorRoles.of(context).foregroundMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: KubusSidebarStatCard(
            title: l10n.userProfileAchievementCategoryEvents,
            value: display('eventsHosted'),
            icon: Icons.event_outlined,
            accent: muted,
          ),
        ),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: KubusSidebarStatCard(
            title: l10n.institutionStatProgrammeViews,
            value: display('visitorsReceived'),
            icon: Icons.visibility_outlined,
            accent: muted,
          ),
        ),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: KubusSidebarStatCard(
            title: l10n.desktopArtistStudioStatArtworks,
            value: display('exhibitionArtworks'),
            icon: Icons.collections_outlined,
            accent: muted,
          ),
        ),
      ],
    );
  }
}

/// Metrics the Institution side panel reads. There is no revenue metric:
/// `achievementTokensTotal` is an achievement reward sum, not income.
@visibleForTesting
const List<String> institutionDashboardMetrics = <String>[
  'eventsHosted',
  'visitorsReceived',
  'exhibitionArtworks',
];
