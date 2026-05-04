import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp({required Widget child, required WalletProvider walletProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<CacheProvider>(create: (_) => CacheProvider()),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<SavedItemsProvider>(
        create: (_) => SavedItemsProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

String _buildJwtWithWallet(String walletAddress) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object>{
            'walletAddress': walletAddress,
            'sub': 'test',
          }),
        ),
      )
      .replaceAll('=', '');
  return 'e30.$payload.';
}

Future<void> _handleWalletResult(
  WidgetTester tester,
  Object? routeResult, {
  String? requiredWalletAddress,
}) async {
  final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
  await state.handleWalletFlowResultForTesting(
    routeResult,
    requiredWalletAddress: requiredWalletAddress,
  );
}

Future<void> _drainPostAuthTimers(WidgetTester tester) async {
  // PostAuthCoordinator uses timeout wrappers (6s wallet + 5s profile + 0.8s
  // token load in downstream services). Advance fake time so pending timers are
  // settled before widget teardown.
  await tester.pump(const Duration(seconds: 13));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(MockClient((_) async => http.Response('Not found', 404)));
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
  });

  testWidgets('wallet map result flips to PostAuthLoadingScreen', (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const Scaffold(body: AuthMethodsPanel(embedded: true)),
        walletProvider: walletProvider,
      ),
    );

    expect(find.byType(PostAuthLoadingScreen), findsNothing);

    await _handleWalletResult(
      tester,
      const <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{
            'id': 'u1',
            'walletAddress': 'wallet-xyz',
          },
        },
      },
    );

    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    final loading =
        tester.widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.origin, AuthOrigin.wallet);
    expect(loading.walletAddress, 'wallet-xyz');

    await _drainPostAuthTimers(tester);
  });

  testWidgets('null wallet result uses session token wallet fallback',
      (tester) async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_buildJwtWithWallet('wallet-from-token'));
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/profiles/me') {
          return http.Response('server error', 500);
        }
        return http.Response('Not found', 404);
      }),
    );

    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const Scaffold(body: AuthMethodsPanel(embedded: true)),
        walletProvider: walletProvider,
      ),
    );

    await _handleWalletResult(tester, null);
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    final loading =
        tester.widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.origin, AuthOrigin.wallet);
    expect(loading.walletAddress, 'wallet-from-token');

    await _drainPostAuthTimers(tester);
  });

  testWidgets('null wallet result with no session evidence stays on auth UI',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const Scaffold(body: AuthMethodsPanel(embedded: true)),
        walletProvider: walletProvider,
      ),
    );

    expect(find.byType(PostAuthLoadingScreen), findsNothing);

    await _handleWalletResult(tester, null);
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsNothing);
    expect(find.byType(AuthMethodsPanel), findsOneWidget);
  });
}
