import 'dart:convert';

import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('loadHomeRails stores ranked rails from the public home endpoint',
      () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/public/home-rails');
        expect(request.url.queryParameters['locale'], 'en');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'locale': 'en',
              'generatedAt': '2026-04-01T10:00:00.000Z',
              'rails': <Object?>[
                <String, Object?>{
                  'entityType': 'artwork',
                  'rail': 'home_artworks',
                  'label': 'artwork',
                  'items': <Object?>[
                    <String, Object?>{
                      'id': 'art-1',
                      'entityType': 'artwork',
                      'title': 'Promoted Artwork',
                      'subtitle': 'Artist One',
                      'imageUrl': '/uploads/art-1.png',
                      'href': '/a/art-1',
                      'promotion': <String, Object?>{
                        'isPromoted': true,
                        'placementMode': 'priority_ranked',
                      },
                    },
                  ],
                },
                <String, Object?>{
                  'entityType': 'profile',
                  'rail': 'home_artists',
                  'label': 'artist',
                  'items': const <Object?>[],
                },
              ],
            },
          }),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    final provider = PromotionProvider(api: api);

    await expectLater(provider.loadHomeRails(locale: 'en'), completes);

    expect(provider.error, isNull);
    expect(provider.lastFeaturedLocale, 'en');
    expect(provider.homeRails, hasLength(2));
    expect(provider.railItemsFor(PromotionEntityType.artwork), hasLength(1));
    expect(
        provider.railItemsFor(PromotionEntityType.artwork).first.id, 'art-1');
    expect(provider.railItemsFor(PromotionEntityType.profile), isEmpty);
  });

  test('loadHomeRails keeps startup-safe behavior when the endpoint fails',
      () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/public/home-rails');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'home rails unavailable',
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    final provider = PromotionProvider(api: api);

    await expectLater(provider.loadHomeRails(locale: 'en'), completes);

    expect(provider.homeRails, isEmpty);
    expect(provider.error, isNotNull);
  });
}
