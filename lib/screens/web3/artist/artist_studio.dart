import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
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
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../models/user_persona.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class ArtistStudio extends StatefulWidget {
  final VoidCallback? onOpenArtworkCreator;
  final VoidCallback? onOpenCollectionCreator;
  final VoidCallback? onOpenExhibitionCreator;
  final ValueChanged<int>? onTabChanged;

  const ArtistStudio({
    super.key,
    this.onOpenArtworkCreator,
    this.onOpenCollectionCreator,
    this.onOpenExhibitionCreator,
    this.onTabChanged,
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
      final isArtistReview = _artistReview?.isArtistApplication ?? false;
      final isApproved =
          isArtistReview && (_artistReview?.status.toLowerCase() == 'approved');
      if (isApproved) {
        try {
          context.read<ProfileProvider>().setRoleFlags(isArtist: true);
        } catch (_) {}
      }
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
    final profileProvider = context.watch<ProfileProvider>();
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _artistReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final hasArtistBadge = profileProvider.currentUser?.isArtist ?? false;
    final hasInstitutionBadge =
        profileProvider.currentUser?.isInstitution ?? false;
    final reviewStatus = review?.status.toLowerCase() ?? '';
    final reviewIsArtist = review?.isArtistApplication ?? false;
    final reviewIsInstitution = review?.isInstitutionApplication ?? false;
    final isApprovedArtist =
        hasArtistBadge || (reviewIsArtist && reviewStatus == 'approved');
    final isReviewRejected = reviewStatus == 'rejected';
    final hasConflictingInstitutionReview =
        reviewIsInstitution && !isReviewRejected;
    final isCrossRoleBlocked =
        hasInstitutionBadge || hasConflictingInstitutionReview;

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.artistStudioTitle,
          style: KubusTextStyles.screenTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showOnboarding,
          ),
          if (AppConfig.isFeatureEnabled('collabInvites'))
            Consumer<CollabProvider>(
              builder: (context, collabProvider, _) {
                final pendingCount = collabProvider.pendingInviteCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Invites',
                      icon: Icon(Icons.inbox_outlined,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const InvitesInboxScreen()),
                        );
                      },
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        right: KubusSpacing.sm,
                        top: KubusSpacing.xs + KubusSpacing.xxs,
                        child: FrostedContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.xs + KubusSpacing.xxs,
                            vertical: KubusSpacing.xxs,
                          ),
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                          showBorder: true,
                          backgroundColor: Theme.of(context).colorScheme.error,
                          child: Text(
                            pendingCount > 99 ? '99+' : pendingCount.toString(),
                            style: KubusTextStyles.badgeCount.copyWith(
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.settings,
                color: Theme.of(context).colorScheme.onSurface),
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
                  _buildStudioHeader(),
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

  Widget _buildStudioHeader() {
    final studioAccent = KubusColorRoles.of(context).web3ArtistStudioAccent;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      padding: const EdgeInsets.all(KubusSpacing.md + KubusSpacing.xs),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            studioAccent,
            studioAccent.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(KubusRadius.lg + KubusRadius.xs),
      ),
      child: Row(
        children: [
          Container(
            width: KubusSpacing.xxl + KubusSpacing.sm,
            height: KubusSpacing.xxl + KubusSpacing.sm,
            decoration: BoxDecoration(
              color: KubusColors.glassLight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(KubusRadius.lg),
            ),
            child: Icon(
              Icons.palette,
              color: KubusColors.textPrimaryDark,
              size: KubusSpacing.lg + KubusSpacing.xs + KubusSpacing.xxs,
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.artistStudioHeaderWelcome,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: KubusColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  AppLocalizations.of(context)!.artistStudioHeaderSubtitle,
                  style: KubusTextStyles.actionTileSubtitle.copyWith(
                    color: KubusColors.textPrimaryDark.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
      final scheme = Theme.of(context).colorScheme;
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
      return _buildRoleBanner(
        icon: Icons.domain_disabled,
        title: title,
        message: message,
        scheme: scheme,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final studioColor = KubusColorRoles.of(context).web3ArtistStudioAccent;
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
    final statusColor = isApproved
        ? KubusColorRoles.of(context).positiveAction
        : isRejected
            ? KubusColorRoles.of(context).negativeAction
            : isPending
                ? KubusColorRoles.of(context).warningAction
                : studioColor;
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

    final cardRadius = BorderRadius.circular(KubusRadius.lg);
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      padding: EdgeInsets.zero,
      borderRadius: cardRadius,
      showBorder: false,
      backgroundColor:
          scheme.surface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: cardRadius,
          border: Border.all(color: studioColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md + KubusSpacing.xs - KubusSpacing.xxs),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: KubusSpacing.xxl,
                height: KubusSpacing.xxl,
                decoration: BoxDecoration(
                  color: studioColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(
                  Icons.brush_rounded,
                  color: studioColor,
                  size: KubusSpacing.lg,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.artistStudioDaoCardTitle,
                      style: KubusTextStyles.sectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      l10n.artistStudioDaoCardSubtitle,
                      style: KubusTextStyles.actionTileSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review != null || _reviewLoading) ...[
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm + KubusSpacing.xs - KubusSpacing.xxs,
                    vertical: KubusSpacing.xs + KubusSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                  child: Text(
                    statusLabel,
                    style: KubusTextStyles.badgeCount
                        .copyWith(color: statusColor),
                  ),
                ),
                const SizedBox(width: KubusSpacing.sm),
                if (_reviewLoading)
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  )
                else if (review != null)
                  Text(
                    l10n.artistStudioStatusSyncedFromDao,
                    style: KubusTextStyles.badgeCount.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
            if ((review?.reviewerNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.sm),
              Text(
                review!.reviewerNotes!,
                style: KubusTextStyles.actionTileSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ] else if (review != null) ...[
              const SizedBox(height: KubusSpacing.sm),
              Text(
                isPending
                    ? l10n.artistStudioReviewPendingInfo
                    : isApproved
                        ? l10n.artistStudioReviewApprovedInfo
                        : isRejected
                            ? l10n.artistStudioReviewRejectedInfo
                            : '',
                style: KubusTextStyles.actionTileSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ] else if (!hasWallet) ...[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.artistStudioConnectWalletToSubmitForDaoReview,
              style: KubusTextStyles.actionTileSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: KubusSpacing.md),
          SizedBox(
            width: double.infinity,
            child: KubusButton(
              onPressed: canSubmit ? () => _showArtistApplicationModal() : null,
              label: ctaLabel,
              icon: ctaIcon,
              isFullWidth: true,
              backgroundColor: studioColor,
              foregroundColor: ThemeData.estimateBrightnessForColor(studioColor) ==
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
  }

  Widget _buildNavigationTabs(bool isApprovedArtist) {
    final l10n = AppLocalizations.of(context)!;
    final studioColor = KubusColorRoles.of(context).web3ArtistStudioAccent;
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.22 : 0.14);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: studioColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: LiquidGlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(KubusSpacing.xs),
        borderRadius: radius,
        blurSigma: KubusGlassEffects.blurSigmaLight,
        showBorder: false,
        backgroundColor: glassTint,
        child: Row(
          children: [
            Expanded(
                child: _buildTabButton(l10n.artistStudioTabGallery,
                    Icons.collections, 0, isApprovedArtist, studioColor)),
            Expanded(
                child: _buildTabButton(l10n.artistStudioTabCreate,
                  Icons.add_circle_outline, 1, isApprovedArtist, studioColor)),
          if (exhibitionsEnabled)
            Expanded(
                child: _buildTabButton(
                    l10n.artistStudioTabExhibitions,
                    Icons.collections_bookmark,
                    2,
                    isApprovedArtist,
                    studioColor)),
          Expanded(
              child: _buildTabButton(
                  l10n.artistStudioTabAnalytics,
                  Icons.analytics,
                  exhibitionsEnabled ? 3 : 2,
                  isApprovedArtist,
                  studioColor)),
          ],
        ),
      )
    );
  }

  Widget _buildTabButton(
      String label, IconData icon, int index, bool enabled, Color studioColor) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: enabled
          ? () => _setSelectedIndex(index)
          : () => ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(
                    content: Text(AppLocalizations.of(context)!
                        .artistStudioUnlocksAfterDaoApprovalToast)),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: KubusSpacing.md,
          horizontal: KubusSpacing.sm,
        ),
        margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
        decoration: BoxDecoration(
          color: isSelected && enabled ? studioColor : Colors.transparent,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled && isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: enabled ? 0.6 : 0.3),
              size: KubusSizes.sidebarActionIcon,
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              label,
              style: KubusTypography.textTheme.labelSmall?.copyWith(
                color: enabled && isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: enabled ? 0.6 : 0.3),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    widget.onTabChanged?.call(index);
  }

  Widget _buildRoleBanner({
    required IconData icon,
    required String title,
    required String message,
    required ColorScheme scheme,
  }) {
    final radius = BorderRadius.circular(KubusRadius.lg);
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      padding: EdgeInsets.zero,
      borderRadius: radius,
      showBorder: false,
      backgroundColor: scheme.surface.withValues(alpha: 0.18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: KubusSizes.sidebarActionIconBox,
                height: KubusSizes.sidebarActionIconBox,
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(icon, color: scheme.error),
              ),
              const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KubusTextStyles.sectionTitle
                          .copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                    Text(
                      message,
                      style: KubusTextStyles.actionTileSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBlockedContent({
    required String title,
    required String description,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(KubusSpacing.md),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: scheme.onTertiaryContainer,
                size: KubusSpacing.lg + KubusSpacing.xs,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KubusTypography.textTheme.titleLarge
                  ?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              description,
              style: KubusTextStyles.actionTileTitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KubusSpacing.md + KubusSpacing.xs),
            Text(
              l10n.artistStudioSeparateWalletsTip,
              style: KubusTextStyles.actionTileSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedContent() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(KubusSpacing.md),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline,
                  color: scheme.onSecondaryContainer,
                  size: KubusSpacing.lg + KubusSpacing.xs),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            Text(
              l10n.artistStudioLockedTitle,
              style: KubusTypography.textTheme.titleLarge
                  ?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.artistStudioLockedDescription,
              style: KubusTextStyles.actionTileTitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KubusSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _showArtistApplicationModal(),
              icon: const Icon(Icons.send_rounded),
              label: Text(l10n.artistStudioCtaApplyForDaoReview),
            ),
          ],
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
          backgroundColor:
              scheme.surfaceContainerHighest.withValues(alpha: 0.18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.artistStudioSettingsTitle,
                style: KubusTextStyles.screenTitle
                    .copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: KubusSpacing.lg),
              // Add settings options here
            ],
          ),
        );
      },
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
        final viewInsets = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: SingleChildScrollView(
                child: BackdropGlassSheet(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  backgroundColor:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                  child: Form(
                    key: formKey,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.artistStudioApplicationModalTitle,
                        style: KubusTextStyles.screenTitle
                            .copyWith(color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(
                        l10n.artistStudioApplicationModalSubtitle,
                        style: KubusTextStyles.actionTileTitle.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: KubusButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final profileProvider =
                                      context.read<ProfileProvider>();
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
                                          content: Text(l10n
                                              .artistStudioApplicationWalletRequiredToast)),
                                    );
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final review =
                                        await daoProvider.submitReview(
                                      walletAddress: wallet,
                                      portfolioUrl:
                                          portfolioController.text.trim(),
                                      medium: mediumController.text.trim(),
                                      statement:
                                          statementController.text.trim(),
                                      title: l10n
                                          .artistStudioApplicationReviewTitle,
                                      metadata: {
                                        'role': 'artist',
                                        'source': 'artist_studio',
                                      },
                                    );
                                    if (!mounted) return;
                                    if (review != null) {
                                      await _loadArtistReviewStatus(
                                          forceRefresh: true);
                                      if (!mounted) return;
                                    }
                                    if (!mounted) return;
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
                                          'ArtistStudio: submission failed: $err');
                                    }
                                    if (!mounted) return;
                                    scaffold.showKubusSnackBar(
                                      SnackBar(
                                        content: Text(l10n
                                            .artistStudioApplicationSubmissionFailedToast),
                                        backgroundColor: errorColor,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setModalState(() => isSubmitting = false);
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
