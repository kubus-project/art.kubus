import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../../config/config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/event.dart';
import '../../../models/map_marker_subject.dart';
import '../../../models/task.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/task_service.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/category_accent_color.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/maplibre_style_utils.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/common/kubus_marker_overlay_card.dart';
import '../../../widgets/map_marker_style_config.dart';
import '../../../widgets/map/cards/kubus_discovery_card.dart';
import 'map_marker_overlay_presentation.dart';
import 'map_overlay_sizing.dart';
import '../map_layers_manager.dart';
import '../controller/kubus_map_controller.dart';
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

class KubusMapLifecycleHelpers {
  const KubusMapLifecycleHelpers._();

  static void handleMapCreated({
    required ml.MapLibreMapController controller,
    required KubusMapController kubusMapController,
    required ValueChanged<ml.MapLibreMapController?> setMapController,
    required ValueChanged<MapLayersManager?> setLayersManager,
    VoidCallback? clearManagedState,
  }) {
    setMapController(controller);
    kubusMapController.attachMapController(controller);
    setLayersManager(kubusMapController.layersManager);
    clearManagedState?.call();
  }

  static ml.MapLibreMapController? detachMapController({
    required ml.MapLibreMapController? controller,
    required KubusMapController kubusMapController,
    required ValueChanged<ml.MapLibreMapController?> setMapController,
    required ValueChanged<MapLayersManager?> setLayersManager,
  }) {
    if (controller == null) return null;
    kubusMapController.detachMapController();
    setMapController(null);
    setLayersManager(null);
    return controller;
  }

  static void reactivateDetachedMapController({
    required ml.MapLibreMapController? currentMapController,
    required ml.MapLibreMapController? detachedController,
    required KubusMapController kubusMapController,
    required ValueChanged<ml.MapLibreMapController?> setMapController,
    required ValueChanged<MapLayersManager?> setLayersManager,
  }) {
    if (detachedController == null || currentMapController != null) return;
    setMapController(detachedController);
    kubusMapController.attachMapController(detachedController);
    setLayersManager(kubusMapController.layersManager);
  }
}

class KubusMapMarkerCreationHelpers {
  const KubusMapMarkerCreationHelpers._();

  static bool shouldUploadStreetArtCover({
    required ArtMarkerType markerType,
    required MarkerSubjectType? subjectType,
    required Uint8List? coverImageBytes,
  }) {
    final isStreetArtMarker = subjectType == MarkerSubjectType.streetArt ||
        markerType == ArtMarkerType.streetArt;
    return isStreetArtMarker &&
        coverImageBytes != null &&
        coverImageBytes.isNotEmpty;
  }

  static Future<String?> uploadStreetArtCover({
    required Uint8List fileBytes,
    required String? fileName,
    required String? fileType,
    required String? walletAddress,
    required String source,
    required String debugLabel,
  }) async {
    final coverImageUrl = await BackendApiService().uploadMarkerCoverImage(
      fileBytes: fileBytes,
      fileName: fileName ?? 'street-art-cover.png',
      fileType: fileType ?? 'image',
      walletAddress: walletAddress,
      source: source,
    );

    if (coverImageUrl == null || coverImageUrl.isEmpty) {
      AppConfig.debugPrint(
        '$debugLabel: cover upload failed for street-art marker creation',
      );
      return null;
    }

    return coverImageUrl;
  }
}

class KubusMapStyleInitHelpers {
  const KubusMapStyleInitHelpers._();

