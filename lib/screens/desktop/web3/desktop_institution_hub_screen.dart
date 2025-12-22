import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../config/config.dart';
import '../../../models/dao.dart';
import '../../../models/user_persona.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/wallet_utils.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../web3/institution/institution_hub.dart';
import '../../web3/institution/event_creator.dart';
import '../../web3/institution/event_manager.dart';
import '../../web3/institution/institution_analytics.dart';
import '../../events/exhibition_creator_screen.dart';
import '../../events/exhibition_detail_screen.dart';
import '../../events/exhibition_list_screen.dart';

/// Desktop Institution Hub screen with split-panel layout
/// Left: Mobile institution hub view
/// Right: Quick actions, stats, and analytics
class DesktopInstitutionHubScreen extends StatefulWidget {
  const DesktopInstitutionHubScreen({super.key});

  @override
  State<DesktopInstitutionHubScreen> createState() =>
      _DesktopInstitutionHubScreenState();
}

class _DesktopInstitutionHubScreenState
    extends State<DesktopInstitutionHubScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  DAOReview? _institutionReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstitutionReviewStatus(forceRefresh: true);
    });
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        _reviewLoading = false;
      });
    } catch (e) {
      if (!mounted || requestedWallet != _lastReviewWallet) return;
      setState(() {
        _reviewLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: _animationController,
              curve: animationTheme.fadeCurve,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Mobile institution hub view (wrapped)
                Expanded(
                  flex: isLarge ? 2 : 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: const InstitutionHub(),
                  ),
                ),

                // Right: Quick actions, stats, and analytics
                if (isLarge)
                  SizedBox(
                    width: 400,
                    child: _buildRightPanel(themeProvider),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPanel(ThemeProvider themeProvider) {
    final persona = context.watch<ProfileProvider>().userPersona;
    final showCreateActions =
        persona == null || persona == UserPersona.institution;

    // Compute approval status for gating quick actions
    final profileProvider = context.watch<ProfileProvider>();
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _institutionReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final hasInstitutionBadge =
        profileProvider.currentUser?.isInstitution ?? false;
    final reviewStatus = review?.status.toLowerCase() ?? '';
    final reviewIsInstitution = review?.isInstitutionApplication ?? false;
    final isApprovedInstitution = hasInstitutionBadge ||
        (reviewIsInstitution && reviewStatus == 'approved');

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Text(
            'Institution Overview',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Verification status
          _buildVerificationStatusCard(themeProvider),
          const SizedBox(height: 20),

          // Quick actions
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (AppConfig.isFeatureEnabled('collabInvites'))
            Consumer<CollabProvider>(
              builder: (context, collabProvider, _) {
                final pending = collabProvider.pendingInviteCount;
                final scheme = Theme.of(context).colorScheme;
                final badge = pending > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          pending > 99 ? '99+' : pending.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onError,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      );

                return _buildQuickActionTile(
                  'Invites',
                  pending > 0
                      ? 'You have pending collaboration invites'
                      : 'View collaboration invites',
                  Icons.inbox_outlined,
                  Theme.of(context).colorScheme.primary,
                  () {
                    DesktopShellScope.of(context)?.pushScreen(
                      DesktopSubScreen(
                        title: 'Collaboration Invites',
                        child: const InvitesInboxScreen(),
                      ),
                    );
                  },
                  trailing: badge,
                );
              },
            ),
          if (isApprovedInstitution &&
              showCreateActions &&
              AppConfig.isFeatureEnabled('events'))
            _buildQuickActionTile(
              'Create Event',
              'Schedule a new event',
              Icons.event_outlined,
              const Color(0xFFFFB300), // Amber
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Create Event',
                    child: const EventCreator(),
                  ),
                );
              },
            ),
          if (isApprovedInstitution &&
              showCreateActions &&
              AppConfig.isFeatureEnabled('exhibitions'))
            _buildQuickActionTile(
              'Create Exhibition',
              'Publish a new exhibition',
              Icons.museum_outlined,
              Theme.of(context).colorScheme.secondary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Create Exhibition',
                    child: const ExhibitionCreatorScreen(),
                  ),
                );
              },
            ),
          if (isApprovedInstitution)
            _buildQuickActionTile(
              'Manage Events',
              'View all events',
              Icons.event_note_outlined,
              const Color(0xFF4ECDC4),
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Manage Events',
                    child: const EventManager(),
                  ),
                );
              },
            ),
          if (isApprovedInstitution &&
              AppConfig.isFeatureEnabled('exhibitions'))
            _buildQuickActionTile(
              'My Exhibitions',
              'View hosted and collaborating exhibitions',
              Icons.collections_bookmark_outlined,
              KubusColorRoles.of(context).web3InstitutionAccent,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'My Exhibitions',
                    child: ExhibitionListScreen(
                      embedded: true,
                      canCreate: true,
                      onCreateExhibition: () {
                        DesktopShellScope.of(context)?.pushScreen(
                          DesktopSubScreen(
                            title: 'Create Exhibition',
                            child: const ExhibitionCreatorScreen(),
                          ),
                        );
                      },
                      onOpenExhibition: (exhibition) {
                        DesktopShellScope.of(context)?.pushScreen(
                          DesktopSubScreen(
                            title: exhibition.title,
                            child: ExhibitionDetailScreen(
                              exhibitionId: exhibition.id,
                              initialExhibition: exhibition,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          if (isApprovedInstitution)
            _buildQuickActionTile(
              'Analytics',
              'View performance stats',
              Icons.analytics_outlined,
              const Color(0xFFFF6B6B),
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Analytics',
                    child: const InstitutionAnalytics(),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          // Stats
          Text(
            'Institution Statistics',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsGrid(themeProvider),
          const SizedBox(height: 24),

          // Upcoming events
          Text(
            'Upcoming Events',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildUpcomingEvents(themeProvider),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard(ThemeProvider themeProvider) {
    final wallet = _resolveWalletAddress();
    final status = _institutionReview?.status.toLowerCase() ?? '';
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    Color statusColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    IconData statusIcon = Icons.help_outline;
    String statusText = 'Not Applied';
    String statusDescription = 'Apply for institution verification';

    if (_reviewLoading) {
      statusText = 'Loading...';
      statusDescription = 'Checking verification status';
    } else if (isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.verified;
      statusText = 'Verified Institution';
      statusDescription = 'Your organization is verified';
    } else if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusText = 'Pending Review';
      statusDescription = 'Application under review';
    } else if (isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Application Rejected';
      statusDescription = 'Please resubmit with improvements';
    }

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDescription,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isApproved && !isPending && wallet.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Apply functionality handled by mobile view
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      KubusColorRoles.of(context).web3InstitutionAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Apply for Verification',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Events',
                '0',
                Icons.event_outlined,
                scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Visitors',
                '0',
                Icons.people_outline,
                const Color(0xFF4ECDC4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Artworks',
                '0',
                Icons.collections_outlined,
                const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Revenue',
                '0 KUB8',
                Icons.attach_money,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 40,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'No upcoming events',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
