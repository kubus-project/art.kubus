import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for hotfix requirement D: linked-subject identity must
/// normalize identically from top-level, metadata, and nested metadata payload
/// shapes, and a transport `markerType` must never override a more specific
/// subject declaration.
void main() {
  Map<String, dynamic> baseMarker(Map<String, dynamic> extra) {
    return <String, dynamic>{
      'id': 'marker-1',
      'name': 'Ponjava VI',
      'description': 'A marker description.',
      'latitude': 46.0569,
      'longitude': 14.5058,
      'createdAt': '2026-07-01T10:00:00.000Z',
      'createdBy': 'tester',
      ...extra,
    };
  }

  group('subject identity normalization', () {
    test('reads subject fields from metadata', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'markerType': 'event',
          'metadata': <String, dynamic>{
            'subjectType': 'exhibition',
            'subjectId': '8a1d8347-fada-4755-95d2-6024519c93cd',
            'subjectTitle': 'Ponjava VI',
          },
        }),
      );

      expect(marker.subjectType, 'exhibition');
      expect(marker.subjectId, '8a1d8347-fada-4755-95d2-6024519c93cd');
      expect(marker.subjectTitle, 'Ponjava VI');
    });

    test('promotes top-level subject fields into the marker getters', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'markerType': 'geolocation',
          'subjectType': 'event',
          'subjectId': 'evt-1',
          'subjectTitle': 'Opening night',
          'subjectCategory': 'Performance',
        }),
      );

      expect(marker.subjectType, 'event');
      expect(marker.subjectId, 'evt-1');
      expect(marker.subjectTitle, 'Opening night');
      expect(marker.subjectCategory, 'Performance');
      expect(marker.type, ArtMarkerType.event);
    });

    test('reads snake_case top-level subject fields', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'subject_type': 'exhibition',
          'subject_id': 'exh-1',
          'subject_title': 'Group show',
        }),
      );

      expect(marker.subjectType, 'exhibition');
      expect(marker.subjectId, 'exh-1');
      expect(marker.subjectTitle, 'Group show');
      expect(marker.type, ArtMarkerType.exhibition);
    });

    test('reads nested metadata subject fields', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'metadata': <String, dynamic>{
            'metadata': <String, dynamic>{
              'subjectType': 'event',
              'subjectId': 'evt-nested',
              'subjectTitle': 'Nested event',
            },
          },
        }),
      );

      expect(marker.subjectType, 'event');
      expect(marker.subjectId, 'evt-nested');
      expect(marker.subjectTitle, 'Nested event');
    });

    test('existing metadata subject values win over top-level duplicates', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'subjectId': 'top-level-id',
          'metadata': <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'metadata-id',
          },
        }),
      );

      expect(marker.subjectId, 'metadata-id');
    });

    test('exhibition summaries resolve from a promoted top-level subject', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'subjectType': 'exhibition',
          'subjectId': 'exh-42',
          'subjectTitle': 'Retrospective',
        }),
      );

      expect(marker.resolvedExhibitionSummary?.id, 'exh-42');
      expect(marker.resolvedExhibitionSummary?.title, 'Retrospective');
    });
  });

  group('transport markerType does not override the subject declaration', () {
    test('exhibition subject beats an event transport type (Ponjava VI shape)',
        () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'markerType': 'event',
          'type': 'geolocation',
          'metadata': <String, dynamic>{
            'subjectType': 'exhibition',
            'subjectId': '8a1d8347-fada-4755-95d2-6024519c93cd',
          },
        }),
      );

      expect(marker.type, ArtMarkerType.exhibition);
      expect(marker.isExhibitionMarker, isTrue);
      expect(marker.isEventSubject, isFalse);
    });

    test('event subject beats an exhibition transport type', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'markerType': 'exhibition',
          'metadata': <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'evt-7',
          },
        }),
      );

      expect(marker.type, ArtMarkerType.event);
      expect(marker.isEventSubject, isTrue);
      // A declared event subject must never be treated as an exhibition marker,
      // or the quick card and the More info route disagree about the entity.
      expect(marker.isExhibitionMarker, isFalse);
      expect(marker.resolvedExhibitionSummary, isNull);
    });

    test('event subject beats an artwork transport type', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'markerType': 'artwork',
          'metadata': <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'evt-8',
          },
        }),
      );

      expect(marker.type, ArtMarkerType.event);
    });

    test('transport-only subject values fall back to markerType', () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'markerType': 'streetArt',
          'metadata': <String, dynamic>{'subjectType': 'geolocation'},
        }),
      );

      expect(marker.type, ArtMarkerType.streetArt);
    });
  });

  group('marker-carried subject context', () {
    test('exposes location and schedule metadata for badge/subtitle fallback',
        () {
      final marker = ArtMarker.fromMap(
        baseMarker(<String, dynamic>{
          'metadata': <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'evt-9',
            'locationName': 'Kino Siska',
            'startsAt': '2026-08-01T18:00:00.000Z',
            'endsAt': '2026-08-10T20:00:00.000Z',
          },
        }),
      );

      expect(marker.locationName, 'Kino Siska');
      expect(marker.subjectStartsAt, isNotNull);
      expect(marker.subjectEndsAt, isNotNull);
      expect(marker.subjectDateRangeLabel, contains('->'));
    });

    test('collapses a single-day range to one date', () {
      final label = ArtMarker.formatMarkerDateRange(
        DateTime.utc(2026, 8, 1, 6),
        DateTime.utc(2026, 8, 1, 18),
      );
      expect(label, isNotNull);
      expect(label, isNot(contains('->')));
    });

    test('returns null when the marker carries no schedule', () {
      final marker = ArtMarker.fromMap(baseMarker(<String, dynamic>{}));
      expect(marker.subjectDateRangeLabel, isNull);
      expect(marker.locationName, isNull);
    });
  });
}