  static Future<void> handleStyleLoaded({
    required ml.MapLibreMapController? controller,
    required bool mounted,
    required bool styleInitializationInProgress,
    required ValueChanged<bool> setStyleInitializationInProgress,
    required ValueChanged<bool> setStyleInitialized,
    required ValueChanged<int> setStyleEpoch,
    required ValueChanged<bool> setLastAppliedMapThemeDark,
    required KubusMapController kubusMapController,
    required ColorScheme scheme,
    required bool isDarkMode,
    required MapLayersThemeSpec themeSpec,
    required String debugLabel,
    required Future<void> Function() onStyleReady,
    VoidCallback? onBeforeHandleStyleLoaded,
  }) async {
    if (controller == null) return;
    if (!mounted) return;
    if (styleInitializationInProgress) return;

    final stopwatch = Stopwatch()..start();
    setStyleInitializationInProgress(true);
    setStyleInitialized(false);

    AppConfig.debugPrint('$debugLabel: style init start');

    try {
      onBeforeHandleStyleLoaded?.call();

      await kubusMapController.handleStyleLoaded(themeSpec: themeSpec);

      final initialized = kubusMapController.styleInitialized;
      setStyleInitialized(initialized);
      if (!initialized || !mounted) {
        return;
      }

      setStyleEpoch(kubusMapController.styleEpoch);
      setLastAppliedMapThemeDark(isDarkMode);

      await onStyleReady();

      stopwatch.stop();
      AppConfig.debugPrint(
        '$debugLabel: style init done in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      setStyleInitialized(false);
      if (kDebugMode) {
        AppConfig.debugPrint('$debugLabel: style init failed: $e');
        AppConfig.debugPrint('$debugLabel: style init stack: $st');
      }
    } finally {
      setStyleInitializationInProgress(false);
    }
  }
}

class KubusMapSourceSyncHelpers {
  const KubusMapSourceSyncHelpers._();

  static Future<void> syncPointSource({
    required ml.MapLibreMapController? controller,
    required bool styleInitialized,
    required Set<String> managedSourceIds,
    required String sourceId,
    required String featureId,
    required LatLng? position,
  }) async {
    if (controller == null) return;
    if (!styleInitialized) return;
    if (!managedSourceIds.contains(sourceId)) return;

    final data = pointFeatureCollection(
      featureId: featureId,
      position: position,
    );
    await controller.setGeoJsonSource(sourceId, data);
  }

  static Map<String, dynamic> pointFeatureCollection({
    required String featureId,
    required LatLng? position,
  }) {
    if (position == null) {
      return const <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      };
    }

    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        <String, dynamic>{
          'type': 'Feature',
          'id': featureId,
          'properties': <String, dynamic>{'id': featureId},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[position.longitude, position.latitude],
          },
        },
      ],
    };
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
      case ArtMarkerType.streetArt:
        return Icons.streetview;
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
      case ArtMarkerType.streetArt:
        return l10n.mapMarkerTypeStreetArt;
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

class KubusMapDiscoveryCardHelpers {
  const KubusMapDiscoveryCardHelpers._();

  static Widget build({
    required Iterable<TaskProgress> activeProgress,
    required double overallProgress,
    required bool expanded,
    required VoidCallback onToggleExpanded,
    required Widget Function(TaskProgress progress) buildTaskRow,
    required TextStyle? titleStyle,
    required TextStyle? percentStyle,
    required EdgeInsets glassPadding,
    BoxConstraints? constraints,
    bool enableMouseRegion = false,
    MouseCursor mouseCursor = SystemMouseCursors.basic,
    double expandButtonSize = 36,
    double badgeGap = 10,
    double tasksTopGap = 10,
  }) {
    final progressList = activeProgress.toList(growable: false);
    if (progressList.isEmpty) return const SizedBox.shrink();

    final tasksToRender = expanded ? progressList : const <TaskProgress>[];

    return KubusDiscoveryCard(
      overallProgress: overallProgress,
      expanded: expanded,
      taskRows: [
        for (final progress in tasksToRender) buildTaskRow(progress),
      ],
      onToggleExpanded: onToggleExpanded,
      titleStyle: titleStyle,
      percentStyle: percentStyle,
      glassPadding: glassPadding,
      constraints: constraints,
      enableMouseRegion: enableMouseRegion,
      mouseCursor: mouseCursor,
      expandButtonSize: expandButtonSize,
      badgeGap: badgeGap,
      tasksTopGap: tasksTopGap,
    );
  }
}

class KubusMarkerOverlayHelpers {
  const KubusMarkerOverlayHelpers._();

