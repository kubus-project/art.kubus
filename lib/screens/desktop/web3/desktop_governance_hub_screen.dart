import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/dao.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/kubus_color_roles.dart';
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
    super.dispose();
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
                // Left: Mobile governance hub view (wrapped)
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
                    child: const GovernanceHub(),
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
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Text(
            'DAO Overview',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Voting power card
          _buildVotingPowerCard(themeProvider),
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
          _buildQuickActionTile(
            'Create Proposal',
            'Submit new governance idea',
            Icons.add_box_outlined,
            Theme.of(context).colorScheme.primary,
            () {
              // Handled by mobile view's create proposal tab
            },
          ),
          _buildQuickActionTile(
            'Vote on Proposals',
            'Participate in governance',
            Icons.how_to_vote_outlined,
            const Color(0xFF4ECDC4),
            () {
              // Navigate to proposals tab in mobile view
            },
          ),
          _buildQuickActionTile(
            'Analytics',
            'View DAO performance',
            Icons.analytics_outlined,
            const Color(0xFFFF6B6B),
            () {
              DesktopShellScope.of(context)?.pushScreen(
                DesktopSubScreen(
                  title: 'DAO Analytics',
                  child: const DAOAnalytics(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // DAO Stats
          Text(
            'DAO Statistics',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildDAOStatsGrid(themeProvider),
          const SizedBox(height: 24),

          // Recent governance activity
          Text(
            'Recent Activity',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentActivity(themeProvider),
        ],
      ),
    );
  }

  Widget _buildVotingPowerCard(ThemeProvider themeProvider) {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, _) {
        final daoAccent = KubusColorRoles.of(context).web3DaoAccent;
        final votingPower = web3Provider.kub8Balance;
        final hasVotingPower = votingPower > 0;

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
                      color: daoAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.how_to_vote,
                      color: daoAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Voting Power',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${votingPower.toStringAsFixed(2)} KUB8',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!hasVotingPower) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Acquire KUB8 tokens to participate in governance',
                          style: GoogleFonts.inter(
                            fontSize: 12,
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

  Widget _buildQuickActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
                    'Members',
                    totalMembers.toString(),
                    Icons.people_outline,
                    const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Treasury',
                    '${(daoProvider.treasuryOnChainBalance ?? 0).toStringAsFixed(2)} KUB8',
                    Icons.account_balance_outlined,
                    Colors.green,
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
    return Consumer<DAOProvider>(
      builder: (context, daoProvider, _) {
        final recentProposals = daoProvider.proposals.take(3).toList();

        if (recentProposals.isEmpty) {
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
                  Icons.inbox_outlined,
                  size: 40,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent activity',
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

        return Column(
          children: recentProposals.map((proposal) {
            final scheme = Theme.of(context).colorScheme;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: proposal.status == ProposalStatus.active
                          ? scheme.tertiary
                          : scheme.onSurface.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposal.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          proposal.status.name,
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
