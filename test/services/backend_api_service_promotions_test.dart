import 'dart:convert';

import 'package:art_kubus/models/promotion.dart';
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

  test('getPublicFeaturedHome reads items from nested data envelope', () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/public/featured-home');
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
                    'title': 'Featured artwork',
                    'artist': 'Artist One',
                    'imageUrl': '/uploads/featured.jpg',
                  },
                  'promotion': <String, Object?>{
                    'isPromoted': true,
                    'placementMode': 'rotation_pool',
                  },
                },
              ],
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final items = await api.getPublicFeaturedHome(
      kind: PromotionEntityType.artwork,
      locale: 'en',
    );

    expect(items, hasLength(1));
    expect(items.first.id, 'art-1');
    expect(items.first.title, 'Featured artwork');
    expect(items.first.promotion.isPromoted, isTrue);
  });

  test('createPromotionRequest preserves checkoutUrl in submission result',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/app/promotion-requests');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'req-1',
              'targetEntityId': 'art-1',
              'entityType': 'artwork',
              'packageId': 'pkg-1',
              'paymentMethod': 'fiat_card',
              'paymentStatus': 'pending',
              'reviewStatus': 'pending_review',
              'checkoutUrl': 'https://checkout.example/session-1',
            },
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final submission = await api.createPromotionRequest(
      targetEntityId: 'art-1',
      entityType: PromotionEntityType.artwork,
      packageId: 'pkg-1',
      paymentMethod: PromotionPaymentMethod.fiatCard,
    );

    expect(submission.request.id, 'req-1');
    expect(submission.request.paymentMethod, PromotionPaymentMethod.fiatCard);
    expect(
      submission.checkoutUrl,
      'https://checkout.example/session-1',
    );
  });

  test(
      'getPublicFeaturedHome uses top-level fallback values when nested entity is sparse',
      () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/public/featured-home');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'kind': 'profile',
              'locale': 'en',
              'items': <Object?>[
                <String, Object?>{
                  'entityType': 'profile',
                  'id': 'wallet-artist-1',
                  'title': 'Featured Artist',
                  'subtitle': 'Contemporary painter',
                  'walletAddress': 'wallet-artist-1',
                  'imageUrl': '/uploads/artist-1.png',
                  'entity': <String, Object?>{
                    'bio': 'Sparse nested payload',
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
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final items = await api.getPublicFeaturedHome(
      kind: PromotionEntityType.profile,
      locale: 'en',
    );

    expect(items, hasLength(1));
    expect(items.first.id, 'wallet-artist-1');
    expect(items.first.title, 'Featured Artist');
    expect(items.first.subtitle, 'Contemporary painter');
    expect(items.first.walletAddress, 'wallet-artist-1');
    expect(items.first.imageUrl, '/uploads/artist-1.png');
  });
}
