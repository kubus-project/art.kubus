import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/presence_marker_visit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('presenceVisitFromMarker resolves subject type + id', () {
    final marker = ArtMarker(
      id: 'm1',
      name: 'Marker',
      description: '',
      position: const LatLng(46.05, 14.50),
      type: ArtMarkerType.other,
      metadata: const {
        'subjectType': 'event',
        'subjectId': 'event_123',
      },
      createdAt: DateTime(2025, 1, 1),
      createdBy: 'system',
    );

    final visit = presenceVisitFromMarker(marker);
    expect(visit, isNotNull);
    expect(visit!.type, 'event');
    expect(visit.id, 'event_123');
  });

  test('shouldRecordPresenceVisitForMarker enforces 10m radius', () {
    final marker = ArtMarker(
      id: 'm2',
      name: 'Marker',
      description: '',
      position: const LatLng(46.05, 14.50),
      type: ArtMarkerType.artwork,
      artworkId: 'art_1',
      metadata: const {
        'subjectType': 'artwork',
        'subjectId': 'art_1',
      },
      createdAt: DateTime(2025, 1, 1),
      createdBy: 'system',
    );

    expect(
      shouldRecordPresenceVisitForMarker(
        marker: marker,
        userLocation: const LatLng(46.05, 14.50),
      ),
      isTrue,
    );

    // ~11m north (latitude delta ~0.0001deg).
    expect(
      shouldRecordPresenceVisitForMarker(
        marker: marker,
        userLocation: const LatLng(46.0501, 14.50),
      ),
      isFalse,
    );
  });
}

