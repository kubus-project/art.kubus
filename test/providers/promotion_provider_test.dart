import 'dart:convert';

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

  test('loadFeaturedHome keeps artwork results when profile request fails',
      () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/public/featured-home') {
          return http.Response(
            jsonEncode(<String, Object?>{'success': false}),
            404,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        final kind = request.url.queryParameters['kind'];
        if (kind == 'artwork') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'kind': 'artwork',
                'locale': 'en',
                'items': <Object?>[
                  <String, Object?>{
                    'entityType': 'artwork',
                    'entity': <String, Object?>{
                      'id': 'art-1',
                      'title': 'Promoted Artwork',
                      'artistName': 'Artist One',
                      'imageURL': '/uploads/art-1.png',
                    },
                    'promotion': <String, Object?>{
                      'isPromoted': true,
                      'placementMode': 'priority_ranked',
                    },
                  },
                ],
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Profiles rail unavailable',
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    final provider = PromotionProvider(api: api);

    await expectLater(provider.loadFeaturedHome(locale: 'en'), completes);

    expect(provider.featuredArtworks, hasLength(1));
    expect(provider.featuredArtworks.first.id, 'art-1');
    expect(provider.featuredProfiles, isEmpty);
    expect(provider.error, isNotNull);
  });
}
