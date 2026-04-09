import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../kubus_map_glass_surface.dart';

class KubusNearbyArtLoadingState extends StatelessWidget {
  const KubusNearbyArtLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class KubusNearbyArtEmptyState extends StatelessWidget {
  const KubusNearbyArtEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final teal = roles.statTeal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: buildKubusMapGlassSurface(
          context: context,
          kind: KubusMapGlassSurfaceKind.card,
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          tintBase: scheme.surface,
          padding: const EdgeInsets.all(KubusSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.explore_outlined, size: 38, color: teal),
              ),
              const SizedBox(height: KubusSpacing.md),
              Text(
                l10n.mapEmptyNoArtworksTitle,
                style: KubusTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                l10n.mapEmptyNoArtworksDescription,
                textAlign: TextAlign.center,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
