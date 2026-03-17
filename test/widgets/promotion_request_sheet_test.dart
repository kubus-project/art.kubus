import 'dart:collection';
import 'dart:convert';

import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/promotion/promotion_request_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
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
          onPressed: () => showPromotionRequestSheet(
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

  PromotionPackage buildPackage() {
    return const PromotionPackage(
      id: 'pkg-1',
      entityType: PromotionEntityType.artwork,
      placementMode: PromotionPlacementMode.rotationPool,
      durationDays: 7,
      fiatPrice: 29,
      kub8Price: 10,
      isActive: true,
      title: 'Featured Artwork',
    );
  }

  PromotionRequest buildRequest(PromotionPaymentMethod paymentMethod) {
    return PromotionRequest(
      id: 'req-1',
      targetEntityId: 'art-1',
      entityType: PromotionEntityType.artwork,
      packageId: 'pkg-1',
      paymentMethod: paymentMethod,
      paymentStatus: 'pending',
      reviewStatus: 'pending_review',
      createdAt: DateTime.utc(2026, 3, 17),
    );
  }

  BackendApiService buildPromotionApi({
    required PromotionRequestSubmission submission,
    required ValueSetter<int> setCreateCalls,
  }) {
    final api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    var createCalls = 0;
    api.setHttpClient(
      MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/app/promotion-packages') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <Object?>[
                <String, Object?>{
                  'id': buildPackage().id,
                  'entityType': buildPackage().entityType.apiValue,
                  'placementMode': buildPackage().placementMode.apiValue,
                  'durationDays': buildPackage().durationDays,
                  'fiatPrice': buildPackage().fiatPrice,
                  'kub8Price': buildPackage().kub8Price,
                  'isActive': true,
                },
              ],
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
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'id': submission.request.id,
                'targetEntityId': submission.request.targetEntityId,
                'entityType': submission.request.entityType.apiValue,
                'packageId': submission.request.packageId,
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
        child: const MaterialApp(home: _SheetLauncher()),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'fiat-card submit retries checkout launch without creating a duplicate request',
      (tester) async {
    final launcher = _FakeUrlLauncherPlatform(<bool>[false, true]);
    UrlLauncherPlatform.instance = launcher;

    var createCalls = 0;
    final api = buildPromotionApi(
      submission: PromotionRequestSubmission(
        request: buildRequest(PromotionPaymentMethod.fiatCard),
        checkoutUrl: 'https://checkout.example/session-1',
      ),
      setCreateCalls: (value) => createCalls = value,
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

    await tester.tap(find.text('Submit promotion request'));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(
        launcher.launchedUrls, <String>['https://checkout.example/session-1']);
    expect(find.text('Continue to payment'), findsOneWidget);

    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(
      launcher.launchedUrls,
      <String>[
        'https://checkout.example/session-1',
        'https://checkout.example/session-1',
      ],
    );
    expect(find.text('Promote Test artwork'), findsNothing);
  });

  testWidgets('KUB8 submit keeps the in-app success flow', (tester) async {
    final launcher = _FakeUrlLauncherPlatform(const <bool>[]);
    UrlLauncherPlatform.instance = launcher;

    var createCalls = 0;
    final api = buildPromotionApi(
      submission: PromotionRequestSubmission(
        request: buildRequest(PromotionPaymentMethod.kub8Balance),
      ),
      setCreateCalls: (value) => createCalls = value,
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

    await tester.tap(find.text('KUB8 balance'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit promotion request'));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(launcher.launchedUrls, isEmpty);
    expect(find.text('Promote Test artwork'), findsNothing);
    expect(
        find.text('Promotion request submitted for review.'), findsOneWidget);
  });
}
