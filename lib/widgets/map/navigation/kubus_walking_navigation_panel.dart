import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../features/map/navigation/walking_navigation_models.dart';
import '../../../providers/walking_navigation_provider.dart';
import '../../../utils/design_tokens.dart';
import '../../common/kubus_badge.dart';
import '../../map_overlay_blocker.dart';
import '../kubus_map_glass_surface.dart';

class KubusWalkingNavigationPanel extends StatelessWidget {
  const KubusWalkingNavigationPanel({
    super.key,
    required this.navigation,
    required this.onEnd,
    required this.onResume,
    required this.onRetry,
  });

  final WalkingNavigationProvider navigation;
  final VoidCallback onEnd;
  final VoidCallback onResume;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final instruction = _instruction(l10n, navigation);
    final remaining = l10n.walkingNavigationRemaining(
      _distance(navigation.remainingDistanceMeters),
      _duration(navigation.remainingDurationSeconds),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: instruction,
      child: MapOverlayBlocker(
        child: buildKubusMapGlassSurface(
          context: context,
          kind: KubusMapGlassSurfaceKind.panel,
          overlayName: 'walking-navigation',
          tintBase: scheme.surface,
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_instructionIcon(navigation.activeStep),
                        color: scheme.primary),
                    const SizedBox(width: KubusSpacing.sm),
                    Expanded(
                      child: Text(
                        instruction,
                        style: KubusTypography.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    KubusBadge(
                      text: l10n.artDetailNavigationInDevelopment,
                      variant: KubusBadgeVariant.status,
                      accent: scheme.primary,
                      icon: Icons.construction_outlined,
                      compact: true,
                    ),
                  ],
                ),
                if (navigation.hasActiveRoute) ...[
                  const SizedBox(height: KubusSpacing.xs),
                  Text(remaining,
                      style: KubusTypography.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  l10n.walkingNavigationPreviewNotice,
                  style: KubusTypography.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  l10n.walkingNavigationRouteAttribution,
                  style: KubusTypography.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (navigation.status == WalkingNavigationStatus.error)
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.walkingNavigationRetry),
                      )
                    else if (navigation.hasActiveRoute)
                      TextButton.icon(
                        onPressed: onResume,
                        icon: const Icon(Icons.my_location),
                        label: Text(l10n.walkingNavigationResume),
                      ),
                    const SizedBox(width: KubusSpacing.xs),
                    TextButton.icon(
                      onPressed: onEnd,
                      icon: const Icon(Icons.close),
                      label: Text(l10n.walkingNavigationEnd),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _instruction(
    AppLocalizations l10n,
    WalkingNavigationProvider navigation,
  ) {
    switch (navigation.status) {
      case WalkingNavigationStatus.awaitingLocation:
        return l10n.walkingNavigationWaitingForLocation;
      case WalkingNavigationStatus.calculating:
        return l10n.walkingNavigationCalculating;
      case WalkingNavigationStatus.arrived:
        return l10n.walkingNavigationArrived;
      case WalkingNavigationStatus.error:
        return navigation.errorMessage?.isNotEmpty == true
            ? l10n.walkingNavigationRouteUnavailable
            : l10n.walkingNavigationRouteUnavailable;
      case WalkingNavigationStatus.active:
        final step = navigation.activeStep;
        final base = switch (step?.modifier) {
          'left' ||
          'slight left' ||
          'sharp left' =>
            l10n.walkingNavigationTurnLeft,
          'right' ||
          'slight right' ||
          'sharp right' =>
            l10n.walkingNavigationTurnRight,
          _ when step?.type == 'depart' => l10n.walkingNavigationDepart,
          _ => l10n.walkingNavigationContinue,
        };
        final roadName = step?.roadName.trim() ?? '';
        return roadName.isEmpty ? base : '$base · $roadName';
      case WalkingNavigationStatus.idle:
        return l10n.walkingNavigationContinue;
    }
  }

  IconData _instructionIcon(WalkingRouteStep? step) => switch (step?.modifier) {
        'left' || 'slight left' || 'sharp left' => Icons.turn_left,
        'right' || 'slight right' || 'sharp right' => Icons.turn_right,
        _ => Icons.navigation_outlined,
      };

  String _distance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  String _duration(double seconds) {
    final minutes = (seconds / 60).ceil().clamp(1, 999);
    return '$minutes min';
  }
}
