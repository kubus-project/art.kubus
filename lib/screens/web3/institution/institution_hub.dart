import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import 'event_creator.dart';
import 'event_manager.dart';
import 'institution_analytics.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../utils/wallet_utils.dart';

class InstitutionHub extends StatefulWidget {
  const InstitutionHub({super.key});

  @override
  State<InstitutionHub> createState() => _InstitutionHubState();
}

class _InstitutionHubState extends State<InstitutionHub> {
  int _selectedIndex = 0;
  DAOReview? _institutionReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _missionController = TextEditingController();
  final TextEditingController _focusController = TextEditingController();
  final GlobalKey<FormState> _applicationFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInstitutionReviewStatus(forceRefresh: true));
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
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(InstitutionHubOnboardingData.featureName)) {
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
          featureName: InstitutionHubOnboardingData.featureName,
          pages: InstitutionHubOnboardingData.pages,
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

  Future<void> _loadInstitutionReviewStatus({bool forceRefresh = false}) async {
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
        _institutionReview = review ?? daoProvider.findReviewForWallet(requestedWallet);
        _hasFetchedReviewForWallet = true;
      });
      final isInstitutionReview = _institutionReview?.isInstitutionApplication ?? false;
      final isApproved = isInstitutionReview && (_institutionReview?.status.toLowerCase() == 'approved');
      if (isApproved) {
        try {
          context.read<ProfileProvider>().setRoleFlags(isInstitution: true);
        } catch (_) {}
      }
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
    final profileProvider = context.watch<ProfileProvider>();
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _institutionReview ?? (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final hasInstitutionBadge = profileProvider.currentUser?.isInstitution ?? false;
    final hasArtistBadge = profileProvider.currentUser?.isArtist ?? false;
    final reviewStatus = review?.status.toLowerCase() ?? '';
    final reviewIsInstitution = review?.isInstitutionApplication ?? false;
    final reviewIsArtist = review?.isArtistApplication ?? false;
    final isApprovedInstitution = hasInstitutionBadge || (reviewIsInstitution && reviewStatus == 'approved');
    final isReviewRejected = reviewStatus == 'rejected';
    final hasConflictingArtistReview = reviewIsArtist && !isReviewRejected;
    final isCrossRoleBlocked = hasArtistBadge || hasConflictingArtistReview;

    final pages = <Widget>[
      const EventManager(),
      const EventCreator(),
      const InstitutionAnalytics(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Institution Hub',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showOnboarding,
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showNotifications,
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildInstitutionHeader(),
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
                title: hasArtistBadge ? 'Artist badge active' : 'Artist review in progress',
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

  Widget _buildInstitutionHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.location_city,
              color: scheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institution Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Host events, exhibitions, and AR experiences for your visitors',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onPrimary.withValues(alpha: 0.9),
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

    final surface = Theme.of(context).colorScheme.surface;
    final accent = Theme.of(context).colorScheme.primary;
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
        ? Colors.green
        : isRejected
            ? Theme.of(context).colorScheme.error
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.domain_add_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Institution application',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit your organization for DAO review and unlock institutional tooling.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                    color: statusColor.withValues(alpha: 0.15),
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
                    style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
              ],
            ),
            if ((review?.reviewerNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review!.reviewerNotes!,
                style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
            ] else if (review != null) ...[
              const SizedBox(height: 8),
              Text(
                isPending
                    ? 'Your submission is in the DAO review queue.'
                    : isApprovedInstitution
                        ? 'Congratulations! Approved for institution tools.'
                        : isRejected
                            ? 'Your last submission was rejected. You can resubmit with updates.'
                            : '',
                style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canSubmit ? _showInstitutionApplicationModal : null,
              icon: Icon(ctaIcon, color: canSubmit ? accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              label: Text(
                ctaLabel,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: canSubmit ? accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(bool enabled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Events', Icons.event, 0, enabled)),
          Expanded(child: _buildTabButton('Create', Icons.add_box, 1, enabled)),
          Expanded(child: _buildTabButton('Analytics', Icons.analytics, 2, enabled)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index, bool enabled) {
    final isSelected = _selectedIndex == index;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() => _selectedIndex = index)
          : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Institution tools unlock after DAO approval.')),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: enabled && isSelected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled && isSelected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurface.withValues(alpha: enabled ? 0.6 : 0.35),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: enabled && isSelected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface.withValues(alpha: enabled ? 0.6 : 0.35),
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
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.onSecondaryContainer, size: 30),
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
              'Tip: Keep artist and institution roles on separate wallets to avoid DAO conflicts.',
              style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // Add notifications here
          ],
        ),
      ),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _applicationFormKey,
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
                    'Institution application',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your mission, programming focus, and how you plan to collaborate with the DAO.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _organizationController,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Please provide your organization name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Website or contact email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Share a website or contact email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _focusController,
                    decoration: const InputDecoration(
                      labelText: 'Curation focus',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Let us know your programming focus'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _missionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mission and goals',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().length < 20)
                        ? 'Describe your mission in at least 20 characters'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!_applicationFormKey.currentState!.validate()) return;
                        final profileProvider = context.read<ProfileProvider>();
                        final web3Provider = context.read<Web3Provider>();
                        final daoProvider = context.read<DAOProvider>();
                        final wallet = profileProvider.currentUser?.walletAddress ?? web3Provider.walletAddress;
                        if (wallet.isEmpty) {
                          scaffold.showSnackBar(
                            const SnackBar(content: Text('Connect your wallet before submitting.')),
                          );
                          return;
                        }
                        Navigator.pop(sheetContext);
                        try {
                          final review = await daoProvider.submitInstitutionReview(
                            walletAddress: wallet,
                            organization: _organizationController.text.trim(),
                            contact: _contactController.text.trim(),
                            focus: _focusController.text.trim(),
                            mission: _missionController.text.trim(),
                          );
                          if (!mounted) return;
                          if (review != null) {
                            await _loadInstitutionReviewStatus(forceRefresh: true);
                          }
                          if (!mounted) return;
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text(review != null
                                  ? 'Application submitted to DAO reviewers.'
                                  : 'Unable to submit application right now.'),
                              backgroundColor: review != null
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text('Submission failed: $e'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
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
              'Institution tools are locked',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Apply for DAO review to unlock events, creation tools, and analytics.',
              style: GoogleFonts.inter(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showInstitutionApplicationModal(),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Apply for DAO review'),
            ),
          ],
        ),
      ),
    );
  }
}