  static double estimateCardHeight({
    required ArtMarker marker,
    required Artwork? artwork,
    required KubusEvent? event,
    required double maxCardHeight,
    required bool isCompactWidth,
  }) {
    final presentation = resolveMarkerOverlayPresentation(
      marker: marker,
      artwork: artwork,
      event: event,
    );

    final normalizedDescription =
        presentation.description.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = normalizedDescription.isEmpty
        ? const <String>[]
        : normalizedDescription.split(' ');
    final wordCapped =
        words.length > 90 ? words.take(90).join(' ') : normalizedDescription;
    final cappedChars = wordCapped.length.clamp(0, 700);
    final hasDescription = cappedChars > 0;
    final hasLinkedContext = presentation.linkedSubject.kind !=
            MapMarkerOverlayLinkedSubjectKind.none ||
        (presentation.linkedSubject.title ?? '').trim().isNotEmpty ||
        (presentation.linkedSubject.subtitle ?? '').trim().isNotEmpty;

    var estimated = isCompactWidth ? 320.0 : 336.0;
    if (hasDescription) {
      final approxCharsPerLine = isCompactWidth ? 34.0 : 42.0;
      final approxLines =
          math.max(1, (cappedChars / approxCharsPerLine).ceil());
      final cappedLines = approxLines.clamp(1, isCompactWidth ? 5 : 7);
      final lineHeightPx = isCompactWidth ? 17.0 : 16.0;
      final descriptionHeight = cappedLines * lineHeightPx;
      estimated += descriptionHeight;
    } else {
      estimated -= 18.0;
    }

    if (hasLinkedContext) {
      estimated += 12.0;
    }

    if (marker.isPromoted || (artwork?.promotion.isPromoted ?? false)) {
      estimated += 8.0;
    }

    return MapOverlaySizing.resolveCardHeight(
      estimatedHeight: estimated,
      maxCardHeight: maxCardHeight,
      isCompactWidth: isCompactWidth,
    );
  }

