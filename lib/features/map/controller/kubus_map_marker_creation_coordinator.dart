import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/map_marker_subject.dart';
import '../../../services/map_marker_service.dart';
import '../../../utils/grid_utils.dart';
import '../../../widgets/map_marker_dialog.dart';
import '../shared/map_screen_shared_helpers.dart';

typedef KubusStreetArtCoverUploader = Future<String?> Function({
  required Uint8List fileBytes,
  required String? fileName,
  required String? fileType,
  required String? walletAddress,
  required String source,
  required String debugLabel,
});

typedef KubusStreetArtArtworkCreator = Future<Artwork> Function({
  required String title,
  required String description,
  required String coverImageUrl,
  required String walletAddress,
  required String category,
  required LatLng position,
  required bool isPublic,
  required String? artistName,
  required String imageAuthor,
  required String imageLicense,
});

typedef KubusStreetArtArtworkRollback = Future<void> Function(
  Artwork? artwork, {
  required bool markerPersistenceAttempted,
});

typedef KubusMarkerPersister = Future<ArtMarker?> Function({
  required LatLng location,
  required String title,
  required String description,
  required ArtMarkerType type,
  required String category,
  required String? artworkId,
  required Map<String, dynamic>? metadata,
  required List<String> tags,
  required bool isPublic,
  required double scale,
  required String? modelCID,
  required String? modelURL,
});

typedef KubusExhibitionRelationWriter = Future<void> Function(
    String exhibitionId, List<String> entityIds);

@immutable
class KubusMapMarkerCreationMessages {
  const KubusMapMarkerCreationMessages({
    required this.createFailed,
    required this.walletRequired,
    required this.imageAuthorRequired,
    required this.imageLicenseRequired,
  });

  factory KubusMapMarkerCreationMessages.fromLocalizations(
    AppLocalizations localizations,
  ) {
    return KubusMapMarkerCreationMessages(
      createFailed: localizations.mapMarkerCreateFailedToast,
      walletRequired: localizations.mapMarkerCreateWalletRequired,
      imageAuthorRequired:
          localizations.mapMarkerDialogImageAuthorRequiredError,
      imageLicenseRequired:
          localizations.mapMarkerDialogImageLicenseRequiredError,
    );
  }

  final String createFailed;
  final String walletRequired;
  final String imageAuthorRequired;
  final String imageLicenseRequired;
}

@immutable
class KubusMapMarkerCreationOutcome {
  const KubusMapMarkerCreationOutcome._({this.marker, this.error});

  const KubusMapMarkerCreationOutcome.success(ArtMarker marker)
      : this._(marker: marker);

  const KubusMapMarkerCreationOutcome.failure([Object? error])
      : this._(error: error);

  final ArtMarker? marker;
  final Object? error;

  bool get succeeded => marker != null;
}

/// Owns marker persistence and its related artwork/provider side effects.
///
/// Mobile and desktop map screens supply only their current camera/UI state
/// and consume the returned marker. This keeps artwork creation, marker
/// persistence, rollback safety, metadata, and exhibition linking identical
/// across both surfaces.
class KubusMapMarkerCreationCoordinator {
  KubusMapMarkerCreationCoordinator({
    MapMarkerService? mapMarkerService,
    KubusStreetArtCoverUploader? coverUploader,
    KubusStreetArtArtworkCreator? artworkCreator,
    KubusStreetArtArtworkRollback? artworkRollback,
    KubusMarkerPersister? markerPersister,
  })  : assert(
          mapMarkerService != null || markerPersister != null,
          'A map marker service or marker persister is required.',
        ),
        _coverUploader =
            coverUploader ?? KubusMapMarkerCreationHelpers.uploadStreetArtCover,
        _artworkCreator = artworkCreator ??
            KubusMapMarkerCreationHelpers.createStreetArtArtwork,
        _artworkRollback = artworkRollback ??
            KubusMapMarkerCreationHelpers.rollbackStreetArtArtwork,
        _markerPersister = markerPersister ?? mapMarkerService!.createMarker;

  static const String _source = 'map_marker_creation_coordinator';
  static const String _debugLabel = 'KubusMapMarkerCreationCoordinator';

