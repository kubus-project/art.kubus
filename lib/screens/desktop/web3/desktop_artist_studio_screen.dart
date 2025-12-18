import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../config/config.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/wallet_utils.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../collab/invites_inbox_screen.dart';
import '../../web3/artist/artist_studio.dart';
import '../../web3/artist/artwork_creator.dart';
import '../../web3/artist/artwork_gallery.dart';
import '../../web3/artist/artist_analytics.dart';
import '../../web3/artist/collection_creator.dart';
import '../../art/collection_detail_screen.dart';
import '../../events/exhibition_list_screen.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : scheme.surface,
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
                    child: const ArtistStudio(),
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

    return Container(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Text(
            l10n.desktopArtistStudioOverviewTitle,
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

          // Quick actions
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
                  l10n.desktopArtistStudioQuickActionInvitesTitle,
                  pending > 0
                      ? l10n
                          .desktopArtistStudioQuickActionInvitesPendingSubtitle
                      : l10n.desktopArtistStudioQuickActionInvitesSubtitle,
                  Icons.group_add_outlined,
                  scheme.primary,
                  () {
                    DesktopShellScope.of(context)?.pushScreen(
                      DesktopSubScreen(
                        title: l10n
                            .desktopArtistStudioQuickActionCollaborationInvitesTitle,
                        child: const InvitesInboxScreen(),
                      ),
                    );
                  },
                  trailing: badge,
                );
              },
            ),
          if (isApprovedArtist)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionCreateArtworkTitle,
              l10n.desktopArtistStudioQuickActionCreateArtworkSubtitle,
              Icons.add_photo_alternate_outlined,
              AppColorUtils.tealAccent, // Collections/gallery
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title:
                        l10n.desktopArtistStudioQuickActionCreateArtworkTitle,
                    child: const ArtworkCreator(),
                  ),
                );
              },
            ),
          if (isApprovedArtist)
            _buildQuickActionTile(
              l10n.collectionCreatorTitle,
              l10n.artistStudioCreateOptionCollectionSubtitle,
              Icons.collections_bookmark_outlined,
              KubusColorRoles.of(context).web3ArtistStudioAccent,
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
          if (isApprovedArtist)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionMyGalleryTitle,
              l10n.desktopArtistStudioQuickActionMyGallerySubtitle,
              Icons.collections_outlined,
              scheme.secondary,
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionMyGalleryTitle,
                    child: const ArtworkGallery(),
                  ),
                );
              },
            ),
          if (isApprovedArtist && AppConfig.isFeatureEnabled('exhibitions'))
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionExhibitionsTitle,
              l10n.desktopArtistStudioQuickActionExhibitionsSubtitle,
              Icons.collections_bookmark_outlined,
              AppColorUtils.tealAccent, // Collections
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionExhibitionsTitle,
                    child: const ExhibitionListScreen(
                        embedded: true, canCreate: true),
                  ),
                );
              },
            ),
          if (isApprovedArtist)
            _buildQuickActionTile(
              l10n.desktopArtistStudioQuickActionAnalyticsTitle,
              l10n.desktopArtistStudioQuickActionAnalyticsSubtitle,
              Icons.analytics_outlined,
              AppColorUtils.indigoAccent, // Analytics
              () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopArtistStudioQuickActionAnalyticsTitle,
                    child: const ArtistAnalytics(),
                  ),
                );
              },
            ),
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

          // Recent activity
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatArtworks,
                '0',
                Icons.collections_outlined,
                AppColorUtils.tealAccent, // Collections
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatViews,
                '0',
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
                '0',
                Icons.favorite_outline,
                scheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                l10n.desktopArtistStudioStatSales,
                '0 KUB8',
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
