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

  test('listArtists only sends supported query params', () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/profiles/artists/list');
        expect(request.url.queryParameters['verified'], 'true');
        expect(request.url.queryParameters['limit'], '12');
        expect(request.url.queryParameters['offset'], '4');
        expect(request.url.queryParameters.containsKey('featured'), isFalse);
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': const <Object?>[],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final items = await api.listArtists(
      verified: true,
      limit: 12,
      offset: 4,
    );

    expect(items, isEmpty);
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
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['rateCardId'], 'rate-1');
        expect(requestBody['durationDays'], 7);
        expect(requestBody['slotIndex'], 1);
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'req-1',
              'targetEntityId': 'art-1',
              'entityType': 'artwork',
              'rateCardId': 'rate-1',
              'rateCardCode': 'artwork_premium',
              'placementTier': 'premium',
              'durationDays': 7,
              'selectedSlotIndex': 1,
              'calculatedFiatPrice': 77.0,
              'calculatedKub8Price': 24.0,
              'discountAppliedPercent': 0,
              'scheduledStartAt': '2026-03-20T00:00:00.000Z',
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
      rateCardId: 'rate-1',
      durationDays: 7,
      paymentMethod: PromotionPaymentMethod.fiatCard,
      slotIndex: 1,
    );

    expect(submission.request.id, 'req-1');
    expect(submission.request.rateCardId, 'rate-1');
    expect(submission.request.selectedSlotIndex, 1);
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

  test(
      'getPublicFeaturedHome normalizes profile id to wallet when both uuid and wallet exist',
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
                  'id': '108b0fff-0514-4acc-a508-465e7aa97b87',
                  'walletAddress': 'A1b2C3Wallet',
                  'title': 'Featured Institution',
                  'entity': <String, Object?>{
                    'id': '108b0fff-0514-4acc-a508-465e7aa97b87',
                    'wallet_address': 'A1b2C3Wallet',
                  },
                  'promotion': <String, Object?>{
                    'isPromoted': true,
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
    expect(items.first.walletAddress, 'A1b2C3Wallet');
    expect(items.first.id, 'A1b2C3Wallet');
  });
}
