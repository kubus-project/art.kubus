import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/glass_components.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../web3/dao/governance_hub.dart';
import '../../web3/dao/dao_analytics.dart';

/// Desktop Governance Hub screen with split-panel layout
/// Left: Mobile governance hub view
/// Right: Quick actions, DAO stats, and voting power
class DesktopGovernanceHubScreen extends StatefulWidget {
  const DesktopGovernanceHubScreen({super.key});

  @override
  State<DesktopGovernanceHubScreen> createState() =>
      _DesktopGovernanceHubScreenState();
}

class _DesktopGovernanceHubScreenState extends State<DesktopGovernanceHubScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final ValueNotifier<int> _hubSelectedIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hubSelectedIndex.dispose();
    super.dispose();
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
                // Left: Mobile governance hub view (wrapped)
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
                    child: GovernanceHub(
                      selectedIndexNotifier: _hubSelectedIndex,
                      embedded: true,
                    ),
                  ),
                ),

                // Right: Quick actions, DAO stats, and voting info
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
    final l10n = AppLocalizations.of(context)!;
    final panelGlassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.sidebarBackground,
    );

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
        backgroundColor: panelGlassStyle.tintColor,
        blurSigma: panelGlassStyle.blurSigma,
        fallbackMinOpacity: panelGlassStyle.fallbackMinOpacity,
        child: ListView(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          children: [
            KubusHeaderText(
              title: l10n.desktopGovernanceSidebarOverviewTitle,
              kind: KubusHeaderKind.section,
            ),
            const SizedBox(height: KubusSpacing.lg),

            // Voting power card
            _buildVotingPowerCard(themeProvider),
            const SizedBox(height: KubusSpacing.md + KubusSpacing.xs),

            // Quick actions
            KubusHeaderText(
              title: l10n.desktopGovernanceSidebarQuickActionsTitle,
              kind: KubusHeaderKind.section,
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            KubusActionSidebarTile(
              title: l10n.desktopGovernanceQuickActionCreateProposalTitle,
              subtitle: l10n.desktopGovernanceQuickActionCreateProposalSubtitle,
              icon: Icons.add_box_outlined,
              semantic: KubusActionSemantic.create,
              onTap: () => _hubSelectedIndex.value = 2,
            ),
            KubusActionSidebarTile(
              title: l10n.desktopGovernanceQuickActionVoteTitle,
              subtitle: l10n.desktopGovernanceQuickActionVoteSubtitle,
              icon: Icons.how_to_vote_outlined,
              semantic: KubusActionSemantic.manage,
              onTap: () => _hubSelectedIndex.value = 0,
            ),
            KubusActionSidebarTile(
              title: l10n.desktopGovernanceQuickActionAnalyticsTitle,
              subtitle: l10n.desktopGovernanceQuickActionAnalyticsSubtitle,
              icon: Icons.analytics_outlined,
              semantic: KubusActionSemantic.analytics,
              onTap: () {
                DesktopShellScope.of(context)?.pushScreen(
                  DesktopSubScreen(
                    title: l10n.desktopGovernanceAnalyticsScreenTitle,
                    child: const DAOAnalytics(embedded: true),
                  ),
                );
              },
            ),
            const SizedBox(height: KubusSpacing.lg),

            // DAO Stats
            KubusHeaderText(
              title: l10n.desktopGovernanceSidebarStatisticsTitle,
              kind: KubusHeaderKind.section,
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            _buildDAOStatsGrid(themeProvider),
            const SizedBox(height: KubusSpacing.lg),

            // Recent governance activity
            KubusHeaderText(
              title: l10n.desktopGovernanceSidebarRecentActivityTitle,
              kind: KubusHeaderKind.section,
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            _buildRecentActivity(themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingPowerCard(ThemeProvider themeProvider) {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, _) {
        final l10n = AppLocalizations.of(context)!;
        final daoAccent = KubusColorRoles.of(context).web3DaoAccent;
        final roles = KubusColorRoles.of(context);
        final votingPower = web3Provider.kub8Balance;
        final hasVotingPower = votingPower > 0;
        final cardGlassStyle = KubusGlassStyle.resolve(
          context,
          surfaceType: KubusGlassSurfaceType.card,
        );

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: KubusChromeMetrics.heroIconBox - KubusSpacing.xs,
                    height: KubusChromeMetrics.heroIconBox - KubusSpacing.xs,
                    decoration: BoxDecoration(
                      color: daoAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                    child: Icon(
                      Icons.how_to_vote,
                      color: daoAccent,
                      size: KubusChromeMetrics.heroIcon,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Voting Power',
                          style: KubusTextStyles.statLabel.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${votingPower.toStringAsFixed(2)} KUB8',
                          style: KubusTextStyles.heroTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!hasVotingPower) ...[
                const SizedBox(height: KubusSpacing.md),
                LiquidGlassPanel(
                  padding:
                      const EdgeInsets.all(KubusSpacing.md - KubusSpacing.xs),
                  borderRadius:
                      BorderRadius.circular(KubusRadius.sm + KubusSpacing.xs),
                  showBorder: false,
                  backgroundColor: cardGlassStyle.tintColor,
                  blurSigma: cardGlassStyle.blurSigma,
                  fallbackMinOpacity: cardGlassStyle.fallbackMinOpacity,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: roles.lockedFeature,
                        size: KubusHeaderMetrics.actionIcon,
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.desktopGovernanceAcquireKub8Hint,
                          style: KubusTextStyles.actionTileSubtitle.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDAOStatsGrid(ThemeProvider themeProvider) {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, _) {
        final proposals = daoProvider.proposals;
        final activeProposals =
            proposals.where((p) => p.status == ProposalStatus.active).length;
        final totalMembers = daoProvider.delegates.length;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Proposals',
                    proposals.length.toString(),
                    Icons.description_outlined,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Active',
                    activeProposals.toString(),
                    Icons.pending_actions_outlined,
                    KubusColorRoles.of(context).statTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Members',
                    totalMembers.toString(),
                    Icons.people_outline,
                    KubusColorRoles.of(context).statCoral,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Treasury',
                    '${(daoProvider.treasuryOnChainBalance ?? 0).toStringAsFixed(2)} KUB8',
                    Icons.account_balance_outlined,
                    KubusColorRoles.of(context).positiveAction,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final radius = BorderRadius.circular(KubusRadius.md);
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: color,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(KubusSpacing.md),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassStyle.tintColor,
        blurSigma: glassStyle.blurSigma,
        fallbackMinOpacity: glassStyle.fallbackMinOpacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: KubusHeaderMetrics.actionIcon),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              value,
              style: KubusTextStyles.statValue.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: KubusTextStyles.statLabel.copyWith(
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

  Widget _buildRecentActivity(ThemeProvider themeProvider) {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, _) {
        final recentProposals = daoProvider.proposals.take(3).toList();
        final activityGlassStyle = KubusGlassStyle.resolve(
          context,
          surfaceType: KubusGlassSurfaceType.card,
        );

        if (recentProposals.isEmpty) {
          return LiquidGlassPanel(
            padding: const EdgeInsets.all(KubusSpacing.md),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            showBorder: false,
            backgroundColor: activityGlassStyle.tintColor,
            blurSigma: activityGlassStyle.blurSigma,
            fallbackMinOpacity: activityGlassStyle.fallbackMinOpacity,
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: KubusChromeMetrics.heroIcon,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  'No recent activity',
                  style: KubusTextStyles.detailBody.copyWith(
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

        return Column(
          children: recentProposals.map((proposal) {
            final scheme = Theme.of(context).colorScheme;
            return Container(
              margin: const EdgeInsets.only(
                  bottom: KubusSpacing.md - KubusSpacing.xs),
              padding: const EdgeInsets.all(KubusSpacing.md - KubusSpacing.xs),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
              child: Row(
                children: [
                  Container(
                    width: KubusChromeMetrics.navBadgeDot,
                    height: KubusChromeMetrics.navBadgeDot,
                    decoration: BoxDecoration(
                      color: proposal.status == ProposalStatus.active
                          ? scheme.tertiary
                          : scheme.onSurface.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposal.title,
                          style: KubusTextStyles.detailCardTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          proposal.status.name,
                          style: KubusTextStyles.detailLabel.copyWith(
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
            );
          }).toList(),
        );
      },
    );
  }
}
