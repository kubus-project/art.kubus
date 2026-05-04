import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _buildApp(Widget child) {
  final walletProvider = WalletProvider(deferInit: true)
    ..setCurrentWalletAddressForTesting('wallet-address-from-connect');

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

Future<void> _triggerAuthSuccess(
  WidgetTester tester,
  Finder finder,
  Map<String, dynamic> payload, {
  required AuthOrigin origin,
}) async {
  final state = tester.state(finder) as dynamic;
  await state.debugTriggerAuthSuccess(payload, origin: origin);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SignInScreen shows loading after email auth success', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const SignInScreen(embedded: true),
      ),
    );

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(PostAuthLoadingScreen), findsNothing);

    await _triggerAuthSuccess(
      tester,
      find.byType(SignInScreen),
      const <String, dynamic>{
        'data': {
          'user': {
            'id': 'test-user-id',
            'walletAddress': 'test-wallet-address',
          },
        },
      },
      origin: AuthOrigin.emailPassword,
    );

    await tester.pump();

    expect(
      find.byType(PostAuthLoadingScreen),
      findsOneWidget,
      reason: 'Loading surface should replace the auth form immediately',
    );
  });

  testWidgets('SignInScreen shows loading after Google auth success', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const SignInScreen(embedded: true),
      ),
    );

    await _triggerAuthSuccess(
      tester,
      find.byType(SignInScreen),
      const <String, dynamic>{
        'data': {
          'user': {
            'id': 'test-google-user',
            'walletAddress': 'test-google-wallet',
          },
        },
      },
      origin: AuthOrigin.google,
    );

    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
  });

  testWidgets('AuthMethodsPanel shows loading after wallet auth success', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const Scaffold(
          body: AuthMethodsPanel(embedded: true),
        ),
      ),
    );

    expect(find.byType(AuthMethodsPanel), findsOneWidget);
    expect(find.byType(PostAuthLoadingScreen), findsNothing);

    await _triggerAuthSuccess(
      tester,
      find.byType(AuthMethodsPanel),
      const <String, dynamic>{
        'data': {
          'user': {
            'id': 'test-wallet-user',
            'walletAddress': 'wallet-address-from-connect',
          },
        },
      },
      origin: AuthOrigin.wallet,
    );

    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
  });

  testWidgets('AuthMethodsPanel hides method buttons after auth success', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const Scaffold(
          body: AuthMethodsPanel(embedded: true),
        ),
      ),
    );

    await _triggerAuthSuccess(
      tester,
      find.byType(AuthMethodsPanel),
      const <String, dynamic>{
        'data': {
          'user': {
            'id': 'test-wallet-user-2',
            'walletAddress': 'wallet-address-from-connect',
          },
        },
      },
      origin: AuthOrigin.wallet,
    );

    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
  });

  testWidgets('Post-auth loading screen is visible without settle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        PostAuthLoadingScreen(
          payload: const <String, dynamic>{
            'data': <String, dynamic>{},
          },
          origin: AuthOrigin.emailPassword,
          coordinator: _NoopCoordinator(),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
  });
}

class _NoopCoordinator extends PostAuthCoordinator {
  _NoopCoordinator();

  @override
  Future<PostAuthResult> complete({
    required BuildContext context,
    required AuthOrigin origin,
    required Map<String, dynamic> payload,
    String? redirectRoute,
    Object? redirectArguments,
    String? walletAddress,
    Object? userId,
    bool embedded = false,
    bool modalReauth = false,
    bool requiresWalletBackup = false,
    Future<void> Function()? onBeforeSavedItemsSync,
    required ValueChanged<PostAuthStage> onStageChanged,
  }) async {
    onStageChanged(PostAuthStage.preparingSession);
    return const PostAuthResult(completed: false, error: 'test-noop');
  }
}
