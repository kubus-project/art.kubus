import 'dart:collection';
import 'dart:convert';

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

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider(this._tokens) : super(deferInit: true);

  final List<Token> _tokens;

  @override
  List<Token> get tokens => List<Token>.unmodifiable(_tokens);
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

  PromotionRequest buildRequest(PromotionPaymentMethod paymentMethod) {
    return PromotionRequest(
      id: 'req-1',
      targetEntityId: 'art-1',
      entityType: PromotionEntityType.artwork,
      rateCardId: 'rate-1',
      rateCardCode: 'artwork_boost',
      placementTier: PromotionPlacementTier.boost,
      durationDays: 7,
      calculatedFiatPrice: 28.98,
      calculatedKub8Price: 10.01,
      discountAppliedPercent: 0,
      paymentMethod: paymentMethod,
      paymentStatus: 'pending',
      reviewStatus: 'pending_review',
      scheduledStartAt: DateTime.utc(2026, 3, 20),
      createdAt: DateTime.utc(2026, 3, 17),
    );
  }

  BackendApiService buildPromotionApi({
    required PromotionRequestSubmission submission,
    required ValueSetter<int> setCreateCalls,
    required ValueSetter<String?> setSubmittedRateCardId,
  }) {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    var createCalls = 0;
    api.setHttpClient(
      MockClient((request) async {
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
                  'fiatPricePerDay': 4.14,
                  'kub8PricePerDay': 1.43,
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
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'rateCardId': 'rate-1',
                'entityType': PromotionEntityType.artwork.apiValue,
                'placementTier': PromotionPlacementTier.boost.apiValue,
                'durationDays': 7,
                'slotAvailable': true,
                'pricing': <String, Object?>{
                  'fiatPricePerDay': 4.14,
                  'kub8PricePerDay': 1.43,
                  'baseFiatPrice': 28.98,
                  'baseKub8Price': 10.01,
                  'discountPercent': 0,
                  'finalFiatPrice': 28.98,
                  'finalKub8Price': 10.01,
                },
                'schedule': <String, Object?>{
                  'startDate': '2026-03-20T00:00:00.000Z',
                  'endDate': '2026-03-27T00:00:00.000Z',
                  'cancellationDeadline': '2026-03-19T00:00:00.000Z',
                },
                'isRefundable': true,
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
          final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          final submittedRateCardId = requestBody['rateCardId']?.toString();
          setSubmittedRateCardId(submittedRateCardId);
          expect(requestBody['durationDays'], 7);
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'id': submission.request.id,
                'targetEntityId': submission.request.targetEntityId,
                'entityType': submission.request.entityType.apiValue,
                'rateCardId':
                    submittedRateCardId ?? submission.request.rateCardId,
                'rateCardCode': submission.request.rateCardCode,
                'placementTier': submission.request.placementTier.apiValue,
                'durationDays': submission.request.durationDays,
                'calculatedFiatPrice': submission.request.calculatedFiatPrice,
                'calculatedKub8Price': submission.request.calculatedKub8Price,
                'discountAppliedPercent':
                    submission.request.discountAppliedPercent,
                'scheduledStartAt':
                    submission.request.scheduledStartAt?.toIso8601String(),
                'paymentMethod': submission.request.paymentMethod.apiValue,
                'paymentStatus': submission.request.paymentStatus,
                'reviewStatus': submission.request.reviewStatus,
                if (submission.checkoutUrl != null)
                  'checkoutUrl': submission.checkoutUrl,
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

    for (var i = 0; i < 10 && target.evaluate().isEmpty; i++) {
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

  testWidgets(
      'fiat-card submit retries checkout launch without creating a duplicate request',
      (tester) async {
    final launcher = _FakeUrlLauncherPlatform(<bool>[false, true]);
    UrlLauncherPlatform.instance = launcher;

    var createCalls = 0;
    String? submittedRateCardId;
    final api = buildPromotionApi(
      submission: PromotionRequestSubmission(
        request: buildRequest(PromotionPaymentMethod.fiatCard),
        checkoutUrl: 'https://checkout.example/session-1',
      ),
      setCreateCalls: (value) => createCalls = value,
      setSubmittedRateCardId: (value) => submittedRateCardId = value,
    );
    final walletProvider = _FakeWalletProvider(
      <Token>[
        Token(
          id: 'kub8',
          name: 'Kub8',
          symbol: 'KUB8',
          type: TokenType.native,
          balance: 50,
          value: 50,
          changePercentage: 0,
          contractAddress: 'kub8',
          network: 'solana',
        ),
      ],
    );

    await pumpSheet(
      tester,
      api: api,
      walletProvider: walletProvider,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BackdropGlassSheet)),
    )!;

    await scrollToSubmitButton(tester);

    await tester.tap(find.byKey(const Key('promotionBuilderSubmitButton')));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(submittedRateCardId, 'rate-1');
    expect(
        launcher.launchedUrls, <String>['https://checkout.example/session-1']);
    expect(find.text(l10n.promotionBuilderContinuePayment), findsOneWidget);

    await tester.tap(find.byKey(const Key('promotionBuilderSubmitButton')));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(
      launcher.launchedUrls,
      <String>[
        'https://checkout.example/session-1',
        'https://checkout.example/session-1',
      ],
    );
    expect(
      find.text(l10n.promotionBuilderPromoteEntityTitle('Test artwork')),
      findsNothing,
    );
  });

  testWidgets('KUB8 submit keeps the in-app success flow', (tester) async {
    final launcher = _FakeUrlLauncherPlatform(const <bool>[]);
    UrlLauncherPlatform.instance = launcher;

    var createCalls = 0;
    String? submittedRateCardId;
    final api = buildPromotionApi(
      submission: PromotionRequestSubmission(
        request: buildRequest(PromotionPaymentMethod.kub8Balance),
      ),
      setCreateCalls: (value) => createCalls = value,
      setSubmittedRateCardId: (value) => submittedRateCardId = value,
    );
    final walletProvider = _FakeWalletProvider(
      <Token>[
        Token(
          id: 'kub8',
          name: 'Kub8',
          symbol: 'KUB8',
          type: TokenType.native,
          balance: 50,
          value: 50,
          changePercentage: 0,
          contractAddress: 'kub8',
          network: 'solana',
        ),
      ],
    );

    await pumpSheet(
      tester,
      api: api,
      walletProvider: walletProvider,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BackdropGlassSheet)),
    )!;

    await scrollSheetUntilVisible(
      tester,
      find.text(l10n.promotionBuilderPaymentKub8),
    );

    await tester.tap(find.text(l10n.promotionBuilderPaymentKub8));
    await tester.pumpAndSettle();

    await scrollToSubmitButton(tester);

    await tester.tap(find.byKey(const Key('promotionBuilderSubmitButton')));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(submittedRateCardId, 'rate-1');
    expect(launcher.launchedUrls, isEmpty);
    expect(
      find.text(l10n.promotionBuilderPromoteEntityTitle('Test artwork')),
      findsNothing,
    );
    expect(find.text(l10n.promotionBuilderSubmitSuccess), findsOneWidget);
  });
}
