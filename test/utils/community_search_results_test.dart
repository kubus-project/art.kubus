import 'package:art_kubus/utils/community_search_results.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped like `GET /api/search?q=...&type=institutions` on the migrated
/// schema (backend `src/routes/search.js`): `results` keyed by kind, the
/// institution row carries `institutionType: null` and `artworkCount: null`.
Map<String, dynamic> _searchResponse({
  List<String> degradedKinds = const [],
}) =>
    {
      'success': true,
      'query': 'gal',
      'type': 'institutions',
      'totalResults': 2,
      'page': 1,
      'degradedKinds': degradedKinds,
      'results': {
        'institutions': [
          {
            'type': 'institution',
            'id': 'inst-moderna',
            'name': 'Moderna galerija',
            'description': 'Contemporary art in Ljubljana',
            'institutionType': null,
            'website': 'https://mg-lj.si',
            'location': 'Ljubljana',
            'coordinates': {'lat': 46.05, 'lng': 14.5},
            'logoUrl': '/uploads/institutions/inst-moderna/logo.png',
            'bannerUrl': '/uploads/institutions/inst-moderna/banner.jpg',
            'artworkCount': null,
          },
          {
            'type': 'institution',
            'id': 'inst-galerija-nova',
            'name': 'Galerija Nova',
            'description': null,
            'institutionType': null,
            'website': null,
            'location': null,
            'coordinates': null,
            'logoUrl': null,
            'bannerUrl': null,
            'artworkCount': null,
          },
        ],
      },
    };

void main() {
  group('communitySearchRows', () {
    test('reads the institutions key for an institutions request', () {
      final rows = communitySearchRows(_searchResponse(), 'institutions');

      expect(rows, hasLength(2));
      expect(rows.first['id'], 'inst-moderna');
      expect(rows.first['name'], 'Moderna galerija');
      expect(rows.first['institutionType'], isNull);
      expect(rows.first['artworkCount'], isNull);
      expect(rows.last['name'], 'Galerija Nova');
    });

    test('does not read the all key the backend never returns', () {
      expect(communitySearchRows(_searchResponse(), 'all'), isEmpty);
    });

    test('reads profiles and artworks by their own keys', () {
      final response = {
        'success': true,
        'results': {
          'profiles': [
            {
              'type': 'profile',
              'walletAddress': 'Wallet1',
              'username': 'rok',
              'displayName': 'Rok',
            },
          ],
          'artworks': [
            {'type': 'artwork', 'id': 'art-1', 'title': 'Fountain'},
          ],
        },
      };

      expect(
          communitySearchRows(response, 'profiles').single['username'], 'rok');
      expect(communitySearchRows(response, 'artworks').single['id'], 'art-1');
      expect(communitySearchRows(response, 'institutions'), isEmpty);
    });

    test('falls back to the legacy data list only when results has no key', () {
      final legacy = {
        'success': true,
        'data': [
          {'id': 'legacy-1', 'name': 'Legacy'},
          'not-a-map',
        ],
      };

      expect(
          communitySearchRows(legacy, 'institutions').single['id'], 'legacy-1');
    });

    test('keeps an empty results key empty instead of falling back', () {
      final response = {
        'success': true,
        'data': [
          {'id': 'legacy-1'},
        ],
        'results': {'institutions': <dynamic>[]},
      };

      expect(communitySearchRows(response, 'institutions'), isEmpty);
    });

    test('tolerates malformed containers without throwing', () {
      expect(communitySearchRows(const {}, 'institutions'), isEmpty);
      expect(
        communitySearchRows(
          const {
            'results': {'institutions': 'nope'},
          },
          'institutions',
        ),
        isEmpty,
      );
    });
  });

  group('communitySearchKindDegraded', () {
    test('is true for a kind the backend reports as degraded', () {
      expect(
        communitySearchKindDegraded(
          _searchResponse(degradedKinds: const ['institutions']),
          'institutions',
        ),
        isTrue,
      );
    });

    test('is false for a kind that is not degraded', () {
      expect(
        communitySearchKindDegraded(
          _searchResponse(degradedKinds: const ['institutions']),
          'profiles',
        ),
        isFalse,
      );
    });

    test('ignores unknown kinds and missing or malformed degradedKinds', () {
      expect(
        communitySearchKindDegraded(
          _searchResponse(degradedKinds: const ['holograms']),
          'institutions',
        ),
        isFalse,
      );
      expect(communitySearchKindDegraded(const {}, 'institutions'), isFalse);
      expect(
        communitySearchKindDegraded(
          const {'degradedKinds': 'institutions'},
          'institutions',
        ),
        isFalse,
      );
    });
  });
}