  final KubusStreetArtCoverUploader _coverUploader;
  final KubusStreetArtArtworkCreator _artworkCreator;
  final KubusStreetArtArtworkRollback _artworkRollback;
  final KubusMarkerPersister _markerPersister;

  Future<KubusMapMarkerCreationOutcome> createMarker({
    required LatLng position,
    required double currentZoom,
    required MapMarkerFormResult form,
    required String? walletAddress,
    required KubusMapMarkerCreationMessages messages,
    required ValueChanged<ArtMarker> ingestMarker,
    required ValueChanged<Artwork> upsertArtwork,
    required KubusExhibitionRelationWriter linkExhibitionMarkers,
    required KubusExhibitionRelationWriter linkExhibitionArtworks,
    LatLng Function(LatLng position, double cameraZoom)? snapToVisibleGrid,
  }) async {
    Artwork? createdStreetArtArtwork;
    var markerPersistenceAttempted = false;

    try {
      String? coverImageUrl;
      if (KubusMapMarkerCreationHelpers.shouldUploadStreetArtCover(
        markerType: form.markerType,
        subjectType: form.subjectType,
        coverImageBytes: form.coverImageBytes,
      )) {
        coverImageUrl = await _coverUploader(
          fileBytes: form.coverImageBytes!,
          fileName: form.coverImageFileName,
          fileType: form.coverImageFileType,
          walletAddress: walletAddress,
          source: _source,
          debugLabel: _debugLabel,
        );
        if (coverImageUrl == null) {
          return const KubusMapMarkerCreationOutcome.failure();
        }
      }

      final requestedPosition = form.positionOverride ?? position;
      final gridCell = GridUtils.gridCellForZoom(
        requestedPosition,
        currentZoom,
      );
      final snappedPosition =
          snapToVisibleGrid?.call(requestedPosition, currentZoom) ??
              gridCell.center;
      final resolvedCategory = form.category.isNotEmpty
          ? form.category
          : form.subject?.type.defaultCategory ??
              form.subjectType.defaultCategory;

      var linkedArtwork = form.linkedArtwork;
      if (KubusMapMarkerCreationHelpers.shouldCreateStreetArtArtwork(
        markerType: form.markerType,
        subjectType: form.subjectType,
        linkedArtwork: linkedArtwork,
      )) {
        final normalizedWallet = (walletAddress ?? '').trim();
        final normalizedAuthor = (form.imageAuthor ?? '').trim();
        final normalizedLicense = (form.imageLicense ?? '').trim();
        if (coverImageUrl == null || coverImageUrl.isEmpty) {
          throw StateError(messages.createFailed);
        }
        if (normalizedWallet.isEmpty) {
          throw StateError(messages.walletRequired);
        }
        if (normalizedAuthor.isEmpty) {
          throw StateError(messages.imageAuthorRequired);
        }
        if (normalizedLicense.isEmpty) {
          throw StateError(messages.imageLicenseRequired);
        }

        createdStreetArtArtwork = await _artworkCreator(
          title: form.title,
          description: form.description,
          coverImageUrl: coverImageUrl,
          walletAddress: normalizedWallet,
          category: resolvedCategory,
          position: snappedPosition,
          isPublic: form.isPublic,
          artistName: form.artistName,
          imageAuthor: normalizedAuthor,
          imageLicense: normalizedLicense,
        );
        linkedArtwork = createdStreetArtArtwork;
      }

      markerPersistenceAttempted = true;
      final marker = await _markerPersister(
        location: snappedPosition,
        title: form.title,
        description: form.description,
        type: form.markerType,
        category: resolvedCategory,
        artworkId: linkedArtwork?.id,
        modelCID: linkedArtwork?.model3DCID,
        modelURL: linkedArtwork?.model3DURL,
        tags: const <String>[],
        isPublic: form.isPublic,
        scale: 1.0,
        metadata: <String, dynamic>{
          'snapZoom': currentZoom,
          'gridAnchor': gridCell.anchorKey,
          'gridLevel': gridCell.gridLevel,
          'gridIndices': <String, dynamic>{
            'u': gridCell.uIndex,
            'v': gridCell.vIndex,
          },
          'createdFrom': _source,
          'subjectType': form.subjectType.name,
          'subjectLabel': form.subjectType.label,
          if (form.subject != null) ...<String, dynamic>{
            'subjectId': form.subject!.id,
            'subjectTitle': form.subject!.title,
            'subjectSubtitle': form.subject!.subtitle,
          },
          if (linkedArtwork != null) ...<String, dynamic>{
            'linkedArtworkId': linkedArtwork.id,
            'linkedArtworkTitle': linkedArtwork.title,
          },
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            'coverImageUrl': coverImageUrl,
          if ((form.artistName ?? '').isNotEmpty) 'artistName': form.artistName,
          if ((form.imageAuthor ?? '').isNotEmpty)
            'imageAuthor': form.imageAuthor,
          if ((form.imageLicense ?? '').isNotEmpty)
            'imageLicense': form.imageLicense,
          if ((form.imageAuthor ?? '').isNotEmpty ||
              (form.imageLicense ?? '').isNotEmpty)
            'coverImageAttribution': <String?>[
              if ((form.imageAuthor ?? '').isNotEmpty) form.imageAuthor,
              if ((form.imageLicense ?? '').isNotEmpty) form.imageLicense,
            ].join(' / '),
          if (form.isCommunity) ...<String, dynamic>{
            'isCommunity': true,
            'community': 'community',
          },
          'visibility': form.isPublic ? 'public' : 'private',
          if (form.subject?.metadata != null) ...form.subject!.metadata!,
        },
      );

      if (marker == null) {
        await _rollbackArtworkIfSafe(
          createdStreetArtArtwork,
          markerPersistenceAttempted: markerPersistenceAttempted,
        );
        return const KubusMapMarkerCreationOutcome.failure();
      }

      final persistedStreetArtArtwork = createdStreetArtArtwork;
      // A persisted marker may already reference the artwork. From this point
      // onward, no local/provider failure may roll that artwork back.
      createdStreetArtArtwork = null;
      _runLocalSync(
        label: 'marker management',
        action: () => ingestMarker(marker),
      );
      if (persistedStreetArtArtwork != null) {
        _runLocalSync(
          label: 'artwork provider',
          action: () => upsertArtwork(persistedStreetArtArtwork),
        );
      }

      if (form.subjectType == MarkerSubjectType.exhibition) {
        final exhibitionId = (form.subject?.id ?? '').trim();
        if (exhibitionId.isNotEmpty) {
          await _writeRelationBestEffort(
            label: 'exhibition marker',
            action: () => linkExhibitionMarkers(exhibitionId, [marker.id]),
          );
          final linkedArtworkId = (linkedArtwork?.id ?? '').trim();
          if (linkedArtworkId.isNotEmpty) {
            await _writeRelationBestEffort(
              label: 'exhibition artwork',
              action: () =>
                  linkExhibitionArtworks(exhibitionId, [linkedArtworkId]),
            );
          }
        }
      }

      return KubusMapMarkerCreationOutcome.success(marker);
    } catch (error) {
      await _rollbackArtworkIfSafe(
        createdStreetArtArtwork,
        markerPersistenceAttempted: markerPersistenceAttempted,
      );
      return KubusMapMarkerCreationOutcome.failure(error);
    }
  }

  Future<void> _rollbackArtworkIfSafe(
    Artwork? artwork, {
    required bool markerPersistenceAttempted,
  }) async {
    if (!KubusMapMarkerCreationHelpers.shouldRollbackStreetArtArtwork(
      artwork: artwork,
      markerPersistenceAttempted: markerPersistenceAttempted,
    )) {
      return;
    }
    await _artworkRollback(artwork, markerPersistenceAttempted: false);
  }

  void _runLocalSync({required String label, required VoidCallback action}) {
    try {
      action();
    } catch (error) {
      AppConfig.debugPrint(
        '$_debugLabel: non-fatal $label update failed: $error',
      );
    }
  }

  Future<void> _writeRelationBestEffort({
    required String label,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error) {
      AppConfig.debugPrint(
        '$_debugLabel: non-fatal $label link failed: $error',
      );
    }
  }
}
