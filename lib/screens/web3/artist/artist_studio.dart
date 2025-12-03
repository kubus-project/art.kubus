import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../onboarding/web3_onboarding.dart';
import '../onboarding/onboarding_data.dart';
import 'artwork_creator.dart';
import 'artwork_gallery.dart';
import 'artist_analytics.dart';
import 'package:provider/provider.dart';

import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../utils/wallet_utils.dart';

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
    if (await isOnboardingNeeded(ArtistStudioOnboardingData.featureName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboarding();
      });
    }
  }

  void _showOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Web3OnboardingScreen(
          featureName: ArtistStudioOnboardingData.featureName,
          pages: ArtistStudioOnboardingData.pages,
          onComplete: () {
            Navigator.pop(context);
          },
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

    final pages = <Widget>[
      ArtworkGallery(onCreateRequested: () => setState(() => _selectedIndex = 1)),
      ArtworkCreator(onCreated: () => setState(() => _selectedIndex = 0)),
      const ArtistAnalytics(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Artist Studio',
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
                title: hasInstitutionBadge ? 'Institution role active' : 'Institution review in progress',
                description: hasInstitutionBadge
                    ? 'Institution accounts can view exhibitions and events but cannot maintain artist applications. Use a dedicated artist wallet to create artworks.'
                    : 'You have an institution application pending. Complete or withdraw it before switching to an artist review.',
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
                  'Welcome to your Studio',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create AR markers for your artwork and share them with the world',
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
    if (isCrossRoleBlocked) {
      final scheme = Theme.of(context).colorScheme;
      final title = hasInstitutionBadge
        ? 'Institution badge active'
        : hasConflictingInstitutionReview
          ? 'Institution review in progress'
          : 'Role conflict detected';
      final message = hasInstitutionBadge
        ? 'Institution accounts unlock curation & event tooling. Use a dedicated artist wallet if you need creator utilities.'
        : hasConflictingInstitutionReview
          ? 'You currently have an institution application pending. Complete that process or request a review reset before applying as an artist.'
          : 'We detected an existing institution record for this wallet. Clear it from settings before applying as an artist.';
      return _buildRoleBanner(
        icon: Icons.domain_disabled,
        title: title,
        message: message,
        scheme: scheme,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    const studioColor = Color(0xFFF59E0B);
    final wallet = _resolveWalletAddress();
    final status = review?.status.toLowerCase() ?? '';
    final isPending = status == 'pending';
    final isApproved = isApprovedArtist;
    final isRejected = status == 'rejected' && !isApprovedArtist;
    final statusLabel = isApproved
        ? 'APPROVED'
        : review != null
            ? status.toUpperCase()
            : 'NOT APPLIED';
    final statusColor = isApproved
        ? Colors.green
        : isRejected
            ? scheme.error
            : studioColor;
    final hasWallet = wallet.isNotEmpty;
    final canSubmit = hasWallet &&
      !_reviewLoading &&
      (!isPending && !isApproved || isRejected);
    final ctaLabel = !hasWallet
        ? 'Connect a wallet to apply'
        : isApproved
            ? 'Approved by DAO'
            : isPending
                ? 'Pending DAO review'
          : isRejected
            ? 'Resubmit for review'
            : 'Apply for DAO review';
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
                child: const Icon(Icons.brush_rounded, color: studioColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artist application (DAO)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit your practice for DAO review. Future releases will route approvals directly through governance.',
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
                    'Status synced from DAO',
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
                    ? 'Your submission is in the DAO review queue. We\'ll notify you after a decision.'
                    : isApproved
                        ? 'Congratulations! You\'ve been cleared by DAO reviewers.'
                        : isRejected
                            ? 'Your last submission was rejected. You can resubmit with updates.'
                            : '',
                style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ] else if (!hasWallet) ...[
            const SizedBox(height: 8),
            Text(
              'Connect your wallet to submit for DAO review.',
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Gallery', Icons.collections, 0, isApprovedArtist)),
          Expanded(child: _buildTabButton('Create', Icons.add_circle_outline, 1, isApprovedArtist)),
          Expanded(child: _buildTabButton('Analytics', Icons.analytics, 2, isApprovedArtist)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index, bool enabled) {
    final isSelected = _selectedIndex == index;
    const studioColor = Color(0xFFF59E0B);
    return GestureDetector(
      onTap: enabled
          ? () => setState(() => _selectedIndex = index)
          : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Artist Studio unlocks after DAO approval.')),
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
              'Tip: Use separate wallets for artist and institution roles to avoid DAO review conflicts.',
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
              'Artist Studio is locked',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Apply for DAO review to unlock gallery, creation tools, and analytics.',
              style: GoogleFonts.inter(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showArtistApplicationModal(),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Apply for DAO review'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
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
              'Studio Settings',
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
                        'Artist application',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share a snapshot of your practice. Submissions are routed to the DAO review queue.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: portfolioController,
                        decoration: InputDecoration(
                          labelText: 'Portfolio or website',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Please provide a link to your work'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: mediumController,
                        decoration: InputDecoration(
                          labelText: 'Primary medium or focus',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Let the DAO know what you create'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: statementController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Artist statement',
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().length < 20)
                            ? 'Share at least 20 characters about your work'
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
                                      const SnackBar(
                                        content: Text('Connect your wallet before submitting to the DAO.'),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    if (wallet.isEmpty) {
                                      throw Exception('Connect your wallet first.');
                                    }
                                    final review = await daoProvider.submitReview(
                                      walletAddress: wallet,
                                      portfolioUrl: portfolioController.text.trim(),
                                      medium: mediumController.text.trim(),
                                      statement: statementController.text.trim(),
                                      title: 'Artist application',
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
                                        content: Text(review != null
                                            ? 'Application submitted to DAO reviewers.'
                                            : 'Unable to submit application right now.'),
                                        backgroundColor: review != null
                                            ? Colors.green
                                            : colorScheme.error,
                                      ),
                                    );
                                  } catch (err) {
                                    if (!mounted) return;
                                    scaffold.showSnackBar(
                                      SnackBar(
                                        content: Text('Submission failed: $err'),
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
                                  'Submit application',
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








