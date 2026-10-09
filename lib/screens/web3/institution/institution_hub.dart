import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import 'event_creator.dart';
import 'event_manager.dart';
import 'institution_analytics.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/recent_activity_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../config/config.dart';
import '../../../models/creator_workspace.dart';
import '../../../models/dao.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/telemetry/telemetry_service.dart';
import '../../../utils/creator_workspace_navigation.dart';
import '../../../widgets/creator/creator_workspace_discovery_panel.dart';
import '../../../models/promotion.dart';
import '../../../models/user_persona.dart';
import '../../../utils/activity_navigation.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../utils/dao_role_verification.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/wallet_utils.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../../widgets/promotion/promotion_builder_sheet.dart';
import '../../../widgets/notifications/kubus_notifications_sheet.dart';
import '../../../widgets/topbar_icon.dart';

class InstitutionHub extends StatefulWidget {
  final ValueChanged<int>? onTabChanged;
  final bool showVerificationCard;
  final bool embedded;

  const InstitutionHub({
    super.key,
    this.onTabChanged,
    this.showVerificationCard = true,
    this.embedded = false,
  });

  @override
  State<InstitutionHub> createState() => _InstitutionHubState();
}

class _InstitutionHubState extends State<InstitutionHub> {
  int _selectedIndex = 0;
  DAOReview? _institutionReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';
  bool _hasSetInitialTabByPersona = false;
  final TextEditingController _organizationController = TextEditingController();
  bool _capabilityViewTracked = false;
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _missionController = TextEditingController();
  final TextEditingController _focusController = TextEditingController();
  final GlobalKey<FormState> _applicationFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadInstitutionReviewStatus(forceRefresh: true));
    _refreshBackendContract();
  }

  /// Learns whether applications are account-authorised (no wallet) and, if so,
  /// loads the caller's own applications. Re-renders either way.
  Future<void> _refreshBackendContract() async {
    final supported =
        await BackendApiService().ensureWalletOptionalCreatorKnown();
    if (!mounted) return;
    if (supported && BackendApiService().hasAuthSession) {
      await _loadInstitutionReviewStatus(forceRefresh: true);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = _resolveWalletAddress(listen: true);
    final walletChanged = wallet != _lastReviewWallet;
    final persona = context.watch<ProfileProvider>().userPersona;
    if (!_hasSetInitialTabByPersona && persona != null) {
      final desiredIndex = persona == UserPersona.institution ? 1 : 0;
      if (_selectedIndex != desiredIndex) {
        setState(() => _selectedIndex = desiredIndex);
        widget.onTabChanged?.call(desiredIndex);
      }
      _hasSetInitialTabByPersona = true;
    }

    if (!walletChanged && _hasFetchedReviewForWallet) return;
    if (wallet.isNotEmpty ||
        (BackendApiService().walletOptionalCreatorSupported &&
            BackendApiService().hasAuthSession)) {
      _loadInstitutionReviewStatus(forceRefresh: true);
    }
  }

  Future<void> _checkOnboarding() async {
    // A visitor without an account reads the discovery panel instead; the
    // feature tour stays one tap away behind the help action.
    if (!BackendApiService().hasAuthSession) return;
    if (await isOnboardingNeeded(InstitutionHubOnboardingData.featureKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboarding();
      });
    }
  }

  void _showOnboarding() {
    final l10n = AppLocalizations.of(context)!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Web3OnboardingScreen(
          featureKey: InstitutionHubOnboardingData.featureKey,
          featureTitle: InstitutionHubOnboardingData.featureTitle(l10n),
          pages: InstitutionHubOnboardingData.pages(l10n),
          onComplete: () {},
        ),
      ),
    );
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
    if (BackendApiService().walletOptionalCreatorSupported) {
      // Account-keyed: works with or without a wallet.
      if (_reviewLoading || !BackendApiService().hasAuthSession) return;
      setState(() => _reviewLoading = true);
      try {
        await context.read<DAOProvider>().loadMyApplications();
      } finally {
        // `_hasFetchedReviewForWallet` also gates didChangeDependencies, which
        // fires on every DAOProvider notification: without it each load would
        // trigger the next one.
        if (mounted) {
          setState(() {
            _reviewLoading = false;
            _hasFetchedReviewForWallet = true;
          });
        }
      }
      return;
    }
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
      });
    } catch (_) {
      if (mounted && requestedWallet == _lastReviewWallet) {
        setState(() {
          _hasFetchedReviewForWallet = true;
        });
      }
    } finally {
      if (mounted && requestedWallet == _lastReviewWallet) {
        setState(() {
          _reviewLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _organizationController.dispose();
    _contactController.dispose();
    _missionController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    // With account-authorised applications each role has its own review, so a
    // review for the other role never blocks this workspace.
    final accountApps = BackendApiService().walletOptionalCreatorSupported;
    final review = accountApps
        ? daoProvider.myReviewFor(DaoRoleType.institution)
        : (_institutionReview ??
            (wallet.isNotEmpty
                ? daoProvider.findReviewForWallet(wallet)
                : null));
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final profileProvider = context.watch<ProfileProvider>();
    final stage = resolveCreatorWorkspaceStage(
      workspace: CreatorWorkspace.institutionHub,
      hasAccountSession: BackendApiService().hasAuthSession,
      hasUsableProfile: profileProvider.hasUsablePublicProfile,
      walletAddress: wallet,
      review: review,
      profileGrantsRole:
          (profileProvider.currentUser?.isInstitution ?? false) ||
              daoProvider.hasServerCapability(DaoRoleType.institution),
      accountApplications: accountApps,
    );
    if (!_capabilityViewTracked) {
      _capabilityViewTracked = true;
      try {
        unawaited(TelemetryService().trackCreatorCapabilityViewed(
          capability: 'institution',
          stage: stage.name,
        ));
      } catch (_) {}
    }
    final isDiscover = stage == CreatorWorkspaceStage.discover;
    final hasArtistBadge = verification.isApprovedFor(DaoRoleType.artist);
    final isApprovedInstitution = stage.isOpen;
    final hasConflictingArtistReview =
        verification.isPendingFor(DaoRoleType.artist);
    final isCrossRoleBlocked = stage == CreatorWorkspaceStage.otherRoleReview;
    final canSelfServeInstitutionPromotion =
        isApprovedInstitution && !isCrossRoleBlocked;

    final pages = <Widget>[
      const EventManager(),
      if (AppConfig.isFeatureEnabled('exhibitions'))
        const ExhibitionListScreen(embedded: true, canCreate: true),
      const EventCreator(),
      const InstitutionAnalytics(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              // No title: the dashboard header below is the page title
              // (and carries any Lab marker). The bar holds actions only.
              actions: [
                TopBarIcon(
                  tooltip: l10n.institutionHubHelpTooltip,
                  icon: Icon(
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _showOnboarding,
                ),
                // A visitor without an account has no markers, invites or
                // notifications here yet; the discovery panel is the page.
                if (!isDiscover) ...<Widget>[
                  TopBarIcon(
                    tooltip: l10n.manageMarkersTitle,
                    icon: Icon(
                      Icons.place_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      unawaited(
                        CreatorShellNavigation.openManageMarkersWorkspace(
                            context),
                      );
                    },
                  ),
                  if (AppConfig.isFeatureEnabled('collabInvites'))
                    Consumer<CollabProvider>(
                      builder: (context, collabProvider, _) {
                        final pendingCount = collabProvider.pendingInviteCount;
                        return TopBarIcon(
                          tooltip: l10n.institutionHubInvitesTooltip,
                          badgeCount: pendingCount,
                          badgeColor: Theme.of(context).colorScheme.error,
                          icon: Icon(
                            Icons.inbox_outlined,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const InvitesInboxScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  if (canSelfServeInstitutionPromotion)
                    TopBarIcon(
                      tooltip: l10n.desktopInstitutionPromoteProfileTitle,
                      icon: Icon(
                        Icons.campaign_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: _openInstitutionPromotionFlow,
                    ),
                  Consumer<NotificationProvider>(
                    builder: (context, notificationProvider, _) => TopBarIcon(
                      tooltip: l10n.commonNotifications,
                      badgeCount: notificationProvider.unreadCount,
                      badgeColor: Theme.of(context).colorScheme.error,
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () => unawaited(_showNotifications()),
                    ),
                  ),
                ],
              ],
            ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildInstitutionHeader(
                    canSelfServeInstitutionPromotion:
                        canSelfServeInstitutionPromotion,
                  ),
                  if (widget.showVerificationCard && !isDiscover)
                    _buildInstitutionApplicationCard(
                      review,
                      isApprovedInstitution,
                      stage: stage,
                      isCrossRoleBlocked: isCrossRoleBlocked,
                      hasArtistBadge: hasArtistBadge,
                      hasConflictingArtistReview: hasConflictingArtistReview,
                    ),
                  if (!isCrossRoleBlocked && !isDiscover)
                    _buildNavigationTabs(isApprovedInstitution),
                ],
              ),
            ),
          ];
        },
        body: isDiscover
            ? _buildStateSlot(
                CreatorWorkspaceDiscoveryPanel(
                  workspace: CreatorWorkspace.institutionHub,
                  onStart: () => _acquireNextCapability(stage),
                ),
                maxWidth: 560,
                // Reads as the page, directly under the header, rather than
                // a state floating in the middle of a tall desktop pane.
                alignment: Alignment.topCenter,
              )
            : isCrossRoleBlocked
                ? _buildRoleBlockedContent(
                    title: hasArtistBadge
                        ? l10n.institutionHubArtistBadgeActiveTitle
                        : l10n.institutionHubArtistReviewInProgressTitle,
                    description: hasArtistBadge
                        ? l10n.institutionHubArtistBadgeActiveDescription
                        : l10n.institutionHubArtistReviewInProgressDescription,
                    icon: Icons.palette_outlined,
                  )
                : isApprovedInstitution
                    ? pages[_selectedIndex]
                    : _buildLockedContent(stage: stage),
      ),
    );
  }

  Widget _buildInstitutionHeader({
    required bool canSelfServeInstitutionPromotion,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final persona = context.watch<ProfileProvider>().userPersona;
    final lede = switch (persona) {
      UserPersona.institution => l10n.web3InstitutionHubP1Description,
      UserPersona.creator => l10n.web3InstitutionHubP5Feature3,
      UserPersona.lover => l10n.web3InstitutionHubP5Description,
      null => l10n.web3InstitutionHubP1Description,
    };
    // Programme leads; paid promotion is a quiet secondary action.
    return KubusDashboardHeader(
      notion: l10n.institutionNotionProgramme,
      accent: KubusColorRoles.of(context).web3InstitutionAccent,
      glyph: Icons.account_balance_outlined,
      title: l10n.navigationScreenInstitutionHub,
      lede: lede,
      actions: [
        if (canSelfServeInstitutionPromotion)
          KubusButton(
            onPressed: _openInstitutionPromotionFlow,
            icon: Icons.campaign_outlined,
            label: l10n.desktopInstitutionPromoteProfileTitle,
            variant: KubusButtonVariant.quiet,
          ),
      ],
    );
  }

  Widget _buildInstitutionApplicationCard(
    DAOReview? review,
    bool isApprovedInstitution, {
    required CreatorWorkspaceStage stage,
    required bool isCrossRoleBlocked,
    required bool hasArtistBadge,
    required bool hasConflictingArtistReview,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (isCrossRoleBlocked) {
      final title = hasArtistBadge
          ? l10n.institutionHubArtistBadgeActiveTitle
          : hasConflictingArtistReview
              ? l10n.institutionHubArtistReviewInProgressTitle
              : l10n.institutionHubCrossRoleConflictTitle;
      final message = hasArtistBadge
          ? l10n.institutionHubArtistWalletSwitchDescription
          : hasConflictingArtistReview
              ? l10n.institutionHubArtistReviewPendingResetDescription
              : l10n.institutionHubArtistSubmissionConflictDescription;
      return KubusNoticeBanner(
        icon: Icons.palette_outlined,
        title: title,
        message: message,
        tone: KubusStatusTone.negative,
      );
    }

    final status = review?.status.toLowerCase() ?? '';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final statusLabel = isApprovedInstitution
        ? l10n.institutionHubDaoStatusApproved
        : review != null
            ? _institutionReviewStatusLabel(status, l10n)
            : l10n.institutionHubDaoStatusNotApplied;
    final tone = isApprovedInstitution
        ? KubusStatusTone.positive
        : isRejected
            ? KubusStatusTone.negative
            : isPending
                ? KubusStatusTone.warning
                : KubusStatusTone.neutral;
    final acquiresCapability =
        CreatorWorkspaceNavigation.requirementsFor(stage) != null;
    final canSubmit = !_reviewLoading &&
        (stage == CreatorWorkspaceStage.apply ||
            stage == CreatorWorkspaceStage.rejected);
    final ctaLabel = switch (stage) {
      CreatorWorkspaceStage.completeProfile =>
        l10n.creatorWorkspaceCompleteProfileCta,
      CreatorWorkspaceStage.linkWalletToApply =>
        l10n.creatorWorkspaceLinkWalletCta,
      CreatorWorkspaceStage.open => l10n.institutionHubCtaApprovedByDao,
      CreatorWorkspaceStage.pending => l10n.institutionHubCtaPendingDaoReview,
      _ => l10n.institutionHubApplyForReviewAction,
    };
    final IconData ctaIcon = isApprovedInstitution
        ? Icons.verified_outlined
        : isPending
            ? Icons.hourglass_bottom
            : Icons.send_rounded;

    String? detail;
    if ((review?.reviewerNotes ?? '').isNotEmpty) {
      detail = review!.reviewerNotes!;
    } else if (review != null) {
      detail = isPending
          ? l10n.institutionHubDaoReviewQueueMessage
          : isApprovedInstitution
              ? l10n.institutionHubApprovedToolsMessage
              : isRejected
                  ? l10n.institutionHubRejectedResubmitMessage
                  : null;
    } else if (stage == CreatorWorkspaceStage.completeProfile) {
      detail = l10n.creatorWorkspaceCompleteProfileDetail;
    } else if (stage == CreatorWorkspaceStage.linkWalletToApply) {
      detail = l10n.creatorWorkspaceLinkWalletDetail;
    }

    return KubusStatusPanel(
      title: l10n.institutionHubApplicationTitle,
      description: l10n.institutionHubApplicationCardSubtitle,
      statusLabel: (review != null || _reviewLoading) ? statusLabel : null,
      tone: tone,
      isLoading: _reviewLoading,
      meta: review != null ? l10n.institutionHubDaoStatusSyncedLabel : null,
      detail: detail,
      action: KubusButton(
        onPressed: acquiresCapability
            ? () => _acquireNextCapability(stage)
            : canSubmit
                ? () => _showInstitutionApplicationModal()
                : null,
        label: ctaLabel,
        icon: acquiresCapability ? Icons.arrow_forward_rounded : ctaIcon,
        isFullWidth: true,
        variant: canSubmit || acquiresCapability
            ? KubusButtonVariant.primary
            : KubusButtonVariant.secondary,
      ),
    );
  }

  String _institutionReviewStatusLabel(String status, AppLocalizations l10n) {
    switch (status.toLowerCase()) {
      case 'pending':
        return l10n.institutionHubDaoStatusPending;
      case 'rejected':
        return l10n.institutionHubDaoStatusRejected;
      case 'approved':
        return l10n.institutionHubDaoStatusApproved;
      default:
        return l10n.institutionHubDaoStatusInReview;
    }
  }

  Widget _buildNavigationTabs(bool enabled) {
    final l10n = AppLocalizations.of(context)!;
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    return KubusDashboardTabs(
      selectedIndex: _selectedIndex,
      enabled: enabled,
      onSelected: _setSelectedIndex,
      onLockedTap: () => ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.desktopInstitutionVerificationApplyHint),
        ),
      ),
      tabs: [
        KubusDashboardTab(
          label: l10n.desktopInstitutionManageEventsTitle,
          icon: Icons.event_outlined,
        ),
        if (exhibitionsEnabled)
          KubusDashboardTab(
            label: l10n.institutionHubTabExhibitions,
            icon: AppColorUtils.exhibitionIcon,
          ),
        KubusDashboardTab(
          label: l10n.institutionHubTabCreate,
          icon: Icons.add_box_outlined,
        ),
        KubusDashboardTab(
          label: l10n.institutionHubTabAnalytics,
          icon: Icons.analytics_outlined,
        ),
      ],
    );
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    widget.onTabChanged?.call(index);
  }

  Widget _buildRoleBlockedContent({
    required String title,
    required String description,
    required IconData icon,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return _buildStateSlot(
      EmptyStateCard(
        icon: icon,
        title: title,
        description: '$description\n\n${l10n.institutionHubSeparateWalletsTip}',
      ),
    );
  }

  /// Centers a flat state card and lets it scroll when the slot is short,
  /// so long copy or large text never overflows.
  Future<void> _acquireNextCapability(CreatorWorkspaceStage stage) {
    return CreatorWorkspaceNavigation.acquireNextCapability(
      context,
      workspace: CreatorWorkspace.institutionHub,
      stage: stage,
    );
  }

  Widget _buildStateSlot(
    Widget card, {
    double maxWidth = 520,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    return Align(
      alignment: alignment,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: card,
        ),
      ),
    );
  }

  Future<void> _showNotifications() async {
    final provider =
        Provider.of<RecentActivityProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    if (provider.initialized) {
      await provider.refresh(force: true);
    } else {
      await provider.initialize(force: true);
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: KubusNotificationsSheet(
            unreadOnly: false,
            onNotificationSelected: (activity) async {
              Navigator.of(context).pop();
              await ActivityNavigation.open(context, activity);
            },
          ),
        );
      },
    );

    if (!mounted) return;
    await notificationProvider.markViewed();
    provider.markAllNotificationsReadLocally();
  }

  Future<void> _openInstitutionPromotionFlow() async {
    final l10n = AppLocalizations.of(context)!;
    final unavailableReason = _institutionPromotionUnavailableReason();
    if (unavailableReason != null) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(unavailableReason)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }
    final profile = context.read<ProfileProvider>().currentUser;
    final wallet = _resolveWalletAddress();
    final entityId = WalletUtils.coalesce(
      walletAddress: profile?.walletAddress,
      wallet: wallet,
    ).trim();
    if (entityId.isEmpty) return;

    await showPromotionBuilderSheet(
      context: context,
      entityType: PromotionEntityType.institution,
      entityId: entityId,
      entityLabel: profile?.displayName ?? l10n.navigationScreenInstitutionHub,
    );
  }

  void _showInstitutionApplicationModal() {
    _organizationController.clear();
    _contactController.clear();
    _missionController.clear();
    _focusController.clear();
    final scaffold = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        final scheme = Theme.of(context).colorScheme;
        final roles = KubusColorRoles.of(context);
        return SingleChildScrollView(
          child: BackdropGlassSheet(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            showHandle: false,
            backgroundColor:
                scheme.surfaceContainerHighest.withValues(alpha: 0.18),
            child: Form(
              key: _applicationFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KubusSheetHeader(
                    title: l10n.institutionHubApplicationTitle,
                    subtitle: l10n.institutionHubApplicationSubtitle,
                    showHandle: false,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  TextFormField(
                    controller: _organizationController,
                    decoration: InputDecoration(
                      labelText:
                          l10n.institutionHubApplicationOrganizationLabel,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.institutionHubApplicationOrganizationRequired
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  TextFormField(
                    controller: _contactController,
                    decoration: InputDecoration(
                      labelText: l10n.institutionHubApplicationContactLabel,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.institutionHubApplicationContactRequired
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  TextFormField(
                    controller: _focusController,
                    decoration: InputDecoration(
                      labelText: l10n.institutionHubApplicationFocusLabel,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.institutionHubApplicationFocusRequired
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  TextFormField(
                    controller: _missionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.institutionHubApplicationMissionLabel,
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 20)
                            ? l10n.institutionHubApplicationMissionRequired
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: KubusButton(
                      onPressed: () async {
                        if (!_applicationFormKey.currentState!.validate()) {
                          return;
                        }
                        final sheetNavigator = Navigator.of(sheetContext);
                        final profileProvider = context.read<ProfileProvider>();
                        final walletProvider = context.read<WalletProvider>();
                        final web3Provider = context.read<Web3Provider>();
                        final daoProvider = context.read<DAOProvider>();
                        // Account-authorised applications need no wallet and
                        // no signer. Only an older backend still takes a
                        // wallet-signed application.
                        if (!daoProvider.accountApplicationsSupported) {
                          final wallet =
                              profileProvider.currentUser?.walletAddress ??
                                  web3Provider.walletAddress;
                          if (wallet.isEmpty) {
                            scaffold.showKubusSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.institutionHubApplicationWalletRequired,
                                ),
                              ),
                            );
                            return;
                          }
                          final canProceed =
                              await WalletActionGuard.ensureSignerAccess(
                            context: context,
                            profileProvider: profileProvider,
                            walletProvider: walletProvider,
                          );
                          if (!mounted || !canProceed) {
                            return;
                          }
                        }
                        sheetNavigator.pop();
                        try {
                          final review =
                              await daoProvider.submitInstitutionReview(
                            organization: _organizationController.text.trim(),
                            contact: _contactController.text.trim(),
                            focus: _focusController.text.trim(),
                            mission: _missionController.text.trim(),
                          );
                          if (!mounted) return;
                          if (review != null) {
                            await _loadInstitutionReviewStatus(
                              forceRefresh: true,
                            );
                          }
                          if (!mounted) return;
                          scaffold.showKubusSnackBar(
                            SnackBar(
                              content: Text(
                                review != null
                                    ? l10n
                                        .institutionHubApplicationSubmittedToast
                                    : daoProvider.lastApplicationErrorCode ==
                                            'PROFILE_INCOMPLETE'
                                        ? l10n
                                            .creatorApplicationProfileIncompleteToast
                                        : l10n
                                            .institutionHubApplicationSubmitUnavailableToast,
                              ),
                              backgroundColor: review != null
                                  ? roles.positiveAction
                                  : roles.negativeAction,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          scaffold.showKubusSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.institutionHubApplicationSubmitFailedToast(
                                  e,
                                ),
                              ),
                              backgroundColor: roles.negativeAction,
                            ),
                          );
                        }
                      },
                      label: l10n.institutionHubApplicationSubmitButton,
                      isFullWidth: true,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockedContent({required CreatorWorkspaceStage stage}) {
    final l10n = AppLocalizations.of(context)!;
    final acquiresCapability =
        CreatorWorkspaceNavigation.requirementsFor(stage) != null;
    final canApply = stage == CreatorWorkspaceStage.apply ||
        stage == CreatorWorkspaceStage.rejected;
    return _buildStateSlot(
      EmptyStateCard(
        icon: Icons.lock_outline,
        // Names the lock, not the review status: the status panel (or the
        // desktop rail) already says "Not applied" and why.
        title: l10n.institutionHubLockedTitle,
        // With the application panel above, that panel already explains the
        // step; the lock only names what opens. Without it (desktop) the lock
        // carries the step's explanation.
        description: widget.showVerificationCard
            ? l10n.institutionHubLockedDescription
            : switch (stage) {
                CreatorWorkspaceStage.completeProfile =>
                  l10n.creatorWorkspaceCompleteProfileDetail,
                CreatorWorkspaceStage.linkWalletToApply =>
                  l10n.creatorWorkspaceLinkWalletDetail,
                _ => l10n.institutionHubLockedDescription,
              },
        // The application panel above owns the next step; without it (the
        // desktop shell) this surface carries the same step, except while a
        // review is already pending.
        showAction:
            !widget.showVerificationCard && (acquiresCapability || canApply),
        actionLabel: switch (stage) {
          CreatorWorkspaceStage.completeProfile =>
            l10n.creatorWorkspaceCompleteProfileCta,
          CreatorWorkspaceStage.linkWalletToApply =>
            l10n.creatorWorkspaceLinkWalletCta,
          _ => l10n.institutionHubApplyForReviewAction,
        },
        onAction: acquiresCapability
            ? () => _acquireNextCapability(stage)
            : _showInstitutionApplicationModal,
      ),
    );
  }
}
