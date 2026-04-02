import "package:flutter/material.dart";
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/dao_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../widgets/charts/stats_interactive_bar_chart.dart';

class DAOAnalytics extends StatelessWidget {
  const DAOAnalytics({super.key, this.embedded = false});

  final bool embedded;

  List<StatsBarEntry> _categoryEntries(Map<String, int> data) {
    final sorted = data.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return List<StatsBarEntry>.generate(
      sorted.length,
      (i) => StatsBarEntry(
        bucketStart: DateTime.utc(1970, 1, 1).add(Duration(days: i)),
        value: sorted[i].value,
      ),
      growable: false,
    );
  }

  List<String> _categoryLabels(Map<String, int> data) {
    final sorted = data.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: Text(
                l10n.daoAnalyticsTitle,
                style: KubusTextStyles.mobileAppBarTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
      body: Consumer<DAOProvider>(
        builder: (context, daoProvider, child) {
          final scheme = Theme.of(context).colorScheme;
          final proposals = daoProvider.proposals;
          final active = daoProvider.getActiveProposals().length;
          final votes = daoProvider.votes.length;
          final delegates = daoProvider.delegates;
          final transactions = daoProvider.transactions;
          final analytics = daoProvider.getDAOAnalytics();
          final treasuryAmount = analytics['treasuryAmount'] as double? ?? 0.0;
          final inflow = transactions
              .where((tx) => tx.amount >= 0)
              .fold<double>(0, (sum, tx) => sum + tx.amount);
          final outflow = transactions
              .where((tx) => tx.amount < 0)
              .fold<double>(0, (sum, tx) => sum + tx.amount.abs());
          final avgVotingPower = delegates.isEmpty
              ? 0.0
              : delegates.fold<int>(0, (sum, d) => sum + d.votingPower) /
                  delegates.length;

          final byType = <String, int>{};
          for (final p in proposals) {
            byType.update(p.type.name, (v) => v + 1, ifAbsent: () => 1);
          }

          final byStatus = <String, int>{};
          for (final p in proposals) {
            byStatus.update(p.status.name, (v) => v + 1, ifAbsent: () => 1);
          }

          final typeEntries = _categoryEntries(byType);
          final typeLabels = _categoryLabels(byType);
          final statusEntries = _categoryEntries(byStatus);
          final statusLabels = _categoryLabels(byStatus);

          final treasuryMap = <String, int>{
            l10n.daoTreasuryTotalLabel: treasuryAmount.round(),
            l10n.daoTreasuryInflowLabel: inflow.round(),
            l10n.daoTreasuryOutflowLabel: outflow.round(),
          };
          final treasuryEntries = _categoryEntries(treasuryMap);
          final treasuryLabels = _categoryLabels(treasuryMap);

          return RefreshIndicator(
            onRefresh: daoProvider.refreshData,
            child: ListView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              children: [
                _metricsGrid(context, daoProvider,
                    active: active,
                    votes: votes,
                    avgVotingPower: avgVotingPower),
                const SizedBox(height: 20),
                _sectionCard(
                  context,
                  title: l10n.daoAnalyticsProposalsByTypeTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: byType.entries.isEmpty
                        ? [
                            Text(
                              l10n.daoAnalyticsNoProposalsYetLabel,
                              style: KubusTypography.inter(
                                fontSize: 13,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ]
                        : [
                            SizedBox(
                              height: 180,
                              child: StatsInteractiveBarChart(
                                entries: typeEntries,
                                xLabels: typeLabels,
                                barColor: scheme.primary,
                                gridColor:
                                    scheme.onSurface.withValues(alpha: 0.12),
                                height: 180,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...byType.entries.map((entry) => _rowStat(
                                context, entry.key, entry.value.toString())),
                          ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.daoAnalyticsProposalsByStatusTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: byStatus.entries.isEmpty
                        ? [
                            Text(
                              l10n.daoAnalyticsNoProposalsYetLabel,
                              style: KubusTypography.inter(
                                fontSize: 13,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ]
                        : [
                            SizedBox(
                              height: 180,
                              child: StatsInteractiveBarChart(
                                entries: statusEntries,
                                xLabels: statusLabels,
                                barColor: scheme.secondary,
                                gridColor:
                                    scheme.onSurface.withValues(alpha: 0.12),
                                height: 180,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...byStatus.entries.map((entry) => _rowStat(
                                context, entry.key, entry.value.toString())),
                          ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.daoHubTabTreasury,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 180,
                        child: StatsInteractiveBarChart(
                          entries: treasuryEntries,
                          xLabels: treasuryLabels,
                          barColor:
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .accentColor,
                          gridColor: scheme.onSurface.withValues(alpha: 0.12),
                          height: 180,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _rowStat(context, l10n.daoTreasuryTotalLabel,
                          '${treasuryAmount.toStringAsFixed(2)} KUB8'),
                      const SizedBox(height: 8),
                      _rowStat(context, l10n.daoTreasuryInflowLabel,
                          '${inflow.toStringAsFixed(2)} KUB8'),
                      const SizedBox(height: 8),
                      _rowStat(context, l10n.daoTreasuryOutflowLabel,
                          '${outflow.toStringAsFixed(2)} KUB8'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricsGrid(
    BuildContext context,
    DAOProvider daoProvider, {
    required int active,
    required int votes,
    required double avgVotingPower,
  }) {
    final accent =
        Provider.of<ThemeProvider>(context, listen: false).accentColor;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _metricCard(context, 'Total Proposals',
            daoProvider.proposals.length.toString(), Icons.how_to_vote, accent),
        _metricCard(context, 'Active Proposals', active.toString(),
            Icons.schedule, Colors.green),
        _metricCard(context, 'Votes Cast', votes.toString(), Icons.ballot,
            Colors.blueGrey),
        _metricCard(
            context,
            'Avg Voting Power',
            '${avgVotingPower.toStringAsFixed(0)} KUB8',
            Icons.account_balance_wallet,
            Colors.teal),
      ],
    );
  }

  Widget _metricCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: KubusTypography.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            title,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onPrimary
                .withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: KubusTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _rowStat(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: KubusTypography.inter(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
          ),
          Text(
            value,
            style: KubusTypography.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
