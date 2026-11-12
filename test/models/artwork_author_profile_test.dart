import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payload([Map<String, dynamic>? extra]) =>
    <String, dynamic>{
      'id': 'art-1',
      'title': 'Title',
      'artist': 'Free Text Artist',
      'description': 'Desc',
      'latitude': 46.0,
      'longitude': 14.0,
      'created_at': '2026-01-01T00:00:00.000Z',
      ...?extra,
    };

void main() {
  group('parseArtworkFromBackendJson authorProfile', () {
    test('an old payload without the key parses with no author profile', () {
      final artwork = parseArtworkFromBackendJson(_payload());
      expect(artwork.authorProfile, isNull);
      expect(artwork.artist, 'Free Text Artist');
    });

    test('passes the explicit author profile through', () {
      final artwork = parseArtworkFromBackendJson(_payload({
        'authorProfile': {
          'profileId': '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
          'username': 'damjan_stevovic',
          'displayName': 'Damjan Stevovic',
        },
      }));
      expect(
        artwork.authorProfile,
        const ArtworkAuthorProfile(
          profileId: '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
          username: 'damjan_stevovic',
          displayName: 'Damjan Stevovic',
        ),
      );
      // The free-text artist name stays a separate concept.
      expect(artwork.artist, 'Free Text Artist');
    });

    test('garbage shapes degrade to null instead of throwing', () {
      for (final garbage in <Object?>[
        null,
        'nope',
        42,
        <Object?>[],
        <String, dynamic>{},
        <String, dynamic>{'username': 'no_id'},
        <String, dynamic>{'profileId': '  ', 'username': 'x'},
        <String, dynamic>{'profileId': 'p-1'},
        <String, dynamic>{
          'profileId': {'nested': true},
          'username': 'x'
        },
      ]) {
        final artwork =
            parseArtworkFromBackendJson(_payload({'authorProfile': garbage}));
        expect(artwork.authorProfile, isNull, reason: '$garbage');
      }
    });

    test('never derives a profile from uploader or wallet fields', () {
      final artwork = parseArtworkFromBackendJson(_payload({
        'walletAddress': 'So1Wallet',
        'creatorId': '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
        'uploader': {'username': 'uploader'},
      }));
      expect(artwork.authorProfile, isNull);
    });
  });

  group('Artwork model', () {
    test('toMap/fromMap round trips the author profile and omits null', () {
      final artwork = parseArtworkFromBackendJson(_payload({
        'authorProfile': {
          'profileId': 'p-1',
          'username': 'u',
          'displayName': 'D',
        },
      }));
      final restored = Artwork.fromMap(artwork.toMap());
      expect(restored.authorProfile, artwork.authorProfile);

      final plain = parseArtworkFromBackendJson(_payload());
      expect(plain.toMap().containsKey('authorProfile'), isFalse);
      expect(Artwork.fromMap(plain.toMap()).authorProfile, isNull);
    });

    test('copyWith keeps the author profile and can clear it explicitly', () {
      final artwork = parseArtworkFromBackendJson(_payload({
        'authorProfile': {
          'profileId': 'p-1',
          'username': 'u',
          'displayName': 'D',
        },
      }));
      expect(artwork.copyWith(title: 'x').authorProfile, artwork.authorProfile);
      expect(
        artwork.copyWith(clearAuthorProfile: true).authorProfile,
        isNull,
      );
    });
  });
}
