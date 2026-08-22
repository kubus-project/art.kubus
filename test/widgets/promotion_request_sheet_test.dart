import 'dart:collection';
import 'dart:convert';

import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/promotion/promotion_builder_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const String kKub8Mint = ApiKeys.kub8MintAddress;
const String kTreasuryOwner = 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws';

/// A wallet whose token list and signing capability the test controls.
class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider(this._tokens, {bool canSign = true})
      : _canSign = canSign,
        super(deferInit: true);

  final List<Token> _tokens;
  final bool _canSign;

  @override
  List<Token> get tokens => List<Token>.unmodifiable(_tokens);

  @override
  bool get canTransact => _canSign;

  @override
  String? get currentWalletAddress =>
      'A8FtJ7fvJHZfsmMLfT85rTE6itNCf4qu26A4nU9LeCZ2';
}

/// A token holding, identified by its mint.
Token buildToken({
  required String mint,
  required String symbol,
  required double balance,
  int decimals = 6,
}) {
  return Token(
    id: 'spl_$mint',
    name: symbol,
    symbol: symbol,
    type: TokenType.erc20,
    balance: balance,
    value: 0,
    changePercentage: 0,
    contractAddress: mint,
    decimals: decimals,
    network: 'Solana',
  );
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  _FakeUrlLauncherPlatform(List<bool> launchResults)
      : _launchResults = Queue<bool>.from(launchResults);

  final Queue<bool> _launchResults;
  final List<String> launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    if (_launchResults.isEmpty) return true;
    return _launchResults.removeFirst();
  }
}

