import 'package:art_kubus/models/institution.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payload({
  Object? kind,
  String type = 'institution',
  Map<String, dynamic>? visitorAccess,
  Object? coverAttribution,
}) {
  return <String, dynamic>{
    'id': 'inst-kind',
    'name': 'Kind check',
    'description': '',
    'type': type,
    if (kind != null) 'kind': kind,
    'address': 'Main Street',
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
    if (visitorAccess != null) 'visitorAccess': visitorAccess,
    if (coverAttribution != null) 'coverAttribution': coverAttribution,
  };
}

void main() {
  group('InstitutionKind', () {
    test('exact backend kind codes map to their kind', () {
      expect(InstitutionKind.resolve(kind: 'museum'), InstitutionKind.museum);
      expect(InstitutionKind.resolve(kind: 'gallery'), InstitutionKind.gallery);
      expect(InstitutionKind.resolve(kind: 'arts_centre'),
          InstitutionKind.artsCentre);
      expect(InstitutionKind.resolve(kind: 'exhibition_space'),
          InstitutionKind.exhibitionSpace);
      expect(InstitutionKind.resolve(kind: 'cultural_centre'),
          InstitutionKind.culturalCentre);
      expect(InstitutionKind.resolve(kind: 'other'), InstitutionKind.other);
    });

    test('exact kind wins over the lossy legacy type guess', () {
      // The backend guesses type "cultural_center" for arts centres too.
      expect(
        InstitutionKind.resolve(kind: 'arts_centre', type: 'cultural_center'),
        InstitutionKind.artsCentre,
      );
    });

    test('unrecognised exact codes resolve to other, not to raw text', () {
      expect(InstitutionKind.resolve(kind: 'archive'), InstitutionKind.other);
      expect(InstitutionKind.resolve(kind: ' Library '), InstitutionKind.other);
    });

    test('legacy type is used only when kind is absent', () {
      expect(InstitutionKind.resolve(type: 'museum'), InstitutionKind.museum);
      expect(InstitutionKind.resolve(type: 'gallery'), InstitutionKind.gallery);
      expect(InstitutionKind.resolve(type: 'cultural_center'),
          InstitutionKind.culturalCentre);
      expect(InstitutionKind.resolve(type: 'education'), isNull);
      expect(InstitutionKind.resolve(type: 'institution'), isNull);
      expect(InstitutionKind.resolve(kind: '  ', type: 'gallery'),
          InstitutionKind.gallery);
    });

    test('Institution reads kind and exposes the resolved kind', () {
      final institution = Institution.fromJson(_payload(kind: 'museum'));
      expect(institution.kind, 'museum');
      expect(institution.institutionKind, InstitutionKind.museum);
      expect(institution.toJson()['kind'], 'museum');
      expect(
        Institution.fromJson(institution.toJson()).institutionKind,
        InstitutionKind.museum,
      );
    });

    test('payloads without kind keep working through the type guess', () {
      final institution =
          Institution.fromJson(_payload(type: 'museum', kind: null));
      expect(institution.kind, isNull);
      expect(institution.institutionKind, InstitutionKind.museum);
      expect(institution.toJson().containsKey('kind'), isFalse);
    });

    test('blank kind is treated as absent', () {
      final institution =
          Institution.fromJson(_payload(kind: '   ', type: 'gallery'));
      expect(institution.kind, isNull);
      expect(institution.institutionKind, InstitutionKind.gallery);
    });
  });

  group('image licence name', () {
    test('derives the short CC name from the canonical licence URL', () {
      const bySa4 = InstitutionImageAttribution(
        licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      );
      const by2 = InstitutionImageAttribution(
        licenseUrl: 'https://creativecommons.org/licenses/by/2.0/',
      );
      const zero = InstitutionImageAttribution(
        licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      );
      expect(bySa4.licenseName, 'CC BY-SA 4.0');
      expect(by2.licenseName, 'CC BY 2.0');
      expect(zero.licenseName, 'CC0 1.0');
      expect(bySa4.isPublicDomain, isFalse);
    });

    test('recognises the public domain mark without a CC name', () {
      const mark = InstitutionImageAttribution(
        licenseUrl: 'https://creativecommons.org/publicdomain/mark/1.0/',
      );
      expect(mark.licenseName, isNull);
      expect(mark.isPublicDomain, isTrue);
    });

    test('unknown or non-CC licence URLs have no derived name', () {
      const other = InstitutionImageAttribution(
        licenseUrl: 'https://example.test/license',
      );
      const badVersion = InstitutionImageAttribution(
        licenseUrl: 'https://creativecommons.org/licenses/by-sa/four/',
      );
      const unknownType = InstitutionImageAttribution(
        licenseUrl: 'https://creativecommons.org/licenses/xyz/4.0/',
      );
      expect(other.licenseName, isNull);
      expect(badVersion.licenseName, isNull);
      expect(unknownType.licenseName, isNull);
      expect(const InstitutionImageAttribution().licenseName, isNull);
    });
  });

  group('visitor access', () {
    Institution withVisitorInfo(Map<String, dynamic> info) {
      return Institution.fromJson(_payload(visitorAccess: {
        'status': 'approved',
        'sourceUrl': 'https://example.test/visit',
        'verifiedAt': '2026-11-02T12:00:00.000Z',
        'visitorInfo': info,
        'bookingUrl': null,
      }));
    }

    test('reads opening hours, accessibility and known admission', () {
      final access = withVisitorInfo({
        'openingHoursText': '  Tue-Sun 10:00-18:00  ',
        'admission': 'Free',
        'accessibilityNote': 'Step-free entrance.',
      }).visitorAccess!;
      expect(access.openingHoursText, 'Tue-Sun 10:00-18:00');
      expect(access.accessibilityNote, 'Step-free entrance.');
      expect(access.admission, InstitutionAdmission.free);
      expect(access.admissionText, isNull);
    });

    test('free-form admission is kept as text, unknown is dropped', () {
      final free = withVisitorInfo({'admission': '5 EUR weekdays'})
          .visitorAccess!;
      expect(free.admission, isNull);
      expect(free.admissionText, '5 EUR weekdays');

      final unknown =
          withVisitorInfo({'admission': 'unknown'}).visitorAccess!;
      expect(unknown.admission, isNull);
      expect(unknown.admissionText, isNull);
    });

    test('blank or non-string visitor fields are treated as absent', () {
      final access = withVisitorInfo({
        'openingHoursText': '   ',
        'admission': 42,
        'accessibilityNote': null,
        'excerpt': 'Evidence text that is not displayed.',
      }).visitorAccess!;
      expect(access.openingHoursText, isNull);
      expect(access.admission, isNull);
      expect(access.admissionText, isNull);
      expect(access.accessibilityNote, isNull);
    });

    test('parses every admission category', () {
      expect(InstitutionAdmission.parse('paid'), InstitutionAdmission.paid);
      expect(InstitutionAdmission.parse(' MIXED '), InstitutionAdmission.mixed);
      expect(InstitutionAdmission.parse(null), isNull);
    });
  });
}
