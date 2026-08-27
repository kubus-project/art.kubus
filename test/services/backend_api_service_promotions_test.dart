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

  test('getPublicHomeRails reads rails from nested data envelope', () async {
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
                      'title': 'Featured artwork',
                      'subtitle': 'Artist One',
                      'imageUrl': '/uploads/featured.jpg',
                      'href': '/a/art-1',
                      'promotion': <String, Object?>{
                        'isPromoted': true,
                        'placementMode': 'rotation_pool',
                      },
                    },
                  ],
                },
              ],
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response = await api.getPublicHomeRails(locale: 'en');

    expect(response.locale, 'en');
    expect(response.rails, hasLength(1));
    expect(response.rails.first.entityType, PromotionEntityType.artwork);
    expect(response.rails.first.items, hasLength(1));
    expect(response.rails.first.items.first.id, 'art-1');
    expect(response.rails.first.items.first.title, 'Featured artwork');
    expect(response.rails.first.items.first.promotion.isPromoted, isTrue);
  });

  test('getPublicHomeRails accepts top-level payloads and limitPerRail',
      () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/public/home-rails');
        expect(request.url.queryParameters['locale'], 'sl');
        expect(request.url.queryParameters['limit'], '4');
        return http.Response(
          jsonEncode(<String, Object?>{
            'locale': 'sl',
            'generatedAt': '2026-04-01T11:00:00.000Z',
            'rails': <Object?>[
              <String, Object?>{
                'entityType': 'profile',
                'rail': 'home_artists',
                'label': 'artist',
                'items': <Object?>[
                  <String, Object?>{
                    'id': 'wallet-artist-1',
                    'entityType': 'profile',
                    'title': 'Featured Artist',
                    'subtitle': 'Contemporary painter',
                    'imageUrl': '/uploads/artist-1.png',
                    'promotion': <String, Object?>{
                      'isPromoted': true,
                      'placementMode': 'priority_ranked',
                    },
                  },
                ],
              },
            ],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response = await api.getPublicHomeRails(
      locale: 'sl',
      limitPerRail: 4,
    );

    expect(response.locale, 'sl');
    expect(response.rails.first.entityType, PromotionEntityType.profile);
    expect(response.rails.first.items.first.id, 'wallet-artist-1');
    expect(response.rails.first.items.first.subtitle, 'Contemporary painter');
    expect(response.rails.first.items.first.imageUrl, '/uploads/artist-1.png');
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
        // Submission references the immutable quote, never raw pricing parameters, so the
        // charged amount cannot drift from what the user accepted.
        expect(requestBody['quoteId'], 'quote-1');
        expect(requestBody['paymentMethod'], 'fiat_card');
        expect(requestBody['idempotencyKey'], 'idem-1');
        expect(requestBody.containsKey('rateCardId'), isFalse);
        expect(requestBody.containsKey('durationDays'), isFalse);
        expect(request.headers['Idempotency-Key'], 'idem-1');
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
      quoteId: 'quote-1',
      paymentMethod: PromotionPaymentMethod.fiatCard,
      idempotencyKey: 'idem-1',
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

  test('createPromotionRequest surfaces the KUB8 payment instruction',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['paymentMethod'], 'kub8_spl');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'req-kub8',
              'targetEntityId': 'art-1',
              'entityType': 'artwork',
              'rateCardId': 'rate-1',
              'placementTier': 'featured',
              'durationDays': 7,
              'calculatedFiatPrice': 77.0,
              'calculatedKub8Price': 238.0,
              'discountAppliedPercent': 0,
              'paymentMethod': 'kub8_spl',
              'paymentStatus': 'awaiting_payment',
              'reviewStatus': 'pending_review',
              'quoteId': 'quote-1',
              'kub8Payment': <String, Object?>{
                'mintAddress': 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
                'decimals': 6,
                'amountRaw': '238000000',
                'amount': '238',
                'cluster': 'devnet',
                'destinationOwner':
                    'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
                'destinationTokenAccount': 'TreasuryTokenAccount1111',
              },
            },
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final submission = await api.createPromotionRequest(
      quoteId: 'quote-1',
      paymentMethod: PromotionPaymentMethod.kub8Spl,
      idempotencyKey: 'idem-kub8',
    );

    // The exact raw amount is carried through untouched: the client signs that integer.
    expect(submission.kub8Payment, isNotNull);
    expect(submission.kub8Payment!.amountRaw, BigInt.parse('238000000'));
    expect(submission.kub8Payment!.decimals, 6);
    expect(
      submission.kub8Payment!.mintAddress,
      'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
    );
    expect(submission.request.awaitsKub8Payment, isTrue);
  });

  test('attachPromotionKub8Payment reports a pending transaction distinctly',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        expect(
            request.url.path, '/api/app/promotion-requests/req-1/kub8-payment');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'pending': true,
            'error': 'Payment transaction is not confirmed yet.',
            'errorCode': 'CHAIN_TRANSACTION_PENDING',
          }),
          202,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    // A pending confirmation is not a failure: the caller must retry verification with the
    // same signature rather than paying again.
    await expectLater(
      api.attachPromotionKub8Payment(requestId: 'req-1', signature: 'sig-1'),
      throwsA(isA<PromotionPaymentPendingException>()),
    );
  });
}
