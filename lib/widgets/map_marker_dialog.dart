import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../models/map_marker_subject.dart';
import '../utils/map_marker_subject_loader.dart';
import 'glass_components.dart';
import 'map/panels/kubus_marker_form_content.dart';

class MapMarkerFormResult {
  final String title;
  final String description;
  final String category;
  final ArtMarkerType markerType;
  final MarkerSubjectType subjectType;
  final MarkerSubjectOption? subject;
  final Artwork? linkedArtwork;
  final bool isPublic;
  final LatLng? positionOverride;

  const MapMarkerFormResult({
    required this.title,
    required this.description,
    required this.category,
    required this.markerType,
    required this.subjectType,
    required this.isPublic,
    this.subject,
    this.linkedArtwork,
    this.positionOverride,
  });
}

class MapMarkerDialog extends StatelessWidget {
  final MarkerSubjectData subjectData;
  final Future<MarkerSubjectData?> Function({bool force}) onRefreshSubjects;
  final LatLng initialPosition;
  final bool allowManualPosition;
  final LatLng? mapCenter;
  final VoidCallback? onUseMapCenter;
  final MarkerSubjectType initialSubjectType;
  final Set<MarkerSubjectType>? allowedSubjectTypes;
  final Set<String> blockedArtworkIds;
  final bool useSheet;

  const MapMarkerDialog({
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
    this.useSheet = false,
  });

  static Future<MapMarkerFormResult?> show({
    required BuildContext context,
    required MarkerSubjectData subjectData,
    required Future<MarkerSubjectData?> Function({bool force}) onRefreshSubjects,
    required LatLng initialPosition,
    bool allowManualPosition = false,
    LatLng? mapCenter,
    VoidCallback? onUseMapCenter,
    MarkerSubjectType initialSubjectType = MarkerSubjectType.artwork,
    Set<MarkerSubjectType>? allowedSubjectTypes,
    Set<String> blockedArtworkIds = const {},
    bool useSheet = false,
  }) {
    if (useSheet) {
      return showModalBottomSheet<MapMarkerFormResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
              child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: KubusSizes.dialogWidthMd + KubusSizes.sidebarActionIconBox,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Material(
                color: Colors.transparent,
                child: MapMarkerDialog(
                  subjectData: subjectData,
                  onRefreshSubjects: onRefreshSubjects,
                  initialPosition: initialPosition,
                  allowManualPosition: allowManualPosition,
                  mapCenter: mapCenter,
                  onUseMapCenter: onUseMapCenter,
                  initialSubjectType: initialSubjectType,
                  allowedSubjectTypes: allowedSubjectTypes,
                  blockedArtworkIds: blockedArtworkIds,
                  useSheet: true,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return showKubusDialog<MapMarkerFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MapMarkerDialog(
        subjectData: subjectData,
        onRefreshSubjects: onRefreshSubjects,
        initialPosition: initialPosition,
        allowManualPosition: allowManualPosition,
        mapCenter: mapCenter,
        onUseMapCenter: onUseMapCenter,
        initialSubjectType: initialSubjectType,
        allowedSubjectTypes: allowedSubjectTypes,
        blockedArtworkIds: blockedArtworkIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * (useSheet ? 0.9 : 0.75);

    if (useSheet) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: KubusGlassEffects.blurSigma,
            sigmaY: KubusGlassEffects.blurSigma,
          ),
          child: Material(
            color: scheme.surface.withValues(alpha: 0.78),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KubusSpacing.md + KubusSpacing.xs,
                KubusSpacing.md + KubusSpacing.xs,
                KubusSpacing.md + KubusSpacing.xs,
                KubusSpacing.sm,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
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
                  onSubmit: (result) => Navigator.of(context).pop(result),
                  onCancel: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return KubusAlertDialog(
      backgroundColor: scheme.surface,
      contentPadding: const EdgeInsets.fromLTRB(
        KubusSpacing.md + KubusSpacing.xs,
        KubusSpacing.md + KubusSpacing.xs,
        KubusSpacing.md + KubusSpacing.xs,
        KubusSpacing.sm + KubusSpacing.xs,
      ),
      title: const SizedBox.shrink(),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
          onSubmit: (result) => Navigator.of(context).pop(result),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
      actions: const [],
    );
  }
}
