import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'dart:async';
import '../../../providers/themeprovider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/analytics_filters_provider.dart';
import '../../../providers/desktop_dashboard_state_provider.dart';
import '../../../config/config.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/wallet_utils.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../web3/artist/artist_studio.dart';
import '../../web3/artist/artwork_creator.dart';
import '../../web3/artist/artist_portfolio_screen.dart';
import '../../web3/artist/artist_analytics.dart';
import '../../web3/artist/collection_creator.dart';
import '../../art/collection_detail_screen.dart';
import '../../events/exhibition_creator_screen.dart';
import '../../events/exhibition_detail_screen.dart';
import '../../events/exhibition_list_screen.dart';
import '../../map_markers/manage_markers_screen.dart';
import '../../../widgets/glass_components.dart';

/// Desktop Artist Studio screen with split-panel layout
/// Left: Mobile artist studio view
/// Right: Quick actions, stats, and analytics
class DesktopArtistStudioScreen extends StatefulWidget {
  const DesktopArtistStudioScreen({super.key});

  @override
  State<DesktopArtistStudioScreen> createState() =>
      _DesktopArtistStudioScreenState();
}

class _DesktopArtistStudioScreenState extends State<DesktopArtistStudioScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  DAOReview? _artistReview;
  bool _reviewLoading = false;
  bool _hasFetchedReviewForWallet = false;
  String _lastReviewWallet = '';

  String _lastStatsWallet = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArtistReviewStatus(forceRefresh: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = _resolveWalletAddress(listen: true);
    final walletChanged = wallet != _lastReviewWallet;
    if (!walletChanged && _hasFetchedReviewForWallet) return;

    if (wallet.isNotEmpty) {
      _loadArtistReviewStatus(forceRefresh: true);
    }

    // StatsProvider.ensureSnapshot() notifies listeners; calling it during build
    // (e.g. from a widget build method) can trigger "setState/markNeedsBuild"
    // exceptions. Schedule the refresh post-frame when the wallet changes.
    final statsWalletChanged = wallet != _lastStatsWallet;
    if (wallet.isEmpty) {
      _lastStatsWallet = '';
    } else if (statsWalletChanged) {
      _lastStatsWallet = wallet;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final statsProvider = context.read<StatsProvider>();
        unawaited(statsProvider.ensureSnapshot(
          entityType: 'user',
          entityId: wallet,
          metrics: const <String>[
            'artworks',
            'viewsReceived',
            'likesReceived',
            'achievementTokensTotal',
          ],
          scope: 'public',
        ));
      });
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
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    void openArtworkCreator() {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope == null) return;
      shellScope.pushScreen(
        DesktopSubScreen(
          title: l10n.artistStudioCreateOptionArtworkTitle,
          child: const ArtworkCreator(),
        ),
      );
    }

    void openCollectionCreator() {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope == null) return;
      shellScope.pushScreen(
        DesktopSubScreen(
          title: l10n.collectionCreatorTitle,
          child: CollectionCreator(
            onCreated: (collectionId) {
              shellScope.popScreen();
              shellScope.pushScreen(
                DesktopSubScreen(
                  title: l10n.userProfileCollectionFallbackTitle,
                  child: CollectionDetailScreen(
                    collectionId: collectionId,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    void openExhibitionCreator() {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope == null) return;
      shellScope.pushScreen(
        DesktopSubScreen(
          title: l10n.exhibitionCreatorAppBarTitle,
          child: const ExhibitionCreatorScreen(),
        ),
      );
    }

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
                // Left: Mobile artist studio view (wrapped)
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
                    child: ArtistStudio(
                      onOpenArtworkCreator: openArtworkCreator,
                      onOpenCollectionCreator: openCollectionCreator,
                      onOpenExhibitionCreator: openExhibitionCreator,
                      onTabChanged: (tabIndex) {
                        context.read<DesktopDashboardStateProvider>().updateArtistStudioSectionFromTabIndex(
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dashboardState = context.watch<DesktopDashboardStateProvider>();
    final section = dashboardState.artistStudioSection;

    // Compute approval status for gating quick actions
    final profileProvider = context.watch<ProfileProvider>();
    final daoProvider = context.watch<DAOProvider>();
    final wallet = _resolveWalletAddress(listen: true);
    final review = _artistReview ??
        (wallet.isNotEmpty ? daoProvider.findReviewForWallet(wallet) : null);
    final hasArtistBadge = profileProvider.currentUser?.isArtist ?? false;
    final reviewStatus = review?.status.toLowerCase() ?? '';
    final reviewIsArtist = review?.isArtistApplication ?? false;
    final isApprovedArtist =
        hasArtistBadge || (reviewIsArtist && reviewStatus == 'approved');

    String sectionTitle() {
      switch (section) {
        case DesktopArtistStudioSection.gallery:
          return l10n.artistStudioTabGallery;
        case DesktopArtistStudioSection.create:
          return l10n.artistStudioTabCreate;
        case DesktopArtistStudioSection.exhibitions:
          return l10n.artistStudioTabExhibitions;
        case DesktopArtistStudioSection.analytics:
          return l10n.artistStudioTabAnalytics;
      }
    }

    final showExhibitions = AppConfig.isFeatureEnabled('exhibitions');

    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: scheme.outline.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        showBorder: false,
        backgroundColor: glassTint,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
          // Header
          Text(
            sectionTitle(),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Verification status
          _buildVerificationStatusCard(themeProvider),
          const SizedBox(height: 20),

          // Contextual sidebar actions
          Text(
            l10n.desktopArtistStudioQuickActionsTitle,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (AppConfig.isFeatureEnabled('collabInvites'))
            Consumer<CollabProvider>(
              builder: (context, collabProvider, _) {
                final pending = collabProvider.pendingInviteCount;
                final badge = pending > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  l10n.desktopArtistStudioQuickActionInvitesTitle,
                  pending > 0
                      ? l10n.desktopArtistStudioQuickActionInvitesPendingSubtitle
                      : l10n.desktopArtistStudioQuickActionInvitesSubtitle,
                  Icons.inbox_outlined,
                  scheme.primary,
                  () {
                    DesktopShellScope.of(context)?.pushScreen(
                      DesktopSubScreen(
                        title: l10n.desktopArtistStudioQuickActionCollaborationInvitesTitle,
                        child: const InvitesInboxScreen(),
                      ),
                    );
                  },
                  trailing: badge,
                );
              },
            ),

          if (isApprovedArtist && section == DesktopArtistStudioSection.create)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionCreateArtworkTitle,
              l10n.desktopArtistStudioQuickActionCreateArtworkSubtitle,
              Icons.add_photo_alternate_outlined,
              scheme.tertiary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionCreateArtworkTitle,
                    child: const ArtworkCreator(),
                  ),
                );
              },
            ),
          if (isApprovedArtist && section == DesktopArtistStudioSection.create)
            _buildQuickActionTile(
              l10n.collectionCreatorTitle,
              l10n.artistStudioCreateOptionCollectionSubtitle,
              Icons.collections_bookmark_outlined,
              scheme.secondary,
              () {
                final shellScope = DesktopShellScope.of(context);
                if (shellScope == null) return;
                shellScope.pushScreen(
                  DesktopSubScreen(
                    title: l10n.collectionCreatorTitle,
                    child: CollectionCreator(
                      onCreated: (collectionId) {
                        shellScope.popScreen();
                        shellScope.pushScreen(
                          DesktopSubScreen(
                            title: l10n.userProfileCollectionFallbackTitle,
                            child: CollectionDetailScreen(
                              collectionId: collectionId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          if (isApprovedArtist && section == DesktopArtistStudioSection.create)
            _buildQuickActionTile(
              l10n.manageMarkersTitle,
              l10n.manageMarkersQuickActionSubtitle,
              Icons.place_outlined,
              scheme.primary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.manageMarkersTitle,
                    child: const ManageMarkersScreen(),
                  ),
                );
              },
            ),
          if (isApprovedArtist && section == DesktopArtistStudioSection.gallery)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionMyGalleryTitle,
              l10n.desktopArtistStudioQuickActionMyGallerySubtitle,
              Icons.collections_outlined,
              scheme.secondary,
              () {
                final wallet = _resolveWalletAddress(listen: false);
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionMyGalleryTitle,
                    child: ArtistPortfolioScreen(walletAddress: wallet),
                  ),
                );
              },
            ),
          if (isApprovedArtist && showExhibitions && section == DesktopArtistStudioSection.exhibitions)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionExhibitionsTitle,
              l10n.desktopArtistStudioQuickActionExhibitionsSubtitle,
              Icons.collections_bookmark_outlined,
              scheme.primary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionExhibitionsTitle,
                    child: ExhibitionListScreen(
                      embedded: true,
                      canCreate: true,
                      onCreateExhibition: () {
                        DesktopShellScope.of(context)?.pushScreen(
                          DesktopSubScreen(
                            title: l10n.exhibitionCreatorAppBarTitle,
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
          if (isApprovedArtist && section == DesktopArtistStudioSection.analytics)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionAnalyticsTitle,
              l10n.desktopArtistStudioQuickActionAnalyticsSubtitle,
              Icons.analytics_outlined,
              scheme.tertiary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionAnalyticsTitle,
                    child: const ArtistAnalytics(),
                  ),
                );
              },
            ),
          if (section == DesktopArtistStudioSection.analytics) ...[
            const SizedBox(height: 8),
            _buildAnalyticsTimeframeSelector(
              title: 'Timeframe',
              value: context.watch<AnalyticsFiltersProvider>().artistTimeframe,
              onChanged: (v) => context.read<AnalyticsFiltersProvider>().setArtistTimeframe(v),
            ),
          ],
          const SizedBox(height: 24),

          // Stats
          Text(
            l10n.desktopArtistStudioStatisticsTitle,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsGrid(themeProvider),
          const SizedBox(height: 24),

          if (section == DesktopArtistStudioSection.gallery) ...[
            Text(
              l10n.desktopArtistStudioRecentActivityTitle,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentActivity(themeProvider),
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
    String labelFor(String timeframe) {
      switch (timeframe) {
        case '7d':
          return '7d';
        case '30d':
          return '30d';
        case '90d':
          return '90d';
        case '1y':
          return '1y';
        default:
          return timeframe;
      }
    }

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
                      child: Text(labelFor(tf)),
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final wallet = _resolveWalletAddress();
    final status = _artistReview?.status.toLowerCase() ?? '';
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    Color statusColor = scheme.onSurface.withValues(alpha: 0.6);
    IconData statusIcon = Icons.help_outline;
    String statusText = l10n.desktopArtistStudioVerificationNotAppliedTitle;
    String statusDescription =
        l10n.desktopArtistStudioVerificationNotAppliedDescription;

    if (_reviewLoading) {
      statusText = l10n.desktopArtistStudioVerificationLoadingTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationLoadingDescription;
    } else if (isApproved) {
      statusColor = scheme.primary;
      statusIcon = Icons.verified;
      statusText = l10n.desktopArtistStudioVerificationApprovedTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationApprovedDescription;
    } else if (isPending) {
      statusColor = scheme.tertiary;
      statusIcon = Icons.pending;
      statusText = l10n.desktopArtistStudioVerificationPendingTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationPendingDescription;
    } else if (isRejected) {
      statusColor = scheme.error;
      statusIcon = Icons.cancel;
      statusText = l10n.desktopArtistStudioVerificationRejectedTitle;
      statusDescription =
          l10n.desktopArtistStudioVerificationRejectedDescription;
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
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDescription,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.6),
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
                      KubusColorRoles.of(context).web3ArtistStudioAccent,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.desktopArtistStudioApplyForVerificationButton,
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final statsProvider = context.watch<StatsProvider>();
    final wallet = _resolveWalletAddress(listen: true);

    const metrics = <String>[
      'artworks',
      'viewsReceived',
      'likesReceived',
      'achievementTokensTotal',
    ];

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
    final artworks = wallet.isEmpty ? null : (counters['artworks'] ?? 0);
    final views = wallet.isEmpty ? null : (counters['viewsReceived'] ?? 0);
    final likes = wallet.isEmpty ? null : (counters['likesReceived'] ?? 0);
    final earnedKub8 = wallet.isEmpty ? null : (counters['achievementTokensTotal'] ?? 0);

    String displayCount(int? value) => isLoading ? '…' : (value?.toString() ?? '—');
    String displayKub8(int? value) => isLoading ? '…' : (value == null ? '—' : '${value.toString()} KUB8');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatArtworks,
                displayCount(artworks),
                Icons.collections_outlined,
                themeProvider.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatViews,
                displayCount(views),
                Icons.visibility_outlined,
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
                l10n.desktopArtistStudioStatLikes,
                displayCount(likes),
                Icons.favorite_outline,
                scheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatSales,
                displayKub8(earnedKub8),
                Icons.attach_money,
                scheme.primary,
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

  Widget _buildRecentActivity(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
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
            Icons.history,
            size: 40,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopArtistStudioNoRecentActivityLabel,
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
