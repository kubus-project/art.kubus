import 'dart:math' as math;
import 'dart:typed_data';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:latlong2/latlong.dart';

/// Shared fixtures for the spatial capture and library tests.
///
/// Kept in one place so the association, continuation and revision suites all
/// agree on what "a capture with real coverage" means.

/// A policy that samples on demand rather than on a wall clock, so a test can
/// push frames as fast as it likes without sleeping.
const SpatialCapturePolicy eagerPolicy = SpatialCapturePolicy(
  minSampleInterval: Duration.zero,
);

/// Frames spread evenly around a subject, so coverage actually accumulates.
///
/// A capture built from these reaches finish eligibility the same way a real
/// walk-around does: viewpoint diversity plus baseline, not frame count.
Map<String, dynamic> orbitFrame(int index) {
  final angle = (index / 12) * 2 * math.pi;
  return <String, dynamic>{
    'rgb': Uint8List.fromList(List<int>.filled(3, 1)),
    'timestampNanos': index,
    'poseTranslation': <double>[math.cos(angle), 0.0, math.sin(angle)],
    'poseRotation': <double>[
      0.0,
      math.sin(angle / 2),
      0.0,
      math.cos(angle / 2),
    ],
    'intrinsics': <String, dynamic>{'width': 640, 'height': 480},
    'depthAvailable': false,
  };
}

/// Pushes [count] orbiting frames into [capture], starting at [from].
///
/// [from] lets a continuation carry on around the same orbit rather than
/// retracing viewpoints the capture already has.
Future<void> pushOrbit(
  SpatialCaptureProvider capture, {
  required int count,
  int from = 0,
}) async {
  for (var index = from; index < from + count; index++) {
    await capture.offerFrame(orbitFrame(index), isTracking: true);
  }
}

/// A minimal artwork with a stable id and title.
Artwork artworkFixture(
  String id, {
  String? title,
  String artist = 'Maja Novak',
  String? arMarkerId,
  String? walletAddress,
}) =>
    Artwork(
      id: id,
      title: title ?? 'Artwork $id',
      artist: artist,
      description: 'Fixture',
      position: const LatLng(46.0569, 14.5058),
      rewards: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      category: 'Mural',
      arMarkerId: arMarkerId,
      walletAddress: walletAddress,
    );

/// A library record with no processing history, for action and display tests.
SpatialLibraryRecord recordFixture({
  required String localSpatialId,
  required String artworkId,
  String? markerId,
  String? displayName,
  String? artworkTitleSnapshot,
  String? artistNameSnapshot,
  String? markerLabelSnapshot,
  int sampleCount = 24,
  int sourceBytes = 1024,
  bool rawPresent = true,
  int revision = 1,
  SpatialLibraryProcessingState processingState =
      SpatialLibraryProcessingState.capturedPrivate,
  SpatialLibraryPublicationState publicationState =
      SpatialLibraryPublicationState.private,
  SpatialNetworkRequest? networkRequest,
  double? coverage,
}) {
  final now = DateTime.utc(2026, 8, 19);
  return SpatialLibraryRecord(
    localSpatialId: localSpatialId,
    artworkId: artworkId,
    markerId: markerId,
    displayName: displayName,
    artworkTitleSnapshot: artworkTitleSnapshot,
    artistNameSnapshot: artistNameSnapshot,
    markerLabelSnapshot: markerLabelSnapshot,
    capturedAt: now,
    updatedAt: now,
    sourcePath: rawPresent ? 'private/$localSpatialId/source' : '',
    sampleCount: sampleCount,
    sourceBytes: rawPresent ? sourceBytes : 0,
    hasDepth: true,
    rawPresent: rawPresent,
    revision: revision,
    processingState: processingState,
    publicationState: publicationState,
    networkRequest: networkRequest,
    coverageMetadata: coverage == null
        ? const <String, dynamic>{}
        : <String, dynamic>{'progress': coverage},
  );
}