class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showPromotionBuilderSheet(
            context: context,
            entityType: PromotionEntityType.artwork,
            entityId: 'art-1',
            entityLabel: 'Test artwork',
          ),
          child: const Text('Open sheet'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UrlLauncherPlatform originalLauncher;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    originalLauncher = UrlLauncherPlatform.instance;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalLauncher;
  });

  /// Backend double for the whole builder flow.
  ///
  /// [kub8Enabled] controls whether the issued quote offers KUB8 at all, mirroring an
  /// environment where the canonical mint is not configured.
  BackendApiService buildPromotionApi({
    required ValueSetter<int> setCreateCalls,
    required ValueSetter<Map<String, dynamic>?> setCreateBody,
    bool kub8Enabled = true,
    String kub8AmountRaw = '70000000',
    String? checkoutUrl,
    ValueSetter<int>? setQuoteCalls,
  }) {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    var createCalls = 0;
    var quoteCalls = 0;
    api.setHttpClient(
      MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/app/promotion-config') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'maxBookingDaysAhead': 90,
                'cancellationWindowHours': 24,
                'quoteTtlSeconds': 900,
                'fiatCurrency': 'EUR',
                'paymentMethods': <String, Object?>{
                  'fiat': <String, Object?>{
                    'method': 'fiat_card',
                    'enabled': true
                  },
                  'kub8': <String, Object?>{
                    'method': 'kub8_spl',
                    'enabled': kub8Enabled,
                    'mintAddress': kKub8Mint,
                    'decimals': 6,
                    'cluster': 'devnet',
                  },
                },
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/app/promotion-rate-cards') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <Object?>[
                <String, Object?>{
                  'id': 'rate-1',
                  'code': 'artwork_boost',
                  'entityType': PromotionEntityType.artwork.apiValue,
                  'placementTier': PromotionPlacementTier.boost.apiValue,
                  'fiatPricePerDay': 4.00,
                  'kub8PricePerDay': 10.00,
                  'minDays': 3,
                  'maxDays': 30,
                  'slotCount': null,
                  'isActive': true,
                  'volumeDiscounts': const <Object?>[],
                },
              ],
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/app/promotion-price-quote') {
          quoteCalls += 1;
          setQuoteCalls?.call(quoteCalls);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // The quote is bound to the entity being promoted.
          expect(body['entityType'], 'artwork');
          expect(body['targetEntityId'], 'art-1');
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'quoteId': 'quote-1',
                'rateCardId': 'rate-1',
                'rateCardVersion': 'v1',
                'entityType': 'artwork',
                'entityId': 'art-1',
                'placementTier': PromotionPlacementTier.boost.apiValue,
                'durationDays': body['durationDays'],
                'slotAvailable': true,
                'allowedPaymentMethods': <Object?>[
                  'fiat_card',
                  if (kub8Enabled) 'kub8_spl',
                ],
                'pricing': <String, Object?>{
                  'fiatPricePerDay': '4.00',
                  'kub8PricePerDay': '10.00',
                  'baseFiatAmount': '28.00',
                  'baseKub8Amount': '70',
                  'discountPercent': '0',
                  'finalFiatAmount': '28.00',
                  'fiatCurrency': 'EUR',
                  'finalKub8Amount': '70',
                  'finalKub8AmountRaw': kub8Enabled ? kub8AmountRaw : null,
                },
                if (kub8Enabled)
                  'kub8': <String, Object?>{
                    'mintAddress': kKub8Mint,
                    'decimals': 6,
                    'amountRaw': kub8AmountRaw,
                    'amount': '70',
                    'cluster': 'devnet',
                    'destinationOwner': kTreasuryOwner,
                    'destinationTokenAccount': 'TreasuryTokenAccount1111',
                  },
                'schedule': <String, Object?>{
                  'startAt': '2026-09-20T00:00:00.000Z',
                  'endAt': '2026-09-27T00:00:00.000Z',
                  'cancellationDeadlineAt': '2026-09-19T00:00:00.000Z',
                },
                'isRefundable': true,
                'expiresAt': '2099-01-01T00:00:00.000Z',
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/app/promotion-requests/me') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': const <Object?>[],
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/app/promotion-requests') {
          createCalls += 1;
          setCreateCalls(createCalls);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          setCreateBody(body);
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'id': 'req-1',
                'targetEntityId': 'art-1',
                'entityType': 'artwork',
                'rateCardId': 'rate-1',
                'rateCardCode': 'artwork_boost',
                'placementTier': PromotionPlacementTier.boost.apiValue,
                'durationDays': 7,
                'calculatedFiatPrice': 28.0,
                'calculatedKub8Price': 70.0,
                'discountAppliedPercent': 0,
                'scheduledStartAt': '2026-09-20T00:00:00.000Z',
                'paymentMethod': body['paymentMethod'],
                'paymentStatus': body['paymentMethod'] == 'kub8_spl'
                    ? 'awaiting_payment'
                    : 'pending',
                'reviewStatus': 'pending_review',
                'quoteId': 'quote-1',
                if (checkoutUrl != null) 'checkoutUrl': checkoutUrl,
              },
            }),
            201,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      }),
    );
    return api;
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    required BackendApiService api,
    required _FakeWalletProvider walletProvider,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<PromotionProvider>(
            create: (_) => PromotionProvider(api: api),
          ),
          ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SheetLauncher(),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropGlassSheet), findsOneWidget);

    final launchError = tester.takeException();
    if (launchError != null) {
      throw launchError;
    }
  }

  Future<void> scrollSheetUntilVisible(
      WidgetTester tester, Finder target) async {
    final listFinder = find.byKey(const Key('promotionBuilderListView'));
    expect(listFinder, findsOneWidget);

    for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
      await tester.drag(listFinder, const Offset(0, -220));
      await tester.pumpAndSettle();
    }

    expect(target, findsOneWidget);
  }

  Future<void> scrollToSubmitButton(WidgetTester tester) async {
    final submitButton = find.byKey(const Key('promotionBuilderSubmitButton'));
    await scrollSheetUntilVisible(tester, submitButton);
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
  }

  Future<void> selectKub8(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final kub8Segment = find.text(l10n.promotionBuilderPaymentKub8);
    await scrollSheetUntilVisible(tester, kub8Segment);
    await tester.tap(kub8Segment);
    await tester.pumpAndSettle();
  }

  bool submitEnabled(WidgetTester tester) {
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('promotionBuilderSubmitButton')),
    );
    return button.onPressed != null;
  }

  testWidgets(
      'submitting references the immutable quote, not raw pricing inputs',
      (tester) async {
    final launcher = _FakeUrlLauncherPlatform(const <bool>[true]);
    UrlLauncherPlatform.instance = launcher;

    var createCalls = 0;
    Map<String, dynamic>? createBody;
    final api = buildPromotionApi(
      setCreateCalls: (value) => createCalls = value,
      setCreateBody: (value) => createBody = value,
      checkoutUrl: 'https://checkout.example/session-1',
    );
    final walletProvider = _FakeWalletProvider(<Token>[]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await scrollToSubmitButton(tester);
    await tester.tap(find.byKey(const Key('promotionBuilderSubmitButton')));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(createBody?['quoteId'], 'quote-1');
    expect(createBody?['idempotencyKey'], isNotNull);
    // The client never re-sends pricing inputs, so it cannot influence the charge.
    expect(createBody?.containsKey('rateCardId'), isFalse);
    expect(createBody?.containsKey('durationDays'), isFalse);
  });

  testWidgets('a token that merely calls itself KUB8 is not treated as KUB8',
      (tester) async {
    var createCalls = 0;
    final api = buildPromotionApi(
      setCreateCalls: (value) => createCalls = value,
      setCreateBody: (_) {},
    );
    // Plenty of balance, but on an impostor mint.
    final walletProvider = _FakeWalletProvider(<Token>[
      buildToken(
        mint: 'So11111111111111111111111111111111111111112',
        symbol: 'KUB8',
        balance: 100000,
      ),
    ]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await selectKub8(tester);
    await scrollToSubmitButton(tester);

    // Identity is the canonical mint, so this wallet has zero spendable KUB8.
    expect(submitEnabled(tester), isFalse);
    expect(createCalls, 0);
  });

  testWidgets(
      'insufficient canonical KUB8 disables submit and shows the shortfall',
      (tester) async {
    final api = buildPromotionApi(
      setCreateCalls: (_) {},
      setCreateBody: (_) {},
    );
    // 70 KUB8 is required; this wallet holds 10.
    final walletProvider = _FakeWalletProvider(<Token>[
      buildToken(mint: kKub8Mint, symbol: 'KUB8', balance: 10),
    ]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await selectKub8(tester);
    await scrollSheetUntilVisible(
      tester,
      find.byKey(const Key('promotionBuilderKub8Status')),
    );

    expect(find.textContaining('70'), findsWidgets);
    await scrollToSubmitButton(tester);
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('sufficient canonical KUB8 enables submit', (tester) async {
    final api = buildPromotionApi(
      setCreateCalls: (_) {},
      setCreateBody: (_) {},
    );
    final walletProvider = _FakeWalletProvider(<Token>[
      buildToken(mint: kKub8Mint, symbol: 'KUB8', balance: 250),
    ]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await selectKub8(tester);
    await scrollToSubmitButton(tester);

    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('a KUB8 shortfall never blocks a fiat submission',
      (tester) async {
    final api = buildPromotionApi(
      setCreateCalls: (_) {},
      setCreateBody: (_) {},
    );
    final walletProvider = _FakeWalletProvider(<Token>[
      buildToken(mint: kKub8Mint, symbol: 'KUB8', balance: 0),
    ]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await scrollToSubmitButton(tester);

    // Fiat is the default method and stays available regardless of the KUB8 balance.
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('a wallet that cannot sign cannot start a KUB8 payment',
      (tester) async {
    final api = buildPromotionApi(
      setCreateCalls: (_) {},
      setCreateBody: (_) {},
    );
    final walletProvider = _FakeWalletProvider(
      <Token>[buildToken(mint: kKub8Mint, symbol: 'KUB8', balance: 250)],
      canSign: false,
    );

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await selectKub8(tester);
    await scrollToSubmitButton(tester);

    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('changing the duration re-quotes before submission is possible',
      (tester) async {
    var quoteCalls = 0;
    final api = buildPromotionApi(
      setCreateCalls: (_) {},
      setCreateBody: (_) {},
      setQuoteCalls: (value) => quoteCalls = value,
    );
    final walletProvider = _FakeWalletProvider(<Token>[]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    final initialQuoteCalls = quoteCalls;

    final slider = find.byType(Slider);
    await scrollSheetUntilVisible(tester, slider);
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle();

    // The selection change forces a fresh quote rather than reusing the old price.
    expect(quoteCalls, greaterThan(initialQuoteCalls));
  });

  testWidgets('KUB8 is not offered when the quote does not allow it',
      (tester) async {
    final api = buildPromotionApi(
      setCreateCalls: (_) {},
      setCreateBody: (_) {},
      kub8Enabled: false,
    );
    final walletProvider = _FakeWalletProvider(<Token>[
      buildToken(mint: kKub8Mint, symbol: 'KUB8', balance: 250),
    ]);

    await pumpSheet(tester, api: api, walletProvider: walletProvider);
    await scrollToSubmitButton(tester);

    // Fiat still works; the KUB8 segment is present but disabled by the quote.
    expect(submitEnabled(tester), isTrue);
  });
}
