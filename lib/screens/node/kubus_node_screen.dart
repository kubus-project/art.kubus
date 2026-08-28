import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/availability_operator_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/node/node_ui.dart';
import 'node_pairing_screen.dart';

/// The kubus Node experience inside art.kubus.
///
/// This screen serves an operator, not a general visitor, so it is allowed to
/// be technical — but it is still part of a cultural platform, and it opens by
/// answering "is my node alright?" rather than by presenting configuration.
///
/// Structure follows the node's own interface: an overview of the four things
/// a node does, then a section per area. Machine states never reach the screen
/// directly; everything passes through [NodeStatePresentation] so the app and
/// the node speak with one voice.
class KubusNodeScreen extends StatefulWidget {
  const KubusNodeScreen({super.key});

  @override
  State<KubusNodeScreen> createState() => _KubusNodeScreenState();
}

enum _NodeSection { overview, archive, spatial, compute, contribution, setup }

class _KubusNodeScreenState extends State<KubusNodeScreen> {
  _NodeSection _section = _NodeSection.overview;
  bool _refreshing = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<KubusNodeProvider>().refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openPairing() async {
    final paired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NodePairingScreen()),
    );
    if (paired == true && mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final node = context.watch<KubusNodeProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_l10n.kubusNodeEntryTitle),
        actions: [
          if (node.isPaired)
            IconButton(
              tooltip: MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel,
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: node.isPaired ? _buildPaired(node, wide) : _buildUnpaired(node),
      ),
    );
  }

  /// Value before configuration. Someone who has never run a node reads what it
  /// is for, not a form.
  Widget _buildUnpaired(KubusNodeProvider node) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding(context),
        vertical: KubusSpacing.lg,
      ),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.kubusNodeEntryTitle,
                style: textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(_l10n.kubusNodeEntrySubtitle, style: textTheme.bodyLarge),
              const SizedBox(height: KubusSpacing.lg),
              for (final feature in [
                _l10n.kubusNodeEntryFeatureArchive,
                _l10n.kubusNodeEntryFeatureSpatial,
                _l10n.kubusNodeEntryFeatureNetwork,
                _l10n.kubusNodeEntryFeatureContribution,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              const SizedBox(height: KubusSpacing.lg),
              FilledButton.icon(
                onPressed: _openPairing,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(_l10n.kubusNodeEntryConnectCta),
              ),
              const SizedBox(height: KubusSpacing.sm),
              TextButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamed('/settings/availability-node/advanced'),
                icon: const Icon(Icons.tune_rounded),
                label: Text(_l10n.kubusNodeAdvancedOperatorSetup),
              ),
              const SizedBox(height: KubusSpacing.lg),
              Text(
                _l10n.kubusNodeReciprocity,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (node.state == KubusNodeConnectionState.error &&
                  node.error != null) ...[
                const SizedBox(height: KubusSpacing.md),
                Text(
                  node.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaired(KubusNodeProvider node, bool wide) {
    final snapshot = node.snapshot;
    final unreachable = node.state == KubusNodeConnectionState.unavailable;

    // A node that cannot be reached still shows its last known state rather
    // than collapsing to an error page.
    final participation = unreachable
        ? NodeStatePresentation.unreachable(_l10n)
        : NodeStatePresentation.participation(
            _l10n,
            snapshot?.participationState ?? 'UNCONFIGURED',
          );

    final sections = _sectionLabels();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          label: _nodeLabel(snapshot),
          description: participation,
        ),
        if (participation.severity == NodeSeverity.attention ||
            participation.severity == NodeSeverity.critical) ...[
          const SizedBox(height: KubusSpacing.md),
          NodeBanner(
            description: participation,
            onAction: () => setState(() => _section = _NodeSection.overview),
          ),
        ],
        const SizedBox(height: KubusSpacing.lg),
        if (!wide) ...[
          _SectionTabs(
            labels: sections,
            selected: _section,
            onChanged: (value) => setState(() => _section = value),
          ),
          const SizedBox(height: KubusSpacing.lg),
        ],
        _buildSection(node, snapshot),
      ],
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: wide
          // Desktop gets a section rail beside the content rather than a
          // single narrow column stranded in the middle of a wide window.
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionRail(
                  labels: sections,
                  selected: _section,
                  onChanged: (value) => setState(() => _section = value),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(KubusSpacing.xl),
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: content,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: _horizontalPadding(context),
                vertical: KubusSpacing.lg,
              ),
              children: [content],
            ),
    );
  }

  Map<_NodeSection, String> _sectionLabels() => {
        _NodeSection.overview: _l10n.kubusNodeOverview,
        _NodeSection.archive: _l10n.kubusNodeArchive,
        _NodeSection.spatial: _l10n.kubusNodeSpatial,
        _NodeSection.compute: _l10n.kubusNodeCompute,
        _NodeSection.contribution: _l10n.kubusNodeContribution,
        _NodeSection.setup: _l10n.kubusNodeSecuritySetup,
      };

  String _nodeLabel(KubusNodeSnapshot? snapshot) {
    final info = snapshot?.info ?? const {};
    final label = (info['label'] ?? '').toString().trim();
    return label.isEmpty ? _l10n.kubusNodeEntryTitle : label;
  }

  Widget _buildSection(KubusNodeProvider node, KubusNodeSnapshot? snapshot) {
    switch (_section) {
      case _NodeSection.overview:
        return _OverviewSection(
          node: node,
          onOpen: (section) => setState(() => _section = section),
        );
      case _NodeSection.archive:
        return _ArchiveSection(snapshot: snapshot);
      case _NodeSection.spatial:
        return _SpatialSection(node: node);
      case _NodeSection.compute:
        return _ComputeSection(node: node);
      case _NodeSection.contribution:
        return const _ContributionSection();
      case _NodeSection.setup:
        return _SetupSection(node: node, onPair: _openPairing);
    }
  }
}

