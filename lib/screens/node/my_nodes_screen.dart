import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/kubus_node_provider.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import '../../widgets/node/node_ui.dart';
import 'add_node_screen.dart';
import 'node_pairing_screen.dart';

/// The single front door to connecting a kubus Node.
///
/// This screen used to offer five controls that all meant roughly "connect" —
/// Confirm, Add Node, Retry, Pair locally, and a link straight into operator
/// setup — which is implementation leakage, not a journey. There is now one
/// primary action, [NodePairingScreen]'s one-time handoff, with a single quiet
/// alternative for a Node that cannot be scanned, and honest states around
/// them:
///
/// * **Looking** — one indicator, no controls competing with it.
/// * **Nodes on this account** — each one named, with its reachability stated
///   plainly and a single Connect, enabled only when it can actually be
///   reached.
/// * **Could not load** — said as itself, never as "no Nodes", with one Retry.
/// * **No Node yet** — what a Node is for, then the one action.
///
/// Operator internals (network identity, operator token, environment) are
/// deliberately not here. A normal person connecting a Node never needs them,
/// so they live under the Node dashboard's Security & Setup, behind the
/// advanced disclosure.
class MyNodesScreen extends StatelessWidget {
  const MyNodesScreen({super.key, this.networkProcessing = false});

  final bool networkProcessing;

  static Future<bool?> show(BuildContext context,
      {bool networkProcessing = false}) {
    // The rollout flag governs the whole Node surface. Bootstrap skips
    // KubusNodeProvider.initialize() when it is off, so discovering and
    // navigating here anyway would issue authenticated Node calls against a
    // provider that was deliberately never started.
    if (!AppConfig.isFeatureEnabled('availabilityNodes')) {
      return Future<bool?>.value(null);
    }
    unawaited(context.read<KubusNodeProvider>().loadOwnedNodes());
    return Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MyNodesScreen(networkProcessing: networkProcessing),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final provider = context.watch<KubusNodeProvider>();
    final attaching = provider.state == KubusNodeConnectionState.connecting;
    final owned = provider.ownedNodes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.kubusMyNodesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            children: [
              if (networkProcessing) ...[
                NodePanel(child: Text(l10n.kubusNetworkStagingExplanation)),
                const SizedBox(height: KubusSpacing.md),
              ],

              // --- State ----------------------------------------------------
              if (provider.loadingOwnedNodes)
                const Center(child: InlineLoading(width: 40, height: 40))
              else if (owned.isNotEmpty) ...[
                Text(
                  l10n.kubusNodeOwnedNodesHeading,
                  style: KubusTextStyles.structuralLabel.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                for (final node in owned) ...[
                  _OwnedNodeRow(
                    node: node,
                    attaching: attaching,
                    onConnect: () => _connect(context, provider, node),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                ],
              ] else if (provider.discoveryError != null) ...[
                // Said as itself, not as "no Nodes": a failed lookup and an
                // account with no Node are different facts.
                NodePanel(child: Text(l10n.kubusMyNodesDiscoveryFailed)),
                const SizedBox(height: KubusSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: KubusOutlineButton(
                    label: l10n.commonRetry,
                    onPressed: attaching ? null : provider.loadOwnedNodes,
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
              ] else ...[
                NodeEmptyState(
                  icon: Icons.dns_outlined,
                  title: l10n.kubusNodeNoNodeTitle,
                  body: l10n.kubusNodeEntrySubtitle,
                ),
                const SizedBox(height: KubusSpacing.lg),
              ],

              // --- The one front door ---------------------------------------
              KubusButton(
                key: const ValueKey<String>('node_connect_primary_action'),
                label: l10n.kubusNodeConnectAction,
                icon: Icons.qr_code_scanner_rounded,
                isFullWidth: true,
                onPressed: attaching ? null : () => _pair(context),
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                l10n.kubusNodeConnectHandoffBody,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              // The one alternative, kept quiet: a Node whose code cannot be
              // scanned (no camera, a headless install) is typed in instead.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: KubusButton(
                  label: l10n.kubusAddNodeTitle,
                  variant: KubusButtonVariant.quiet,
                  onPressed: attaching
                      ? null
                      : () async {
                          await AddNodeScreen.show(context);
                          if (!context.mounted) return;
                          await provider.loadOwnedNodes();
                        },
                ),
              ),

              if (provider.error != null) ...[
                const SizedBox(height: KubusSpacing.lg),
                NodePanel(
                  child: Text(
                    NodeStatePresentation.connection(
                      l10n,
                      provider.connectionDetail,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pair(BuildContext context) async {
    final paired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NodePairingScreen()),
    );
    if (!context.mounted || paired != true) return;
    // Connected: land in the dashboard rather than back in a setup menu.
    Navigator.of(context).pop(true);
  }

  Future<void> _connect(
    BuildContext context,
    KubusNodeProvider provider,
    Map<String, dynamic> node,
  ) async {
    try {
      await provider.attachOwnedNode(node);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      // The provider owns the error and retains any previously durable
      // pairing; the panel below reports it.
    }
  }
}

/// One Node already registered to this account.
///
/// Named, with its reachability stated plainly rather than implied, and a
/// single Connect that is disabled when the Node genuinely cannot be reached —
/// so the screen never offers an action that cannot succeed.
class _OwnedNodeRow extends StatelessWidget {
  const _OwnedNodeRow({
    required this.node,
    required this.attaching,
    required this.onConnect,
  });

  final Map<String, dynamic> node;
  final bool attaching;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reachable = node['remoteAttachAvailable'] == true;
    final label = (node['label'] as String?)?.trim();

    return NodePanel(
      title:
          (label == null || label.isEmpty) ? l10n.kubusNodeEntryTitle : label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NodeStatusLabel(
            label: reachable ? l10n.kubusNodeAvailable : l10n.kubusNodeOffline,
            severity: reachable ? NodeSeverity.good : NodeSeverity.attention,
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            reachable
                ? l10n.kubusMyNodesAvailable
                : l10n.kubusMyNodesUnavailable,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: KubusSpacing.md),
          KubusButton(
            label: attaching
                ? l10n.kubusMyNodesAttaching
                : l10n.kubusNodeConfirmAction,
            isLoading: attaching,
            onPressed: attaching || !reachable ? null : onConnect,
          ),
        ],
      ),
    );
  }
}
