import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
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
import '../../../providers/web3provider.dart';
import '../../../config/config.dart';
import '../../../models/dao.dart';
import '../../../models/promotion.dart';
import '../../../models/user_persona.dart';
import '../../../utils/activity_navigation.dart';
import '../../../utils/dao_role_verification.dart';
import '../../../utils/wallet_utils.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';
import '../../map_markers/manage_markers_screen.dart';
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
  int? _hoveredTabIndex;
  DAOReview? _institutionReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';
  bool _hasSetInitialTabByPersona = false;
  final TextEditingController _organizationController = TextEditingController();
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
    if (wallet.isNotEmpty) {
      _loadInstitutionReviewStatus(forceRefresh: true);
    }
  }

  Future<void> _checkOnboarding() async {
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
    final wallet = _resolveWalletAddress();
    if (wallet.isEmpty) {
      return 'Connect an approved institution wallet to request institution promotion.';
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
      return 'Artist wallets cannot self-serve institution promotion. Use a dedicated institution wallet.';
    }
    if (!verification.isApprovedFor(DaoRoleType.institution)) {
      return 'Institution promotion is available only for approved institution wallets.';
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
    final review = _institutionReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: review,
    );
    final hasInstitutionBadge =
        verification.isApprovedFor(DaoRoleType.institution);
    final hasArtistBadge = verification.isApprovedFor(DaoRoleType.artist);
    final isApprovedInstitution = hasInstitutionBadge;
    final hasConflictingArtistReview =
        verification.isPendingFor(DaoRoleType.artist);
    final isCrossRoleBlocked = hasArtistBadge || hasConflictingArtistReview;
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
              flexibleSpace: KubusGlassAppBarBackdrop(
                tintBase: Theme.of(context).colorScheme.surface,
              ),
              title: Text(
                'Institution Hub',
                style: KubusTextStyles.responsiveMobileAppBarTitle(context)
                    .copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TopBarIcon(
                  tooltip: 'Help',
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
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageMarkersScreen(),
                      ),
                    );
                  },
                ),
                if (AppConfig.isFeatureEnabled('collabInvites'))
                  Consumer<CollabProvider>(
                    builder: (context, collabProvider, _) {
                      final pendingCount = collabProvider.pendingInviteCount;
                      return TopBarIcon(
                        tooltip: 'Invites',
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
                    tooltip: 'Promote my institution',
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
                  if (widget.showVerificationCard)
                    _buildInstitutionApplicationCard(
                      review,
                      isApprovedInstitution,
                      isCrossRoleBlocked: isCrossRoleBlocked,
                      hasArtistBadge: hasArtistBadge,
                      hasConflictingArtistReview: hasConflictingArtistReview,
                    ),
                  if (!isCrossRoleBlocked)
                    _buildNavigationTabs(isApprovedInstitution),
                ],
              ),
            ),
          ];
        },
        body: isCrossRoleBlocked
            ? _buildRoleBlockedContent(
                title: hasArtistBadge
                    ? 'Artist badge active'
                    : 'Artist review in progress',
                description: hasArtistBadge
                    ? 'Artist wallets unlock creation tooling. Institution flows need a dedicated wallet without creator approvals.'
                    : 'You have an active artist application. Wait for that decision or reset it before continuing as an institution.',
                icon: Icons.palette_outlined,
              )
            : isApprovedInstitution
                ? pages[_selectedIndex]
                : _buildLockedContent(),
      ),
    );
  }

  Widget _buildInstitutionHeader({
    required bool canSelfServeInstitutionPromotion,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final persona = context.watch<ProfileProvider>().userPersona;
    final subtitle = switch (persona) {
      UserPersona.institution =>
        'Host events, exhibitions, and AR experiences for your visitors',
      UserPersona.creator =>
        'Collaborate with institutions and curate exhibitions',
      UserPersona.lover =>
        'Discover exhibitions and events curated by institutions',
      null => 'Host events, exhibitions, and AR experiences for your visitors',
    };
    final panelStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
      tintBase: roles.web3InstitutionAccent,
    );
    final radius = BorderRadius.circular(KubusRadius.lg);

    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: radius,
      blurSigma: panelStyle.blurSigma,
      fallbackMinOpacity: panelStyle.fallbackMinOpacity,
      showBorder: false,
      backgroundColor: panelStyle.tintColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: roles.web3InstitutionAccent.withValues(alpha: 0.24),
            width: KubusSizes.hairline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Row(
            children: [
              Container(
                width: KubusSpacing.xxl,
                height: KubusSpacing.xxl,
                decoration: BoxDecoration(
                  color: roles.web3InstitutionAccent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                ),
                child: Icon(
                  Icons.location_city,
                  color: roles.web3InstitutionAccent,
                  size: KubusSpacing.lg,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KubusHeaderText(
                      title: l10n.navigationScreenInstitutionHub,
                      subtitle: subtitle,
                      titleStyle: KubusTextStyles.heroTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                      subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.80),
                      ),
                      maxTitleLines: 1,
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      'Manage exhibitions, events, and institutional visibility from one shared workspace.',
                      style: KubusTextStyles.actionTileSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.74),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (canSelfServeInstitutionPromotion) ...[
                      const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _openInstitutionPromotionFlow,
                            icon: const Icon(Icons.campaign_outlined),
                            label: const Text(
                              'Promote my institution',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstitutionApplicationCard(
    DAOReview? review,
    bool isApprovedInstitution, {
    required bool isCrossRoleBlocked,
    required bool hasArtistBadge,
    required bool hasConflictingArtistReview,
  }) {
    if (isCrossRoleBlocked) {
      final scheme = Theme.of(context).colorScheme;
      final title = hasArtistBadge
          ? 'Artist badge active'
          : hasConflictingArtistReview
              ? 'Artist review in progress'
              : 'Role conflict detected';
      final message = hasArtistBadge
          ? 'Artist wallets are optimized for creation tooling. Switch to a dedicated institutional wallet before applying for curation tools.'
          : hasConflictingArtistReview
              ? 'You currently have an artist application pending. Finish that review or request a reset prior to submitting an institution application.'
              : 'We detected an artist submission for this wallet. Clear it from settings before continuing as an institution.';
      return _buildRoleBanner(
        icon: Icons.palette_outlined,
        title: title,
        message: message,
        scheme: scheme,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final accent = roles.web3InstitutionAccent;
    final wallet = _resolveWalletAddress();
    final status = review?.status.toLowerCase() ?? '';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final statusLabel = isApprovedInstitution
        ? 'APPROVED'
        : review != null
            ? status.toUpperCase()
            : 'NOT APPLIED';
    final statusColor = isApprovedInstitution
        ? roles.positiveAction
        : isRejected
            ? roles.negativeAction
            : accent;
    final canSubmit = wallet.isNotEmpty &&
        !_reviewLoading &&
        (!isPending && !isApprovedInstitution || isRejected);
    final ctaLabel = !canSubmit
        ? (isApprovedInstitution
            ? 'Approved by DAO'
            : isPending
                ? 'Pending DAO review'
                : 'Connect wallet to apply')
        : 'Apply for review';
    final IconData ctaIcon = isApprovedInstitution
        ? Icons.verified_outlined
        : isPending
            ? Icons.hourglass_bottom
            : Icons.send_rounded;

    final cardRadius = BorderRadius.circular(KubusRadius.lg);
    final cardStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: accent,
    );
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      padding: EdgeInsets.zero,
      borderRadius: cardRadius,
      blurSigma: cardStyle.blurSigma,
      fallbackMinOpacity: cardStyle.fallbackMinOpacity,
      showBorder: false,
      backgroundColor: cardStyle.tintColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: cardRadius,
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: KubusSizes.sidebarActionIconBox,
                    height: KubusSizes.sidebarActionIconBox,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                    child: Icon(Icons.domain_add_rounded, color: accent),
                  ),
                  const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Institution application',
                          style: KubusTextStyles.sectionTitle.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: KubusSpacing.xs),
                        Text(
                          'Submit your organization for DAO review and unlock institutional tooling.',
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
                        horizontal: KubusSpacing.sm +
                            KubusSpacing.xs -
                            KubusSpacing.xxs,
                        vertical: KubusSpacing.xs + KubusSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      )
                    else if (review != null)
                      Text(
                        'Status synced from DAO',
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
                        ? 'Your submission is in the DAO review queue.'
                        : isApprovedInstitution
                            ? 'Congratulations! Approved for institution tools.'
                            : isRejected
                                ? 'Your last submission was rejected. You can resubmit with updates.'
                                : '',
                    style: KubusTextStyles.actionTileSubtitle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: KubusSpacing.md),
              SizedBox(
                width: double.infinity,
                child: KubusButton(
                  onPressed: canSubmit
                      ? () => _showInstitutionApplicationModal()
                      : null,
                  label: ctaLabel,
                  icon: ctaIcon,
                  isFullWidth: true,
                  backgroundColor: accent,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(accent) ==
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

  Widget _buildNavigationTabs(bool enabled) {
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final panelStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
      tintBase: scheme.surface,
    );
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
      padding: const EdgeInsets.all(KubusSpacing.xs),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      blurSigma: panelStyle.blurSigma,
      fallbackMinOpacity: panelStyle.fallbackMinOpacity,
      showBorder: false,
      backgroundColor: panelStyle.tintColor,
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              'Events',
              Icons.event,
              0,
              enabled,
              scheme.primary,
            ),
          ),
          if (exhibitionsEnabled)
            Expanded(
              child: _buildTabButton(
                'Exhibitions',
                Icons.collections_bookmark,
                1,
                enabled,
                roles.web3InstitutionAccent,
              ),
            ),
          Expanded(
            child: _buildTabButton(
              'Create',
              Icons.add_box,
              exhibitionsEnabled ? 2 : 1,
              enabled,
              roles.positiveAction,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'Analytics',
              Icons.analytics,
              exhibitionsEnabled ? 3 : 2,
              enabled,
              roles.statTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    IconData icon,
    int index,
    bool enabled,
    Color accent,
  ) {
    final isSelected = _selectedIndex == index;
    final isHovered = _hoveredTabIndex == index;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tintBase =
        (enabled && (isSelected || isHovered)) ? accent : scheme.surface;
    final buttonStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: tintBase,
    );
    final background = !enabled
        ? scheme.surface.withValues(alpha: isDark ? 0.10 : 0.08)
        : isSelected
            ? accent.withValues(alpha: isDark ? 0.28 : 0.20)
            : isHovered
                ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                : scheme.surface.withValues(alpha: isDark ? 0.06 : 0.04);
    final foreground = !enabled
        ? scheme.onSurface.withValues(alpha: 0.35)
        : isSelected
            ? scheme.onSurface
            : isHovered
                ? accent.withValues(alpha: 0.90)
                : scheme.onSurface.withValues(alpha: 0.72);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hoveredTabIndex = index),
      onExit: (_) {
        if (_hoveredTabIndex == index) {
          setState(() => _hoveredTabIndex = null);
        }
      },
      child: LiquidGlassCard(
        onTap: enabled
            ? () => _setSelectedIndex(index)
            : () => ScaffoldMessenger.of(context).showKubusSnackBar(
                  const SnackBar(
                      content:
                          Text('Institution tools unlock after DAO approval.')),
                ),
        padding: const EdgeInsets.symmetric(
          vertical: KubusSpacing.md,
          horizontal: KubusSpacing.sm,
        ),
        margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        blurSigma: buttonStyle.blurSigma,
        fallbackMinOpacity: buttonStyle.fallbackMinOpacity,
        showBorder: false,
        backgroundColor: background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: foreground,
              size: KubusSizes.sidebarActionIcon,
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              label,
              style: KubusTypography.textTheme.labelSmall?.copyWith(
                color: foreground,
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
              child: Icon(
                icon,
                color: scheme.onSecondaryContainer,
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
              'Tip: Keep artist and institution roles on separate wallets to avoid DAO conflicts.',
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
      entityLabel: profile?.displayName ?? 'my institution',
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
                    title: 'Institution application',
                    subtitle:
                        'Share your mission, programming focus, and how you plan to collaborate with the DAO.',
                    showHandle: false,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  TextFormField(
                    controller: _organizationController,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please provide your organization name'
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Website or contact email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Share a website or contact email'
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  TextFormField(
                    controller: _focusController,
                    decoration: const InputDecoration(
                      labelText: 'Curation focus',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Let us know your programming focus'
                            : null,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  TextFormField(
                    controller: _missionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mission and goals',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 20)
                            ? 'Describe your mission in at least 20 characters'
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
                        final profileProvider = context.read<ProfileProvider>();
                        final web3Provider = context.read<Web3Provider>();
                        final daoProvider = context.read<DAOProvider>();
                        final wallet =
                            profileProvider.currentUser?.walletAddress ??
                                web3Provider.walletAddress;
                        if (wallet.isEmpty) {
                          scaffold.showKubusSnackBar(
                            const SnackBar(
                              content: Text(
                                'Connect your wallet before submitting.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(sheetContext);
                        try {
                          final review =
                              await daoProvider.submitInstitutionReview(
                            walletAddress: wallet,
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
                                    ? 'Application submitted to DAO reviewers.'
                                    : 'Unable to submit application right now.',
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
                              content: Text('Submission failed: $e'),
                              backgroundColor: roles.negativeAction,
                            ),
                          );
                        }
                      },
                      label: 'Submit application',
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

  Widget _buildLockedContent() {
    final scheme = Theme.of(context).colorScheme;
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
              child: Icon(
                Icons.lock_outline,
                color: scheme.onSecondaryContainer,
                size: KubusSpacing.lg + KubusSpacing.xs,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            Text(
              'Institution tools are locked',
              style: KubusTypography.textTheme.titleLarge
                  ?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              'Apply for DAO review to unlock events, creation tools, and analytics.',
              style: KubusTextStyles.actionTileTitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KubusSpacing.md),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _showInstitutionApplicationModal(),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Apply for DAO review'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
