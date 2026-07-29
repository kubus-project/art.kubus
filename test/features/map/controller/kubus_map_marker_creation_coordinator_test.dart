import 'dart:typed_data';

import 'package:art_kubus/features/map/controller/kubus_map_marker_creation_coordinator.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/map_marker_subject.dart';
import 'package:art_kubus/widgets/map_marker_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const messages = KubusMapMarkerCreationMessages(
    createFailed: 'create failed',
    walletRequired: 'wallet required',
    imageAuthorRequired: 'author required',
    imageLicenseRequired: 'license required',
  );
  const snappedPosition = LatLng(46.0569, 14.5058);
  final createdAt = DateTime.utc(2026, 7, 29);

  Artwork artwork() => Artwork(
        id: 'artwork-1',
        walletAddress: 'wallet-1',
        title: 'Street art',
        artist: 'Artist',
        description: 'Description',
        imageUrl: 'https://cdn.example/cover.jpg',
        position: snappedPosition,
        rewards: 0,
        createdAt: createdAt,
      );

  ArtMarker marker() => ArtMarker(
        id: 'marker-1',
        name: 'Street art',
        description: 'Description',
        position: snappedPosition,
        type: ArtMarkerType.streetArt,
        artworkId: 'artwork-1',
        createdAt: createdAt,
        createdBy: 'wallet-1',
      );

  MapMarkerFormResult form({
    String? imageAuthor = 'Photographer',
    String? imageLicense = 'CC BY 4.0',
  }) {
    return MapMarkerFormResult(
      title: 'Street art',
      description: 'Description',
      category: 'graffiti',
      markerType: ArtMarkerType.streetArt,
      subjectType: MarkerSubjectType.streetArt,
      isPublic: true,
      isCommunity: false,
      coverImageBytes: Uint8List.fromList(const <int>[1, 2, 3]),
      coverImageFileName: 'cover.jpg',
      coverImageFileType: 'image/jpeg',
      imageAuthor: imageAuthor,
      imageLicense: imageLicense,
    );
  }

  KubusStreetArtArtworkCreator artworkCreator(Artwork createdArtwork) {
    return ({
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
    }) async {
      expect(coverImageUrl, 'https://cdn.example/cover.jpg');
      expect(walletAddress, 'wallet-1');
      expect(position, snappedPosition);
      expect(imageAuthor, 'Photographer');
      expect(imageLicense, 'CC BY 4.0');
      return createdArtwork;
    };
  }

  KubusStreetArtCoverUploader coverUploader() {
    return ({
      required Uint8List fileBytes,
      required String? fileName,
      required String? fileType,
      required String? walletAddress,
      required String source,
      required String debugLabel,
    }) async {
      expect(fileBytes, isNotEmpty);
      expect(source, 'map_marker_creation_coordinator');
      return 'https://cdn.example/cover.jpg';
    };
  }

  test(
    'persists street art and synchronizes shared provider callbacks',
    () async {
      final createdArtwork = artwork();
      final persistedMarker = marker();
      final ingestedMarkers = <ArtMarker>[];
      final upsertedArtworks = <Artwork>[];
      Map<String, dynamic>? persistedMetadata;

      final coordinator = KubusMapMarkerCreationCoordinator(
        coverUploader: coverUploader(),
        artworkCreator: artworkCreator(createdArtwork),
        artworkRollback: (
          Artwork? artwork, {
          required bool markerPersistenceAttempted,
        }) async {
          fail('Successful persistence must not roll back its artwork.');
        },
        markerPersister: ({
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
        }) async {
          expect(location, snappedPosition);
          expect(artworkId, createdArtwork.id);
          persistedMetadata = metadata;
          return persistedMarker;
        },
      );

      final outcome = await coordinator.createMarker(
        position: const LatLng(46.0, 14.0),
        currentZoom: 16,
        form: form(),
        walletAddress: 'wallet-1',
        messages: messages,
        ingestMarker: ingestedMarkers.add,
        upsertArtwork: upsertedArtworks.add,
        linkExhibitionMarkers: (_, __) async {},
        linkExhibitionArtworks: (_, __) async {},
        snapToVisibleGrid: (_, __) => snappedPosition,
      );

      expect(outcome.marker, same(persistedMarker));
      expect(outcome.error, isNull);
      expect(ingestedMarkers, <ArtMarker>[persistedMarker]);
      expect(upsertedArtworks, <Artwork>[createdArtwork]);
      expect(
        persistedMetadata,
        containsPair('createdFrom', 'map_marker_creation_coordinator'),
      );
      expect(
        persistedMetadata,
        containsPair('coverImageAttribution', 'Photographer / CC BY 4.0'),
      );
    },
  );

  test(
    'does not roll back after an ambiguous marker persistence result',
    () async {
      var rollbackCalls = 0;
      final coordinator = KubusMapMarkerCreationCoordinator(
        coverUploader: coverUploader(),
        artworkCreator: artworkCreator(artwork()),
        artworkRollback: (
          Artwork? artwork, {
          required bool markerPersistenceAttempted,
        }) async {
          rollbackCalls++;
        },
        markerPersister: ({
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
        }) async {
          return null;
        },
      );

      final outcome = await coordinator.createMarker(
        position: snappedPosition,
        currentZoom: 16,
        form: form(),
        walletAddress: 'wallet-1',
        messages: messages,
        ingestMarker: (_) {},
        upsertArtwork: (_) {},
        linkExhibitionMarkers: (_, __) async {},
        linkExhibitionArtworks: (_, __) async {},
      );

      expect(outcome.succeeded, isFalse);
      expect(rollbackCalls, 0);
    },
  );

  test(
    'returns localized validation error before marker persistence',
    () async {
      var persistenceCalls = 0;
      final coordinator = KubusMapMarkerCreationCoordinator(
        coverUploader: coverUploader(),
        artworkCreator: artworkCreator(artwork()),
        markerPersister: ({
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
        }) async {
          persistenceCalls++;
          return marker();
        },
      );

      final outcome = await coordinator.createMarker(
        position: snappedPosition,
        currentZoom: 16,
        form: form(imageAuthor: ''),
        walletAddress: 'wallet-1',
        messages: messages,
        ingestMarker: (_) {},
        upsertArtwork: (_) {},
        linkExhibitionMarkers: (_, __) async {},
        linkExhibitionArtworks: (_, __) async {},
      );

      expect(outcome.marker, isNull);
      expect((outcome.error as StateError).message, 'author required');
      expect(persistenceCalls, 0);
    },
  );
}
