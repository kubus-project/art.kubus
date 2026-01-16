import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../providers/themeprovider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/analytics_filters_provider.dart';
import '../../../providers/desktop_dashboard_state_provider.dart';
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
import '../../map_markers/manage_markers_screen.dart';
import '../../../widgets/glass_components.dart';

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
      backgroundColor: Colors.transparent,
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
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: InstitutionHub(
                      onTabChanged: (tabIndex) {
                        context.read<DesktopDashboardStateProvider>().updateInstitutionSectionFromTabIndex(
                              tabIndex: tabIndex,
                              exhibitionsEnabled: AppConfig.isFeatureEnabled('exhibitions'),
                            );
                      },
                    ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final persona = context.watch<ProfileProvider>().userPersona;
    final showCreateActions =
        persona == null || persona == UserPersona.institution;
    final dashboardState = context.watch<DesktopDashboardStateProvider>();
    final section = dashboardState.institutionSection;
    final showExhibitions = AppConfig.isFeatureEnabled('exhibitions');

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

    String sectionTitle() {
      switch (section) {
        case DesktopInstitutionSection.events:
          return 'Events';
        case DesktopInstitutionSection.exhibitions:
          return 'Exhibitions';
        case DesktopInstitutionSection.create:
          return 'Create';
        case DesktopInstitutionSection.analytics:
          return 'Analytics';
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : scheme.outline.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        showBorder: false,
        backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
          // Header
          Text(
            sectionTitle(),
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
                  scheme.primary,
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
          if (section == DesktopInstitutionSection.create &&
              isApprovedInstitution &&
              showCreateActions &&
              AppConfig.isFeatureEnabled('events'))
            _buildQuickActionTile(
              'Create Event',
              'Schedule a new event',
              Icons.event_outlined,
              Theme.of(context).colorScheme.tertiary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Create Event',
                    child: const EventCreator(),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.create &&
              isApprovedInstitution &&
              showCreateActions &&
              showExhibitions)
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
          if (section == DesktopInstitutionSection.create &&
              isApprovedInstitution &&
              showCreateActions)
            _buildQuickActionTile(
              'Manage Markers',
              'Create, publish, and edit map markers',
              Icons.place_outlined,
              Theme.of(context).colorScheme.primary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Manage Markers',
                    child: const ManageMarkersScreen(),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.events && isApprovedInstitution)
            _buildQuickActionTile(
              'Manage Events',
              'View all events',
              Icons.event_note_outlined,
              Theme.of(context).colorScheme.secondary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Manage Events',
                    child: const EventManager(),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.exhibitions &&
              isApprovedInstitution &&
              showExhibitions)
            _buildQuickActionTile(
              'My Exhibitions',
              'View hosted and collaborating exhibitions',
              Icons.collections_bookmark_outlined,
              Theme.of(context).colorScheme.primary,
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
          if (section == DesktopInstitutionSection.analytics && isApprovedInstitution)
            _buildQuickActionTile(
              'Analytics',
              'View performance stats',
              Icons.analytics_outlined,
              Theme.of(context).colorScheme.tertiary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Analytics',
                    child: const InstitutionAnalytics(),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.analytics) ...[
            const SizedBox(height: 8),
            _buildAnalyticsTimeframeSelector(
              title: 'Timeframe',
              value: context.watch<AnalyticsFiltersProvider>().institutionTimeframe,
              onChanged: (v) => context.read<AnalyticsFiltersProvider>().setInstitutionTimeframe(v),
            ),
          ],
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
          if (section == DesktopInstitutionSection.events) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTimeframeSelector({
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = value.trim().toLowerCase();
    final effective = AnalyticsFiltersProvider.allowedTimeframes.contains(normalized) ? normalized : '30d';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effective,
              dropdownColor: scheme.surfaceContainerHighest,
              items: AnalyticsFiltersProvider.allowedTimeframes
                  .map(
                    (tf) => DropdownMenuItem<String>(
                      value: tf,
                      child: Text(tf),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next == null) return;
                onChanged(next);
              },
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: color.withValues(alpha: isDark ? 0.16 : 0.10),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
    final roles = KubusColorRoles.of(context);
    final statsProvider = context.watch<StatsProvider>();
    final wallet = _resolveWalletAddress(listen: true);

    const metrics = <String>[
      'eventsHosted',
      'visitorsReceived',
      'exhibitionArtworks',
      'achievementTokensTotal',
    ];

    if (wallet.isNotEmpty) {
      unawaited(statsProvider.ensureSnapshot(
        entityType: 'user',
        entityId: wallet,
        metrics: metrics,
        scope: 'public',
      ));
    }

    final snapshot = wallet.isEmpty
        ? null
        : statsProvider.getSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: metrics,
            scope: 'public',
          );
    final isLoading = wallet.isNotEmpty &&
        statsProvider.isSnapshotLoading(
          entityType: 'user',
          entityId: wallet,
          metrics: metrics,
          scope: 'public',
        ) &&
        snapshot == null;

    final counters = snapshot?.counters ?? const <String, int>{};
    final events = wallet.isEmpty ? null : (counters['eventsHosted'] ?? 0);
    final visitors = wallet.isEmpty ? null : (counters['visitorsReceived'] ?? 0);
    final artworks = wallet.isEmpty ? null : (counters['exhibitionArtworks'] ?? 0);
    final revenue = wallet.isEmpty ? null : (counters['achievementTokensTotal'] ?? 0);

    String displayCount(int? value) => isLoading ? '…' : (value?.toString() ?? '—');
    String displayKub8(int? value) => isLoading ? '…' : (value == null ? '—' : '${value.toString()} KUB8');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Events',
                displayCount(events),
                Icons.event_outlined,
                scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Visitors',
                displayCount(visitors),
                Icons.people_outline,
                scheme.secondary,
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
                displayCount(artworks),
                Icons.collections_outlined,
                scheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Revenue',
                displayKub8(revenue),
                Icons.attach_money,
                roles.positiveAction,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: radius,
      showBorder: false,
      backgroundColor: color.withValues(alpha: isDark ? 0.15 : 0.10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: color.withValues(alpha: 0.18)),
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
