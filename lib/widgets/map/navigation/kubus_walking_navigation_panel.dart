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
    required this.onAllowLocation,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    required this.onUseExternalMaps,
    required this.onViewDestination,
  });

  final WalkingNavigationProvider navigation;
  final VoidCallback onEnd;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onAllowLocation;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onUseExternalMaps;
  final VoidCallback onViewDestination;

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
                      text: l10n.walkingNavigationBeta,
                      variant: KubusBadgeVariant.status,
                      accent: scheme.primary,
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
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  children: [
                    ..._stateActions(l10n),
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

  List<Widget> _stateActions(AppLocalizations l10n) {
    if (navigation.status == WalkingNavigationStatus.arrived) {
      return <Widget>[
        TextButton.icon(
          onPressed: onViewDestination,
          icon: const Icon(Icons.place_outlined),
          label: Text(l10n.walkingNavigationViewDestination),
        ),
      ];
    }
    if (navigation.status == WalkingNavigationStatus.error) {
      final primary = switch (navigation.failureKind) {
        WalkingNavigationFailureKind.locationPermissionDenied =>
          TextButton.icon(
            onPressed: onAllowLocation,
            icon: const Icon(Icons.location_on_outlined),
            label: Text(l10n.walkingNavigationAllowLocation),
          ),
        WalkingNavigationFailureKind.locationPermissionDeniedPermanently =>
          TextButton.icon(
            onPressed: onOpenAppSettings,
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.walkingNavigationOpenAppSettings),
          ),
        WalkingNavigationFailureKind.locationServicesDisabled =>
          TextButton.icon(
            onPressed: onOpenLocationSettings,
            icon: const Icon(Icons.location_searching),
            label: Text(l10n.walkingNavigationOpenLocationSettings),
          ),
        _ => TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.walkingNavigationRetry),
          ),
      };
      return <Widget>[
        primary,
        TextButton.icon(
          onPressed: onUseExternalMaps,
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.walkingNavigationUseExternalMaps),
        ),
      ];
    }
    if (navigation.hasActiveRoute ||
        navigation.status == WalkingNavigationStatus.rerouting) {
      return <Widget>[
        TextButton.icon(
          onPressed: onResume,
          icon: const Icon(Icons.my_location),
          label: Text(l10n.walkingNavigationResume),
        ),
      ];
    }
    return const <Widget>[];
  }

  String _instruction(
    AppLocalizations l10n,
    WalkingNavigationProvider navigation,
  ) {
    switch (navigation.status) {
      case WalkingNavigationStatus.awaitingLocation:
        return l10n.walkingNavigationWaitingForLocation;
      case WalkingNavigationStatus.requestingPermission:
        return l10n.walkingNavigationRequestingPermission;
      case WalkingNavigationStatus.calculating:
        return l10n.walkingNavigationCalculating;
      case WalkingNavigationStatus.arrived:
        return l10n.walkingNavigationArrived;
      case WalkingNavigationStatus.error:
        return switch (navigation.failureKind) {
          WalkingNavigationFailureKind.locationPermissionDenied =>
            l10n.walkingNavigationPermissionDenied,
          WalkingNavigationFailureKind.locationPermissionDeniedPermanently =>
            l10n.walkingNavigationPermissionDeniedPermanently,
          WalkingNavigationFailureKind.locationServicesDisabled =>
            l10n.walkingNavigationServicesDisabled,
          WalkingNavigationFailureKind.locationUnavailable =>
            l10n.walkingNavigationLocationUnavailable,
          WalkingNavigationFailureKind.locationTimedOut =>
            l10n.walkingNavigationLocationTimedOut,
          WalkingNavigationFailureKind.noRoute => l10n.walkingNavigationNoRoute,
          WalkingNavigationFailureKind.routeTooLong =>
            l10n.walkingNavigationRouteTooLong,
          WalkingNavigationFailureKind.routeSourceTimeout =>
            l10n.walkingNavigationRouteSourceTimeout,
          WalkingNavigationFailureKind.routeNetwork =>
            l10n.walkingNavigationRouteNetworkFailure,
          WalkingNavigationFailureKind.routeMalformed =>
            l10n.walkingNavigationRouteMalformed,
          null => l10n.walkingNavigationRouteUnavailable,
        };
      case WalkingNavigationStatus.rerouting:
        return l10n.walkingNavigationRerouting;
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
