import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../features/web3/web3_capabilities.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/glass_components.dart';
import '../desktop_shell.dart';
import '../../web3/dao/governance_hub.dart';
import '../../web3/dao/dao_analytics.dart';

/// Native desktop governance workspace with a contextual right rail.
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
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final capabilities = Web3CapabilityResolver.resolve(
      Web3CapabilityContext.fromProviders(
        profileProvider: context.watch<ProfileProvider>(),
        walletProvider: context.watch<WalletProvider>(),
      ),
    );

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
                    child: GovernanceWorkspace(
                      selectedIndexNotifier: _hubSelectedIndex,
                      embedded: true,
                      desktopLayout: true,
                    ),
                  ),
                ),
                if (isLarge)
                  SizedBox(
                    width: 380,
                    child: _buildRightPanel(capabilities),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPanel(Web3Capabilities capabilities) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    const sectionGap = KubusSpacing.lg;
    const sectionHeaderGap = KubusSpacing.sm + KubusSpacing.xs;
    const blockGap = KubusSpacing.md + KubusSpacing.xs;
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
        child: ValueListenableBuilder<int>(
          valueListenable: _hubSelectedIndex,
          builder: (context, currentSection, _) => ListView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            children: [
              KubusHeaderText(
                title: l10n.desktopGovernanceSidebarOverviewTitle,
                kind: KubusHeaderKind.section,
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                _governanceSectionLabel(l10n, currentSection),
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
              const SizedBox(height: sectionGap),

              if (capabilities.canViewOwnGovernanceHistory) ...[
                _buildVotingPowerCard(),
                const SizedBox(height: blockGap),
              ],

              // Quick actions
              KubusHeaderText(
                title: l10n.desktopGovernanceSidebarQuickActionsTitle,
                kind: KubusHeaderKind.section,
              ),
              const SizedBox(height: sectionHeaderGap),
              if (capabilities.canCreateProposal && currentSection != 2)
                KubusActionSidebarTile(
                  title: l10n.desktopGovernanceQuickActionCreateProposalTitle,
                  subtitle:
                      l10n.desktopGovernanceQuickActionCreateProposalSubtitle,
                  icon: Icons.add_box_outlined,
                  semantic: KubusActionSemantic.create,
                  onTap: () => _hubSelectedIndex.value = 2,
                ),
              if (capabilities.canVote && currentSection != 0)
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
              const SizedBox(height: sectionGap),

              // Recent governance activity
              KubusHeaderText(
                title: l10n.desktopGovernanceSidebarRecentActivityTitle,
                kind: KubusHeaderKind.section,
              ),
              const SizedBox(height: sectionHeaderGap),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  String _governanceSectionLabel(AppLocalizations l10n, int sectionIndex) {
    switch (sectionIndex) {
      case 1:
        return l10n.daoHubTabVotingHistory;
      case 2:
        return l10n.daoHubTabCreateProposal;
      case 3:
        return l10n.daoHubTabTreasury;
      case 4:
        return l10n.daoHubTabDelegation;
      case 0:
      default:
        return l10n.daoHubTabActiveProposals;
    }
  }

  Widget _buildVotingPowerCard() {
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

        return LiquidGlassCard(
          padding: const EdgeInsets.all(KubusSpacing.md),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          showBorder: false,
          backgroundColor: cardGlassStyle.tintColor,
          blurSigma: cardGlassStyle.blurSigma,
          fallbackMinOpacity: cardGlassStyle.fallbackMinOpacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                color: daoAccent.withValues(alpha: 0.18),
                width: KubusSizes.hairline,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: KubusSizes.sidebarActionIconBox,
                        height: KubusSizes.sidebarActionIconBox,
                        decoration: BoxDecoration(
                          color: daoAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                        ),
                        child: Icon(
                          Icons.how_to_vote,
                          color: daoAccent,
                          size: KubusSizes.sidebarActionIcon,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.daoHubStatYourVotingPowerLabel,
                              style:
                                  KubusTextStyles.actionTileSubtitle.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.62),
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xxs),
                            Text(
                              '${votingPower.toStringAsFixed(2)} KUB8',
                              style: KubusTextStyles.sectionTitle.copyWith(
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
                      padding: const EdgeInsets.all(
                          KubusSpacing.md - KubusSpacing.xs),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
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
                              style:
                                  KubusTextStyles.actionTileSubtitle.copyWith(
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, _) {
        final l10n = AppLocalizations.of(context)!;
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
                  size: KubusChromeMetrics.heroIcon - KubusSpacing.xs,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  l10n.homeNoRecentActivityTitle,
                  style: KubusTextStyles.actionTileSubtitle.copyWith(
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
            return Padding(
              padding: const EdgeInsets.only(
                  bottom: KubusSpacing.md - KubusSpacing.xs),
              child: LiquidGlassCard(
                padding:
                    const EdgeInsets.all(KubusSpacing.md - KubusSpacing.xs),
                borderRadius: BorderRadius.circular(KubusRadius.md),
                showBorder: false,
                backgroundColor: activityGlassStyle.tintColor,
                blurSigma: activityGlassStyle.blurSigma,
                fallbackMinOpacity: activityGlassStyle.fallbackMinOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.14),
                      width: KubusSizes.hairline,
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(KubusSpacing.md - KubusSpacing.xs),
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
                                style: KubusTextStyles.actionTileTitle.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
