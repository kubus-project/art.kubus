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
import '../../../providers/account_verification_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/account_verification.dart';
import '../../../models/promotion.dart';
import '../../../models/user_persona.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/verification/artist_verification_panel.dart';
import '../../../widgets/promotion/promotion_builder_sheet.dart';
import '../../../widgets/topbar_icon.dart';

/// Why profile promotion is unavailable, or null. Promotion is a paid action
/// keyed to the wallet, so a wallet is required for THAT action only; the
/// Studio itself never needs one. Eligibility is the server-confirmed artist
/// standing of the account, never a persona or a wallet-keyed review.
@visibleForTesting
String? resolveArtistPromotionUnavailableReason({
  required bool isVerifiedArtist,
  required String walletAddress,
  required String walletRequiredReason,
  required String approvalRequiredReason,
}) {
  if (!isVerifiedArtist) return approvalRequiredReason;
  if (walletAddress.trim().isEmpty) return walletRequiredReason;
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
  bool _hasSetInitialTabByPersona = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final persona = context.watch<ProfileProvider>().userPersona;
    if (!_hasSetInitialTabByPersona && persona != null) {
      final desiredIndex = persona == UserPersona.creator ? 1 : 0;
      if (_selectedIndex != desiredIndex) {
        _selectedIndex = desiredIndex;
        widget.onTabChanged?.call(desiredIndex);
      }
      _hasSetInitialTabByPersona = true;
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
    return resolveArtistPromotionUnavailableReason(
      isVerifiedArtist: context.read<AccountVerificationProvider>().isArtist,
      walletAddress: _resolveWalletAddress(),
      walletRequiredReason: l10n.artistPromotionRequiresWalletReason,
      approvalRequiredReason: l10n.artistPromotionRequiresApprovalReason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The server's answer for THIS account decides access: no wallet, persona
    // or cached flag is consulted, and an institution membership never blocks it.
    final verification = context.watch<AccountVerificationProvider>();
    final isApprovedArtist = verification.isArtist;
    final canSelfServeArtistPromotion = isApprovedArtist;

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
              // No title: the dashboard header below is the page title
              // (and carries any Lab marker). The bar holds actions only.
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
                  if (widget.showVerificationCard && !isApprovedArtist)
                    const ArtistVerificationPanel(),
                  _buildNavigationTabs(isApprovedArtist),
                ],
              ),
            ),
          ];
        },
        body: isApprovedArtist
            ? pages[_selectedIndex]
            : _buildLockedContent(
                reviewPending: verification.artistStatus ==
                    ArtistVerificationStatus.pending,
                unavailable: verification.isUnavailable,
              ),
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

  Widget _buildLockedContent({
    required bool reviewPending,
    required bool unavailable,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return _buildStateSlot(
      EmptyStateCard(
        icon: Icons.lock_outline,
        title: l10n.artistStudioLockedTitle,
        description: unavailable
            ? l10n.verificationUnavailable
            : l10n.artistStudioLockedDescription,
        // The verification panel above owns the application CTA (and knows
        // when it is pending or rejected); this surface only explains the
        // lock. Without that panel (the desktop shell) it carries the action,
        // except while an application is already pending.
        showAction: !widget.showVerificationCard && !reviewPending,
        actionLabel: unavailable
            ? l10n.verificationCtaRetry
            : l10n.verificationArtistCtaApply,
        onAction: unavailable
            ? () => context.read<AccountVerificationProvider>().refresh()
            : () => showArtistApplicationSheet(context),
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
}
