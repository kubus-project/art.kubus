import 'package:art_kubus/features/map/shared/map_marker_overlay_presentation.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker({
  required String name,
  required String description,
  String? artworkId,
  Map<String, dynamic>? metadata,
  List<ExhibitionSummaryDto> exhibitionSummaries =
      const <ExhibitionSummaryDto>[],
}) {
  return ArtMarker(
    id: 'marker-1',
    name: name,
    description: description,
    position: const LatLng(46.0569, 14.5058),
    artworkId: artworkId,
    type: ArtMarkerType.artwork,
    metadata: metadata,
    exhibitionSummaries: exhibitionSummaries,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

Artwork _artwork({
  required String title,
  required String description,
}) {
  return Artwork(
    id: 'art-1',
    title: title,
    artist: 'Artist',
    description: description,
    position: const LatLng(46.0569, 14.5058),
    rewards: 0,
    createdAt: DateTime(2024, 1, 1),
    category: 'Painting',
  );
}

KubusEvent _event() {
  return KubusEvent(
    id: 'event-1',
    title: 'City Walk',
    description: 'Event description',
    startsAt: DateTime(2025, 5, 1),
    endsAt: DateTime(2025, 5, 3),
    locationName: 'Ljubljana',
    coverUrl: 'https://example.test/event.jpg',
    updatedAt: DateTime(2025, 4, 20),
  );
}

Exhibition _exhibition() {
  return Exhibition(
    id: 'exh-1',
    title: 'Summer Show',
    description: 'Exhibition description',
    startsAt: DateTime(2025, 6, 1),
    endsAt: DateTime(2025, 6, 10),
    locationName: 'Gallery K',
    coverUrl: 'https://example.test/exhibition.jpg',
    updatedAt: DateTime(2025, 5, 20),
  );
}

void main() {
  group('resolveMarkerOverlayPresentation', () {
    test('uses marker title and description first for artwork-linked markers',
        () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(
          name: 'North Entrance',
          description: 'Use the north plaza marker copy.',
          artworkId: 'art-1',
          metadata: const <String, dynamic>{
            'subjectType': 'artwork',
            'subjectId': 'art-1',
            'subjectTitle': 'Main Artwork',
          },
        ),
        artwork: _artwork(
          title: 'Main Artwork',
          description: 'Artwork description fallback',
        ),
      );

      expect(presentation.title, 'North Entrance');
      expect(presentation.description, 'Use the north plaza marker copy.');
      expect(
        presentation.linkedSubject.kind,
        MapMarkerOverlayLinkedSubjectKind.artwork,
      );
      expect(presentation.linkedSubject.title, 'Main Artwork');
      expect(
        presentation.primaryTarget,
        MapMarkerOverlayPrimaryTarget.artwork,
      );
    });

    test('uses hydrated exhibition content in the quick details presentation',
        () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(
          name: 'Hall B Marker',
          description: 'Second room entry point.',
          metadata: const <String, dynamic>{
            'subjectType': 'exhibition',
            'subjectId': 'exh-1',
            'subjectTitle': 'Summer Show',
            'subjectSubtitle': 'Gallery - 2025-06-01 -> 2025-06-10',
          },
          exhibitionSummaries: const <ExhibitionSummaryDto>[
            ExhibitionSummaryDto(id: 'exh-1', title: 'Summer Show'),
          ],
        ),
        exhibition: _exhibition(),
      );

      expect(presentation.title, 'Summer Show');
      expect(presentation.description, 'Exhibition description');
      expect(
        presentation.linkedSubject.kind,
        MapMarkerOverlayLinkedSubjectKind.exhibition,
      );
      expect(presentation.linkedSubject.id, 'exh-1');
      expect(presentation.linkedSubject.title, 'Summer Show');
      expect(presentation.linkedSubject.subtitle, contains('Gallery K'));
      expect(presentation.linkedSubject.subtitle, contains('2025-06-01'));
      expect(presentation.mediaUrl, 'https://example.test/exhibition.jpg');
      expect(presentation.mediaUpdatedAt, DateTime(2025, 5, 20));
      expect(
        presentation.primaryTarget,
        MapMarkerOverlayPrimaryTarget.exhibition,
      );
    });

    test('resolves event context and target for event-linked markers', () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(
          name: 'Stage Right',
          description: 'Meet beside the installation.',
          metadata: const <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'event-1',
            'subjectTitle': 'Fallback Event',
          },
        ),
        event: _event(),
      );

      expect(presentation.title, 'City Walk');
      expect(presentation.description, 'Event description');
      expect(
        presentation.linkedSubject.kind,
        MapMarkerOverlayLinkedSubjectKind.event,
      );
      expect(presentation.linkedSubject.id, 'event-1');
      expect(presentation.linkedSubject.title, 'City Walk');
      expect(presentation.linkedSubject.subtitle, contains('Ljubljana'));
      expect(presentation.linkedSubject.subtitle, contains('2025-05-01'));
      expect(presentation.mediaUrl, 'https://example.test/event.jpg');
      expect(presentation.mediaUpdatedAt, DateTime(2025, 4, 20));
      expect(
        presentation.primaryTarget,
        MapMarkerOverlayPrimaryTarget.event,
      );
    });

    test('falls back to linked artwork copy when marker fields are blank', () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(
          name: '',
          description: '',
          artworkId: 'art-1',
          metadata: const <String, dynamic>{
            'subjectType': 'artwork',
            'subjectId': 'art-1',
            'subjectTitle': 'Fallback Artwork',
          },
        ),
        artwork: _artwork(
          title: 'Fallback Artwork',
          description: 'Artwork description fallback',
        ),
      );

      expect(presentation.title, 'Fallback Artwork');
      expect(presentation.description, 'Artwork description fallback');
      expect(
        presentation.primaryTarget,
        MapMarkerOverlayPrimaryTarget.artwork,
      );
    });
  });
}
