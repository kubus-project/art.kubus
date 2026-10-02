import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/dashboard/kubus_dashboard_chrome.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import 'artist_portfolio_screen.dart';
import 'artist_analytics.dart';
import 'artist_studio_create_screen.dart';
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../models/promotion.dart';
import '../../../models/user_persona.dart';
import '../../../utils/dao_role_verification.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../../widgets/promotion/promotion_builder_sheet.dart';
import '../../../widgets/topbar_icon.dart';

@visibleForTesting
String? resolveArtistPromotionUnavailableReason({
  required String walletAddress,
  required DAOReview? review,
  required String walletRequiredReason,
  required String institutionConflictReason,
  required String approvalRequiredReason,
}) {
  final normalizedWallet = walletAddress.trim();
  if (normalizedWallet.isEmpty) {
    return walletRequiredReason;
  }

  final verification = DaoRoleVerification(
    walletAddress: normalizedWallet,
    review: review,
  );

  if (verification.isApprovedFor(DaoRoleType.institution) ||
      verification.isPendingFor(DaoRoleType.institution)) {
    return institutionConflictReason;
  }
  if (!verification.isApprovedFor(DaoRoleType.artist)) {
    return approvalRequiredReason;
  }
  return null;
}

class ArtistStudio extends StatefulWidget {
  final VoidCallback? onOpenArtworkCreator;
  final VoidCallback? onOpenCollectionCreator;
  final VoidCallback? onOpenExhibitionCreator;
  final ValueChanged<int>? onTabChanged;
  final bool showVerificationCard;
  final bool embedded;

  const ArtistStudio({
    super.key,
    this.onOpenArtworkCreator,
    this.onOpenCollectionCreator,
    this.onOpenExhibitionCreator,
    this.onTabChanged,
    this.showVerificationCard = true,
    this.embedded = false,
  });

  @override
  State<ArtistStudio> createState() => _ArtistStudioState();
}

class _ArtistStudioState extends State<ArtistStudio> {
  int _selectedIndex = 0;
  DAOReview? _artistReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';
  bool _hasSetInitialTabByPersona = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = _resolveWalletAddress(listen: true);
    final walletChanged = wallet != _lastReviewWallet;
    final persona = context.watch<ProfileProvider>().userPersona;
    if (!_hasSetInitialTabByPersona && persona != null) {
      final desiredIndex = persona == UserPersona.creator ? 1 : 0;
      if (_selectedIndex != desiredIndex) {
        _selectedIndex = desiredIndex;
        widget.onTabChanged?.call(desiredIndex);
      }
      _hasSetInitialTabByPersona = true;
    }

    if (!walletChanged && _hasFetchedReviewForWallet) return;

    final daoProvider = context.read<DAOProvider>();
    final cachedReview =
        wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null;

    setState(() {
      _artistReview = cachedReview;
      _lastReviewWallet = wallet;
      _reviewLoading = false;
      _hasFetchedReviewForWallet = cachedReview != null;
    });

