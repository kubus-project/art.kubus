import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/models/institution.dart';

Map<String, dynamic> _institutionJson({Object? verifiedAccountProfile}) => {
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'name': 'City Museum',
      'description': '',
      'type': 'museum',
      'address': '',
      'latitude': 46.05,
      'longitude': 14.50,
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
      'createdAt': '2026-11-04T00:00:00.000Z',
      'claimState': 'claimed',
      if (verifiedAccountProfile != null)
        'verifiedAccountProfile': verifiedAccountProfile,
    };

void main() {
  test(
      'parses the explicit linked public profile without treating a claim as a link',
      () {
    final institution = Institution.fromJson(_institutionJson(
      verifiedAccountProfile: {
        'profileId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'userId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'username': 'citymuseum',
        'displayName': 'City Museum',
        'allowMessages': false,
      },
    ));
    expect(institution.verifiedAccountProfile?.profileId,
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    expect(institution.verifiedAccountProfile?.username, 'citymuseum');
    expect(institution.verifiedAccountProfile?.allowMessages, isFalse);
    expect(institution.copyWith().verifiedAccountProfile?.userId,
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
  });

  test('a claimed institution without explicit linked profile stays unlinked',
      () {
    final institution = Institution.fromJson(_institutionJson());
    expect(institution.verifiedAccountProfile, isNull);
    expect(institution.toJson().containsKey('verifiedAccountProfile'), isFalse);
  });

  test(
      'malformed linked identity is omitted instead of guessed from venue or membership fields',
      () {
    final institution = Institution.fromJson(_institutionJson(
      verifiedAccountProfile: {
        'userId': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
      },
    ));
    expect(institution.verifiedAccountProfile, isNull);
  });

  test('a blank or missing username is kept as no username, never as a handle',
      () {
    for (final username in <Object?>['', '   ', null]) {
      final institution = Institution.fromJson(_institutionJson(
        verifiedAccountProfile: {
          'profileId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'userId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'username': username,
          'displayName': 'City Museum',
          'allowMessages': true,
        },
      ));
      expect(institution.verifiedAccountProfile, isNotNull,
          reason: 'username=$username');
      expect(institution.verifiedAccountProfile?.username, isNull,
          reason: 'username=$username');
      expect(institution.verifiedAccountProfile?.displayName, 'City Museum');
    }
  });

  test('a user id is optional: a walletless public profile still parses', () {
    final institution = Institution.fromJson(_institutionJson(
      verifiedAccountProfile: {
        'profileId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'userId': null,
        'username': 'citymuseum',
        'displayName': null,
        'allowMessages': true,
      },
    ));
    expect(institution.verifiedAccountProfile?.userId, isNull);
    expect(institution.verifiedAccountProfile?.username, 'citymuseum');
    expect(institution.verifiedAccountProfile?.allowMessages, isTrue);
  });
}
