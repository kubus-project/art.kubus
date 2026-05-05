import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp(
    {required Widget child, required WalletProvider walletProvider}) {
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
  String? fallbackWalletAddress,
}) async {
  final state = tester.state(find.byType(SignInScreen)) as dynamic;
  await state.debugHandleWalletFlowResult(
    routeResult,
    fallbackWalletAddress: fallbackWalletAddress,
  );
}

Future<void> _triggerAuthSuccess(
  WidgetTester tester,
  Map<String, dynamic> payload, {
  required AuthOrigin origin,
}) async {
  final state = tester.state(find.byType(SignInScreen)) as dynamic;
  await state.debugTriggerAuthSuccess(payload, origin: origin);
}

Future<void> _drainPostAuthTimers(WidgetTester tester) async {
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

  testWidgets(
      'debugTriggerAuthSuccess with wallet hides auth form and shows loading',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    expect(find.byType(PostAuthLoadingScreen), findsNothing);

    await _triggerAuthSuccess(
      tester,
      const <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{
            'id': 'u1',
            'walletAddress': 'wallet-123',
          },
        },
      },
      origin: AuthOrigin.wallet,
    );
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    final loading = tester
        .widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.origin, AuthOrigin.wallet);
    expect(loading.walletAddress, 'wallet-123');

    await _drainPostAuthTimers(tester);
  });

  testWidgets('wallet success path using test seam shows loading',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    await _handleWalletResult(
      tester,
      const <String, dynamic>{'wallet_address': 'wallet-from-result'},
    );
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    final loading = tester
        .widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.origin, AuthOrigin.wallet);
    expect(loading.walletAddress, 'wallet-from-result');

    await _drainPostAuthTimers(tester);
  });

  testWidgets('wallet cancel path keeps auth form and does not show loading',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    await _handleWalletResult(tester, null);
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
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
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    await _handleWalletResult(tester, null);
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    final loading = tester
        .widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.origin, AuthOrigin.wallet);
    expect(loading.walletAddress, 'wallet-from-token');

    await _drainPostAuthTimers(tester);
  });

  testWidgets('null wallet result uses fallback wallet', (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    await _handleWalletResult(
      tester,
      null,
      fallbackWalletAddress: 'wallet-from-fallback',
    );
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    final loading = tester
        .widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.walletAddress, 'wallet-from-fallback');

    await _drainPostAuthTimers(tester);
  });

  testWidgets('email auth regression still shows loading', (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    await _triggerAuthSuccess(
      tester,
      const <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{
            'id': 'email-user',
            'walletAddress': 'email-wallet',
          },
        },
      },
      origin: AuthOrigin.emailPassword,
    );
    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    expect(
      tester
          .widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen))
          .origin,
      AuthOrigin.emailPassword,
    );

    await _drainPostAuthTimers(tester);
  });

  testWidgets(
      'Google auth regression shows loading without default password prompt',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true);

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        walletProvider: walletProvider,
      ),
    );

    await _triggerAuthSuccess(
      tester,
      const <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{
            'id': 'google-user',
            'walletAddress': 'google-wallet',
          },
        },
      },
      origin: AuthOrigin.google,
    );
    await tester.pump();

    final loading = tester
        .widget<PostAuthLoadingScreen>(find.byType(PostAuthLoadingScreen));
    expect(loading.origin, AuthOrigin.google);
    expect(loading.onBeforeSavedItemsSync, isNull);

    await _drainPostAuthTimers(tester);
  });
}
