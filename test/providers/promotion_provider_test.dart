import 'dart:async';
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
  /// Build a quote payload with a distinguishing duration, resolved after [delay].
  Map<String, Object?> quotePayload({
    required String quoteId,
    required int durationDays,
    String? kub8AmountRaw,
  }) {
    return <String, Object?>{
      'quoteId': quoteId,
      'rateCardId': 'rate-1',
      'rateCardVersion': 'v1',
      'entityType': 'artwork',
      'entityId': 'art-1',
      'placementTier': 'boost',
      'durationDays': durationDays,
      'slotAvailable': true,
      'allowedPaymentMethods': <Object?>['fiat_card', if (kub8AmountRaw != null) 'kub8_spl'],
      'pricing': <String, Object?>{
        'fiatPricePerDay': '4.00',
        'kub8PricePerDay': '2.00',
        'baseFiatAmount': '${4 * durationDays}',
        'baseKub8Amount': '${2 * durationDays}',
        'discountPercent': '0',
        'finalFiatAmount': '${4 * durationDays}',
        'fiatCurrency': 'EUR',
        'finalKub8Amount': '${2 * durationDays}',
        'finalKub8AmountRaw': kub8AmountRaw,
      },
      if (kub8AmountRaw != null)
        'kub8': <String, Object?>{
          'mintAddress': 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
          'decimals': 6,
          'amountRaw': kub8AmountRaw,
          'amount': '${2 * durationDays}',
          'cluster': 'devnet',
          'destinationOwner': 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
          'destinationTokenAccount': 'TreasuryTokenAccount1111',
        },
      'schedule': <String, Object?>{
        'startAt': '2026-06-20T00:00:00.000Z',
        'endAt': '2026-06-27T00:00:00.000Z',
        'cancellationDeadlineAt': '2026-06-19T00:00:00.000Z',
      },
      'isRefundable': true,
      'expiresAt': '2099-01-01T00:00:00.000Z',
    };
  }

  test('a slow earlier quote response cannot overwrite a newer one', () async {
    final completers = <int, Completer<void>>{
      7: Completer<void>(),
      30: Completer<void>(),
    };
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final durationDays = body['durationDays'] as int;
        // Hold the 7-day response open until the 30-day response has already landed.
        final gate = completers[durationDays]!;
        await gate.future;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': quotePayload(
              quoteId: 'quote-$durationDays',
              durationDays: durationDays,
            ),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final provider = PromotionProvider(api: api);

    // Request A (7 days) then request B (30 days); B resolves first.
    final requestA = provider.requestQuote(
      rateCardId: 'rate-1',
      durationDays: 7,
      entityType: PromotionEntityType.artwork,
      targetEntityId: 'art-1',
    );
    final requestB = provider.requestQuote(
      rateCardId: 'rate-1',
      durationDays: 30,
      entityType: PromotionEntityType.artwork,
      targetEntityId: 'art-1',
    );

    completers[30]!.complete();
    final quoteB = await requestB;
    expect(quoteB, isNotNull);
    expect(provider.currentQuote?.durationDays, 30);

    completers[7]!.complete();
    final quoteA = await requestA;

    // The stale response is discarded rather than written to state.
    expect(quoteA, isNull);
    expect(provider.currentQuote?.durationDays, 30);
    expect(provider.currentQuote?.quoteId, 'quote-30');
  });

  test('a slow earlier availability response cannot overwrite a newer one',
      () async {
    final completers = <int, Completer<void>>{
      1: Completer<void>(),
      2: Completer<void>(),
    };
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        final slotCount =
            request.url.queryParameters['startDate']!.contains('2026-07') ? 2 : 1;
        final gate = completers[slotCount]!;
        await gate.future;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'rateCardId': 'rate-1',
              'slotCount': slotCount,
              'isSlotBased': true,
              'available': true,
              'slots': <Object?>[
                for (var index = 1; index <= slotCount; index += 1)
                  <String, Object?>{
                    'slotIndex': index,
                    'isAvailable': true,
                    'bookings': const <Object?>[],
                  },
              ],
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final provider = PromotionProvider(api: api);
    final first = provider.checkSlotAvailability(
      rateCardId: 'rate-1',
      startDate: DateTime.utc(2026, 6, 1),
      endDate: DateTime.utc(2026, 6, 8),
    );
    final second = provider.checkSlotAvailability(
      rateCardId: 'rate-1',
      startDate: DateTime.utc(2026, 7, 1),
      endDate: DateTime.utc(2026, 7, 8),
    );

    completers[2]!.complete();
    await second;
    expect(provider.currentSlotAvailability?.slotCount, 2);

    completers[1]!.complete();
    expect(await first, isNull);
    expect(provider.currentSlotAvailability?.slotCount, 2);
  });

  test('a new quote request clears the previous quote immediately', () async {
    final gate = Completer<void>();
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    var calls = 0;
    api.setHttpClient(
      MockClient((request) async {
        calls += 1;
        if (calls > 1) await gate.future;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': quotePayload(quoteId: 'quote-$calls', durationDays: 7),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final provider = PromotionProvider(api: api);
    await provider.requestQuote(
      rateCardId: 'rate-1',
      durationDays: 7,
      entityType: PromotionEntityType.artwork,
      targetEntityId: 'art-1',
    );
    expect(provider.currentQuote, isNotNull);

    final pending = provider.requestQuote(
      rateCardId: 'rate-1',
      durationDays: 14,
      entityType: PromotionEntityType.artwork,
      targetEntityId: 'art-1',
    );
    // While a newer quote is in flight the old price must not remain submittable.
    expect(provider.currentQuote, isNull);
    expect(provider.quoteLoading, isTrue);

    gate.complete();
    await pending;
    expect(provider.currentQuote?.quoteId, 'quote-2');
  });

  test('invalidateQuote drops a quote that no longer matches the selection', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': quotePayload(quoteId: 'quote-1', durationDays: 7),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final provider = PromotionProvider(api: api);
    await provider.requestQuote(
      rateCardId: 'rate-1',
      durationDays: 7,
      entityType: PromotionEntityType.artwork,
      targetEntityId: 'art-1',
    );
    expect(provider.currentQuote, isNotNull);

    provider.invalidateQuote();
    expect(provider.currentQuote, isNull);
  });

  test('submitPromotionRequest sends the quote id and the idempotency key',
      () async {
    Map<String, dynamic>? sentBody;
    String? sentHeader;
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        sentHeader = request.headers['Idempotency-Key'];
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'req-1',
              'targetEntityId': 'art-1',
              'entityType': 'artwork',
              'rateCardId': 'rate-1',
              'placementTier': 'boost',
              'durationDays': 7,
              'calculatedFiatPrice': 28.0,
              'calculatedKub8Price': 14.0,
              'discountAppliedPercent': 0,
              'paymentMethod': 'kub8_spl',
              'paymentStatus': 'awaiting_payment',
              'reviewStatus': 'pending_review',
              'quoteId': 'quote-1',
              'kub8Payment': <String, Object?>{
                'mintAddress': 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
                'decimals': 6,
                'amountRaw': '14000000',
                'amount': '14',
                'cluster': 'devnet',
                'destinationOwner': 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
              },
            },
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final provider = PromotionProvider(api: api);
    final submission = await provider.submitPromotionRequest(
      quoteId: 'quote-1',
      paymentMethod: PromotionPaymentMethod.kub8Spl,
      idempotencyKey: 'idem-1',
    );

    expect(sentBody?['quoteId'], 'quote-1');
    expect(sentBody?['idempotencyKey'], 'idem-1');
    expect(sentHeader, 'idem-1');
    expect(submission?.kub8Payment?.amountRaw, BigInt.parse('14000000'));
  });

  test('a KUB8 payment signs the exact raw amount and confirms after verification',
      () async {
    BigInt? signedAmount;
    String? signedMint;
    int? signedDecimals;
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/kub8-payment')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['signature'], 'sig-1');
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'request': <String, Object?>{
                  'id': 'req-1',
                  'targetEntityId': 'art-1',
                  'entityType': 'artwork',
                  'rateCardId': 'rate-1',
                  'placementTier': 'boost',
                  'durationDays': 7,
                  'calculatedFiatPrice': 28.0,
                  'calculatedKub8Price': 14.0,
                  'discountAppliedPercent': 0,
                  'paymentMethod': 'kub8_spl',
                  'paymentStatus': 'captured',
                  'reviewStatus': 'pending_review',
                },
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final provider = PromotionProvider(api: api);
    final submission = PromotionRequestSubmission(
      request: PromotionRequest(
        id: 'req-1',
        targetEntityId: 'art-1',
        entityType: PromotionEntityType.artwork,
        rateCardId: 'rate-1',
        placementTier: PromotionPlacementTier.boost,
        durationDays: 7,
        calculatedFiatPrice: 28.0,
        calculatedKub8Price: 14.0,
        discountAppliedPercent: 0,
        paymentMethod: PromotionPaymentMethod.kub8Spl,
        paymentStatus: 'awaiting_payment',
        reviewStatus: 'pending_review',
      ),
      kub8Payment: PromotionQuoteKub8(
        mintAddress: 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
        decimals: 6,
        amountRaw: BigInt.parse('14000000'),
        amount: '14',
        cluster: 'devnet',
        destinationOwner: 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
      ),
    );

    final outcome = await provider.payPromotionWithKub8(
      submission: submission,
      signer: ({
        required String mintAddress,
        required String destinationOwner,
        required BigInt rawAmount,
        required int decimals,
      }) async {
        signedMint = mintAddress;
        signedAmount = rawAmount;
        signedDecimals = decimals;
        return 'sig-1';
      },
    );

    // The wallet signs the integer the backend issued, unchanged.
    expect(signedAmount, BigInt.parse('14000000'));
    expect(signedMint, 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm');
    expect(signedDecimals, 6);
    expect(outcome.isConfirmed, isTrue);
    expect(provider.kub8Stage, Kub8PaymentStage.confirmed);
    expect(provider.pendingKub8Signature, isNull);
  });

  test('a user-rejected wallet signature never reaches verification', () async {
    var verificationCalls = 0;
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        verificationCalls += 1;
        return http.Response('{}', 200);
      }),
    );

    final provider = PromotionProvider(api: api);
    final outcome = await provider.payPromotionWithKub8(
      submission: PromotionRequestSubmission(
        request: PromotionRequest(
          id: 'req-1',
          targetEntityId: 'art-1',
          entityType: PromotionEntityType.artwork,
          rateCardId: 'rate-1',
          placementTier: PromotionPlacementTier.boost,
          durationDays: 7,
          calculatedFiatPrice: 28.0,
          calculatedKub8Price: 14.0,
          discountAppliedPercent: 0,
          paymentMethod: PromotionPaymentMethod.kub8Spl,
          paymentStatus: 'awaiting_payment',
          reviewStatus: 'pending_review',
        ),
        kub8Payment: PromotionQuoteKub8(
          mintAddress: 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
          decimals: 6,
          amountRaw: BigInt.parse('14000000'),
          amount: '14',
          cluster: 'devnet',
          destinationOwner: 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
        ),
      ),
      signer: ({
        required String mintAddress,
        required String destinationOwner,
        required BigInt rawAmount,
        required int decimals,
      }) async {
        throw Exception('User rejected the transaction');
      },
    );

    expect(outcome.stage, Kub8PaymentStage.failed);
    expect(outcome.message, contains('User rejected'));
    expect(verificationCalls, 0);
  });

  test('an unconfirmed transfer keeps its signature for retry instead of re-signing',
      () async {
    var attempts = 0;
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((request) async {
        attempts += 1;
        if (attempts == 1) {
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
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'request': <String, Object?>{
                'id': 'req-1',
                'targetEntityId': 'art-1',
                'entityType': 'artwork',
                'rateCardId': 'rate-1',
                'placementTier': 'boost',
                'durationDays': 7,
                'calculatedFiatPrice': 28.0,
                'calculatedKub8Price': 14.0,
                'discountAppliedPercent': 0,
                'paymentMethod': 'kub8_spl',
                'paymentStatus': 'captured',
                'reviewStatus': 'pending_review',
              },
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final provider = PromotionProvider(api: api);
    var signCount = 0;
    final submission = PromotionRequestSubmission(
      request: PromotionRequest(
        id: 'req-1',
        targetEntityId: 'art-1',
        entityType: PromotionEntityType.artwork,
        rateCardId: 'rate-1',
        placementTier: PromotionPlacementTier.boost,
        durationDays: 7,
        calculatedFiatPrice: 28.0,
        calculatedKub8Price: 14.0,
        discountAppliedPercent: 0,
        paymentMethod: PromotionPaymentMethod.kub8Spl,
        paymentStatus: 'awaiting_payment',
        reviewStatus: 'pending_review',
      ),
      kub8Payment: PromotionQuoteKub8(
        mintAddress: 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
        decimals: 6,
        amountRaw: BigInt.parse('14000000'),
        amount: '14',
        cluster: 'devnet',
        destinationOwner: 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
      ),
    );

    final first = await provider.payPromotionWithKub8(
      submission: submission,
      signer: ({
        required String mintAddress,
        required String destinationOwner,
        required BigInt rawAmount,
        required int decimals,
      }) async {
        signCount += 1;
        return 'sig-1';
      },
    );

    expect(first.needsVerificationRetry, isTrue);
    expect(provider.pendingKub8Signature, 'sig-1');

    // Retrying verifies the SAME signature; the user is never asked to pay twice.
    final second = await provider.verifyPendingKub8Payment(
      requestId: 'req-1',
      signature: provider.pendingKub8Signature!,
    );
    expect(second.isConfirmed, isTrue);
    expect(signCount, 1);
  });
}
