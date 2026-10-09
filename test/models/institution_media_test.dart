import 'package:art_kubus/models/institution.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _institutionJson({
  Object? coverImageUrl,
  Object? logoUrl,
  Object? imageUrls,
}) {
  return <String, dynamic>{
    'id': 'inst-1',
    'name': 'kubus Contemporary',
    'description': '',
    'type': 'gallery',
    'address': 'Central District',
    'latitude': 46.05,
    'longitude': 14.5,
    'contactEmail': '',
    'website': '',
    'stats': <String, dynamic>{
      'totalVisitors': 0,
      'activeEvents': 0,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'createdAt': '2026-07-01T10:00:00.000Z',
    if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (imageUrls != null) 'imageUrls': imageUrls,
  };
}

void main() {
  group('Institution imagery comes from the schema-backed fields', () {
    test('cover and logo are read from their schema names', () {
      final institution = Institution.fromJson(_institutionJson(
        coverImageUrl: '/uploads/cover.jpg',
        logoUrl: '/uploads/logo.png',
      ));
      expect(institution.coverImageUrl, '/uploads/cover.jpg');
      expect(institution.logoUrl, '/uploads/logo.png');
      expect(institution.heroImageRef, '/uploads/cover.jpg');
    });

    test('snake_case schema names are accepted at the boundary', () {
      final institution = Institution.fromJson(_institutionJson()
        ..addAll(<String, dynamic>{
          'cover_image_url': '/uploads/cover.jpg',
          'logo_url': '/uploads/logo.png',
        }));
      expect(institution.coverImageUrl, '/uploads/cover.jpg');
      expect(institution.logoUrl, '/uploads/logo.png');
    });

    test('a logo-only institution uses the logo as its hero', () {
      final institution = Institution.fromJson(_institutionJson(
        logoUrl: '/uploads/logo.png',
      ));
      expect(institution.coverImageUrl, isNull);
      expect(institution.heroImageRef, '/uploads/logo.png');
    });

    test('the legacy imageUrls array maps cover first, logo second', () {
      final institution = Institution.fromJson(_institutionJson(
        imageUrls: <String>['/uploads/cover.jpg', '/uploads/logo.png'],
      ));
      expect(institution.coverImageUrl, '/uploads/cover.jpg');
      expect(institution.logoUrl, '/uploads/logo.png');
    });

    test('schema fields win over the legacy array', () {
      final institution = Institution.fromJson(_institutionJson(
        coverImageUrl: '/uploads/schema-cover.jpg',
        imageUrls: <String>['/uploads/legacy-cover.jpg'],
      ));
      expect(institution.coverImageUrl, '/uploads/schema-cover.jpg');
    });

    test('an institution with no imagery has no hero', () {
      final institution = Institution.fromJson(_institutionJson());
      expect(institution.heroImageRef, isNull);
    });

    test('toJson writes the schema names back', () {
      final json = Institution.fromJson(_institutionJson(
        coverImageUrl: '/uploads/cover.jpg',
        logoUrl: '/uploads/logo.png',
      )).toJson();
      expect(json['coverImageUrl'], '/uploads/cover.jpg');
      expect(json['logoUrl'], '/uploads/logo.png');
      expect(json.containsKey('imageUrls'), isFalse);
    });
  });

  group('Event hero image: cover first, then the first gallery image', () {
    Event eventWith({String? coverUrl, List<String> imageUrls = const []}) {
      return Event(
        id: 'event-1',
        title: 'Opening',
        description: '',
        type: EventType.galleryOpening,
        category: EventCategory.mixedMedia,
        institutionId: 'inst-1',
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 1, 2),
        location: 'Main Hall',
        imageUrls: imageUrls,
        coverUrl: coverUrl,
        createdAt: DateTime.utc(2026, 7, 1),
        createdBy: 'host-1',
      );
    }

    test('the cover wins even when a gallery exists', () {
      final event = eventWith(
        coverUrl: '/uploads/events/cover.png',
        imageUrls: const ['/uploads/events/gallery-1.png'],
      );
      expect(event.heroImageRef, '/uploads/events/cover.png');
      expect(event.imageUrls, const ['/uploads/events/gallery-1.png']);
    });

    test('a gallery image is used when there is no cover', () {
      final event = eventWith(
        imageUrls: const ['/uploads/events/gallery-1.png'],
      );
      expect(event.heroImageRef, '/uploads/events/gallery-1.png');
    });

    test('a blank cover falls back to the gallery', () {
      final event = eventWith(
        coverUrl: '   ',
        imageUrls: const ['/uploads/events/gallery-1.png'],
      );
      expect(event.heroImageRef, '/uploads/events/gallery-1.png');
    });
  });
}
