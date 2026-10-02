import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../features/web3/web3_capabilities.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../desktop_shell.dart';
import '../../web3/dao/governance_hub.dart';
import '../../web3/dao/dao_analytics.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/common/kubus_stat_card.dart';
import '../../../widgets/dao/dao_proposal_status.dart';

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
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    const sectionGap = KubusSpacing.lg;
    const sectionHeaderGap = KubusSpacing.sm + KubusSpacing.xs;
    const blockGap = KubusSpacing.md + KubusSpacing.xs;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.ground,
        border: Border(left: BorderSide(color: roles.rule)),
      ),
      child: Material(
        type: MaterialType.transparency,
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

  /// Voting power is the KUB8 the backend snapshots at vote time; with
  /// none, the wallet cannot vote (the backend rejects zero-power votes).
  Widget _buildVotingPowerCard() {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, _) {
        final l10n = AppLocalizations.of(context)!;
        final roles = KubusColorRoles.of(context);
        final votingPower = web3Provider.kub8Balance;
        final amount = votingPower.toStringAsFixed(2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KubusStatCard(
              title: l10n.daoHubStatYourVotingPowerLabel,
              value: '$amount KUB8',
              semanticsLabel: l10n.walletBalanceAmountSemantic(
                l10n.daoHubStatYourVotingPowerLabel,
                amount,
                'KUB8',
              ),
              minHeight: 64,
            ),
            if (votingPower <= 0) ...[
              const SizedBox(height: KubusSpacing.sm),
              Text(
                l10n.daoNotEligibleBody,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final roles = KubusColorRoles.of(context);
        final recentProposals = daoProvider.proposals.take(3).toList();

        if (recentProposals.isEmpty) {
          return Text(
            l10n.homeNoRecentActivityTitle,
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foregroundMuted,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final proposal in recentProposals)
              Container(
                padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: roles.rule)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.actionTileTitle.copyWith(
                        color: roles.foreground,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xxs),
                    KubusStatusText(
                      label: daoProposalStatusLabel(l10n, proposal.status),
                      tone: daoProposalStatusTone(proposal.status),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