    if (wallet.isNotEmpty) {
      _loadArtistReviewStatus(forceRefresh: true);
    }
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(ArtistStudioOnboardingData.featureKey)) {
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
          featureKey: ArtistStudioOnboardingData.featureKey,
          featureTitle: ArtistStudioOnboardingData.featureTitle(l10n),
          pages: ArtistStudioOnboardingData.pages(l10n),
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

  String? _artistPromotionUnavailableReason() {
    final l10n = AppLocalizations.of(context)!;
    final daoProvider = context.read<DAOProvider>();
    final wallet = _resolveWalletAddress();
    final review = _artistReview ?? daoProvider.findReviewForWallet(wallet);
    return resolveArtistPromotionUnavailableReason(
      walletAddress: wallet,
      review: review,
      walletRequiredReason: l10n.artistPromotionRequiresWalletReason,
      institutionConflictReason:
          l10n.artistPromotionConflictWithInstitutionReason,
      approvalRequiredReason: l10n.artistPromotionRequiresApprovalReason,
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
      });
    } catch (e) {
      // Soft-fail; errors are already logged in DAOProvider
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _artistReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final isApprovedArtist = verification.isApprovedFor(DaoRoleType.artist);
    final hasInstitutionBadge =
        verification.isApprovedFor(DaoRoleType.institution);
    final hasConflictingInstitutionReview =
        verification.isPendingFor(DaoRoleType.institution);
    final isCrossRoleBlocked =
        hasInstitutionBadge || hasConflictingInstitutionReview;
    final canSelfServeArtistPromotion = isApprovedArtist && !isCrossRoleBlocked;

    // Build pages list - Exhibitions tab is optional based on feature flag
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final walletAddress = _resolveWalletAddress(listen: true);
    final pages = <Widget>[
      ArtistPortfolioScreen(
        walletAddress: walletAddress,
        onCreateRequested: () => _setSelectedIndex(1),
      ),
      ArtistStudioCreateScreen(
        onArtworkCreated: () => _setSelectedIndex(0),
        onCollectionCreated: () => _setSelectedIndex(0),
        onOpenArtworkCreator: widget.onOpenArtworkCreator,
        onOpenCollectionCreator: widget.onOpenCollectionCreator,
        onOpenExhibitionCreator: widget.onOpenExhibitionCreator,
      ),
      if (exhibitionsEnabled)
        const ExhibitionListScreen(embedded: true, canCreate: true),
      const ArtistAnalytics(),
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
              title: Text(
                l10n.artistStudioTitle,
                style: KubusTextStyles.responsiveMobileAppBarTitle(context)
                    .copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TopBarIcon(
                  tooltip: l10n.artistCreatorHelpTitle,
                  icon: Icon(
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _showOnboarding,
                ),
                if (AppConfig.isFeatureEnabled('collabInvites'))
                  Consumer<CollabProvider>(
                    builder: (context, collabProvider, _) {
                      final pendingCount = collabProvider.pendingInviteCount;
                      return TopBarIcon(
                        tooltip:
                            l10n.desktopArtistStudioQuickActionInvitesTitle,
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
                if (canSelfServeArtistPromotion)
                  TopBarIcon(
                    icon: Icon(
                      Icons.campaign_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    tooltip: l10n.artistStudioPromoteTooltip,
                    onPressed: _openProfilePromotionFlow,
                  ),
                TopBarIcon(
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  tooltip:
                      MaterialLocalizations.of(context).openAppDrawerTooltip,
                  onPressed: _showSettings,
                ),
              ],
            ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildStudioHeader(
                    canSelfServeArtistPromotion: canSelfServeArtistPromotion,
                  ),
                  if (widget.showVerificationCard)
                    _buildArtistApplicationCard(
                      review,
                      isApprovedArtist,
                      isCrossRoleBlocked: isCrossRoleBlocked,
                      hasInstitutionBadge: hasInstitutionBadge,
                      hasConflictingInstitutionReview:
                          hasConflictingInstitutionReview,
                    ),
                  if (!isCrossRoleBlocked)
                    _buildNavigationTabs(isApprovedArtist),
                ],
              ),
            ),
          ];
        },
        body: isCrossRoleBlocked
            ? _buildRoleBlockedContent(
                title: hasInstitutionBadge
                    ? l10n.artistStudioInstitutionRoleActiveTitle
                    : l10n.artistStudioInstitutionReviewInProgressTitle,
                description: hasInstitutionBadge
                    ? l10n.artistStudioInstitutionRoleActiveDescription
                    : l10n.artistStudioInstitutionReviewInProgressDescription,
                icon: Icons.domain_disabled,
              )
            : isApprovedArtist
                ? pages[_selectedIndex]
                : _buildLockedContent(),
      ),
    );
  }

  Widget _buildStudioHeader({
    required bool canSelfServeArtistPromotion,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Practice leads; paid promotion is a quiet secondary action.
    return KubusDashboardHeader(
      notion: l10n.studioNotionPractice,
      accent: KubusColorRoles.of(context).web3ArtistStudioAccent,
      glyph: Icons.palette_outlined,
      title: l10n.artistStudioTitle,
      lede: l10n.artistStudioHeaderSubtitle,
      actions: [
        if (canSelfServeArtistPromotion)
          KubusButton(
            onPressed: _openProfilePromotionFlow,
            icon: Icons.campaign_outlined,
            label: l10n.artistStudioPromoteProfile,
            variant: KubusButtonVariant.quiet,
          ),
      ],
    );
  }

  Widget _buildArtistApplicationCard(
    DAOReview? review,
    bool isApprovedArtist, {
    required bool isCrossRoleBlocked,
    required bool hasInstitutionBadge,
    required bool hasConflictingInstitutionReview,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (isCrossRoleBlocked) {
      final title = hasInstitutionBadge
          ? l10n.artistStudioCrossRoleInstitutionBadgeActiveTitle
          : hasConflictingInstitutionReview
              ? l10n.artistStudioCrossRoleInstitutionReviewInProgressTitle
              : l10n.artistStudioCrossRoleConflictTitle;
      final message = hasInstitutionBadge
          ? l10n.artistStudioCrossRoleInstitutionBadgeActiveDescription
          : hasConflictingInstitutionReview
              ? l10n.artistStudioCrossRoleInstitutionReviewInProgressDescription
              : l10n.artistStudioCrossRoleConflictDescription;
      return KubusNoticeBanner(
        icon: Icons.domain_disabled,
        title: title,
        message: message,
        tone: KubusStatusTone.negative,
      );
    }

    final wallet = _resolveWalletAddress();
    final status = review?.status.toLowerCase() ?? '';
    final isPending = status == 'pending';
    final isApproved = isApprovedArtist;
    final isRejected = status == 'rejected' && !isApprovedArtist;
    final statusLabel = isApproved
        ? l10n.artistStudioDaoStatusApproved
        : review != null
            ? (isPending
                ? l10n.artistStudioDaoStatusPending
                : isRejected
                    ? l10n.artistStudioDaoStatusRejected
                    : status.toUpperCase())
            : l10n.artistStudioDaoStatusNotApplied;
    final tone = isApproved
        ? KubusStatusTone.positive
        : isRejected
            ? KubusStatusTone.negative
            : isPending
                ? KubusStatusTone.warning
                : KubusStatusTone.neutral;
    final hasWallet = wallet.isNotEmpty;
    final canSubmit = hasWallet &&
        !_reviewLoading &&
        (!isPending && !isApproved || isRejected);
    final ctaLabel = !hasWallet
        ? l10n.artistStudioCtaConnectWalletToApply
        : isApproved
            ? l10n.artistStudioCtaApprovedByDao
            : isPending
                ? l10n.artistStudioCtaPendingDaoReview
                : isRejected
                    ? l10n.artistStudioCtaResubmitForReview
                    : l10n.artistStudioCtaApplyForDaoReview;
    final IconData ctaIcon = isApproved
        ? Icons.verified_outlined
        : isPending
            ? Icons.hourglass_bottom
            : Icons.send_rounded;

    String? detail;
    if ((review?.reviewerNotes ?? '').isNotEmpty) {
      detail = review!.reviewerNotes!;
    } else if (review != null) {
      detail = isPending
          ? l10n.artistStudioReviewPendingInfo
          : isApproved
              ? l10n.artistStudioReviewApprovedInfo
              : isRejected
                  ? l10n.artistStudioReviewRejectedInfo
                  : null;
    } else if (!hasWallet) {
      detail = l10n.artistStudioConnectWalletToSubmitForDaoReview;
    }

    return KubusStatusPanel(
      title: l10n.artistStudioDaoCardTitle,
      description: l10n.artistStudioDaoCardSubtitle,
      statusLabel: (review != null || _reviewLoading) ? statusLabel : null,
      tone: tone,
      isLoading: _reviewLoading,
      meta: review != null ? l10n.artistStudioStatusSyncedFromDao : null,
      detail: detail,
      action: KubusButton(
        onPressed: canSubmit ? () => _showArtistApplicationModal() : null,
        label: ctaLabel,
        icon: ctaIcon,
        isFullWidth: true,
        variant: canSubmit
            ? KubusButtonVariant.primary
            : KubusButtonVariant.secondary,
      ),
    );
  }

  Widget _buildNavigationTabs(bool isApprovedArtist) {
    final l10n = AppLocalizations.of(context)!;
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    return KubusDashboardTabs(
      selectedIndex: _selectedIndex,
      enabled: isApprovedArtist,
      onSelected: _setSelectedIndex,
      onLockedTap: () => ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.artistStudioUnlocksAfterDaoApprovalToast)),
      ),
      tabs: [
        KubusDashboardTab(
          label: l10n.artistStudioTabGallery,
          icon: Icons.collections_outlined,
        ),
        KubusDashboardTab(
          label: l10n.artistStudioTabCreate,
          icon: Icons.add_circle_outline,
        ),
        if (exhibitionsEnabled)
          KubusDashboardTab(
            label: l10n.artistStudioTabExhibitions,
            icon: AppColorUtils.exhibitionIcon,
          ),
        KubusDashboardTab(
          label: l10n.artistStudioTabAnalytics,
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
        description: '$description\n\n${l10n.artistStudioSeparateWalletsTip}',
      ),
    );
  }

  Widget _buildLockedContent() {
    final l10n = AppLocalizations.of(context)!;
    return _buildStateSlot(
      EmptyStateCard(
        icon: Icons.lock_outline,
        title: l10n.artistStudioLockedTitle,
        description: l10n.artistStudioLockedDescription,
        showAction: true,
        actionLabel: l10n.artistStudioCtaApplyForDaoReview,
        onAction: _showArtistApplicationModal,
      ),
    );
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

  void _showSettings() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return BackdropGlassSheet(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          showHandle: false,
          backgroundColor:
              scheme.surfaceContainerHighest.withValues(alpha: 0.18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KubusSheetHeader(
                title: l10n.artistStudioSettingsTitle,
                showHandle: false,
              ),
              // Add settings options here
            ],
          ),
        );
      },
    );
  }

  @visibleForTesting
  Future<void> debugOpenProfilePromotionFlow() => _openProfilePromotionFlow();

  Future<void> _openProfilePromotionFlow() async {
    final l10n = AppLocalizations.of(context)!;
    final unavailableReason = _artistPromotionUnavailableReason();
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
      entityType: PromotionEntityType.profile,
      entityId: entityId,
      entityLabel: profile?.displayName ?? l10n.desktopArtistStudioMyProfile,
    );
  }

  Future<void> _showArtistApplicationModal() async {
    final l10n = AppLocalizations.of(context)!;
    final portfolioController = TextEditingController();
    final mediumController = TextEditingController();
    final statementController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scaffold = ScaffoldMessenger.of(context);
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            return SingleChildScrollView(
              child: BackdropGlassSheet(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                showHandle: false,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KubusSheetHeader(
                        title: l10n.artistStudioApplicationModalTitle,
                        subtitle: l10n.artistStudioApplicationModalSubtitle,
                        showHandle: false,
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      TextFormField(
                        controller: portfolioController,
                        decoration: InputDecoration(
                          labelText:
                              l10n.artistStudioApplicationFieldPortfolioLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null ||
                                value.trim().isEmpty)
                            ? l10n.artistStudioApplicationValidationPortfolio
                            : null,
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      TextFormField(
                        controller: mediumController,
                        decoration: InputDecoration(
                          labelText:
                              l10n.artistStudioApplicationFieldMediumLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? l10n.artistStudioApplicationValidationMedium
                                : null,
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      TextFormField(
                        controller: statementController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              l10n.artistStudioApplicationFieldStatementLabel,
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null ||
                                value.trim().length < 20)
                            ? l10n
                                .artistStudioApplicationValidationStatementMinChars(
                                    20)
                            : null,
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: KubusButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final profileProvider =
                                      context.read<ProfileProvider>();
                                  final walletProvider =
                                      context.read<WalletProvider>();
                                  final web3Provider =
                                      context.read<Web3Provider>();
                                  final daoProvider =
                                      context.read<DAOProvider>();
                                  final navigator = Navigator.of(sheetContext);
                                  final roles = KubusColorRoles.of(context);
                                  final successColor = roles.positiveAction;
                                  final errorColor = roles.negativeAction;
                                  final wallet = profileProvider
                                          .currentUser?.walletAddress ??
                                      web3Provider.walletAddress;
                                  if (wallet.isEmpty) {
                                    scaffold.showKubusSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.artistStudioApplicationWalletRequiredToast,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final canProceed = await WalletActionGuard
                                      .ensureSignerAccess(
                                    context: context,
                                    profileProvider: profileProvider,
                                    walletProvider: walletProvider,
                                  );
                                  if (!mounted || !canProceed) {
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final review =
                                        await daoProvider.submitReview(
                                      portfolioUrl:
                                          portfolioController.text.trim(),
                                      medium: mediumController.text.trim(),
                                      statement:
                                          statementController.text.trim(),
                                      title: l10n
                                          .artistStudioApplicationReviewTitle,
                                      metadata: const {
                                        'role': 'artist',
                                        'source': 'artist_studio',
                                      },
                                    );
                                    if (!mounted) return;
                                    if (review != null) {
                                      await _loadArtistReviewStatus(
                                        forceRefresh: true,
                                      );
                                      if (!mounted) return;
                                    }
                                    navigator.pop();
                                    if (!mounted) return;
                                    scaffold.showKubusSnackBar(
                                      SnackBar(
                                        content: Text(
                                          review != null
                                              ? l10n
                                                  .artistStudioApplicationSubmittedToast
                                              : l10n
                                                  .artistStudioApplicationUnableToSubmitToast,
                                        ),
                                        backgroundColor: review != null
                                            ? successColor
                                            : errorColor,
                                      ),
                                    );
                                  } catch (err) {
                                    if (kDebugMode) {
                                      debugPrint(
                                        'ArtistStudio: submission failed: $err',
                                      );
                                    }
                                    if (!mounted) return;
                                    scaffold.showKubusSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.artistStudioApplicationSubmissionFailedToast,
                                        ),
                                        backgroundColor: errorColor,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setModalState(
                                        () => isSubmitting = false,
                                      );
                                    }
                                  }
                                },
                          label: l10n.artistStudioApplicationSubmitButton,
                          icon: Icons.send_rounded,
                          isLoading: isSubmitting,
                          isFullWidth: true,
                          backgroundColor: KubusColorRoles.of(context)
                              .web3ArtistStudioAccent,
                          foregroundColor: ThemeData.estimateBrightnessForColor(
                                      KubusColorRoles.of(context)
                                          .web3ArtistStudioAccent) ==
                                  Brightness.dark
                              ? KubusColors.textPrimaryDark
                              : KubusColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    portfolioController.dispose();
    mediumController.dispose();
    statementController.dispose();
  }
}
