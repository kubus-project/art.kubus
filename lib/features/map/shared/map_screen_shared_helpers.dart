import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/task.dart';
import '../../../services/task_service.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/category_accent_color.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/maplibre_style_utils.dart';
import '../../../widgets/map_marker_style_config.dart';
import '../../../screens/map_core/map_ui_state_coordinator.dart';

/// Shared helper utilities used by both MapScreen (mobile) and DesktopMapScreen.
///
/// Intentionally:
/// - no provider reads
/// - no navigation side-effects
/// - no long-lived state
///
/// These helpers are extracted to reduce duplication while keeping the
/// screen-local method signatures stable.
class KubusMapWebPointerInterceptor {
  const KubusMapWebPointerInterceptor._();

  /// Wraps [child] with [PointerInterceptor] on web to prevent pointer events
  /// leaking through overlays to MapLibre's DOM surface.
  static Widget wrap({
    required Widget child,
    bool enabled = true,
  }) {
    if (!kIsWeb || !enabled) return child;
    return PointerInterceptor(child: child);
  }
}

class KubusMapRouteAwareHelpers {
  const KubusMapRouteAwareHelpers._();

  static void didPushNext({required ValueChanged<bool> setRouteVisible}) {
    setRouteVisible(false);
  }

  static void didPopNext({required ValueChanged<bool> setRouteVisible}) {
    setRouteVisible(true);
  }
}

class KubusMapTutorialNav {
  const KubusMapTutorialNav._();

  static void dismiss({
    required bool mounted,
    required MapUiStateCoordinator coordinator,
    required AsyncCallback persistSeen,
  }) {
    if (!mounted) return;
    final idx = coordinator.value.tutorial.index;
    coordinator.setTutorial(show: false, index: idx);
    unawaited(persistSeen());
  }

  static void next({
    required bool mounted,
    required MapUiStateCoordinator coordinator,
    required int stepsLength,
    required VoidCallback onDismiss,
  }) {
    if (!mounted) return;
    final current = coordinator.value.tutorial;
    if (current.index >= stepsLength - 1) {
      onDismiss();
      return;
    }
    coordinator.setTutorial(show: true, index: current.index + 1);
  }

  static void back({
    required bool mounted,
    required MapUiStateCoordinator coordinator,
  }) {
    if (!mounted) return;
    final current = coordinator.value.tutorial;
    if (current.index <= 0) return;
    coordinator.setTutorial(show: true, index: current.index - 1);
  }
}

class KubusMarkerLayerAnimationHelpers {
  const KubusMarkerLayerAnimationHelpers._();

  static void startSelectionPopAnimation({
    required bool styleInitialized,
    required AnimationController animationController,
    required VoidCallback requestMarkerLayerStyleUpdate,
  }) {
    if (!styleInitialized) return;
    animationController.forward(from: 0.0);
    requestMarkerLayerStyleUpdate();
  }

  static void updateCubeSpinTicker({
    required bool shouldSpin,
    required AnimationController cubeIconSpinController,
  }) {
    if (shouldSpin) {
      if (!cubeIconSpinController.isAnimating) {
        cubeIconSpinController.repeat();
      }
      return;
    }

    if (cubeIconSpinController.isAnimating) {
      cubeIconSpinController.stop();
    }
  }

  static void handleMarkerLayerAnimationTick({
    required bool mounted,
    required bool styleInitialized,
    required bool shouldSpin,
    required bool shouldPop,
    required AnimationController cubeIconSpinController,
    required ValueChanged<double> setCubeIconSpinDegrees,
    required ValueChanged<double> setCubeIconBobOffsetEm,
    required VoidCallback requestMarkerLayerStyleUpdate,
  }) {
    if (!mounted) return;
    if (!styleInitialized) return;

    if (!shouldSpin && !shouldPop) return;

    if (shouldSpin) {
      setCubeIconSpinDegrees(cubeIconSpinController.value * 360.0);
      final bobMs = MapMarkerStyleConfig.cubeIconBobPeriod.inMilliseconds;
      final t = (DateTime.now().millisecondsSinceEpoch % bobMs) / bobMs;
      setCubeIconBobOffsetEm(
        math.sin(t * 2 * math.pi) * MapMarkerStyleConfig.cubeIconBobAmplitudeEm,
      );
    }

    requestMarkerLayerStyleUpdate();
  }
}

class KubusMapMarkerHelpers {
  const KubusMapMarkerHelpers._();

  static String hexRgb(Color color) {
    return MapLibreStyleUtils.hexRgb(color);
  }

  static bool markersEquivalent(List<ArtMarker> current, List<ArtMarker> next) {
    if (identical(current, next)) return true;
    if (current.length != next.length) return false;
    final byId = <String, ArtMarker>{
      for (final marker in current) marker.id: marker,
    };
    if (byId.length != current.length) return false;
    for (final marker in next) {
      final existing = byId[marker.id];
      if (existing == null) return false;
      if (existing.type != marker.type) return false;
      if (existing.artworkId != marker.artworkId) return false;
      if (existing.position.latitude != marker.position.latitude) return false;
      if (existing.position.longitude != marker.position.longitude) {
        return false;
      }
    }
    return true;
  }

  static IconData resolveArtMarkerIcon(ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return Icons.auto_awesome;
      case ArtMarkerType.institution:
        return Icons.museum_outlined;
      case ArtMarkerType.event:
        return Icons.event_available;
      case ArtMarkerType.residency:
        return Icons.apartment;
      case ArtMarkerType.drop:
        return Icons.wallet_giftcard;
      case ArtMarkerType.experience:
        return Icons.view_in_ar;
      case ArtMarkerType.other:
        return Icons.location_on_outlined;
    }
  }

  static String markerTypeLabel(AppLocalizations l10n, ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return l10n.mapMarkerTypeArtworks;
      case ArtMarkerType.institution:
        return l10n.mapMarkerTypeInstitutions;
      case ArtMarkerType.event:
        return l10n.mapMarkerTypeEvents;
      case ArtMarkerType.residency:
        return l10n.mapMarkerTypeResidencies;
      case ArtMarkerType.drop:
        return l10n.mapMarkerTypeDrops;
      case ArtMarkerType.experience:
        return l10n.mapMarkerTypeExperiences;
      case ArtMarkerType.other:
        return l10n.mapMarkerTypeMisc;
    }
  }

  static Widget markerImageFallback({
    required Color baseColor,
    required ColorScheme scheme,
    required ArtMarker marker,
  }) {
    final hasExhibitions =
        marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
    final icon = hasExhibitions
        ? AppColorUtils.exhibitionIcon
        : resolveArtMarkerIcon(marker.type);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.25),
            baseColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        icon,
        color: scheme.onPrimary,
        size: 42,
      ),
    );
  }
}

class KubusMapTaskProgressRow {
  const KubusMapTaskProgressRow._();

  static Widget build({
    required BuildContext context,
    required TaskProgress progress,
  }) {
    final task = TaskService().getTaskById(progress.taskId);
    if (task == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final pct = progress.progressPercentage;
    final accent = CategoryAccentColor.resolve(context, task.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: Icon(task.icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: KubusTypography.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(pct * 100).round()}%',
            style: KubusTypography.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
