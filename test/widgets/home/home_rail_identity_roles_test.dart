import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';

HomeRailItem _profile(Map<String, dynamic> extra) {
  return HomeRailItem.fromJson(<String, dynamic>{
    'id': 'artist_wallet_1',
    'entityType': PromotionEntityType.profile.apiValue,
    'title': 'Maya',
    'stats': <String, dynamic>{},
    ...extra,
  });
}

void main() {
  group('home rail identity roles', () {
    test('a rail payload without role fields states no role', () {
      final data = ProfileIdentityData.fromHomeRailItem(
        _profile(const <String, dynamic>{}),
        fallbackLabel: 'Artist',
      );
      expect(data.isArtist, isFalse);
      expect(data.roleStatements.isArtistSpecified, isFalse);
    });

    test('a cached artist keeps the badge when the rail payload is silent', () {
      final data = ProfileIdentityData.fromHomeRailItem(
        _profile(const <String, dynamic>{}),
        fallbackLabel: 'Artist',
        cachedRoles: const ProfileIdentityRoles(
          isArtist: true,
          isArtistSpecified: true,
        ),
      );
      expect(data.isArtist, isTrue);
      expect(data.isInstitution, isFalse);
    });

    test('a stated false in the rail payload revokes a cached artist', () {
      final data = ProfileIdentityData.fromHomeRailItem(
        _profile(const <String, dynamic>{'isArtist': false}),
        fallbackLabel: 'Artist',
        cachedRoles: const ProfileIdentityRoles(
          isArtist: true,
          isArtistSpecified: true,
        ),
      );
      expect(data.isArtist, isFalse);
    });

    test('an ordinary cached user gets no badge from an unstated cache', () {
      final data = ProfileIdentityData.fromHomeRailItem(
        _profile(const <String, dynamic>{}),
        fallbackLabel: 'Visitor',
        cachedRoles: ProfileIdentityRoles.none,
      );
      expect(data.isArtist, isFalse);
      expect(data.isVerified, isFalse);
      expect(data.hasRoleBadge, isFalse);
    });

    test('an institution rail item stays an institution with a silent cache',
        () {
      final data = ProfileIdentityData.fromHomeRailItem(
        HomeRailItem.fromJson(<String, dynamic>{
          'id': 'inst_1',
          'entityType': PromotionEntityType.institution.apiValue,
          'title': 'Gallery',
          'stats': <String, dynamic>{},
        }),
        fallbackLabel: 'Institution',
        cachedRoles: ProfileIdentityRoles.none,
      );
      expect(data.isInstitution, isTrue);
    });
  });
}
