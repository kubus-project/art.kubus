import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import 'event_creator.dart';
import 'event_manager.dart';
import 'institution_analytics.dart';
import '../../../providers/account_verification_provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/recent_activity_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../config/config.dart';
import '../../../models/promotion.dart';
import '../../../models/user_persona.dart';
import '../../../utils/activity_navigation.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../utils/wallet_utils.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/verification/institution_verification_panel.dart';
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
  bool _hasSetInitialTabByPersona = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_checkOnboarding()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final persona = context.watch<ProfileProvider>().userPersona;
    if (!_hasSetInitialTabByPersona && persona != null) {
      final desiredIndex = persona == UserPersona.institution ? 1 : 0;
      if (_selectedIndex != desiredIndex) {
        setState(() => _selectedIndex = desiredIndex);
        widget.onTabChanged?.call(desiredIndex);
      }
      _hasSetInitialTabByPersona = true;
    }
  }

  // First-visit Web3 onboarding is for users with a wallet. Guests and
  // email-only accounts browse institutions without wallet education; the
  // help action still opens the same explanation on request.
  Future<void> _checkOnboarding() async {
    if (!mounted || _resolveWalletAddress().isEmpty) return;
    if (!await isOnboardingNeeded(InstitutionHubOnboardingData.featureKey)) {
      return;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showOnboarding();
    });
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

  /// Promotion is a paid, wallet-keyed action, so a wallet is needed for THAT
  /// action only. Eligibility starts from the server-confirmed membership of the
  /// institution the account is acting for; the server decides the rest.
  String? _institutionPromotionUnavailableReason() {
    final l10n = AppLocalizations.of(context)!;
    final membership =
        context.read<AccountVerificationProvider>().selectedMembership;
    if (membership == null || !membership.canAdminister) {
      return l10n.desktopInstitutionPromotionRequiresApprovalReason;
    }
    if (_resolveWalletAddress().isEmpty) {
      return l10n.desktopInstitutionPromotionWalletRequiredReason;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Access is the account's server-confirmed institution membership. No
    // wallet, persona or artist standing is consulted, and being an artist
    // never blocks it.
    final verification = context.watch<AccountVerificationProvider>();
    final membership = verification.selectedMembership;
    final hasInstitutionAccess = membership != null;
    final canSelfServeInstitutionPromotion =
        membership != null && membership.canAdminister;

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
                  if (hasInstitutionAccess) const InstitutionSelector(),
                  if (widget.showVerificationCard && !hasInstitutionAccess)
                    InstitutionVerificationPanel(
                      onRequestSent: () => verification.refresh(),
                    ),
                  _buildNavigationTabs(hasInstitutionAccess),
                ],
              ),
            ),
          ];
        },
        body: hasInstitutionAccess
            ? pages[_selectedIndex]
            : _buildLockedContent(
                reviewPending: verification.hasOpenInstitutionRequest,
                unavailable: verification.isUnavailable,
              ),
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
        // The embedded layout has no app bar, so the help entry lives here.
        if (widget.embedded)
          KubusButton(
            onPressed: _showOnboarding,
            icon: Icons.help_outline,
            label: l10n.institutionHubHelpTooltip,
            variant: KubusButtonVariant.quiet,
          ),
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

  /// Centers a flat state card and lets it scroll when the slot is short,
  /// so long copy or large text never overflows.
  Widget _buildStateSlot(Widget card) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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

  Widget _buildLockedContent({
    required bool reviewPending,
    required bool unavailable,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return _buildStateSlot(
      EmptyStateCard(
        icon: Icons.lock_outline,
        title: l10n.institutionHubLockedTitle,
        description: unavailable
            ? l10n.verificationUnavailable
            : l10n.institutionHubLockedDescription,
        // The verification panel above owns the claim / request actions; without
        // it (the desktop shell) this surface carries the action, except while a
        // request is already pending.
        showAction: !widget.showVerificationCard && !reviewPending,
        actionLabel: unavailable
            ? l10n.verificationCtaRetry
            : l10n.verificationInstitutionClaimTitle,
        onAction: unavailable
            ? () => context.read<AccountVerificationProvider>().refresh()
            : () => showInstitutionDirectorySheet(context),
      ),
    );
  }
}
