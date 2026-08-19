import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/spatial_library_provider.dart';
import '../../widgets/kubus_kit.dart';

/// What the user picked in the processing sheet.
enum SpatialProcessorChoice {
  /// The user's own paired Node, wherever it currently is.
  ownNode,

  /// A request for compute from someone else's GPU on the kubus network.
  kubusNetwork,
}

/// Asks who should process a capture.
///
/// There are exactly two answers, and they are different in kind rather than
/// in degree: your own Node, or a stranger's. Reaching your own Node over
/// HTTPS instead of the LAN changes the route, not the trust — so it is one
/// option with a connection note, never a third processor.
///
/// The network option is always offered. Provider discovery is asynchronous,
/// so "nobody answered in the last two seconds" is a fact about right now, not
/// a reason to hide a capability; choosing it opens a durable request that
/// waits for a provider to appear.
class SpatialProcessSheet extends StatelessWidget {
  const SpatialProcessSheet({
    super.key,
    required this.ownNode,
    required this.providersAvailableNow,
  });

  final SpatialOwnNodeReachability ownNode;

  /// Whether provider discovery found anyone at the moment the sheet opened.
  /// Informational only — it never gates the option.
  final bool providersAvailableNow;

  static Future<SpatialProcessorChoice?> show(
    BuildContext context, {
    required SpatialOwnNodeReachability ownNode,
    required bool providersAvailableNow,
  }) =>
      showModalBottomSheet<SpatialProcessorChoice>(
        context: context,
        useSafeArea: true,
        builder: (_) => SpatialProcessSheet(
          ownNode: ownNode,
          providersAvailableNow: providersAvailableNow,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.spatialProcessTitle, style: KubusTextStyles.sheetTitle),
            const SizedBox(height: KubusSpacing.md),
            _ProcessorOption(
              icon: Icons.computer_rounded,
              accent: roles.statTeal,
              title: l10n.spatialProcessLocalTitle,
              body: l10n.spatialProcessOwnNodeSubtitle,
              // The connection note is the whole difference between LAN and
              // remote: same Node, same data, different route.
              note: switch (ownNode) {
                SpatialOwnNodeReachability.localNetwork =>
                  l10n.spatialProcessOwnNodeLocal,
                SpatialOwnNodeReachability.remote =>
                  l10n.spatialProcessOwnNodeRemote,
                SpatialOwnNodeReachability.unpaired => null,
              },
              enabled: ownNode != SpatialOwnNodeReachability.unpaired,
              onTap: () => Navigator.of(context).pop(
                SpatialProcessorChoice.ownNode,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            _ProcessorOption(
              icon: Icons.hub_rounded,
              accent: roles.statBlue,
              title: l10n.spatialProcessNetworkTitle,
              body: l10n.spatialProcessNetworkSubtitle,
              note: providersAvailableNow
                  ? null
                  : l10n.spatialProcessNoProviderNow,
              noteColor: providersAvailableNow ? null : scheme.onSurfaceVariant,
              enabled: true,
              onTap: () => Navigator.of(context).pop(
                SpatialProcessorChoice.kubusNetwork,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessorOption extends StatelessWidget {
  const _ProcessorOption({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.enabled,
    required this.onTap,
    this.note,
    this.noteColor,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? note;
  final Color? noteColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: KubusCard(
        onTap: enabled ? onTap : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: accent),
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: KubusTextStyles.detailCardTitle),
                  const SizedBox(height: KubusSpacing.xxs),
                  Text(
                    body,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (note != null) ...<Widget>[
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      note!,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: noteColor ?? accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
