import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../models/dao.dart';
import '../../../utils/wallet_utils.dart';
import '../../../config/config.dart';
import '../../../utils/app_color_utils.dart';


class GovernanceHub extends StatefulWidget {
  const GovernanceHub({super.key});

  @override
  State<GovernanceHub> createState() => _GovernanceHubState();
}

class _GovernanceHubState extends State<GovernanceHub> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _reviewActionId;

  // Proposal creation form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  String _selectedCategory = 'Platform Update';
  final _votingPeriodController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _votingPeriodController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'DAO Governance',
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
            icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showGovernanceInfo,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildGovernanceHeader(),
                    _buildNavigationTabs(),
                  ],
                ),
              ),
            ];
          },
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildActiveProposals(),
              _buildVotingHistory(),
              _buildCreateProposal(),
              _buildTreasury(),
              _buildDelegation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGovernanceHeader() {
    return Consumer2<DAOProvider, Web3Provider>(
      builder: (context, daoProvider, web3Provider, child) {
        final kub8Balance = web3Provider.kub8Balance;
        final votingPower = '${kub8Balance.toStringAsFixed(2)} KUB8';
        final activeProposals = daoProvider.getActiveProposals().length.toString();
        final totalMembers = daoProvider.delegates.length.toString();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.fromARGB(255, 6, 215, 37), Color.fromARGB(255, 5, 112, 87)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 4, 236, 124).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.how_to_vote,
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
                          'art.kubus DAO',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Decentralized governance for the AR art platform',
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Your Voting Power', votingPower),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard('Active Proposals', activeProposals),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard('Total Delegates', totalMembers),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton('Proposals', Icons.how_to_vote, 0),
            _buildTabButton('History', Icons.history, 1),
            _buildTabButton('Create', Icons.add_circle_outline, 2),
            _buildTabButton('Treasury', Icons.account_balance, 3),
            _buildTabButton('Delegate', Icons.people, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    const daoColor = Color.fromARGB(255, 5, 164, 76);
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? daoColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProposals() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        // Filter active proposals using DAOProvider method
        final activeProposals = daoProvider.getActiveProposals();
        final reviews = daoProvider.reviews;
        
        // Show empty state if no proposals
        if (activeProposals.isEmpty && reviews.isEmpty) {
          return Center(
            child: EmptyStateCard(
              icon: Icons.how_to_vote,
              title: l10n.daoActiveProposalsEmptyTitle,
              description: l10n.daoActiveProposalsEmptyDescription,
            ),
          );
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (reviews.isNotEmpty) _buildReviewQueue(reviews),
              ...activeProposals
                  .map((proposal) => _buildProposalCard(proposal)),
            ],
          ),
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
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...reviews.map((review) => _buildReviewCard(review, themeProvider)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildReviewCard(DAOReview review, ThemeProvider themeProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    const daoColor = Color(0xFF10B981);
    final statusColor = review.status.toLowerCase() == 'approved'
        ? Colors.green
        : review.status.toLowerCase() == 'rejected'
            ? colorScheme.error
            : daoColor;
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final viewerWallet = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
    final isOwnSubmission = WalletUtils.equals(viewerWallet, review.walletAddress);
    final votingDisabledOverride = review.metadata?['votingDisabled'] == true || review.metadata?['voting_disabled'] == true;
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
        : l10n.daoReviewDecisionRecordedHelper(review.status.toUpperCase());
    final isPending = normalizedStatus == 'pending';
    final canModerate = moderationEnabled && !isOwnSubmission && isPending;
    final isActionInFlight = _reviewActionId == review.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColorUtils.purpleAccent.withValues(alpha: 0.2),
                backgroundImage: review.applicantProfile?['avatarUrl'] != null
                    ? NetworkImage(review.applicantProfile!['avatarUrl'] as String)
                    : null,
                child: review.applicantProfile?['avatarUrl'] == null
                    ? Icon(Icons.person, color: AppColorUtils.purpleAccent)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.applicantProfile?['displayName']?.toString() ?? review.walletAddress,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      review.portfolioUrl,
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
                  review.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.medium.isNotEmpty ? review.medium : l10n.daoReviewMediumNotProvided,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.statement,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: isActionInFlight ? null : () => _showReviewDetails(review),
                icon: Icon(Icons.visibility, color: colorScheme.onSurface, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorUtils.purpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                label: Text(
                  l10n.daoReviewViewDetailsButton,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voteHelperText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (canModerate) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isActionInFlight ? null : () => _confirmReviewDecision(review, 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isActionInFlight && _reviewActionId == review.id
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                      ),
                                    )
                                  : Text(
                                      l10n.daoModerationApproveLabel,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isActionInFlight ? null : () => _confirmReviewDecision(review, 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(color: colorScheme.error),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isActionInFlight && _reviewActionId == review.id
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.error),
                                      ),
                                    )
                                  : Text(
                                      l10n.daoModerationRejectLabel,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
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

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        title: Text(
          l10n.daoModerationDecisionDialogTitle(decisionLabel),
          style: GoogleFonts.inter(color: colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoModerationDecisionDialogDescription,
              style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.75)),
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
      await _handleReviewDecision(review, decision, notesController.text.trim(), messenger);
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

    if (!AppConfig.isFeatureEnabled('daoReviewDecisions')) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.daoModerationDisabledToast)),
      );
      return;
    }

    if (reviewerWallet.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.daoModerationWalletRequiredToast)),
      );
      return;
    }

    if (WalletUtils.equals(reviewerWallet, review.walletAddress)) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.daoModerationSelfNotAllowedToast)),
      );
      return;
    }

    setState(() {
      _reviewActionId = review.id;
    });

    try {
      final updated = await context.read<DAOProvider>().decideReview(
            idOrWallet: review.id,
            status: decision,
            reviewerNotes: reviewerNotes.isNotEmpty ? reviewerNotes : null,
            reviewerWallet: reviewerWallet,
          );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      messenger.showSnackBar(
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.daoModerationUpdateFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reviewActionId = null;
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
    final isOwnSubmission = WalletUtils.equals(viewerWallet, review.walletAddress);
    final votingDisabledOverride = review.metadata?['votingDisabled'] == true || review.metadata?['voting_disabled'] == true;
    final l10n = AppLocalizations.of(context)!;
    final voteDetailsText = isOwnSubmission
      ? l10n.daoReviewDetailsVotingDisabledForApplicant
        : votingDisabledOverride
        ? l10n.daoReviewDetailsVotingDisabledForSubmission
        : l10n.daoReviewDetailsVotingManagedByDao;
    final isPending = review.status.toLowerCase() == 'pending';
    final canModerate = AppConfig.isFeatureEnabled('daoReviewDecisions') && !isOwnSubmission && isPending;
    final isActionInFlight = _reviewActionId == review.id;

    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.daoReviewDetailsPortfolioLabel(review.portfolioUrl),
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.daoReviewDetailsMediumLabel(review.medium),
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.daoReviewDetailsStatusLabel(review.status),
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
              ),
              if ((review.reviewerNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.daoReviewDetailsReviewerNotesLabel,
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  review.reviewerNotes ?? '',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                voteDetailsText,
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        actions: [
          if (canModerate) ...[
            TextButton(
              onPressed: isActionInFlight ? null : () => _confirmReviewDecision(review, 'rejected'),
              child: Text(
                l10n.daoModerationRejectLabel,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: isActionInFlight ? null : () => _confirmReviewDecision(review, 'approved'),
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

  Widget _buildProposalCard(Proposal proposal) {
    final color = AppColorUtils.indigoAccent;
    final totalVotes = proposal.totalVotes;
    final supportPct = (proposal.supportPercentage * 100).clamp(0, 100);
    final l10n = AppLocalizations.of(context)!;
    final quorumText = proposal.hasQuorum ? l10n.daoQuorumReached : l10n.daoQuorumPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  proposal.type.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                proposal.timeLeft,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            proposal.title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            proposal.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalVotes votes • ${supportPct.toStringAsFixed(1)}% support',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: supportPct / 100,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    quorumText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.of(context)!.daoProposalVotesYesLabel(proposal.yesVotes.toString()),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                  ),
                  Text(
                    AppLocalizations.of(context)!.daoProposalVotesNoLabel(proposal.noVotes.toString()),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                  ),
                  Text(
                    AppLocalizations.of(context)!.daoProposalVotesAbstainLabel(proposal.abstainVotes.toString()),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _voteOnProposal(proposal.id, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.daoVoteYesButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _voteOnProposal(proposal.id, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.daoVoteNoButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVotingHistory() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        // Get actual votes from provider - use user's votes if available
        final userVotes = daoProvider.votes.take(10).toList();
        
        // Convert to display format
        final votingHistory = userVotes.map((vote) {
          final proposal = daoProvider.getProposalById(vote.proposalId);
          return {
            'title': proposal?.title ?? l10n.daoVotingHistoryUnknownProposal,
            'date': vote.timestamp.toString().substring(0, 10),
            'vote': vote.choice.name == 'yes'
                ? l10n.daoVoteChoiceYes
                : vote.choice.name == 'no'
                    ? l10n.daoVoteChoiceNo
                    : l10n.daoVoteChoiceAbstain,
            'result': proposal?.isPassing == true ? l10n.daoVotingResultPassing : l10n.daoVotingResultNotPassing,
            'participation': proposal != null && proposal.totalVotes > 0 
                ? '${((proposal.totalVotes / 100000) * 100).toStringAsFixed(0)}%' 
                : l10n.commonNotAvailableShort,
            'yourPower': l10n.daoVotingHistoryYourPowerLabel('${vote.votingPower} KUB8'),
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
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: votingHistory.length,
        itemBuilder: (context, index) {
          final vote = votingHistory[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vote['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: vote['result'] == 'Passed' 
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vote['result'] == 'Passed' 
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      child: Text(
                        vote['result']!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: vote['result'] == 'Passed' 
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildHistoryInfo('Date', vote['date']!),
                    const SizedBox(width: 24),
                    _buildHistoryInfo('Your Vote', vote['vote']!),
                    const SizedBox(width: 24),
                    _buildHistoryInfo('Participation', vote['participation']!),
                  ],
                ),
                const SizedBox(height: 8),
                _buildHistoryInfo('Your Voting Power', vote['yourPower']!),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateProposal() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Proposal',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a proposal for the community to vote on',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            _buildFormField(
              'Proposal Title',
              'Enter a clear, descriptive title',
              _titleController,
            ),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            _buildFormField(
              'Description',
              'Provide detailed explanation of your proposal',
              _descriptionController,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Voting Period (Days)',
              'How many days should voting be open?',
              _votingPeriodController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _buildProposalRequirements(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitProposal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Submit Proposal',
                  style: GoogleFonts.inter(
                    fontSize: 16,
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

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final categories = [
      'Platform Update',
      'New Feature',
      'Policy Change',
      'Treasury Allocation',
      'Community Initiative',
      'Technical Improvement',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.daoProposalCategoryLabel,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
          ),
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: scheme.surfaceContainerHighest,
            style: TextStyle(color: scheme.onSurface),
            items: categories.map((category) {
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
      case 'Platform Update':
        return l10n.daoCategoryPlatformUpdate;
      case 'New Feature':
        return l10n.daoCategoryNewFeature;
      case 'Policy Change':
        return l10n.daoCategoryPolicyChange;
      case 'Treasury Allocation':
        return l10n.daoCategoryTreasuryAllocation;
      case 'Community Initiative':
        return l10n.daoCategoryCommunityInitiative;
      case 'Technical Improvement':
        return l10n.daoCategoryTechnicalImprovement;
      default:
        return category;
    }
  }

  Widget _buildProposalRequirements() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
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
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementItem(l10n.daoProposalRequirementWalletConnected, Provider.of<Web3Provider>(context, listen: false).isConnected),
          _buildRequirementItem(l10n.daoProposalRequirementClearlyDefined, true),
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
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitProposal() async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.daoProposalFillRequiredFieldsToast),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    final daoProvider = context.read<DAOProvider>();
    final web3Provider = context.read<Web3Provider>();
    final wallet = web3Provider.walletAddress;

    if (wallet.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.daoProposalWalletRequiredToast)),
      );
      return;
    }

    final selectedType = () {
      switch (_selectedCategory.toLowerCase()) {
        case 'platform update':
          return ProposalType.platformUpdate;
        case 'new feature':
        case 'technical improvement':
          return ProposalType.featureRequest;
        case 'treasury allocation':
        case 'community fund allocation':
          return ProposalType.rewards;
        case 'policy change':
        case 'governance':
          return ProposalType.governance;
        default:
          return ProposalType.community;
      }
    }();

    final votingDays = int.tryParse(_votingPeriodController.text.trim()) ?? 7;

    try {
      final proposal = await daoProvider.createProposal(
        walletAddress: wallet,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: selectedType,
        votingPeriodDays: votingDays,
      );

      if (!mounted) return;
      if (proposal == null) return;

      _clearForm();
      setState(() => _selectedIndex = 0);
      messenger.showSnackBar(
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.daoProposalSubmitFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _votingPeriodController.clear();
    setState(() {
      _selectedCategory = 'Platform Update';
    });
  }

  Widget _buildTreasury() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoTreasuryTitle,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.daoTreasurySubtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
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
        final treasuryAmountDisplay = (analytics['treasuryAmount'] as double? ?? 0.0).toStringAsFixed(2);
        final transactions = daoProvider.transactions;
        final inflow = transactions.where((tx) => tx.amount >= 0).fold<double>(0, (sum, tx) => sum + tx.amount);
        final outflow = transactions.where((tx) => tx.amount < 0).fold<double>(0, (sum, tx) => sum + tx.amount.abs());
        const treasuryColor = AppColorUtils.amberAccent;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                treasuryColor.withValues(alpha: 0.85),
                treasuryColor,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, color: Theme.of(context).colorScheme.onSurface, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Treasury Value',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          '$treasuryAmountDisplay KUB8',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
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
                    Expanded(child: _buildTreasuryStatCard(l10n.daoTreasuryInflowLabel, '${inflow.toStringAsFixed(2)} KUB8', Icons.trending_up)),
                  const SizedBox(width: 12),
                    Expanded(child: _buildTreasuryStatCard(l10n.daoTreasuryOutflowLabel, '${outflow.toStringAsFixed(2)} KUB8', Icons.trending_down)),
                  const SizedBox(width: 12),
                    Expanded(child: _buildTreasuryStatCard(l10n.daoTreasuryProposalsLabel, '${daoProvider.proposals.length}', Icons.security)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTreasuryStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tx.type == 'allocation'
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                            : tx.type == 'reward'
                                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.type.toString().split('.').last.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            tx.description,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _formatDate(tx.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[400],
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
        final treasuryProposals = daoProvider.proposals.where((p) => p.type == ProposalType.rewards).toList();

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
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  child: Text(
                    l10n.daoCreateProposalButton,
                    style: TextStyle(color: AppColorUtils.purpleAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...treasuryProposals.map((proposal) => _buildProposalCard(proposal)),
          ],
        );
      },
    );
  }

  Widget _buildDelegation() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoVoteDelegationTitle,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.daoVoteDelegationSubtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            _buildCurrentDelegation(),
            const SizedBox(height: 24),
            _buildTopDelegates(),
            const SizedBox(height: 24),
            _buildDelegationActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDelegation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Text(
                'Your Delegation Status',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDelegationInfo(
                  'Voting Power',
                  '${Provider.of<Web3Provider>(context, listen: false).kub8Balance.toStringAsFixed(2)} KUB8',
                ),
              ),
              Expanded(
                child: _buildDelegationInfo('Delegated To', 'Self'),
              ),
              Expanded(
                child: _buildDelegationInfo(
                  'Delegators',
                  Provider.of<DAOProvider>(context, listen: false).delegates.length.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTopDelegates() {
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
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
                onTap: () => _delegateVote(delegate.name),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColorUtils.purpleAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            delegate.name.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
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
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${delegate.delegatorCount} delegators • ${(delegate.participationRate * 100).toStringAsFixed(0)}% participation',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.7),
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
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColorUtils.amberAccent,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              l10n.daoDelegateActiveLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.daoTapToDelegateHint,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: scheme.onSurface.withValues(alpha: 0.6),
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
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.daoDelegationActionsSubtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        // Delegate to Others Button
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selfDelegate,
                icon: Icon(Icons.person_outline, size: 18),
                label: Text(l10n.daoSelfDelegateButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _revokeDelegation,
                icon: Icon(Icons.cancel_outlined, size: 18),
                label: Text(l10n.daoRevokeButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
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
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a Delegate',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a trusted community member to vote on your behalf',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[400],
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
                              _delegateVote(delegate.name);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColorUtils.purpleAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      delegate.name.substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
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
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        '${delegate.delegatorCount} delegators • ${(delegate.participationRate * 100).toStringAsFixed(0)}% participation',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(delegate.votingPower / 1000).toStringAsFixed(1)}K KUB8',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
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
        ),
      ),
    );
  }

  void _delegateVote(String delegateName) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final votingPowerDisplay = '${context.read<Web3Provider>().kub8Balance.toStringAsFixed(2)} KUB8';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(
          l10n.daoDelegateVotingPowerDialogTitle,
          style: GoogleFonts.inter(color: scheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daoDelegateVotingPowerDialogBody(votingPowerDisplay, delegateName),
              style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.daoDelegationBenefitsBody,
                    style: GoogleFonts.inter(
                      fontSize: 11,
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
            child: Text(l10n.commonCancel, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeDelegation(delegateName);
            },
            child: Text(l10n.daoConfirmDelegationButton, style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  void _completeDelegation(String delegateName) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Here you would typically call a smart contract or API
    // For now, we'll simulate the delegation
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.daoDelegationSuccessToast(delegateName)),
        backgroundColor: scheme.primary,
        action: SnackBarAction(
          label: l10n.daoViewDelegationDetailsAction,
          textColor: scheme.onPrimary,
          onPressed: () {
            // Show delegation details
            _showDelegationDetails(delegateName);
          },
        ),
      ),
    );
    
    // Update the delegation status in the UI
    setState(() {
      // You would update your delegation state here
    });
  }

  void _showDelegationDetails(String delegateName) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  l10n.daoDelegationActiveTitle,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(l10n.daoDelegationDetailDelegateLabel, delegateName),
            _buildDetailRow(
              l10n.daoDelegationDetailVotingPowerLabel,
              '${Provider.of<Web3Provider>(context, listen: false).kub8Balance.toStringAsFixed(2)} KUB8',
            ),
            _buildDetailRow(l10n.daoDelegationDetailStatusLabel, l10n.daoDelegationStatusActive),
            _buildDetailRow(l10n.daoDelegationDetailStartedLabel, l10n.daoDelegationStartedJustNow),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _revokeDelegation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(l10n.daoRevokeDelegationButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _revokeDelegation() {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.daoDelegationRevokedToast),
        backgroundColor: scheme.tertiary,
      ),
    );
  }

  void _selfDelegate() {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.daoSelfDelegationEnabledToast),
        backgroundColor: scheme.tertiary,
      ),
    );
  }

  Future<void> _voteOnProposal(String proposalId, bool isYes) async {
    final daoProvider = context.read<DAOProvider>();
    final web3Provider = context.read<Web3Provider>();
    final wallet = web3Provider.walletAddress;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (wallet.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.daoVoteWalletRequiredToast)),
      );
      return;
    }

    try {
      final votingPower = web3Provider.kub8Balance.floor();
      await daoProvider.castVote(
        proposalId: proposalId,
        choice: isYes ? VoteChoice.yes : VoteChoice.no,
        votingPower: votingPower > 0 ? votingPower : 1,
        walletAddress: wallet,
      );
      if (!mounted) return;
      messenger.showSnackBar(
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.daoVoteSubmitFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  void _showGovernanceInfo() {
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
              'How DAO Governance Works',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The art.kubus DAO allows community members to vote on platform decisions, new features, and policies. Your voting power is based on your KUB8 token holdings.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}





