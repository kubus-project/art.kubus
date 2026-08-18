import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/availability_operator_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/glass_components.dart';

class AvailabilityNodeOperatorScreen extends StatelessWidget {
  const AvailabilityNodeOperatorScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AvailabilityNodeOperatorBody();
}

class _AvailabilityNodeOperatorBody extends StatefulWidget {
  const _AvailabilityNodeOperatorBody();

  @override
  State<_AvailabilityNodeOperatorBody> createState() =>
      _AvailabilityNodeOperatorBodyState();
}

class _AvailabilityNodeOperatorBodyState
    extends State<_AvailabilityNodeOperatorBody> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _pairingController = TextEditingController();
  int _expiresInDays = 90;
  int _section = 0;
  String? _loadedWallet;
  bool _initializedDefaultLabel = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _labelController.dispose();
    _pairingController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedDefaultLabel && _labelController.text.trim().isEmpty) {
      _labelController.text = l10n.availabilityNodeDefaultLabel;
      _labelController.selection = TextSelection.collapsed(
        offset: _labelController.text.length,
      );
      _initializedDefaultLabel = true;
    }
    final wallet = _resolveWallet(listen: true);
    if (wallet.isNotEmpty && wallet != _loadedWallet) {
      _loadedWallet = wallet;
      unawaited(
        context
            .read<AvailabilityOperatorProvider>()
            .loadTokens(walletAddress: wallet)
            .catchError((_) {}),
      );
    }
  }

  String _resolveWallet({bool listen = false}) {
    final walletProvider = Provider.of<WalletProvider>(
      context,
      listen: listen,
    );
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: listen,
    );
    return (walletProvider.currentWalletAddress ??
            profileProvider.currentUser?.walletAddress ??
            '')
        .trim();
  }

  Future<void> _copyText(String value, String toast) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _createToken() async {
    final wallet = _resolveWallet();
    if (wallet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.availabilityNodeConnectWalletToast)));
      return;
    }

    final walletProvider = context.read<WalletProvider>();
    final signed = await walletProvider.ensureBackendSessionForActiveSigner(
      walletAddress: wallet,
    );
    if (!mounted) return;
    if (!signed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.availabilityNodeSigningRequiredToast)),
      );
      return;
    }

    try {
      final created =
          await context.read<AvailabilityOperatorProvider>().createToken(
                label: _labelController.text,
                walletAddress: wallet,
                expiresInDays: _expiresInDays,
              );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final snippet = context
              .read<AvailabilityOperatorProvider>()
              .buildEnvSnippet(token: created.token, walletAddress: wallet);
          return AlertDialog(
            title: Text(l10n.availabilityNodeCreatedTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.availabilityNodeCreatedBody),
                    const SizedBox(height: KubusSpacing.md),
                    _CodeBlock(text: created.token),
                    const SizedBox(height: KubusSpacing.md),
                    Text(
                      l10n.availabilityNodeEnvSnippetLabel,
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: KubusSpacing.md),
                    _CodeBlock(text: snippet),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => unawaited(
                  _copyText(
                    created.token,
                    l10n.availabilityNodeTokenCopiedToast,
                  ),
                ),
                icon: const Icon(Icons.copy),
                label: Text(l10n.availabilityNodeCopyTokenButton),
              ),
              FilledButton.icon(
                onPressed: () {
                  unawaited(_copyText(
                    snippet,
                    l10n.availabilityNodeSnippetCopiedToast,
                  ));
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.content_paste),
                label: Text(l10n.availabilityNodeCopySnippetButton),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      context.read<AvailabilityOperatorProvider>().clearCreatedToken();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${l10n.availabilityNodeCreateFailedToast}: $e')),
      );
    }
  }

  Future<void> _revokeToken(AvailabilityOperatorTokenRecord token) async {
    final wallet = _resolveWallet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.availabilityNodeRevokeTitle),
        content: Text(l10n.availabilityNodeRevokeBody(token.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AvailabilityOperatorProvider>().revokeToken(
          tokenId: token.id,
          walletAddress: wallet,
        );
  }

  Future<void> _pairLocalNode() async {
    try {
      final decoded = jsonDecode(_pairingController.text.trim());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid pairing payload');
      }
      await context.read<KubusNodeProvider>().pair(
            KubusNodePairingPayload.fromJson(decoded),
          );
      if (!mounted) return;
      _pairingController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.kubusNodePairedToast)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.kubusNodePairFailed}: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localNode = context.watch<KubusNodeProvider>();
    final operator = context.watch<AvailabilityOperatorProvider>();
    final sections = <String>[
      l10n.kubusNodeOverview,
      l10n.kubusNodeArchive,
      l10n.kubusNodeSpatial,
      l10n.kubusNodeCompute,
      l10n.kubusNodeRewards,
      l10n.kubusNodeSecuritySetup,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.availabilityNodeTitle)),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width > 900
              ? KubusSpacing.xxl
              : KubusSpacing.lg,
          vertical: KubusSpacing.lg,
        ),
        children: [
          const _InfoPanel(),
          const SizedBox(height: KubusSpacing.lg),
          _LocalNodePanel(provider: localNode),
          const SizedBox(height: KubusSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: [
                for (var index = 0; index < sections.length; index++)
                  ButtonSegment(value: index, label: Text(sections[index])),
              ],
              selected: {_section},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          if (_section == 0) _NodeStatusPanel(status: operator.nodeStatus),
          if (_section == 1)
            _ArchivePanel(
              local: localNode.snapshot,
              network: operator.nodeStatus,
            ),
          if (_section == 2) _SpatialPanel(provider: localNode),
          if (_section == 3) _ComputePanel(provider: localNode),
          if (_section == 4) _RewardsPanel(status: operator.nodeStatus),
          if (_section == 5) ...[
            _PairingPanel(
              controller: _pairingController,
              provider: localNode,
              onPair: _pairLocalNode,
            ),
            const SizedBox(height: KubusSpacing.lg),
            ExpansionTile(
              title: Text(l10n.kubusNodeAdvancedOperatorSetup),
              subtitle: Text(l10n.kubusNodeAdvancedOperatorSetupBody),
              childrenPadding: const EdgeInsets.only(top: KubusSpacing.sm),
              children: [
                GlassSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(KubusSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.availabilityNodeCreateTitle,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: KubusSpacing.sm),
                        TextField(
                          controller: _labelController,
                          decoration: InputDecoration(
                              labelText: l10n.availabilityNodeLabel),
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        DropdownButtonFormField<int>(
                          initialValue: _expiresInDays,
                          decoration: InputDecoration(
                              labelText: l10n.availabilityNodeExpiry),
                          items: const [30, 90, 180, 365]
                              .map((days) => DropdownMenuItem<int>(
                                    value: days,
                                    child: Text(
                                      l10n.availabilityNodeExpiryDaysOption(
                                          days),
                                    ),
                                  ))
                              .toList(growable: false),
                          onChanged: operator.isLoading
                              ? null
                              : (value) => setState(
                                    () => _expiresInDays = value ?? 90,
                                  ),
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        FilledButton.icon(
                          onPressed: operator.isLoading ? null : _createToken,
                          icon: operator.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: InlineLoading(tileSize: 4),
                                )
                              : const Icon(Icons.vpn_key_outlined),
                          label: Text(l10n.commonCreate),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
                Text(l10n.availabilityNodeExistingTokensTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: KubusSpacing.sm),
                if (operator.tokens.isEmpty)
                  Text(
                    l10n.availabilityNodeEmptyState,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  ...operator.tokens.map(
                    (token) => Card(
                      child: ListTile(
                        leading: Icon(
                          token.status == 'active'
                              ? Icons.check_circle_outline
                              : Icons.block,
                          color: token.status == 'active'
                              ? AppColorUtils.greenAccent
                              : scheme.error,
                        ),
                        title: Text(token.label.isEmpty
                            ? token.tokenPrefix
                            : token.label),
                        subtitle: Text(
                          _buildTokenSubtitle(token),
                        ),
                        trailing: token.status == 'active'
                            ? IconButton(
                                tooltip: l10n.commonDelete,
                                onPressed: operator.isLoading
                                    ? null
                                    : () => unawaited(_revokeToken(token)),
                                icon: const Icon(Icons.delete_outline),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return date.toLocal().toIso8601String().split('.').first;
  }

  String _buildTokenSubtitle(AvailabilityOperatorTokenRecord token) {
    final parts = <String>[
      token.tokenPrefix,
      token.status,
      '${l10n.availabilityNodeExpiresLabel}: ${_formatDate(token.expiresAt)}',
    ];
    if (token.lastUsedAt != null) {
      parts.add(
        '${l10n.availabilityNodeLastUsedLabel}: ${_formatDate(token.lastUsedAt)}',
      );
    }
    return parts.join(' - ');
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.kubusNodeHeroTitle,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: KubusSpacing.sm),
            Text(l10n.kubusNodeHeroBody),
            const SizedBox(height: KubusSpacing.md),
            Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(child: Text(l10n.kubusNodePrivacyBody)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalNodePanel extends StatelessWidget {
  const _LocalNodePanel({required this.provider});
  final KubusNodeProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = provider.snapshot;
    final paired = provider.isPaired;
    final online = provider.state == KubusNodeConnectionState.paired;
    final scheme = Theme.of(context).colorScheme;
    final participation = snapshot?.participationState ?? 'UNCONFIGURED';
    final participationLabel = switch (participation) {
      'CONTRIBUTING' => l10n.kubusNodeParticipationContributing,
      'DEGRADED' => l10n.kubusNodeParticipationDegraded,
      'LOCKED' => l10n.kubusNodeParticipationLocked,
      _ => online ? l10n.kubusNodeOnline : l10n.kubusNodeOffline,
    };
    return GlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (online ? AppColorUtils.greenAccent : scheme.outline)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Icon(
                Icons.dns_outlined,
                color: online ? AppColorUtils.greenAccent : scheme.outline,
              ),
            ),
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot?.info['label']?.toString() ??
                        (paired
                            ? l10n.kubusNodeUnavailable
                            : l10n.kubusNodeNotPaired),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    online
                        ? participationLabel
                        : provider.error ?? participationLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (paired)
              IconButton(
                tooltip: l10n.commonRefresh,
                onPressed: provider.refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchivePanel extends StatelessWidget {
  const _ArchivePanel({required this.local, required this.network});
  final KubusNodeSnapshot? local;
  final AvailabilityNodeStatusSnapshot? network;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionPanel(
      title: l10n.kubusNodeArchiveTitle,
      body: l10n.kubusNodeArchiveBody,
      icon: Icons.inventory_2_outlined,
      metrics: [
        _MetricData(l10n.kubusNodeBytesStored,
            _formatBytes(_asInt(local?.storage['publicReplicaBytes']))),
        _MetricData(l10n.kubusNodeRecords,
            '${network?.publicCidsPinned ?? _asInt(local?.network['publicPinSetCount'])}'),
        _MetricData(
          l10n.availabilityNodePublicCoverageLabel,
          '${((network?.publicArchiveCoverage ?? 0) * 100).toStringAsFixed(1)}%',
        ),
        _MetricData(
          l10n.kubusNodeRetrievalHealth,
          network?.status ?? local?.status['status']?.toString() ?? '—',
        ),
      ],
    );
  }
}

class _SpatialPanel extends StatelessWidget {
  const _SpatialPanel({required this.provider});
  final KubusNodeProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = provider.snapshot;
    final available =
        snapshot?.capabilityAvailable('spatial.reconstruction') == true;
    final gpu = snapshot?.capabilityAvailable('compute.gpu') == true;
    return _SectionPanel(
      title: l10n.kubusNodeSpatialTitle,
      body: l10n.kubusNodeSpatialBody,
      icon: Icons.view_in_ar_outlined,
      metrics: [
        _MetricData(l10n.kubusNodeWorker,
            available ? l10n.kubusNodeAvailable : l10n.kubusNodeUnavailable),
        _MetricData(l10n.kubusNodeGpu,
            gpu ? l10n.kubusNodeAvailable : l10n.kubusNodeUnavailable),
        _MetricData(l10n.kubusNodeRunningJobs, '${snapshot?.runningJobs ?? 0}'),
        _MetricData(l10n.kubusNodeLocalCaptures,
            '${_asInt(snapshot?.status['captures'])}'),
      ],
      footer: Text(l10n.kubusNodePrivacyBody),
    );
  }
}

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel({required this.status});
  final AvailabilityNodeStatusSnapshot? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionPanel(
      title: l10n.kubusNodeRewardsTitle,
      body: l10n.kubusNodeRewardsBody,
      icon: Icons.verified_outlined,
      metrics: [
        _MetricData(l10n.kubusNodeArchiveContribution,
            status?.archivePendingKub8.toStringAsFixed(2) ?? '—'),
        _MetricData(l10n.kubusNodeComputeContribution,
            status?.computePendingKub8.toStringAsFixed(2) ?? '—'),
        _MetricData(l10n.kubusNodePendingTotal,
            status?.pendingKub8.toStringAsFixed(2) ?? '—'),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.kubusNodeVerifiedArchiveCopy),
          const SizedBox(height: KubusSpacing.sm),
          Text(l10n.kubusNodeVerifiedComputeCopy),
          const SizedBox(height: KubusSpacing.sm),
          Text(l10n.kubusNodeSettlementPending),
        ],
      ),
    );
  }
}

class _ComputePanel extends StatelessWidget {
  const _ComputePanel({required this.provider});

  final KubusNodeProvider provider;

  Future<void> _update(
    BuildContext context,
    Map<String, dynamic> settings,
  ) async {
    try {
      await provider.updateComputeSettings(settings);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = provider.computeSettings;
    final settingsAvailable = provider.computeSettingsAvailable;
    final enabled = settings['enabled'] == true;
    final paused = settings['paused'] == true;
    final maxConcurrency =
        int.tryParse((settings['maxConcurrency'] ?? 1).toString()) ?? 1;
    final concurrencyOptions = <int>{1, 2, 3, 4, 8, maxConcurrency}.toList()
      ..sort();
    return _SectionPanel(
      title: l10n.kubusNodeComputeTitle,
      body: l10n.kubusNodeComputeBody,
      icon: Icons.memory_outlined,
      metrics: [
        _MetricData(
          l10n.kubusNodeRunningJobs,
          '${provider.snapshot?.runningJobs ?? 0}',
        ),
        _MetricData(
          l10n.kubusNodeRemoteJobsCompleted,
          '${provider.snapshot?.status['remoteJobsCompleted'] ?? 0}',
        ),
      ],
      footer: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: settingsAvailable
                ? (value) => unawaited(_update(context, {'enabled': value}))
                : null,
            title: Text(l10n.kubusNodeOfferGpu),
            subtitle: Text(l10n.kubusNodeOfferGpuBody),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: paused,
            onChanged: settingsAvailable && enabled
                ? (value) => unawaited(_update(context, {'paused': value}))
                : null,
            title: Text(l10n.kubusNodePauseRemoteJobs),
          ),
          DropdownButtonFormField<int>(
            initialValue: maxConcurrency,
            decoration: InputDecoration(
              labelText: l10n.kubusNodeMaxRemoteJobs,
            ),
            items: concurrencyOptions
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value'),
                    ))
                .toList(growable: false),
            onChanged: settingsAvailable && enabled
                ? (value) {
                    if (value != null) {
                      unawaited(
                        _update(context, {'maxConcurrency': value}),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _PairingPanel extends StatelessWidget {
  const _PairingPanel({
    required this.controller,
    required this.provider,
    required this.onPair,
  });
  final TextEditingController controller;
  final KubusNodeProvider provider;
  final Future<void> Function() onPair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionPanel(
      title: l10n.kubusNodePairTitle,
      body: l10n.kubusNodePairBody,
      icon: Icons.phonelink_lock_outlined,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.kubusNodePairingPayload,
              hintText: '{"sessionId":"…","secret":"…","node":{…}}',
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          FilledButton.icon(
            onPressed: provider.state == KubusNodeConnectionState.connecting
                ? null
                : onPair,
            icon: const Icon(Icons.link),
            label: Text(l10n.kubusNodePairAction),
          ),
          if (provider.isPaired)
            TextButton(
              onPressed: provider.unpair,
              child: Text(l10n.kubusNodeUnpairAction),
            ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);
  final String label;
  final String value;
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.body,
    required this.icon,
    this.metrics = const [],
    this.footer,
  });
  final String title;
  final String body;
  final IconData icon;
  final List<_MetricData> metrics;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => GlassSurface(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: KubusSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: KubusSpacing.xs),
              Text(body,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.md),
                Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.sm,
                  children: [
                    for (final metric in metrics)
                      _MetricChip(label: metric.label, value: metric.value),
                  ],
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: KubusSpacing.md),
                footer!,
              ],
            ],
          ),
        ),
      );
}

int _asInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _NodeStatusPanel extends StatelessWidget {
  const _NodeStatusPanel({required this.status});

  final AvailabilityNodeStatusSnapshot? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final coverage = ((status?.publicArchiveCoverage ?? 0) * 100)
        .clamp(0, 100)
        .toStringAsFixed(1);
    return GlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.availabilityNodeStatusTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (status != null)
                  Chip(
                    label: Text(status!.status),
                    side: BorderSide(color: scheme.outlineVariant),
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
              ],
            ),
            const SizedBox(height: KubusSpacing.sm),
            if (status == null) ...[
              Text(
                l10n.availabilityNodeNoNodeTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                l10n.availabilityNodeRunNodeCta,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: KubusSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(
                  const ClipboardData(
                      text: 'http://my.node.kubus.site:8787/gui'),
                ),
                icon: const Icon(Icons.copy),
                label: Text(l10n.availabilityNodeCopyGuiUrlButton),
              ),
            ] else ...[
              Wrap(
                spacing: KubusSpacing.sm,
                runSpacing: KubusSpacing.sm,
                children: [
                  _MetricChip(
                    label: l10n.availabilityNodeUptimeTodayLabel,
                    value: '${status!.uptimeTodayHours.toStringAsFixed(1)} h',
                  ),
                  _MetricChip(
                    label: l10n.availabilityNodePublicCoverageLabel,
                    value: '$coverage%',
                  ),
                  _MetricChip(
                    label: l10n.availabilityNodeContributionScoreLabel,
                    value:
                        status!.estimatedContributionScore.toStringAsFixed(0),
                  ),
                  _MetricChip(
                    label: l10n.availabilityNodePendingKub8Label,
                    value: status!.pendingKub8.toStringAsFixed(2),
                  ),
                ],
              ),
              const SizedBox(height: KubusSpacing.md),
              Text(
                l10n.availabilityNodeFormulaExplanation,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: KubusSpacing.md),
              Text(
                '${l10n.availabilityNodePublicCidsPinnedLabel}: ${status!.publicCidsPinned}/${status!.publicCidsTracked} - '
                '${l10n.availabilityNodeRewardableCidsPinnedLabel}: ${status!.rewardableCidsPinned}/${status!.rewardableCidsTracked}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: KubusSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      'http://my.node.kubus.site:8787/gui',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.availabilityNodeCopyGuiUrlButton,
                    onPressed: () => Clipboard.setData(
                      const ClipboardData(
                          text: 'http://my.node.kubus.site:8787/gui'),
                    ),
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}
