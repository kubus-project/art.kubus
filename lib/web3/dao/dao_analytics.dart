import "package:flutter/material.dart";
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/themeprovider.dart';

class DAOAnalytics extends StatelessWidget {
  const DAOAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'DAO Analytics',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Consumer<DAOProvider>(
        builder: (context, daoProvider, child) {
          final proposals = daoProvider.proposals;
          final active = daoProvider.getActiveProposals().length;
          final votes = daoProvider.votes.length;
          final delegates = daoProvider.delegates;
          final transactions = daoProvider.transactions;
          final analytics = daoProvider.getDAOAnalytics();
          final treasuryAmount = analytics['treasuryAmount'] as double? ?? 0.0;
          final inflow = transactions.where((tx) => tx.amount >= 0).fold<double>(0, (sum, tx) => sum + tx.amount);
          final outflow = transactions.where((tx) => tx.amount < 0).fold<double>(0, (sum, tx) => sum + tx.amount.abs());
          final avgVotingPower = delegates.isEmpty
              ? 0.0
              : delegates.fold<int>(0, (sum, d) => sum + d.votingPower) / delegates.length;

          final byType = <String, int>{};
          for (final p in proposals) {
            byType.update(p.type.name, (v) => v + 1, ifAbsent: () => 1);
          }

          final byStatus = <String, int>{};
          for (final p in proposals) {
            byStatus.update(p.status.name, (v) => v + 1, ifAbsent: () => 1);
          }

          return RefreshIndicator(
            onRefresh: daoProvider.refreshData,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _metricsGrid(context, daoProvider, active: active, votes: votes, avgVotingPower: avgVotingPower),
                const SizedBox(height: 20),
                _sectionCard(
                  context,
                  title: 'Proposals by Type',
                  child: Column(
                    children: byType.entries
                        .map((entry) => _rowStat(context, entry.key, entry.value.toString()))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Proposals by Status',
                  child: Column(
                    children: byStatus.entries
                        .map((entry) => _rowStat(context, entry.key, entry.value.toString()))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Treasury',
                  child: Column(
                    children: [
                      _rowStat(context, 'Total', '${treasuryAmount.toStringAsFixed(2)} KUB8'),
                      const SizedBox(height: 8),
                      _rowStat(context, 'Inflow', '${inflow.toStringAsFixed(2)} KUB8'),
                      const SizedBox(height: 8),
                      _rowStat(context, 'Outflow', '${outflow.toStringAsFixed(2)} KUB8'),
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
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _metricCard(context, 'Total Proposals', daoProvider.proposals.length.toString(), Icons.how_to_vote, accent),
        _metricCard(context, 'Active Proposals', active.toString(), Icons.schedule, Colors.green),
        _metricCard(context, 'Votes Cast', votes.toString(), Icons.ballot, Colors.blueGrey),
        _metricCard(context, 'Avg Voting Power', '${avgVotingPower.toStringAsFixed(0)} KUB8', Icons.account_balance_wallet, Colors.teal),
      ],
    );
  }

  Widget _metricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
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
