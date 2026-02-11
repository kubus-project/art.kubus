import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../providers/themeprovider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
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
import '../../../widgets/kubus_action_sidebar.dart';

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
          padding: const EdgeInsets.all(KubusSpacing.lg),
          children: [
          // Header
          Text(
            sectionTitle(),
            style: KubusTextStyles.screenTitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: KubusSpacing.lg),

          // Verification status
          _buildVerificationStatusCard(themeProvider),
          const SizedBox(height: KubusSpacing.md + KubusSpacing.xs),

          // Quick actions
          Text(
            'Quick Actions',
            style: KubusTextStyles.sectionTitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
          if (AppConfig.isFeatureEnabled('collabInvites'))
            Consumer<CollabProvider>(
              builder: (context, collabProvider, _) {
                final pending = collabProvider.pendingInviteCount;
                final badge = pending > 0
                    ? FrostedContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.sm,
                          vertical: KubusSpacing.xs,
                        ),
                        borderRadius: BorderRadius.circular(KubusRadius.xl),
                        showBorder: false,
                        backgroundColor:
                            scheme.error.withValues(alpha: isDark ? 0.30 : 0.22),
                        child: Text(
                          pending > 99 ? '99+' : pending.toString(),
                          style: KubusTextStyles.badgeCount
                              .copyWith(color: scheme.onError),
                        ),
                      )
                    : null;

                return KubusActionSidebarTile(
                  title: 'Invites',
                  subtitle: pending > 0
                      ? 'You have pending collaboration invites'
                      : 'View collaboration invites',
                  icon: Icons.inbox_outlined,
                  semantic: KubusActionSemantic.invite,
                  onTap: () {
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
            KubusActionSidebarTile(
              title: 'Create Event',
              subtitle: 'Schedule a new event',
              icon: Icons.event_outlined,
              semantic: KubusActionSemantic.create,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Create Event',
                    child: const EventCreator(embedded: true),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.create &&
              isApprovedInstitution &&
              showCreateActions &&
              showExhibitions)
            KubusActionSidebarTile(
              title: 'Create Exhibition',
              subtitle: 'Publish a new exhibition',
              icon: Icons.museum_outlined,
              semantic: KubusActionSemantic.publish,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Create Exhibition',
                    child: const ExhibitionCreatorScreen(embedded: true),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.create &&
              isApprovedInstitution &&
              showCreateActions)
            KubusActionSidebarTile(
              title: 'Manage Markers',
              subtitle: 'Create, publish, and edit map markers',
              icon: Icons.place_outlined,
              semantic: KubusActionSemantic.manage,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Manage Markers',
                    child: const ManageMarkersScreen(embedded: true),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.events && isApprovedInstitution)
            KubusActionSidebarTile(
              title: 'Manage Events',
              subtitle: 'View all events',
              icon: Icons.event_note_outlined,
              semantic: KubusActionSemantic.manage,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Manage Events',
                    child: const EventManager(embedded: true),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.exhibitions &&
              isApprovedInstitution &&
              showExhibitions)
            KubusActionSidebarTile(
              title: 'My Exhibitions',
              subtitle: 'View hosted and collaborating exhibitions',
              icon: Icons.collections_bookmark_outlined,
              semantic: KubusActionSemantic.view,
              onTap: () {
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
                            child: const ExhibitionCreatorScreen(embedded: true),
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
            KubusActionSidebarTile(
              title: 'Analytics',
              subtitle: 'View performance stats',
              icon: Icons.analytics_outlined,
              semantic: KubusActionSemantic.analytics,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: 'Analytics',
                    child: const InstitutionAnalytics(),
                  ),
                );
              },
            ),
          if (section == DesktopInstitutionSection.analytics) ...[
            const SizedBox(height: KubusSpacing.sm),
            _buildAnalyticsTimeframeSelector(
              title: 'Timeframe',
              value: context.watch<AnalyticsFiltersProvider>().institutionTimeframe,
              onChanged: (v) => context.read<AnalyticsFiltersProvider>().setInstitutionTimeframe(v),
            ),
          ],
          const SizedBox(height: KubusSpacing.lg),

          // Stats
          Text(
            'Institution Statistics',
            style: KubusTextStyles.sectionTitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
          _buildStatsGrid(themeProvider),
          const SizedBox(height: KubusSpacing.lg),

          // Upcoming events
          if (section == DesktopInstitutionSection.events) ...[
            Text(
              'Upcoming Events',
              style:
                  KubusTextStyles.sectionTitle.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
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

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: KubusTextStyles.actionTileTitle
                  .copyWith(color: scheme.onSurface),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effective,
              dropdownColor: scheme.surfaceContainerHighest,
              style: KubusTextStyles.actionTileSubtitle
                  .copyWith(color: scheme.onSurface),
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
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;

    Color statusColor =
        scheme.onSurface.withValues(alpha: 0.6);
    IconData statusIcon = Icons.help_outline;
    String statusText = 'Not Applied';
    String statusDescription = 'Apply for institution verification';

    if (_reviewLoading) {
      statusText = 'Loading...';
      statusDescription = 'Checking verification status';
    } else if (isApproved) {
      statusColor = roles.positiveAction;
      statusIcon = Icons.verified;
      statusText = 'Verified Institution';
      statusDescription = 'Your organization is verified';
    } else if (isPending) {
      statusColor = roles.warningAction;
      statusIcon = Icons.pending;
      statusText = 'Pending Review';
      statusDescription = 'Application under review';
    } else if (isRejected) {
      statusColor = roles.negativeAction;
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
                width: KubusSpacing.xxl,
                height: KubusSpacing.xxl,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: KubusSpacing.lg,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: KubusTextStyles.sectionTitle
                          .copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      statusDescription,
                      style: KubusTextStyles.actionTileSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isApproved && !isPending && wallet.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.md),
            Text(
              'Use the Institution Hub panel to submit verification.',
              style: KubusTextStyles.actionTileSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
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
    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = color.withValues(alpha: isDark ? 0.12 : 0.08);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(KubusSpacing.md),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: KubusSizes.sidebarActionIcon),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              value,
              style: KubusTypography.textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: KubusTextStyles.actionTileSubtitle.copyWith(
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
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.18),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: KubusSizes.sidebarActionIconBox,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            'No upcoming events',
            style: KubusTextStyles.actionTileTitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
