import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';

Widget buildSpatialViewer({
  required BuildContext context,
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
}) {
  final variant = content.variants
          .where((item) => item.role == 'spatial_mobile')
          .firstOrNull ??
      content.variants
          .where((item) => item.role == 'spatial_preview')
          .firstOrNull ??
      content.variants
          .where((item) => item.role == 'spatial_archive')
          .firstOrNull;
  final scheme = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  return ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined, size: 48),
            const SizedBox(height: 12),
            Text(l10n.spatialArchiveTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.spatialViewerWebSafety,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (variant != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final candidates = await nodeService
                      .resolveContentCandidates('ipfs://${variant.cid}');
                  if (candidates.isNotEmpty) {
                    await launchUrl(candidates.first.uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  variant.role == 'spatial_archive'
                      ? l10n.spatialLoadArchiveQuality
                      : l10n.spatialViewIn3d,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
