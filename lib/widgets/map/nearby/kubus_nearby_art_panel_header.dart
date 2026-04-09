import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../common/kubus_screen_header.dart';
import '../kubus_map_glass_surface.dart';
import 'kubus_nearby_art_panel_types.dart';

class KubusNearbyArtPanelHeader extends StatelessWidget {
  const KubusNearbyArtPanelHeader({
    super.key,
    required this.layout,
    required this.titleKey,
    required this.artworkCount,
    required this.discoveryProgress,
    required this.travelModeEnabled,
    required this.radiusKm,
    required this.useGrid,
    required this.sort,
    required this.accentColor,
    required this.onClose,
    required this.onRadiusTap,
    required this.onToggleGrid,
    required this.onSortChanged,
  });

  final KubusNearbyArtPanelLayout layout;
  final Key? titleKey;
  final int artworkCount;
  final double? discoveryProgress;
  final bool travelModeEnabled;
  final double radiusKm;
  final bool useGrid;
  final KubusNearbyArtSort sort;
  final Color accentColor;
  final VoidCallback? onClose;
  final VoidCallback? onRadiusTap;
  final VoidCallback onToggleGrid;
  final ValueChanged<KubusNearbyArtSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isMobile = layout == KubusNearbyArtPanelLayout.mobileBottomSheet;
    final title = isMobile ? l10n.mapNearbyArtTitle : l10n.arNearbyArtworksTitle;

    final subtitle = (() {
      if (travelModeEnabled) {
        return isMobile
            ? '${l10n.mapResultsDiscoveredLabel(artworkCount, ((discoveryProgress ?? 0) * 100).round())} ${l10n.mapTravelModeStatusTravelling}'
            : l10n.mapTravelModeStatusTravelling;
      }

      if (isMobile && discoveryProgress != null) {
        return l10n.mapResultsDiscoveredLabel(
          artworkCount,
          ((discoveryProgress ?? 0) * 100).round(),
        );
      }

      return '${l10n.mapNearbyRadiusTitle}: ${radiusKm.toStringAsFixed(1)} km';
    })();

    final headerRow = Row(
      children: [
        if (!isMobile) ...[
          Icon(
            Icons.auto_awesome,
            color: accentColor,
            size: KubusHeaderMetrics.actionIcon - KubusSpacing.xxs,
          ),
          const SizedBox(width: KubusSpacing.sm),
        ],
        Expanded(
          child: KeyedSubtree(
            key: titleKey,
            child: KubusHeaderText(
              title: title,
              subtitle: subtitle,
              kind: KubusHeaderKind.section,
              titleColor: scheme.onSurface,
              subtitleColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (isMobile) ...[
          _glassIconButton(
            context,
            icon: Icons.radar,
            tooltip: travelModeEnabled
                ? l10n.mapTravelModeStatusTravellingTooltip
                : l10n.mapNearbyRadiusTooltip(radiusKm.toInt()),
            onTap: travelModeEnabled ? null : onRadiusTap,
          ),
          const SizedBox(width: KubusSpacing.sm),
          _glassIconButton(
            context,
            icon: useGrid ? Icons.view_list : Icons.grid_view,
            tooltip: useGrid
                ? l10n.mapShowListViewTooltip
                : l10n.mapShowGridViewTooltip,
            onTap: onToggleGrid,
          ),
          const SizedBox(width: KubusSpacing.sm),
          PopupMenuButton<KubusNearbyArtSort>(
            tooltip: l10n.mapSortResultsTooltip,
            onSelected: onSortChanged,
            itemBuilder: (context) => [
              for (final s in KubusNearbyArtSort.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Expanded(child: Text(s.label(l10n))),
                      if (s == sort) Icon(Icons.check, color: scheme.primary),
                    ],
                  ),
                ),
            ],
            child: _glassIconButton(
              context,
              icon: Icons.sort,
              tooltip: l10n.mapSortResultsTooltip,
              onTap: null,
            ),
          ),
        ] else ...[
          IconButton(
            tooltip: l10n.commonClose,
            onPressed: onClose,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          KubusSpacing.md,
          KubusSpacing.md - KubusSpacing.xxs,
          KubusSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Semantics(
                label: 'nearby_art_handle',
                child: Container(
                  width: KubusHeaderMetrics.searchBarHeight,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KubusSpacing.md - KubusSpacing.xxs),
            headerRow,
            const SizedBox(height: KubusSpacing.sm),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.sm + KubusSpacing.xxs,
      ),
      child: headerRow,
    );
  }

  Widget _glassIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final button = buildKubusMapGlassSurface(
      context: context,
      kind: KubusMapGlassSurfaceKind.button,
      borderRadius: BorderRadius.circular(KubusRadius.md),
      tintBase: scheme.surfaceContainerHighest,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: KubusHeaderMetrics.actionHitArea,
        height: KubusHeaderMetrics.actionHitArea,
        child: Center(
          child: Icon(
            icon,
            size: KubusHeaderMetrics.actionIcon - KubusSpacing.xxs,
            color: onTap == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );

    return Tooltip(message: tooltip, child: button);
  }
}
