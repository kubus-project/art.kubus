import 'package:art_kubus/models/institution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Institution image attribution', () {
    test('reads safe source and license links for each image role', () {
      final institution = Institution.fromJson(_payload(
        coverAttribution: {
          'credit': '  Cover archive  ',
          'sourceUrl': 'https://example.test/cover',
          'licenseUrl': 'http://example.test/license',
        },
        logoAttribution: {
          'credit': 'Institution archive',
          'sourceUrl': 'https://example.test/logo',
        },
      ));

      expect(institution.coverAttribution?.credit, 'Cover archive');
      expect(institution.coverAttribution?.sourceUrl,
          'https://example.test/cover');
      expect(institution.coverAttribution?.licenseUrl,
          'http://example.test/license');
      expect(institution.logoAttribution?.credit, 'Institution archive');
      expect(
          institution.logoAttribution?.sourceUrl, 'https://example.test/logo');
      expect(institution.logoAttribution?.licenseUrl, isNull);
    });

    test('drops malformed objects and unsafe or blank fields', () {
      final institution = Institution.fromJson(_payload(
        coverAttribution: {
          'credit': '  ',
          'sourceUrl': 'javascript:alert(1)',
          'licenseUrl': 'https://user:secret@example.test/license',
        },
        logoAttribution: 'not-an-object',
      ));

      expect(institution.coverAttribution, isNull);
      expect(institution.logoAttribution, isNull);
      expect(
        Institution.fromJson(_payload()).coverAttribution,
        isNull,
      );
    });

    test('compares credit changes by value for provider refresh', () {
      const first = InstitutionImageAttribution(credit: 'First');
      const unchanged = InstitutionImageAttribution(credit: 'First');
      const updated = InstitutionImageAttribution(credit: 'Updated');
      expect(first, unchanged);
      expect(first, isNot(updated));
    });

    test(
        'reads approved visitor information and rejects pending or unsafe data',
        () {
      final data = _payload();
      data['visitorAccess'] = {
        'status': 'approved',
        'sourceUrl': 'https://museum.example/visit',
        'verifiedAt': '2026-11-02T12:00:00Z',
        'visitorInfo': {'admission': 'Free'},
        'bookingUrl': 'https://museum.example/book',
      };
      final institution = Institution.fromJson(data);
      expect(institution.visitorAccess?.visitorInfo['admission'], 'Free');
      expect(
          institution.visitorAccess?.bookingUrl, 'https://museum.example/book');
      expect(Institution.fromJson(institution.toJson()).visitorAccess,
          institution.visitorAccess);
      data['visitorAccess'] = {
        ...data['visitorAccess'] as Map,
        'status': 'needs_review'
      };
      expect(Institution.fromJson(data).visitorAccess, isNull);
      data['visitorAccess'] = {
        ...data['visitorAccess'] as Map,
        'status': 'approved',
        'sourceUrl': 'https://user:pass@museum.example/'
      };
      expect(Institution.fromJson(data).visitorAccess, isNull);
    });
  });
}

Map<String, dynamic> _payload({
  Object? coverAttribution,
  Object? logoAttribution,
}) =>
    {
      'id': 'institution-1',
      'name': 'Example Museum',
      'description': '',
      'type': 'museum',
      'address': '',
      'latitude': 46.05,
      'longitude': 14.5,
      'contactEmail': '',
      'website': '',
      'coverImageUrl': 'https://example.test/cover.png',
      'logoUrl': 'https://example.test/logo.png',
      if (coverAttribution != null) 'coverAttribution': coverAttribution,
      if (logoAttribution != null) 'logoAttribution': logoAttribution,
      'disciplines': [
        {'code': 'painting', 'labelEn': 'Painting', 'labelSl': 'Slikarstvo'},
      ],
      'stats': {
        'totalVisitors': 0,
        'activeEvents': 0,
        'artworkViews': 0,
        'revenue': 0,
        'visitorGrowth': 0,
        'revenueGrowth': 0,
      },
      'isVerified': false,
      'createdAt': '2026-07-01T10:00:00.000Z',
    };