double _horizontalPadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width > 900 ? KubusSpacing.xxl : KubusSpacing.lg;

class _Header extends StatelessWidget {
  const _Header({required this.label, required this.description});

  final String label;
  final NodeStateDescription description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              label,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            NodeStatusLabel(
              label: description.title,
              severity: description.severity,
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          description.body,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final Map<_NodeSection, String> labels;
  final _NodeSection selected;
  final ValueChanged<_NodeSection> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in labels.entries)
              Padding(
                padding: const EdgeInsets.only(right: KubusSpacing.sm),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == selected,
                  onSelected: (_) => onChanged(entry.key),
                ),
              ),
          ],
        ),
      );
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final Map<_NodeSection, String> labels;
  final _NodeSection selected;
  final ValueChanged<_NodeSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 208,
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xl),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
                vertical: KubusSpacing.xxs,
              ),
              child: _RailButton(
                label: entry.value,
                selected: entry.key == selected,
                onTap: () => onChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four conceptual areas, at a glance. Not four identical dashboard tiles:
/// each carries only the figures that help decide something.
class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.node, required this.onOpen});

  final KubusNodeProvider node;
  final ValueChanged<_NodeSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = node.snapshot;
    final worker = snapshot?.worker ?? const {};
    final storage = snapshot?.storage ?? const {};
    final workerState = NodeStatePresentation.worker(l10n, worker);
    final gpu = NodeStatePresentation.gpuLabel(worker);
    final sharing = node.computeSettings['enabled'] == true &&
        node.computeSettings['paused'] != true;

    final publicBytes =
        num.tryParse((storage['publicReplicaBytes'] ?? 0).toString()) ?? 0;

    return Column(
      children: [
        NodePanel(
          title: l10n.kubusNodeArchiveTitle,
          trailing: TextButton(
            onPressed: () => onOpen(_NodeSection.archive),
            child: Text(l10n.kubusNodeArchive),
          ),
          child: NodeMetricRow(
            metrics: [
              NodeMetric(
                label: l10n.kubusNodeStoredLabel,
                value: NodeStatePresentation.formatBytes(publicBytes),
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        NodePanel(
          title: l10n.kubusNodeSpatialTitle,
          trailing: NodeStatusLabel(
            label: workerState.title,
            severity: workerState.severity,
            dense: true,
          ),
          child: NodeMetricRow(
            metrics: [
              if (gpu != null)
                NodeMetric(
                  label: l10n.kubusNodeGpu,
                  value: gpu,
                  isText: true,
                ),
              NodeMetric(
                label: l10n.kubusNodeRunningJobs,
                value: '${snapshot?.runningJobs ?? 0}',
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        NodePanel(
          title: l10n.kubusNodeComputeTitle,
          trailing: NodeStatusLabel(
            label: sharing ? l10n.kubusNodeOnline : l10n.kubusNodeOffline,
            // Sharing is optional, so "off" is a neutral choice, not a fault.
            severity: sharing ? NodeSeverity.good : NodeSeverity.neutral,
            dense: true,
          ),
          child: Text(
            l10n.kubusNodeComputeBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        const _ContributionSection(compact: true),
        const SizedBox(height: KubusSpacing.lg),
        Text(
          l10n.kubusNodeReciprocity,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({required this.snapshot});

  final KubusNodeSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final storage = snapshot?.storage ?? const {};
    final publicBytes =
        (num.tryParse((storage['publicReplicaBytes'] ?? 0).toString()) ?? 0)
            .toDouble();
    final privateBytes =
        (num.tryParse((storage['privateCaptureBytes'] ?? 0).toString()) ?? 0)
            .toDouble();
    final repoBytes =
        (num.tryParse((storage['repoBytes'] ?? 0).toString()) ?? 0).toDouble();
    final maxBytes =
        (num.tryParse((storage['storageMaxBytes'] ?? 0).toString()) ?? 0)
            .toDouble();

    final otherBytes = (repoBytes - publicBytes).clamp(0, double.infinity);
    final used = publicBytes + privateBytes + otherBytes;
    final available = maxBytes > 0 ? (maxBytes - used).clamp(0, maxBytes) : 0.0;

    // The network's verified view of this node, where the app has it. Coverage
    // is only meaningful once the node has been asked to keep something, so it
    // is omitted rather than shown as a discouraging 0%.
    final status = context.watch<AvailabilityOperatorProvider>().nodeStatus;
    final tracked = status?.publicCidsTracked ?? 0;
    final pinned = status?.publicCidsPinned ?? 0;

    return Column(
      children: [
        NodePanel(
          title: l10n.kubusNodeArchive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NodeMetricRow(
                metrics: [
                  NodeMetric(
                    label: l10n.kubusNodeStoredLabel,
                    value: NodeStatePresentation.formatBytes(publicBytes),
                  ),
                  if (tracked > 0)
                    NodeMetric(
                      label: l10n.kubusNodeCoverageLabel,
                      value: NodeStatePresentation.formatPercent(
                        pinned / tracked,
                      ),
                      detail: '$pinned / $tracked',
                    ),
                  if (pinned > 0)
                    NodeMetric(
                      label: l10n.kubusNodePublicRecordsLabel,
                      value: '$pinned',
                    ),
                ],
              ),
              if (used > 0) ...[
                const SizedBox(height: KubusSpacing.lg),
                NodeCapacityBar(
                  segments: [
                    if (publicBytes > 0)
                      NodeCapacitySegment(
                        label: l10n.kubusNodeArchive,
                        bytes: publicBytes,
                        tone: NodeCapacityTone.public,
                      ),
                    if (privateBytes > 0)
                      NodeCapacitySegment(
                        label: l10n.kubusNodeLocalCaptures,
                        bytes: privateBytes,
                        tone: NodeCapacityTone.private,
                      ),
                    if (otherBytes > 0)
                      NodeCapacitySegment(
                        label: l10n.kubusNodeEntryTitle,
                        bytes: otherBytes.toDouble(),
                        tone: NodeCapacityTone.other,
                      ),
                    if (available > 0)
                      NodeCapacitySegment(
                        label: l10n.kubusNodeAvailable,
                        bytes: available.toDouble(),
                        tone: NodeCapacityTone.other,
                        isRemainder: true,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: KubusSpacing.md),
              Text(
                l10n.kubusNodeArchiveBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpatialSection extends StatelessWidget {
  const _SpatialSection({required this.node});

  final KubusNodeProvider node;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = node.snapshot;
    final worker = snapshot?.worker ?? const {};
    final state = NodeStatePresentation.worker(l10n, worker);
    final gpu = NodeStatePresentation.gpuLabel(worker);
    final captures =
        int.tryParse((snapshot?.status['captures'] ?? 0).toString()) ?? 0;

    return Column(
      children: [
        NodePanel(
          title: l10n.kubusNodeSpatial,
          trailing: NodeStatusLabel(
            label: state.title,
            severity: state.severity,
            dense: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: KubusSpacing.md),
              NodeMetricRow(
                metrics: [
                  if (gpu != null)
                    NodeMetric(
                      label: l10n.kubusNodeGpu,
                      value: gpu,
                      isText: true,
                    ),
                  NodeMetric(
                    label: l10n.kubusNodeRunningJobs,
                    value: '${snapshot?.runningJobs ?? 0}',
                  ),
                  NodeMetric(
                    label: l10n.kubusNodeLocalCaptures,
                    value: '$captures',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (captures == 0) ...[
          const SizedBox(height: KubusSpacing.md),
          NodePanel(
            child: NodeEmptyState(
              icon: Icons.view_in_ar_outlined,
              title: l10n.kubusNodeEmptyCapturesTitle,
              body: l10n.kubusNodeEmptyCapturesBody,
            ),
          ),
        ],
      ],
    );
  }
}

class _ComputeSection extends StatefulWidget {
  const _ComputeSection({required this.node});

  final KubusNodeProvider node;

  @override
  State<_ComputeSection> createState() => _ComputeSectionState();
}

class _ComputeSectionState extends State<_ComputeSection> {
  bool _busy = false;

  Future<void> _update(Map<String, dynamic> patch) async {
    setState(() => _busy = true);
    try {
      await widget.node.updateComputeSettings(patch);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.node.computeSettings;
    final available = widget.node.computeSettingsAvailable;
    final enabled = settings['enabled'] == true;

    return Column(
      children: [
        NodePanel(
          title: l10n.kubusNodeComputeTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.kubusNodeVerifiedComputeCopy,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: KubusSpacing.md),
              // Archive participation and GPU sharing are deliberately separate
              // controls: one is required, the other is a choice.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                onChanged: !available || _busy
                    ? null
                    : (value) => unawaited(_update({'enabled': value})),
                title: Text(l10n.kubusNodeOfferGpu),
                subtitle: Text(l10n.kubusNodeOfferGpuBody),
              ),
              if (enabled)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings['paused'] == true,
                  onChanged: !available || _busy
                      ? null
                      : (value) => unawaited(_update({'paused': value})),
                  title: Text(l10n.kubusNodePauseRemoteJobs),
                ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        NodePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.kubusNodePrivacyBody,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (enabled) ...[
                const SizedBox(height: KubusSpacing.sm),
                NodeDisclosure(
                  title: l10n.kubusNodeAdvancedDetails,
                  children: [
                    NodeDetailRow(
                      label: l10n.kubusNodeMaxRemoteJobs,
                      value: '${settings['maxConcurrency'] ?? 1}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Contribution, not a wallet. No fiat, no chart, no "earnings".
class _ContributionSection extends StatelessWidget {
  const _ContributionSection({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = context.watch<AvailabilityOperatorProvider>().nodeStatus;

    final archive = status?.archivePendingKub8 ?? 0;
    final compute = status?.computePendingKub8 ?? 0;
    final total = archive + compute;

    if (total <= 0) {
      return NodePanel(
        title: l10n.kubusNodeContribution,
        child: NodeEmptyState(
          title: l10n.kubusNodeEmptyContributionTitle,
          body: l10n.kubusNodeEmptyContributionBody,
        ),
      );
    }

    return NodePanel(
      title: l10n.kubusNodeContribution,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NodeMetricRow(
            metrics: [
              NodeMetric(
                label: l10n.kubusNodeArchiveContribution,
                value: '${NodeStatePresentation.formatKub8(archive)} KUB8',
              ),
              NodeMetric(
                label: l10n.kubusNodeComputeContribution,
                value: '${NodeStatePresentation.formatKub8(compute)} KUB8',
              ),
              NodeMetric(
                label: l10n.kubusNodePendingTotal,
                value: '${NodeStatePresentation.formatKub8(total)} KUB8',
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          Text(
            l10n.kubusNodeSettlementPending,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (!compact) ...[
            const SizedBox(height: KubusSpacing.sm),
            NodeDisclosure(
              title: l10n.kubusNodeHowCalculated,
              children: [
                Text(l10n.kubusNodeVerifiedArchiveCopy,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: KubusSpacing.sm),
                Text(l10n.kubusNodeVerifiedComputeCopy,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Everyday controls first; identifiers and destructive actions kept apart.
class _SetupSection extends StatelessWidget {
  const _SetupSection({required this.node, required this.onPair});

  final KubusNodeProvider node;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = node.snapshot;
    final info = snapshot?.info ?? const {};
    final network = snapshot?.network ?? const {};
    final peerId = (network['peerId'] ?? '').toString();
    final nodeId = (network['nodeId'] ?? info['nodeId'] ?? '').toString();

    return Column(
      children: [
        NodePanel(
          title: l10n.kubusNodePairTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.kubusNodePairBody,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: KubusSpacing.md),
              Wrap(
                spacing: KubusSpacing.sm,
                runSpacing: KubusSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPair,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(l10n.kubusNodePairAction),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        NodePanel(
          child: NodeDisclosure(
            title: l10n.kubusNodeAdvancedDetails,
            children: [
              if (nodeId.isNotEmpty)
                NodeIdentifierRow(
                  label: l10n.kubusNodeEntryTitle,
                  value: nodeId,
                ),
              if (peerId.isNotEmpty)
                NodeIdentifierRow(
                  label: 'Peer ID',
                  value: peerId,
                ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        // Disconnecting is separated from everyday controls rather than sitting
        // among them.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => unawaited(_confirmUnpair(context, node)),
            icon: const Icon(Icons.link_off_rounded),
            label: Text(l10n.kubusNodeUnpairAction),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUnpair(
    BuildContext context,
    KubusNodeProvider node,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(l10n.kubusNodeUnpairAction),
        content: Text(l10n.kubusNodeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.kubusNodeUnpairAction),
          ),
        ],
      ),
    );
    if (confirmed == true) await node.unpair();
  }
}
