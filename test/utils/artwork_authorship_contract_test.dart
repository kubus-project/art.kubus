import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/artwork_authorship.dart';
import 'package:art_kubus/utils/home_rail_creator_identity.dart';
import 'package:art_kubus/utils/search_suggestions.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cultural authorship is the explicit artist only. The uploader, owner wallet
/// and photographer never stand in for it, on any surface.
const _uploaderWallet = 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb';

Map<String, dynamic> _detail({String? artistName}) => {
      'id': 'work-1',
      'title': 'A work',
      'artistName': artistName,
      'walletAddress': _uploaderWallet,
      'imageAuthor': 'Different Photographer',
    };

HomeRailItem _railItem({String? artistName}) =>
    HomeRailItem.fromJson(<String, dynamic>{
      'id': 'work-1',
      'entityType': 'artwork',
      'title': 'A work',
      // What the backend used to put on the card: the uploader's profile.
      'subtitle': artistName,
      'artistName': artistName,
      'creatorDisplayName': 'Different Uploader',
      'creatorUsername': 'uploader',
      'creatorWalletAddress': _uploaderWallet,
    });

void main() {
  group('parse boundary', () {
    test('a recorded artist is kept', () {
      final artwork =
          parseArtworkFromBackendJson(_detail(artistName: 'Recorded Artist'));
      expect(artwork.artist, 'Recorded Artist');
      expect(artwork.recordedArtist, 'Recorded Artist');
    });

    test('the uploader wallet is never promoted to the artist', () {
      final artwork = parseArtworkFromBackendJson(_detail());
      expect(artwork.artist, isEmpty);
      expect(artwork.recordedArtist, isNull);
    });

    test('a blank artist field does not shadow the recorded artistName', () {
      final artwork = parseArtworkFromBackendJson({
        ..._detail(artistName: 'Recorded Artist'),
        'artist': '   ',
      });
      expect(artwork.recordedArtist, 'Recorded Artist');
    });

    test('"Unknown" is unattributed, not an author', () {
      expect(
        parseArtworkFromBackendJson(_detail(artistName: 'Unknown'))
            .recordedArtist,
        isNull,
      );
    });
  });

  group('home rail card', () {
    const unknown = 'Unknown artist';

    test('recorded artist wins and is plain text, not a profile link', () {
      final identity = resolveArtworkHomeRailCreator(
        _railItem(artistName: 'Recorded Artist'),
        fallbackLabel: unknown,
      )!;
      expect(identity.label, 'Recorded Artist');
      expect(identity.canOpenProfile, isFalse);
    });

    test('an unattributed artwork is Unknown, never the uploader', () {
      final identity = resolveArtworkHomeRailCreator(
        _railItem(),
        fallbackLabel: unknown,
      )!;
      expect(identity.label, unknown);
      expect(identity.label, isNot(contains('Different Uploader')));
      expect(identity.canOpenProfile, isFalse);
    });
  });

  group('search', () {
    test('an artwork suggestion without an artist has no invented subtitle',
        () {
      final out = normalizeSearchSuggestionsPayload([
        {
          'type': 'artwork',
          'id': '4e380159-2269-4e02-b206-3a0d2fdecb82',
          'label': 'kubus 1.0',
          'username': 'uploader',
          'walletAddress': _uploaderWallet,
        },
      ]);
      final result = KubusSearchResult.fromMap(out.single);
      expect(result.label, 'kubus 1.0');
      expect(result.detail, isNull);
      expect(result.data.toString(), isNot(contains('@uploader')));
    });

    test('a recorded artist is the artwork subtitle', () {
      final out = normalizeSearchSuggestionsPayload([
        {
          'type': 'artwork',
          'id': 'work-1',
          'label': 'Robba Fountain',
          'subtitle': 'Francesco Robba',
        },
      ]);
      expect(KubusSearchResult.fromMap(out.single).detail, 'Francesco Robba');
    });
  });

  group('edit authorship', () {
    Artwork withArtist(String artist) =>
        parseArtworkFromBackendJson(_detail(artistName: artist));

    test('setting an author on an unattributed artwork is sent', () {
      expect(
        artistNameUpdateFor(withArtist(''), '  Recorded Artist '),
        'Recorded Artist',
      );
    });

    test('an unchanged field is not sent', () {
      expect(
          artistNameUpdateFor(withArtist('Recorded Artist'), 'Recorded Artist'),
          isNull);
      expect(artistNameUpdateFor(withArtist(''), '   '), isNull);
    });

    test('clearing sends a blank so the backend stores no author', () {
      expect(artistNameUpdateFor(withArtist('Recorded Artist'), ''), '');
    });
  });
}
