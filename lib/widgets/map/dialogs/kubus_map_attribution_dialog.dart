import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../glass_components.dart';

Future<void> showKubusMapAttributionDialog(BuildContext context) async {
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;

  await showKubusDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;

      Widget item(String title, String subtitle) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm,
            vertical: KubusSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KubusTypography.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: KubusTypography.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      return KubusAlertDialog(
        title: const Text('Map attributions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item('MapLibre', 'Map rendering engine'),
            const SizedBox(height: KubusSpacing.sm),
            item('CARTO', 'Basemap style and cartography'),
            const SizedBox(height: KubusSpacing.sm),
            item('OpenStreetMap', 'Map data contributors'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      );
    },
  );
}
