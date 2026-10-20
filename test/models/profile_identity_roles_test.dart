import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roles stated by an identity payload', () {
    test('reads the nested roles map, flags and verification', () {
      final identity = ProfileIdentityData.fromIdentityPayload(
        {
          'author': {
            'id': 'u1',
            'displayName': 'Ana',
            'roles': {'artist': true, 'institution': true},
            'isVerified': true,
          },
        },
        fallbackLabel: 'Unknown',
      );
      expect(identity.isArtist, isTrue);
      expect(identity.isInstitution, isTrue);
      expect(identity.isVerified, isTrue);
    });

    test('accepts snake_case flags on the author', () {
      final identity = ProfileIdentityData.fromIdentityPayload(
        {
          'author': {
            'id': 'u1',
            'is_institution': 'true',
            'is_verified': 1,
          },
        },
        fallbackLabel: 'Unknown',
      );
      expect(identity.isArtist, isFalse);
      expect(identity.isInstitution, isTrue);
      expect(identity.isVerified, isTrue);
    });

    test('accepts author-prefixed flags beside the author object', () {
      final identity = ProfileIdentityData.fromIdentityPayload(
        {
          'authorIsArtist': true,
          'author_is_verified': true,
          'author': {'id': 'u1'},
        },
        fallbackLabel: 'Unknown',
      );
      expect(identity.isArtist, isTrue);
      expect(identity.isVerified, isTrue);
      expect(identity.isInstitution, isFalse);
    });

    test('a bare flag outside the author object is not the author\'s', () {
      // `isArtist` on a comment/post envelope would describe something else.
      final identity = ProfileIdentityData.fromIdentityPayload(
        {
          'isArtist': true,
          'isVerified': true,
          'author': {'id': 'u1'},
        },
        fallbackLabel: 'Unknown',
      );
      expect(identity.hasRoleBadge, isFalse);
    });

    test('never infers a role from a name, handle or wallet', () {
      final identity = ProfileIdentityData.fromIdentityPayload(
        {
          'author': {
            'id': 'u1',
            'displayName': 'Museum of Modern Art - verified artist',
            'username': 'official_artist_institution',
            'walletAddress': '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
          },
        },
        fallbackLabel: 'Unknown',
      );
      expect(identity.hasRoleBadge, isFalse);
    });

    test('a profile map states its own roles', () {
      final identity = ProfileIdentityData.fromProfileMap(
        {
          'id': 'u1',
          'displayName': 'Gallery',
          'is_institution': true,
          'isVerified': true,
        },
        fallbackLabel: 'Unknown',
      );
      expect(identity.isInstitution, isTrue);
      expect(identity.isVerified, isTrue);
      expect(identity.isArtist, isFalse);
    });
  });

  group('ProfileIdentityRoles', () {
    test('merging keeps every stated role and never removes one', () {
      const a = ProfileIdentityRoles(isArtist: true);
      const b = ProfileIdentityRoles(isInstitution: true, isVerified: true);
      final merged = a.merge(b);
      expect(merged.isArtist, isTrue);
      expect(merged.isInstitution, isTrue);
      expect(merged.isVerified, isTrue);
      expect(ProfileIdentityRoles.none.merge(ProfileIdentityRoles.none).any,
          isFalse);
    });
  });
}
