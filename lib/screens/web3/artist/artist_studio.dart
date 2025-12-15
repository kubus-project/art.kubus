import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import 'artwork_creator.dart';
import 'artwork_gallery.dart';
import 'artist_analytics.dart';
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../models/user_persona.dart';
import '../../../utils/wallet_utils.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../events/exhibition_list_screen.dart';

class ArtistStudio extends StatefulWidget {
  const ArtistStudio({super.key});

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
      }
      _hasSetInitialTabByPersona = true;
    }

    if (!walletChanged && _hasFetchedReviewForWallet) return;

    final daoProvider = context.read<DAOProvider>();
    final cachedReview = wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null;

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
    final profileProvider = listen ? context.watch<ProfileProvider>() : context.read<ProfileProvider>();
    final web3Provider = listen ? context.watch<Web3Provider>() : context.read<Web3Provider>();
    return WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
  }

  Future<void> _loadArtistReviewStatus({bool forceRefresh = false}) async {
    final wallet = _resolveWalletAddress();
    if (wallet.isEmpty || _reviewLoading) return;
    if (!forceRefresh && _hasFetchedReviewForWallet && wallet == _lastReviewWallet) return;

    final requestedWallet = wallet;
    setState(() {
      _reviewLoading = true;
      _lastReviewWallet = requestedWallet;
    });
    try {
      final daoProvider = context.read<DAOProvider>();
      final review = await daoProvider.loadReviewForWallet(requestedWallet, forceRefresh: forceRefresh);
      if (!mounted || requestedWallet != _lastReviewWallet) return;
      setState(() {
        _artistReview = review ?? daoProvider.findReviewForWallet(requestedWallet);
        _hasFetchedReviewForWallet = true;
      });
      final isArtistReview = _artistReview?.isArtistApplication ?? false;
      final isApproved = isArtistReview && (_artistReview?.status.toLowerCase() == 'approved');
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
    final review = _artistReview ?? (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final hasArtistBadge = profileProvider.currentUser?.isArtist ?? false;
    final hasInstitutionBadge = profileProvider.currentUser?.isInstitution ?? false;
    final reviewStatus = review?.status.toLowerCase() ?? '';
    final reviewIsArtist = review?.isArtistApplication ?? false;
    final reviewIsInstitution = review?.isInstitutionApplication ?? false;
    final isApprovedArtist = hasArtistBadge || (reviewIsArtist && reviewStatus == 'approved');
    final isReviewRejected = reviewStatus == 'rejected';
    final hasConflictingInstitutionReview = reviewIsInstitution && !isReviewRejected;
    final isCrossRoleBlocked = hasInstitutionBadge || hasConflictingInstitutionReview;

    // Build pages list - Exhibitions tab is optional based on feature flag
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final pages = <Widget>[
      ArtworkGallery(onCreateRequested: () => setState(() => _selectedIndex = 1)),
      ArtworkCreator(onCreated: () => setState(() => _selectedIndex = 0)),
      if (exhibitionsEnabled)
        const ExhibitionListScreen(embedded: true, canCreate: true),
      const ArtistAnalytics(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.artistStudioTitle,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon:  Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
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
                      icon: Icon(Icons.group_add_outlined, color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvitesInboxScreen()),
                        );
                      },
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        right: 8,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                          ),
                          child: Text(
                            pendingCount > 99 ? '99+' : pendingCount.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
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
            icon:  Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
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
                    hasConflictingInstitutionReview: hasConflictingInstitutionReview,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.palette,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.artistStudioHeaderWelcome,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.artistStudioHeaderSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
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
    final studioColor = context.watch<ThemeProvider>().accentColor;
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
        ? scheme.primary
        : isRejected
            ? scheme.error
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: studioColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: studioColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.brush_rounded, color: studioColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.artistStudioDaoCardTitle,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.artistStudioDaoCardSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review != null || _reviewLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                    style: GoogleFonts.inter(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.6)),
                  ),
              ],
            ),
            if ((review?.reviewerNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review!.reviewerNotes!,
                style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.75)),
              ),
            ] else if (review != null) ...[
              const SizedBox(height: 8),
              Text(
                isPending
                    ? l10n.artistStudioReviewPendingInfo
                    : isApproved
                        ? l10n.artistStudioReviewApprovedInfo
                        : isRejected
                            ? l10n.artistStudioReviewRejectedInfo
                            : '',
                style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ] else if (!hasWallet) ...[
            const SizedBox(height: 8),
            Text(
              l10n.artistStudioConnectWalletToSubmitForDaoReview,
              style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canSubmit ? () => _showArtistApplicationModal() : null,
              icon: Icon(ctaIcon, color: canSubmit ? studioColor : scheme.onSurface.withValues(alpha: 0.6), size: 20),
              label: Text(
                ctaLabel,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: canSubmit ? studioColor : scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: studioColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(bool isApprovedArtist) {
    final l10n = AppLocalizations.of(context)!;
    final studioColor = context.watch<ThemeProvider>().accentColor;
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton(l10n.artistStudioTabGallery, Icons.collections, 0, isApprovedArtist, studioColor)),
          Expanded(child: _buildTabButton(l10n.artistStudioTabCreate, Icons.add_circle_outline, 1, isApprovedArtist, studioColor)),
          if (exhibitionsEnabled)
            Expanded(child: _buildTabButton('Exhibitions', Icons.collections_bookmark, 2, isApprovedArtist, studioColor)),
          Expanded(child: _buildTabButton(l10n.artistStudioTabAnalytics, Icons.analytics, exhibitionsEnabled ? 3 : 2, isApprovedArtist, studioColor)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index, bool enabled, Color studioColor) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() => _selectedIndex = index)
          : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.artistStudioUnlocksAfterDaoApprovalToast)),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected && enabled ? studioColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled && isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: enabled ? 0.6 : 0.3),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: enabled && isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: enabled ? 0.6 : 0.3),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBanner({
    required IconData icon,
    required String title,
    required String message,
    required ColorScheme scheme,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.onTertiaryContainer, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.artistStudioSeparateWalletsTip,
              style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, color: scheme.onSecondaryContainer, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.artistStudioLockedTitle,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.artistStudioLockedDescription,
              style: GoogleFonts.inter(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.artistStudioSettingsTitle,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // Add settings options here
          ],
        ),
      ),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.artistStudioApplicationModalTitle,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.artistStudioApplicationModalSubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: portfolioController,
                        decoration: InputDecoration(
                          labelText: l10n.artistStudioApplicationFieldPortfolioLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? l10n.artistStudioApplicationValidationPortfolio
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: mediumController,
                        decoration: InputDecoration(
                          labelText: l10n.artistStudioApplicationFieldMediumLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? l10n.artistStudioApplicationValidationMedium
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: statementController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.artistStudioApplicationFieldStatementLabel,
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().length < 20)
                            ? l10n.artistStudioApplicationValidationStatementMinChars(20)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final profileProvider = context.read<ProfileProvider>();
                                  final web3Provider = context.read<Web3Provider>();
                                  final daoProvider = context.read<DAOProvider>();
                                  final navigator = Navigator.of(sheetContext);
                                  final colorScheme = Theme.of(context).colorScheme;
                                  final wallet = profileProvider.currentUser?.walletAddress ?? web3Provider.walletAddress;
                                  if (wallet.isEmpty) {
                                    scaffold.showSnackBar(
                                      SnackBar(content: Text(l10n.artistStudioApplicationWalletRequiredToast)),
                                    );
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final review = await daoProvider.submitReview(
                                      walletAddress: wallet,
                                      portfolioUrl: portfolioController.text.trim(),
                                      medium: mediumController.text.trim(),
                                      statement: statementController.text.trim(),
                                      title: l10n.artistStudioApplicationReviewTitle,
                                      metadata: {
                                        'role': 'artist',
                                        'source': 'artist_studio',
                                      },
                                    );
                                    if (!mounted) return;
                                    if (review != null) {
                                      await _loadArtistReviewStatus(forceRefresh: true);
                                      if (!mounted) return;
                                    }
                                    if (!mounted) return;
                                    navigator.pop();
                                    if (!mounted) return;
                                    scaffold.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          review != null
                                              ? l10n.artistStudioApplicationSubmittedToast
                                              : l10n.artistStudioApplicationUnableToSubmitToast,
                                        ),
                                        backgroundColor: review != null
                                            ? colorScheme.primary
                                            : colorScheme.error,
                                      ),
                                    );
                                  } catch (err) {
                                    if (kDebugMode) {
                                      debugPrint('ArtistStudio: submission failed: $err');
                                    }
                                    if (!mounted) return;
                                    scaffold.showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.artistStudioApplicationSubmissionFailedToast),
                                        backgroundColor: colorScheme.error,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setModalState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onSurface,
                                    ),
                                  ),
                                )
                              : Text(
                                  l10n.artistStudioApplicationSubmitButton,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
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







