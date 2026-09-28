import 'package:flutter/material.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/common/kubus_meter_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../models/dao.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/dao_action_state.dart';
import '../../../config/config.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/kubus_labs_feature.dart';
import '../../../utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/common/kubus_labs_adornment.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import '../../../widgets/topbar_icon.dart';
import '../../../features/web3/web3_capabilities.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/states/kubus_product_states.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/dao/dao_proposal_status.dart';

class GovernanceHub extends StatelessWidget {
  final ValueNotifier<int>? selectedIndexNotifier;
  final bool embedded;

  const GovernanceHub({
    super.key,
    this.selectedIndexNotifier,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GovernanceWorkspace(
      selectedIndexNotifier: selectedIndexNotifier,
      embedded: embedded,
    );
  }
}

class GovernanceWorkspace extends StatefulWidget {
  const GovernanceWorkspace({
    super.key,
    this.selectedIndexNotifier,
    this.embedded = false,
    this.desktopLayout = false,
  });

  final ValueNotifier<int>? selectedIndexNotifier;
  final bool embedded;
  final bool desktopLayout;

  @override
  State<GovernanceWorkspace> createState() => _GovernanceWorkspaceState();
}

class _GovernanceWorkspaceState extends State<GovernanceWorkspace>
    with TickerProviderStateMixin {
  static const String _categoryPlatformUpdate = 'platform_update';
  static const String _categoryNewFeature = 'new_feature';
  static const String _categoryPolicyChange = 'policy_change';
  static const String _categoryTreasuryAllocation = 'treasury_allocation';
  static const String _categoryCommunityInitiative = 'community_initiative';
  static const String _categoryTechnicalImprovement = 'technical_improvement';
  static const List<String> _proposalCategories = [
    _categoryPlatformUpdate,
    _categoryNewFeature,
    _categoryPolicyChange,
    _categoryTreasuryAllocation,
    _categoryCommunityInitiative,
    _categoryTechnicalImprovement,
  ];

  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final DaoActionState _daoActionState = DaoActionState();
  VoidCallback? _selectedIndexListener;

  // Proposal creation form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  String _selectedCategory = _categoryPlatformUpdate;
  final _votingPeriodController = TextEditingController();

  KubusColorRoles get _roles => KubusColorRoles.of(context);
  Color get _daoAccent => _roles.web3DaoAccent;

  Web3Capabilities _capabilities({
    bool proposalAllowsVoting = true,
    bool listen = true,
  }) {
    final profileProvider = listen
        ? context.watch<ProfileProvider>()
        : context.read<ProfileProvider>();
    final walletProvider = listen
        ? context.watch<WalletProvider>()
        : context.read<WalletProvider>();
    final daoProvider =
        listen ? context.watch<DAOProvider>() : context.read<DAOProvider>();
    return Web3CapabilityResolver.resolve(
      Web3CapabilityContext.fromProviders(
        profileProvider: profileProvider,
        walletProvider: walletProvider,
        proposalAllowsVoting: proposalAllowsVoting,
        daoReviewAuthority: daoProvider.canModerateReviews,
      ),
    );
  }

  List<int> _visibleSections(Web3Capabilities capabilities) => <int>[
        0,
        if (capabilities.canViewOwnGovernanceHistory) 1,
        if (capabilities.canCreateProposal) 2,
        3,
        if (capabilities.hasAccount) 4,
      ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndexNotifier?.value ?? 0;
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

    // Initialize pages list but don't build widgets yet
    _checkOnboarding();
    _animationController.forward();

    final notifier = widget.selectedIndexNotifier;
    if (notifier != null) {
      _selectedIndexListener = () {
        final next = notifier.value;
        if (next == _selectedIndex) return;
        if (!mounted) return;
        setState(() => _selectedIndex = next);
      };
      notifier.addListener(_selectedIndexListener!);
    }
  }

  @override
  void dispose() {
    if (_selectedIndexListener != null) {
      widget.selectedIndexNotifier?.removeListener(_selectedIndexListener!);
      _selectedIndexListener = null;
    }
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _votingPeriodController.dispose();
    super.dispose();
  }

  void _setSelectedIndex(int next, {bool syncNotifier = true}) {
    if (next == _selectedIndex) return;
    setState(() => _selectedIndex = next);
    if (syncNotifier) {
      final notifier = widget.selectedIndexNotifier;
      if (notifier != null && notifier.value != next) {
        notifier.value = next;
      }
    }
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(DAOOnboardingData.featureKey)) {
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
          featureKey: DAOOnboardingData.featureKey,
          featureTitle: DAOOnboardingData.featureTitle(l10n),
          pages: DAOOnboardingData.pages(l10n),
          onComplete: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities();
    if (!capabilities.canViewGovernance) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: EmptyStateCard(
            icon: Icons.how_to_vote_outlined,
            title: l10n.commonDisabled,
            description: l10n.exhibitionListDisabledSubtitle,
          ),
        ),
      );
    }
    final visibleSections = _visibleSections(capabilities);
    final selectedIndex = visibleSections.contains(_selectedIndex)
        ? _selectedIndex
        : visibleSections.first;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.daoHubAppBarTitle,
                      style:
                          KubusTextStyles.responsiveMobileAppBarTitle(context)
                              .copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  const KubusLabsAdornment.inlinePill(
                    feature: KubusLabsFeature.dao,
                    emphasized: true,
                  ),
                ],
              ),
              actions: [
                TopBarIcon(
                  tooltip: l10n.profileHelpSupportTitle,
                  icon: Icon(
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _showOnboarding,
                ),
                TopBarIcon(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  icon: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _showGovernanceInfo,
                ),
              ],
            ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.desktopLayout
            ? Column(
                children: [
                  _buildGovernanceHeader(),
                  _buildNavigationTabs(capabilities, selectedIndex),
                  if (capabilities.hasAccount && !capabilities.canTransact)
                    _buildParticipationState(capabilities),
                  Expanded(
                    child: _buildSelectedTabBody(
                      capabilities,
                      selectedIndex,
                    ),
                  ),
                ],
              )
            : NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildGovernanceHeader(),
                          _buildNavigationTabs(capabilities, selectedIndex),
                          if (capabilities.hasAccount &&
                              !capabilities.canTransact)
                            _buildParticipationState(capabilities),
                        ],
                      ),
                    ),
                  ];
                },
                body: _buildSelectedTabBody(capabilities, selectedIndex),
              ),
      ),
    );
  }

  Widget _buildSelectedTabBody(
    Web3Capabilities capabilities,
    int selectedIndex,
  ) {
    switch (selectedIndex) {
      case 0:
        return _buildActiveProposals();
      case 1:
        return _buildVotingHistory();
      case 2:
        return capabilities.canCreateProposal
            ? _buildCreateProposal()
            : _buildParticipationState(capabilities);
      case 3:
        return _buildTreasury();
      case 4:
        return _buildDelegation(capabilities);
      default:
        return _buildActiveProposals();
    }
  }

  /// Wallet gating appears only where signing is needed: this explains why
  /// the viewer cannot vote/propose yet and offers the one recovery that
  /// applies (connect a wallet, or restore signing for a read-only one).
  Widget _buildParticipationState(Web3Capabilities capabilities) {
    final l10n = AppLocalizations.of(context)!;
    final authority = context.watch<WalletProvider>().authority;
    final message = !capabilities.hasWalletIdentity
        ? l10n.walletActionAccountShellNeedsWalletToast
        : authority.canRestoreFromEncryptedBackup
            ? l10n.walletActionEncryptedBackupRestoreToast
            : l10n.walletActionReadOnlyReconnectToast;
    final actionLabel = !capabilities.hasWalletIdentity
        ? l10n.authConnectWalletButton
        : l10n.walletHomeRestoreWalletAction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.sm,
        KubusSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KubusNoticeBanner(
            margin: EdgeInsets.zero,
            icon: Icons.lock_outline,
            title: !capabilities.hasWalletIdentity
                ? l10n.stateWalletTitle
                : l10n.walletReadOnlyStatus,
            message: message,
          ),
          const SizedBox(height: KubusSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: KubusButton(
              onPressed: () => WalletActionGuard.ensureSignerAccess(
                context: context,
                profileProvider: context.read<ProfileProvider>(),
                walletProvider: context.read<WalletProvider>(),
                returnRoute: '/governance',
              ),
              label: actionLabel,
              variant: KubusButtonVariant.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceHeader() {
    return Consumer2<DAOProvider, Web3Provider>(
      builder: (context, daoProvider, web3Provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final capabilities = _capabilities();
        // Voting power is the KUB8 the backend snapshots at vote time.
        final votingPower = web3Provider.kub8Balance.toStringAsFixed(2);
        final activeProposals =
            daoProvider.getActiveProposals().length.toString();
        final totalMembers = daoProvider.delegates.length.toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KubusDashboardHeader(
              notion: l10n.dashboardNotionInfrastructure,
              title: l10n.daoHubAppBarTitle,
              lede: l10n.daoHubHeaderSubtitle,
              actions: const [
                KubusLabsAdornment.inlinePill(
                  feature: KubusLabsFeature.dao,
                  emphasized: true,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KubusSpacing.md,
                0,
                KubusSpacing.md,
                KubusSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (capabilities.hasAccount) ...[
                    Expanded(
                      child: KubusStatCard(
                        title: l10n.daoHubStatYourVotingPowerLabel,
                        value: '$votingPower KUB8',
                        semanticsLabel: l10n.walletBalanceAmountSemantic(
                          l10n.daoHubStatYourVotingPowerLabel,
                          votingPower,
                          'KUB8',
                        ),
                        titleMaxLines: 2,
                        minHeight: 64,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.sm),
                  ],
                  Expanded(
                    child: KubusStatCard(
                      title: l10n.daoHubStatActiveProposalsLabel,
                      value: activeProposals,
                      titleMaxLines: 2,
                      minHeight: 64,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Expanded(
                    child: KubusStatCard(
                      title: l10n.daoHubStatTotalDelegatesLabel,
                      value: totalMembers,
                      titleMaxLines: 2,
                      minHeight: 64,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationTabs(
    Web3Capabilities capabilities,
    int selectedIndex,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // Section indices are fixed (0..4); only some are visible.
    final visible = <(int, KubusDashboardTab)>[
      (
        0,
        KubusDashboardTab(
          label: l10n.daoHubTabActiveProposals,
          icon: Icons.how_to_vote_outlined,
        ),
      ),
      if (capabilities.canViewOwnGovernanceHistory)
        (
          1,
          KubusDashboardTab(
            label: l10n.daoHubTabVotingHistory,
            icon: Icons.history,
          ),
        ),
      if (capabilities.canCreateProposal)
        (
          2,
          KubusDashboardTab(
            label: l10n.daoHubTabCreateProposal,
            icon: Icons.add_circle_outline,
          ),
        ),
      (
        3,
        KubusDashboardTab(
          label: l10n.daoHubTabTreasury,
          icon: Icons.account_balance_outlined,
        ),
      ),
      if (capabilities.hasAccount)
        (
          4,
          KubusDashboardTab(
            label: l10n.daoHubTabDelegation,
            icon: Icons.people_outline,
          ),
        ),
    ];
    final position = visible.indexWhere((item) => item.$1 == selectedIndex);
    return KubusDashboardTabs(
      selectedIndex: position < 0 ? 0 : position,
      onSelected: (i) => _setSelectedIndex(visible[i].$1),
      tabs: [for (final item in visible) item.$2],
    );
  }

  /// Distinct states: loading, network failure (never shown as "no
  /// proposals"), no proposals, and the proposal list with a not-eligible
  /// note when the wallet can sign but holds no voting power.
  Widget _buildActiveProposals() {
    return Consumer2<DAOProvider, Web3Provider>(
      builder: (context, daoProvider, web3Provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final activeProposals = daoProvider.getActiveProposals();
        final reviews = daoProvider.reviews;
        final isEmpty = activeProposals.isEmpty && reviews.isEmpty;

        if (daoProvider.isLoading && isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(KubusSpacing.md),
            child: KubusSectionLoading(rows: 3, rowHeight: 160),
          );
        }
        if (daoProvider.loadError != null && isEmpty) {
          return KubusStateView.fromError(
            daoProvider.loadError,
            onRetry: () => daoProvider.refreshData(force: true),
          );
        }
        if (isEmpty) {
          return Center(
            child: EmptyStateCard(
              icon: Icons.how_to_vote,
              title: l10n.daoActiveProposalsEmptyTitle,
              description: l10n.daoActiveProposalsEmptyDescription,
            ),
          );
        }

        final capabilities = _capabilities();
        final notEligible = capabilities.canVote &&
            activeProposals.isNotEmpty &&
            web3Provider.kub8Balance <= 0;

        return ListView(
          padding: const EdgeInsets.all(KubusSpacing.md),
          children: [
            if (notEligible) ...[
              KubusNoticeBanner(
                margin: EdgeInsets.zero,
                icon: Icons.info_outline,
                tone: KubusStatusTone.neutral,
                title: l10n.daoNotEligibleTitle,
                message: l10n.daoNotEligibleBody,
              ),
              const SizedBox(height: KubusSpacing.md),
            ],
            if (reviews.isNotEmpty) _buildReviewQueue(reviews),
            ...activeProposals.map((proposal) => _buildProposalCard(proposal)),
          ],
        );
      },
    );
  }

  Widget _buildReviewQueue(List<DAOReview> reviews) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.daoReviewQueueTitle,
          style: KubusTextStyles.sectionTitle.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        ...reviews.map((review) => _buildReviewCard(review, themeProvider)),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
      ],
    );
  }

  Widget _buildReviewCard(DAOReview review, ThemeProvider themeProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final statusColor = review.status.toLowerCase() == 'approved'
        ? Colors.green
        : review.status.toLowerCase() == 'rejected'
            ? colorScheme.error
            : _daoAccent;
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final viewerWallet = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
    final isOwnSubmission =
        WalletUtils.equals(viewerWallet, review.walletAddress);
    final votingDisabledOverride = review.metadata?['votingDisabled'] == true ||
        review.metadata?['voting_disabled'] == true;
    final normalizedStatus = review.status.toLowerCase();
    final moderationEnabled = AppConfig.isFeatureEnabled('daoReviewDecisions');
    final voteHelperText = !moderationEnabled
        ? l10n.daoReviewVotingHandledByDaoHelper
        : normalizedStatus == 'pending'
            ? (isOwnSubmission
                ? l10n.daoReviewCannotVoteOwnSubmissionHelper
                : votingDisabledOverride
                    ? l10n.daoReviewVotingDisabledSubmissionHelper
                    : l10n.daoReviewVotingOpensAfterReviewHelper)
            : l10n.daoReviewDecisionRecordedHelper(
                _daoReviewStatusLabel(review.status, l10n),
              );
    final isPending = normalizedStatus == 'pending';
    final canModerate = _capabilities().canModerateDao &&
        moderationEnabled &&
        !isOwnSubmission &&
        isPending;
    final isActionInFlight = _daoActionState.reviewActionId == review.id;

    return Container(
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm + KubusSpacing.xs),
      padding: const EdgeInsets.all(KubusSpacing.md - KubusSpacing.xxs),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _daoAccent.withValues(alpha: 0.2),
                backgroundImage: review.applicantProfile?['avatarUrl'] != null
                    ? NetworkImage(
                        review.applicantProfile!['avatarUrl'] as String)
                    : null,
                child: review.applicantProfile?['avatarUrl'] == null
                    ? Icon(Icons.person, color: _daoAccent)
                    : null,
              ),
              const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.applicantProfile?['displayName']?.toString() ??
                          review.walletAddress,
                      style: KubusTextStyles.navLabel.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      review.portfolioUrl,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _daoReviewStatusLabel(review.status, l10n),
                  style: KubusTextStyles.compactBadge.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            review.medium.isNotEmpty
                ? review.medium
                : l10n.daoReviewMediumNotProvided,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            review.statement,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: KubusTextStyles.detailBody.copyWith(
              fontSize: KubusChromeMetrics.navMetaLabel,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed:
                    isActionInFlight ? null : () => _showReviewDetails(review),
                icon: Icon(Icons.visibility,
                    color: colorScheme.onSurface, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _daoAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                label: Text(
                  l10n.daoReviewViewDetailsButton,
                  style: KubusTextStyles.actionTileTitle.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: KubusChromeMetrics.navMetaLabel,
                  ),
                ),
              ),
              const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voteHelperText,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        fontSize: KubusChromeMetrics.navMetaLabel - 1,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (canModerate) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isActionInFlight
                                  ? null
                                  : () => _confirmReviewDecision(
                                      review, 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isActionInFlight &&
                                      _daoActionState.reviewActionId ==
                                          review.id
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: InlineLoading(
                                          tileSize: 4,
                                          color: colorScheme.onPrimary),
                                    )
                                  : Text(
                                      l10n.daoModerationApproveLabel,
                                      style: KubusTextStyles.actionTileTitle
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize:
                                            KubusChromeMetrics.navMetaLabel,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: KubusSpacing.sm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isActionInFlight
                                  ? null
                                  : () => _confirmReviewDecision(
                                      review, 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(color: colorScheme.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isActionInFlight &&
                                      _daoActionState.reviewActionId ==
                                          review.id
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: InlineLoading(
                                          tileSize: 4,
                                          color: colorScheme.error),
                                    )
                                  : Text(
                                      l10n.daoModerationRejectLabel,
                                      style:
                                          KubusTextStyles.navMetaLabel.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReviewDecision(DAOReview review, String decision) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final notesController = TextEditingController();
    final decisionLabel = decision == 'approved'
        ? l10n.daoModerationApproveLabel
        : decision == 'rejected'
            ? l10n.daoModerationRejectLabel
            : l10n.daoModerationSetPendingLabel;

    final shouldProceed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        title: Text(
          l10n.daoModerationDecisionDialogTitle(decisionLabel),
          style: KubusTextStyles.sectionTitle.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoModerationDecisionDialogDescription,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.daoModerationReviewerNotesLabel,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(decisionLabel),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      await _handleReviewDecision(
          review, decision, notesController.text.trim(), messenger);
    }
  }

  Future<void> _handleReviewDecision(
    DAOReview review,
    String decision,
    String reviewerNotes,
    ScaffoldMessengerState messenger,
  ) async {
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final reviewerWallet = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );

    if (!_capabilities(listen: false).canModerateDao) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.daoModerationDisabledToast,
          ),
        ),
      );
      return;
    }

    if (!AppConfig.isFeatureEnabled('daoReviewDecisions')) {
      messenger.showKubusSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.daoModerationDisabledToast)),
      );
      return;
    }

    if (reviewerWallet.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .daoModerationWalletRequiredToast)),
      );
      return;
    }

    if (WalletUtils.equals(reviewerWallet, review.walletAddress)) {
      messenger.showKubusSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .daoModerationSelfNotAllowedToast)),
      );
      return;
    }

    setState(() => _daoActionState.beginReview(review.id));

    try {
      final updated = await context.read<DAOProvider>().decideReview(
            idOrWallet: review.id,
            status: decision,
            reviewerNotes: reviewerNotes.isNotEmpty ? reviewerNotes : null,
          );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            updated != null
                ? (decision == 'approved'
                    ? l10n.daoModerationSubmissionApprovedToast
                    : l10n.daoModerationSubmissionUpdatedToast)
                : l10n.daoModerationNoChangesSavedToast,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GovernanceHub: unable to update review: $e');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)!.daoModerationUpdateFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _daoActionState.endReview();
        });
      }
    }
  }

  void _showReviewDetails(DAOReview review) {
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final viewerWallet = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
    final isOwnSubmission =
        WalletUtils.equals(viewerWallet, review.walletAddress);
    final votingDisabledOverride = review.metadata?['votingDisabled'] == true ||
        review.metadata?['voting_disabled'] == true;
    final l10n = AppLocalizations.of(context)!;
    final voteDetailsText = isOwnSubmission
        ? l10n.daoReviewDetailsVotingDisabledForApplicant
        : votingDisabledOverride
            ? l10n.daoReviewDetailsVotingDisabledForSubmission
            : l10n.daoReviewDetailsVotingManagedByDao;
    final isPending = review.status.toLowerCase() == 'pending';
    final canModerate = _capabilities(listen: false).canModerateDao &&
        AppConfig.isFeatureEnabled('daoReviewDecisions') &&
        !isOwnSubmission &&
        isPending;
    final isActionInFlight = _daoActionState.reviewActionId == review.id;

    final colorScheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        title: Text(
          l10n.daoReviewDetailsDialogTitle,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                review.statement,
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.daoReviewDetailsPortfolioLabel(review.portfolioUrl),
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.daoReviewDetailsMediumLabel(review.medium),
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.daoReviewDetailsStatusLabel(review.status),
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.8)),
              ),
              if ((review.reviewerNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.daoReviewDetailsReviewerNotesLabel,
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  review.reviewerNotes ?? '',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.8)),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                voteDetailsText,
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        actions: [
          if (canModerate) ...[
            TextButton(
              onPressed: isActionInFlight
                  ? null
                  : () => _confirmReviewDecision(review, 'rejected'),
              child: Text(
                l10n.daoModerationRejectLabel,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: isActionInFlight
                  ? null
                  : () => _confirmReviewDecision(review, 'approved'),
              child: Text(l10n.daoModerationApproveLabel),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  /// Proposal hierarchy: title, status, summary, timeline, quorum
  /// requirement, results, actions. The quorum line states the requirement
  /// only: the backend sends no total voting power, so "reached/pending"
  /// cannot be known client-side and is not shown.
  Widget _buildProposalCard(Proposal proposal) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final material = MaterialLocalizations.of(context);
    final totalVotes = proposal.totalVotes;
    final supportPct = (proposal.supportPercentage * 100).clamp(0, 100);
    final capabilities = _capabilities(
      proposalAllowsVoting: proposal.isActive,
    );
    final end = proposal.votingEndDate;
    final timeline = end == null
        ? null
        : (end.isAfter(DateTime.now())
            ? l10n.daoVotingEndsLabel(material.formatMediumDate(end.toLocal()))
            : l10n
                .daoVotingEndedLabel(material.formatMediumDate(end.toLocal())));
    final quorumPercent = (proposal.quorumRequired * 100)
        .toStringAsFixed(proposal.quorumRequired * 100 % 1 == 0 ? 0 : 1);

    return Container(
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm + KubusSpacing.xs),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusNotionLabel(_proposalTypeLabel(proposal.type, l10n)),
          const SizedBox(height: KubusSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              proposal.title,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: roles.foreground,
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          KubusStatusText(
            label: daoProposalStatusLabel(l10n, proposal.status),
            tone: daoProposalStatusTone(proposal.status),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            proposal.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: KubusTextStyles.detailBody.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          if (timeline != null)
            Text(
              timeline,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foreground,
              ),
            ),
          Text(
            l10n.daoQuorumRequirementLabel(quorumPercent),
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          KubusNotionLabel(l10n.daoResultsNotion),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.daoProposalVotesSupportSummaryLabel(
              totalVotes,
              supportPct.toStringAsFixed(1),
            ),
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foreground,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KubusRadius.control),
              child: KubusMeterBar(
                progress: supportPct / 100,
                height: 6,
                color: roles.active,
                trackColor: roles.surfaceRaised,
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Wrap(
            spacing: KubusSpacing.md,
            runSpacing: KubusSpacing.xxs,
            children: [
              for (final text in [
                l10n.daoProposalVotesYesLabel(proposal.yesVotes.toString()),
                l10n.daoProposalVotesNoLabel(proposal.noVotes.toString()),
                l10n.daoProposalVotesAbstainLabel(
                    proposal.abstainVotes.toString()),
              ])
                Text(
                  text,
                  style: KubusTextStyles.machineValue.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
            ],
          ),
          if (capabilities.canVote) ...[
            const SizedBox(height: KubusSpacing.md),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                _buildVoteButton(proposal: proposal, isYes: true),
                _buildVoteButton(proposal: proposal, isYes: false),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _proposalTypeLabel(ProposalType type, AppLocalizations l10n) {
    switch (type) {
      case ProposalType.platformUpdate:
        return l10n.daoProposalTypePlatformUpdate;
      case ProposalType.rewards:
        return l10n.daoProposalTypeRewards;
      case ProposalType.featureRequest:
        return l10n.daoProposalTypeFeatureRequest;
      case ProposalType.governance:
        return l10n.daoProposalTypeGovernance;
      case ProposalType.community:
        return l10n.daoProposalTypeCommunity;
    }
  }

  String _daoReviewStatusLabel(String status, AppLocalizations l10n) {
    switch (status.toLowerCase()) {
      case 'approved':
        return l10n.daoReviewStatusApproved;
      case 'rejected':
        return l10n.daoReviewStatusRejected;
      case 'pending':
        return l10n.daoReviewStatusPending;
      default:
        return l10n.daoReviewStatusInReview;
    }
  }

  Widget _buildVotingHistory() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final roles = KubusColorRoles.of(context);
        // Get actual votes from provider - use user's votes if available
        final viewerWallet =
            context.watch<WalletProvider>().currentWalletAddress ?? '';
        final userVotes = daoProvider.votes
            .where((vote) => WalletUtils.equals(vote.voter, viewerWallet))
            .take(10)
            .toList();

        // Convert to display format
        final votingHistory = userVotes.map((vote) {
          final proposal = daoProvider.getProposalById(vote.proposalId);
          final isPassing = proposal?.isPassing == true;
          return {
            'title': proposal?.title ?? l10n.daoVotingHistoryUnknownProposal,
            'date': vote.timestamp.toString().substring(0, 10),
            'vote': vote.choice.name == 'yes'
                ? l10n.daoVoteChoiceYes
                : vote.choice.name == 'no'
                    ? l10n.daoVoteChoiceNo
                    : l10n.daoVoteChoiceAbstain,
            'isPassing': isPassing,
            'resultLabel': isPassing
                ? l10n.daoVotingResultPassing
                : l10n.daoVotingResultNotPassing,
            'participation': proposal != null && proposal.totalVotes > 0
                ? '${((proposal.totalVotes / 100000) * 100).toStringAsFixed(0)}%'
                : l10n.commonNotAvailableShort,
            'yourPower':
                l10n.daoVotingHistoryYourPowerLabel('${vote.votingPower} KUB8'),
          };
        }).toList();

        // Show placeholder if no voting history
        if (votingHistory.isEmpty) {
          return Center(
            child: EmptyStateCard(
              icon: Icons.how_to_vote,
              title: l10n.daoVotingHistoryEmptyTitle,
              description: l10n.daoVotingHistoryEmptyDescription,
            ),
          );
        }

        return Container(
          color: Colors.transparent,
          child: ListView.builder(
            padding: const EdgeInsets.all(KubusSpacing.md),
            itemCount: votingHistory.length,
            itemBuilder: (context, index) {
              final vote = votingHistory[index];
              final title = vote['title']?.toString() ?? '';
              final resultLabel = vote['resultLabel']?.toString() ?? '';
              final dateLabel = vote['date']?.toString() ?? '';
              final yourVoteLabel = vote['vote']?.toString() ?? '';
              final participationLabel =
                  vote['participation']?.toString() ?? '';
              final yourPowerLabel = vote['yourPower']?.toString() ?? '';
              final isPassing = vote['isPassing'] == true;
              final accent =
                  isPassing ? roles.positiveAction : roles.negativeAction;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(KubusSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(KubusRadius.lg),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: KubusTextStyles.sectionTitle.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.65),
                            ),
                          ),
                          child: Text(
                            resultLabel,
                            style: KubusTextStyles.compactBadge.copyWith(
                              color: accent.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KubusSpacing.md),
                    Row(
                      children: [
                        _buildHistoryInfo(
                            l10n.daoVotingHistoryInfoDateLabel, dateLabel),
                        const SizedBox(width: 24),
                        _buildHistoryInfo(
                            l10n.daoVotingHistoryInfoYourVoteLabel,
                            yourVoteLabel),
                        const SizedBox(width: 24),
                        _buildHistoryInfo(
                            l10n.daoVotingHistoryInfoParticipationLabel,
                            participationLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildHistoryInfo(
                      l10n.daoVotingHistoryInfoYourVotingPowerLabel,
                      yourPowerLabel,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryInfo(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.navMetaLabel.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        Text(
          value,
          style: KubusTextStyles.navLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateProposal() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoCreateProposalTitle,
              style: KubusTextStyles.screenTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.daoCreateProposalSubtitle,
              style: KubusTextStyles.screenSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            _buildFormField(
              l10n.daoCreateProposalFieldTitleLabel,
              l10n.daoCreateProposalFieldTitleHint,
              _titleController,
            ),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            _buildFormField(
              l10n.commonDescription,
              l10n.daoCreateProposalFieldDescriptionHint,
              _descriptionController,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              l10n.daoCreateProposalFieldVotingPeriodLabel,
              l10n.daoCreateProposalFieldVotingPeriodHint,
              _votingPeriodController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _buildProposalRequirements(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _daoActionState.proposalSubmitInFlight
                    ? null
                    : _submitProposal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _daoAccent,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
                child: _daoActionState.proposalSubmitInFlight
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: InlineLoading(
                          tileSize: 4,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Text(
                        l10n.daoCreateProposalSubmitButtonLabel,
                        style: KubusTextStyles.navLabel.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton({
    required Proposal proposal,
    required bool isYes,
  }) {
    final actionId = DaoActionState.proposalVoteActionId(proposal.id, isYes);
    final isCurrentAction = _daoActionState.voteActionId == actionId;
    final isAnyVoteInFlight = _daoActionState.voteActionId != null;
    final l10n = AppLocalizations.of(context)!;

    return KubusButton(
      onPressed: isAnyVoteInFlight
          ? null
          : () => _submitProposalVote(proposal.id, isYes),
      isLoading: isCurrentAction,
      label: isYes ? l10n.daoVoteYesButton : l10n.daoVoteNoButton,
      variant:
          isYes ? KubusButtonVariant.primary : KubusButtonVariant.secondary,
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.navLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: scheme.onSurface.withValues(alpha: 0.45)),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide:
                  BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide:
                  BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(color: _daoAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.daoProposalCategoryLabel,
          style: KubusTextStyles.navLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
          ),
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: scheme.surfaceContainerHighest,
            style: TextStyle(color: scheme.onSurface),
            items: _proposalCategories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(_categoryDisplayLabel(category, l10n)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  String _categoryDisplayLabel(String category, AppLocalizations l10n) {
    switch (category) {
      case _categoryPlatformUpdate:
        return l10n.daoCategoryPlatformUpdate;
      case _categoryNewFeature:
        return l10n.daoCategoryNewFeature;
      case _categoryPolicyChange:
        return l10n.daoCategoryPolicyChange;
      case _categoryTreasuryAllocation:
        return l10n.daoCategoryTreasuryAllocation;
      case _categoryCommunityInitiative:
        return l10n.daoCategoryCommunityInitiative;
      case _categoryTechnicalImprovement:
        return l10n.daoCategoryTechnicalImprovement;
      default:
        return category;
    }
  }

  Widget _buildProposalRequirements() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.daoProposalRequirementsTitle,
                style: KubusTextStyles.navLabel.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementItem(
              l10n.daoProposalRequirementWalletConnected,
              Provider.of<WalletProvider>(context, listen: false)
                  .authority
                  .canTransact),
          _buildRequirementItem(
              l10n.daoProposalRequirementClearlyDefined, true),
          _buildRequirementItem(l10n.daoProposalRequirementVotingPeriod, true),
          _buildRequirementItem(l10n.daoProposalRequirementQuorumTargets, true),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? scheme.primary : scheme.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitProposal() async {
    if (_daoActionState.proposalSubmitInFlight) return;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.daoProposalFillRequiredFieldsToast),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    final daoProvider = context.read<DAOProvider>();
    final web3Provider = context.read<Web3Provider>();
    final walletProvider = context.read<WalletProvider>();
    final profileProvider = context.read<ProfileProvider>();

    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      returnRoute: '/governance',
    );
    if (!mounted || !canProceed) {
      return;
    }

    final wallet =
        (walletProvider.currentWalletAddress ?? web3Provider.walletAddress)
            .trim();

    if (wallet.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.daoProposalWalletRequiredToast)),
      );
      return;
    }

    final selectedType = () {
      switch (_selectedCategory) {
        case _categoryPlatformUpdate:
          return ProposalType.platformUpdate;
        case _categoryNewFeature:
        case _categoryTechnicalImprovement:
          return ProposalType.featureRequest;
        case _categoryTreasuryAllocation:
          return ProposalType.rewards;
        case _categoryPolicyChange:
          return ProposalType.governance;
        case _categoryCommunityInitiative:
        default:
          return ProposalType.community;
      }
    }();

    final votingDays = int.tryParse(_votingPeriodController.text.trim()) ?? 7;

    if (!_daoActionState.beginProposalSubmit()) return;
    setState(() {});

    try {
      await daoProvider.createProposal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: selectedType,
        votingPeriodDays: votingDays,
      );

      if (!mounted) return;

      _clearForm();
      _setSelectedIndex(0);
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.daoProposalSubmittedToast),
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GovernanceHub: unable to submit proposal: $e');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.daoProposalSubmitFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _daoActionState.endProposalSubmit());
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _votingPeriodController.clear();
    setState(() {
      _selectedCategory = _categoryPlatformUpdate;
    });
  }

  Widget _buildTreasury() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoTreasuryTitle,
              style: KubusTextStyles.screenTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.daoTreasurySubtitle,
              style: KubusTextStyles.screenSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            _buildTreasuryOverview(),
            const SizedBox(height: 24),
            _buildRecentTransactions(),
            const SizedBox(height: 24),
            _buildTreasuryProposals(),
          ],
        ),
      ),
    );
  }

  Widget _buildTreasuryOverview() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final analytics = daoProvider.getDAOAnalytics();
        final treasuryAmountDisplay =
            (analytics['treasuryAmount'] as double? ?? 0.0).toStringAsFixed(2);
        final transactions = daoProvider.transactions;
        final inflow = transactions
            .where((tx) => tx.amount >= 0)
            .fold<double>(0, (sum, tx) => sum + tx.amount);
        final outflow = transactions
            .where((tx) => tx.amount < 0)
            .fold<double>(0, (sum, tx) => sum + tx.amount.abs());
        final isOnChain = daoProvider.treasuryOnChainBalance != null;
        final roles = KubusColorRoles.of(context);
        return Container(
          padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
          decoration: BoxDecoration(
            color: roles.surface,
            borderRadius: BorderRadius.circular(KubusRadius.surface),
            border: Border.all(color: roles.rule),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance,
                      color: Theme.of(context).colorScheme.onSurface, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnChain
                              ? l10n.daoTreasuryOnChainLabel
                              : l10n.daoTreasuryLedgerLabel,
                          style: KubusTextStyles.statLabel.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          '$treasuryAmountDisplay KUB8',
                          style: KubusTextStyles.statValue.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _buildTreasuryStatCard(
                          l10n.daoTreasuryInflowLabel,
                          '${inflow.toStringAsFixed(2)} KUB8',
                          Icons.trending_up)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTreasuryStatCard(
                          l10n.daoTreasuryOutflowLabel,
                          '${outflow.toStringAsFixed(2)} KUB8',
                          Icons.trending_down)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTreasuryStatCard(
                          l10n.daoTreasuryProposalsLabel,
                          '${daoProvider.proposals.length}',
                          Icons.security)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTreasuryStatCard(String label, String value, IconData icon) {
    final roles = KubusColorRoles.of(context);
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: roles.surfaceRaised,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            value,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: KubusTextStyles.compactBadge.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final transactions = daoProvider.transactions.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoRecentTransactionsTitle,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (transactions.isEmpty)
              Center(
                child: EmptyStateCard(
                  icon: Icons.history,
                  title: l10n.daoRecentTransactionsEmptyTitle,
                  description: l10n.daoRecentTransactionsEmptyDescription,
                ),
              )
            else
              ...transactions.map((tx) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(KubusSpacing.md),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tx.type == 'allocation'
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)
                                : tx.type == 'reward'
                                    ? Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.2)
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(KubusRadius.xl),
                          ),
                          child: Icon(
                            tx.type == 'allocation'
                                ? Icons.account_balance
                                : tx.type == 'reward'
                                    ? Icons.emoji_events
                                    : Icons.card_giftcard,
                            color: tx.type == 'allocation'
                                ? Theme.of(context).colorScheme.primary
                                : tx.type == 'reward'
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: KubusSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.type
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: KubusTextStyles.navLabel.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                tx.description,
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                              style: KubusTextStyles.navLabel.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _formatDate(tx.timestamp),
                              style: KubusTextStyles.navMetaLabel.copyWith(
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
                  )),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return l10n.commonTimeAgoDays(difference.inDays.toString());
    } else if (difference.inHours > 0) {
      return l10n.commonTimeAgoHours(difference.inHours.toString());
    } else {
      return l10n.commonTimeAgoMinutes(difference.inMinutes.toString());
    }
  }

  Widget _buildTreasuryProposals() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final treasuryProposals = daoProvider.proposals
            .where((p) => p.type == ProposalType.rewards)
            .toList();

        if (treasuryProposals.isEmpty) {
          return EmptyStateCard(
            icon: Icons.savings,
            title: l10n.daoTreasuryProposalsEmptyTitle,
            description: l10n.daoTreasuryProposalsEmptyDescription,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.daoTreasuryProposalsTitle,
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (_capabilities().canCreateProposal) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => _setSelectedIndex(2),
                    child: Text(
                      l10n.daoCreateProposalButton,
                      style: TextStyle(color: _daoAccent),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            ...treasuryProposals
                .map((proposal) => _buildProposalCard(proposal)),
          ],
        );
      },
    );
  }

  Widget _buildDelegation(Web3Capabilities capabilities) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoVoteDelegationTitle,
              style: KubusTextStyles.screenTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.daoVoteDelegationSubtitle,
              style: KubusTextStyles.screenSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            if (!capabilities.canDelegate) ...[
              _buildParticipationState(capabilities),
              const SizedBox(height: KubusSpacing.lg),
            ],
            _buildTopDelegates(capabilities),
            if (capabilities.canDelegate) ...[
              const SizedBox(height: KubusSpacing.lg),
              _buildDelegationActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopDelegates(Web3Capabilities capabilities) {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final delegates = daoProvider.delegates.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoTopDelegatesTitle,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (delegates.isEmpty)
              Center(
                child: EmptyStateCard(
                  icon: Icons.people,
                  title: l10n.daoTopDelegatesEmptyTitle,
                  description: l10n.daoTopDelegatesEmptyDescription,
                ),
              )
            else
              ...delegates.map((delegate) => GestureDetector(
                    onTap: capabilities.canDelegate
                        ? () => _delegateVote(delegate)
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: KubusSpacing.md),
                      padding: const EdgeInsets.all(KubusSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(KubusRadius.md),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _daoAccent,
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.xl),
                            ),
                            child: Center(
                              child: Text(
                                delegate.name.substring(0, 1).toUpperCase(),
                                style: KubusTextStyles.sectionTitle.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  delegate.name,
                                  style:
                                      KubusTextStyles.actionTileTitle.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${l10n.daoDelegationDelegatorsCountLabel(delegate.delegatorCount)} • ${l10n.daoDelegationParticipationRateLabel((delegate.participationRate * 100).toStringAsFixed(0))}',
                                  style: KubusTextStyles.navMetaLabel.copyWith(
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(delegate.votingPower / 1000).toStringAsFixed(1)}K KUB8',
                                style: KubusTextStyles.actionTileTitle.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  l10n.daoDelegateActiveLabel,
                                  style: KubusTextStyles.compactBadge.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: KubusSpacing.xs),
                              if (capabilities.canDelegate)
                                Text(
                                  l10n.daoTapToDelegateHint,
                                  style: KubusTextStyles.compactBadge.copyWith(
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildDelegationActions() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.daoDelegationActionsTitle,
          style: KubusTextStyles.sectionTitle.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.daoDelegationActionsSubtitle,
          style: KubusTextStyles.sectionSubtitle.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showDelegateSelection,
            icon: Icon(Icons.people_outline, size: 20),
            label: Text(l10n.daoDelegateToTrustedMembersButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDelegateSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          final l10n = AppLocalizations.of(context)!;
          final scheme = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KubusRadius.xl)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(KubusSpacing.xl),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outline.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.daoDelegationSelectDelegateTitle,
                        style: KubusTextStyles.sheetTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.daoDelegationSelectDelegateSubtitle,
                        textAlign: TextAlign.center,
                        style: KubusTextStyles.sheetSubtitle.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<DAOProvider>(
                    builder: (context, daoProvider, child) {
                      final delegates = daoProvider.delegates.take(10).toList();

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: delegates.length,
                        itemBuilder: (context, index) {
                          final delegate = delegates[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _delegateVote(delegate);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.surfaceContainerHighest,
                                foregroundColor: scheme.onSurface,
                                padding: const EdgeInsets.all(KubusSpacing.md),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(KubusRadius.md),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _daoAccent,
                                      borderRadius:
                                          BorderRadius.circular(KubusRadius.xl),
                                    ),
                                    child: Center(
                                      child: Text(
                                        delegate.name
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: KubusTextStyles.sectionTitle
                                            .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          delegate.name,
                                          style: KubusTextStyles.sectionTitle
                                              .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        Text(
                                          '${l10n.daoDelegationDelegatorsCountLabel(delegate.delegatorCount)} • ${l10n.daoDelegationParticipationRateLabel((delegate.participationRate * 100).toStringAsFixed(0))}',
                                          style: KubusTextStyles.navMetaLabel
                                              .copyWith(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${(delegate.votingPower / 1000).toStringAsFixed(1)}K KUB8',
                                    style: KubusTextStyles.actionTileTitle
                                        .copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.55),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _delegateVote(Delegate delegate) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final votingPowerDisplay =
        '${context.read<Web3Provider>().kub8Balance.toStringAsFixed(2)} KUB8';
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(
          l10n.daoDelegateVotingPowerDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(color: scheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoDelegateVotingPowerDialogBody(
                  votingPowerDisplay, delegate.name),
              style: KubusTextStyles.detailBody.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: KubusSpacing.lg),
            Container(
              padding: const EdgeInsets.all(KubusSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KubusRadius.md),
                border: Border.all(color: scheme.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        l10n.daoDelegationBenefitsTitle,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  Text(
                    l10n.daoDelegationBenefitsBody,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel,
                style:
                    TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeDelegation(delegate);
            },
            child: Text(l10n.daoConfirmDelegationButton,
                style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDelegation(Delegate delegate) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profileProvider = context.read<ProfileProvider>();

    if (!_capabilities(listen: false).canDelegate) {
      return;
    }
    final walletProvider = context.read<WalletProvider>();
    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      returnRoute: '/governance',
    );
    if (!mounted || !canProceed) return;

    try {
      final result = await context.read<DAOProvider>().delegateVotingPower(
        delegateId: delegate.id,
        metadata: <String, dynamic>{
          'delegateWallet': delegate.address,
        },
      );
      if (!mounted) return;
      if (result == null) {
        throw StateError('Delegation was not persisted');
      }
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.daoDelegationSuccessToast(delegate.name)),
          backgroundColor: scheme.primary,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('GovernanceHub: unable to delegate voting power: $error');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.daoDelegationFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  Future<void> _submitProposalVote(String proposalId, bool isYes) async {
    if (_daoActionState.voteActionId != null) return;
    final daoProvider = context.read<DAOProvider>();
    final web3Provider = context.read<Web3Provider>();
    final walletProvider = context.read<WalletProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final proposal = daoProvider.getProposalById(proposalId);
    if (!_capabilities(
      proposalAllowsVoting: proposal?.isActive ?? false,
      listen: false,
    ).canVote) {
      return;
    }

    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      returnRoute: '/governance',
    );
    if (!mounted || !canProceed) {
      return;
    }

    final wallet =
        (walletProvider.currentWalletAddress ?? web3Provider.walletAddress)
            .trim();

    if (wallet.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.daoVoteWalletRequiredToast)),
      );
      return;
    }

    if (!_daoActionState.beginVote(proposalId, isYes)) return;
    setState(() {});

    try {
      await daoProvider.castVote(
        proposalId: proposalId,
        choice: isYes ? VoteChoice.yes : VoteChoice.no,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            isYes
                ? AppLocalizations.of(context)!.daoVoteSubmittedYesToast
                : AppLocalizations.of(context)!.daoVoteSubmittedNoToast,
          ),
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GovernanceHub: unable to submit vote: $e');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.daoVoteSubmitFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _daoActionState.endVote());
      }
    }
  }

  void _showGovernanceInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.daoHubInfoDialogTitle,
                style: KubusTextStyles.sheetTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.daoHubInfoDialogBody,
                style: KubusTextStyles.sheetSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
