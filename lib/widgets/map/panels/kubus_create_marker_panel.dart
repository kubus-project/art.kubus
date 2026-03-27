import 'package:flutter/material.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/map_marker_subject.dart';
import '../../../utils/map_marker_subject_loader.dart';
import '../../map_marker_dialog.dart';
import '../../map_overlay_blocker.dart';
import '../kubus_map_glass_surface.dart';
import 'kubus_marker_form_content.dart';

/// Desktop sidebar panel for creating a map marker.
///
/// Matches the visual style of [KubusNearbyArtPanel] in
/// [KubusNearbyArtPanelLayout.desktopSidePanel] mode: full-height glass
/// surface with a left border and shadow.
class KubusCreateMarkerPanel extends StatelessWidget {
  const KubusCreateMarkerPanel({
    super.key,
    required this.subjectData,
    required this.onRefreshSubjects,
    required this.initialPosition,
    this.allowManualPosition = false,
    this.mapCenter,
    this.onUseMapCenter,
    this.initialSubjectType = MarkerSubjectType.artwork,
    this.allowedSubjectTypes,
    this.blockedArtworkIds = const {},
    required this.onSubmit,
    required this.onCancel,
  });

  final MarkerSubjectData subjectData;
  final Future<MarkerSubjectData?> Function({bool force}) onRefreshSubjects;
  final LatLng initialPosition;
  final bool allowManualPosition;
  final LatLng? mapCenter;
  final VoidCallback? onUseMapCenter;
  final MarkerSubjectType initialSubjectType;
  final Set<MarkerSubjectType>? allowedSubjectTypes;
  final Set<String> blockedArtworkIds;
  final ValueChanged<MapMarkerFormResult> onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.sm,
      ),
      child: KubusMarkerFormContent(
        subjectData: subjectData,
        onRefreshSubjects: onRefreshSubjects,
        initialPosition: initialPosition,
        allowManualPosition: allowManualPosition,
        mapCenter: mapCenter,
        onUseMapCenter: onUseMapCenter,
        initialSubjectType: initialSubjectType,
        allowedSubjectTypes: allowedSubjectTypes,
        blockedArtworkIds: blockedArtworkIds,
        onSubmit: onSubmit,
        onCancel: onCancel,
      ),
    );

    // Glass panel surface matching nearby art sidebar style.
    content = buildKubusMapGlassSurface(
      context: context,
      kind: KubusMapGlassSurfaceKind.panel,
      borderRadius: BorderRadius.zero,
      tintBase: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      showBorder: false,
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withValues(
                alpha: KubusGlassEffects.shadowOpacityLight,
              ),
          blurRadius: 16,
          offset: const Offset(-4, 0),
        ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(
                    alpha: KubusGlassEffects.glassBorderOpacityStrong,
                  ),
            ),
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(
                    alpha: KubusGlassEffects.glassBorderOpacityStrong,
                  ),
            ),
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(
                    alpha: KubusGlassEffects.glassBorderOpacityStrong,
                  ),
            ),
          ),
        ),
        child: content,
      ),
    );

    // Pointer interception so the map doesn't receive events.
    return MapOverlayBlocker(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: (_) {},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      ),
    );
  }
}