  static String? resolveDistanceText({
    required LatLng? userLocation,
    required ArtMarker marker,
    required Distance distance,
  }) {
    if (userLocation == null || !marker.hasValidPosition) return null;
    final meters = distance.as(
      LengthUnit.Meter,
      userLocation,
      marker.position,
    );
    if (!meters.isFinite || meters < 0) return null;
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static bool canOpenStreetArtClaims(ArtMarker marker) {
    return AppConfig.isFeatureEnabled('streetArtClaims') &&
        marker.type == ArtMarkerType.streetArt &&
        marker.isPublic;
  }

  static bool markerOwnedByCurrentUser({
    required ArtMarker marker,
    required String? walletAddress,
    required String? currentUserId,
  }) {
    final normalizedUserId = (currentUserId ?? '').trim();
    final metadata = marker.metadata ?? const <String, dynamic>{};
    final nestedMetadataRaw = metadata['metadata'] ?? metadata['meta'];
    final nestedMetadata = nestedMetadataRaw is Map
        ? Map<String, dynamic>.from(
            nestedMetadataRaw.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
        : const <String, dynamic>{};

    final ownerCandidates = <String>{
      marker.createdBy,
      (metadata['ownerWallet'] ?? '').toString(),
      (metadata['owner_wallet'] ?? '').toString(),
      (metadata['walletAddress'] ?? '').toString(),
      (metadata['wallet_address'] ?? '').toString(),
      (metadata['createdBy'] ?? '').toString(),
      (metadata['created_by'] ?? '').toString(),
      (nestedMetadata['ownerWallet'] ?? '').toString(),
      (nestedMetadata['owner_wallet'] ?? '').toString(),
      (nestedMetadata['walletAddress'] ?? '').toString(),
      (nestedMetadata['wallet_address'] ?? '').toString(),
      (nestedMetadata['createdBy'] ?? '').toString(),
      (nestedMetadata['created_by'] ?? '').toString(),
    };

    for (final candidate in ownerCandidates) {
      final value = candidate.trim();
      if (value.isEmpty) continue;
      if (WalletUtils.equals(value, walletAddress)) {
        return true;
      }
      if (normalizedUserId.isNotEmpty && value == normalizedUserId) {
        return true;
      }
    }

    return false;
  }

  static KubusEvent? resolveLinkedEvent({
    required ArtMarker marker,
    required Iterable<KubusEvent> events,
  }) {
    final subjectType = (marker.subjectType ?? '').trim().toLowerCase();
    if (!subjectType.contains('event')) return null;
    final eventId = (marker.subjectId ?? '').trim();
    if (eventId.isEmpty) return null;
    for (final event in events) {
      if (event.id == eventId) return event;
    }
    return null;
  }

  static String? subjectTypeLabel(
    AppLocalizations l10n,
    MapMarkerOverlayLinkedSubjectKind kind,
  ) {
    switch (kind) {
      case MapMarkerOverlayLinkedSubjectKind.artwork:
        return l10n.commonArtwork;
      case MapMarkerOverlayLinkedSubjectKind.exhibition:
        return l10n.commonExhibition;
      case MapMarkerOverlayLinkedSubjectKind.event:
        return l10n.mapMarkerSubjectTypeEvent;
      case MapMarkerOverlayLinkedSubjectKind.institution:
        return l10n.commonInstitution;
      case MapMarkerOverlayLinkedSubjectKind.group:
        return l10n.mapMarkerSubjectTypeGroup;
      case MapMarkerOverlayLinkedSubjectKind.misc:
      case MapMarkerOverlayLinkedSubjectKind.none:
        return null;
    }
  }

  static IconData primaryActionIcon(
    MapMarkerOverlayPrimaryTarget target,
  ) {
    switch (target) {
      case MapMarkerOverlayPrimaryTarget.exhibition:
        return Icons.museum_outlined;
      case MapMarkerOverlayPrimaryTarget.event:
        return Icons.event_outlined;
      case MapMarkerOverlayPrimaryTarget.institution:
        return Icons.museum_outlined;
      case MapMarkerOverlayPrimaryTarget.artwork:
        return Icons.arrow_forward;
      case MapMarkerOverlayPrimaryTarget.markerInfo:
        return Icons.info_outline;
    }
  }

  static KubusMarkerOverlayCard buildOverlayCard({
    required BuildContext context,
    required ArtMarker marker,
    required Artwork? artwork,
    required KubusEvent? event,
    required Color baseColor,
    required bool canPresentExhibition,
    required String? distanceText,
    required VoidCallback onClose,
    required VoidCallback onOpenDetails,
    required List<MarkerOverlayActionSpec> actions,
    required int stackCount,
    required int stackIndex,
    ValueChanged<int>? onSelectStackIndex,
    VoidCallback? onNextStacked,
    VoidCallback? onPreviousStacked,
    GestureDragEndCallback? onHorizontalDragEnd,
    required double maxCardHeight,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final presentation = resolveMarkerOverlayPresentation(
      marker: marker,
      artwork: artwork,
      event: event,
    );

    return KubusMarkerOverlayCard(
      marker: marker,
      artwork: artwork,
      baseColor: baseColor,
      displayTitle: presentation.title,
      canPresentExhibition: canPresentExhibition,
      distanceText: distanceText,
      description: presentation.description,
      linkedSubjectTypeLabel:
          subjectTypeLabel(l10n, presentation.linkedSubject.kind),
      linkedSubjectTitle: presentation.linkedSubject.title,
      linkedSubjectSubtitle: presentation.linkedSubject.subtitle,
      onClose: onClose,
      onPrimaryAction: onOpenDetails,
      onCardTap: onOpenDetails,
      onTitleTap: onOpenDetails,
      primaryActionIcon: primaryActionIcon(presentation.primaryTarget),
      primaryActionLabel: l10n.commonViewDetails,
      actions: actions,
      stackCount: stackCount,
      stackIndex: stackIndex,
      onNextStacked: onNextStacked,
      onPreviousStacked: onPreviousStacked,
      onSelectStackIndex: onSelectStackIndex,
      onHorizontalDragEnd: onHorizontalDragEnd,
      maxHeight: maxCardHeight,
    );
  }
}
