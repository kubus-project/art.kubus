import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/kubus_node_provider.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import '../../widgets/node/node_ui.dart';
import '../settings/availability_node_operator_screen.dart';
import 'node_pairing_screen.dart';

/// Account discovery is initiated by the navigation action, not widget init.
class MyNodesScreen extends StatelessWidget {
  const MyNodesScreen({super.key, this.networkProcessing = false});

  final bool networkProcessing;

  static Future<bool?> show(BuildContext context,
      {bool networkProcessing = false}) {
    unawaited(context.read<KubusNodeProvider>().loadOwnedNodes());
    return Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MyNodesScreen(networkProcessing: networkProcessing),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<KubusNodeProvider>();
    final attaching = provider.state == KubusNodeConnectionState.connecting;
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
              if (provider.loadingOwnedNodes)
                const Center(child: InlineLoading(width: 40, height: 40))
              else if (provider.discoveryError != null)
                NodePanel(child: Text(l10n.kubusMyNodesDiscoveryFailed))
              else if (provider.ownedNodes.isEmpty)
                NodePanel(child: Text(l10n.kubusMyNodesEmpty))
              else
                for (final node in provider.ownedNodes) ...[
                  NodePanel(
                    title:
                        (node['label'] as String?) ?? l10n.kubusNodeEntryTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(node['remoteAttachAvailable'] == true
                            ? l10n.kubusMyNodesAvailable
                            : l10n.kubusMyNodesUnavailable),
                        const SizedBox(height: KubusSpacing.md),
                        KubusButton(
                          label: attaching
                              ? l10n.kubusMyNodesAttaching
                              : l10n.kubusNodeConfirmAction,
                          onPressed:
                              attaching || node['remoteAttachAvailable'] != true
                                  ? null
                                  : () async {
                                      try {
                                        await provider.attachOwnedNode(node);
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop(true);
                                      } catch (_) {
                                        // The provider owns the error and retains
                                        // any previously durable pairing.
                                      }
                                    },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                ],
              if (provider.error != null) ...[
                NodePanel(
                    child: Text(NodeStatePresentation.connection(
                        l10n, provider.connectionDetail))),
                const SizedBox(height: KubusSpacing.md),
              ],
              const SizedBox(height: KubusSpacing.md),
              KubusOutlineButton(
                label: l10n.commonRetry,
                onPressed: provider.loadingOwnedNodes || attaching
                    ? null
                    : provider.loadOwnedNodes,
              ),
              const SizedBox(height: KubusSpacing.md),
              KubusOutlineButton(
                label: l10n.kubusMyNodesLocalPairing,
                onPressed: attaching
                    ? null
                    : () async {
                        final paired = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const NodePairingScreen()),
                        );
                        if (!context.mounted || paired != true) return;
                        Navigator.of(context).pop(true);
                      },
              ),
              const SizedBox(height: KubusSpacing.md),
              KubusOutlineButton(
                label: l10n.kubusNodeEntryConnectCta,
                onPressed: attaching
                    ? null
                    : () => Navigator.of(context).push<void>(MaterialPageRoute(
                        builder: (_) =>
                            const AvailabilityNodeOperatorScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
