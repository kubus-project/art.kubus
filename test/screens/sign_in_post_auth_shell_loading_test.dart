import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:art_kubus/widgets/auth_entry_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>(
        create: (_) => WalletProvider(deferInit: true),
      ),
      ChangeNotifierProvider<CacheProvider>(create: (_) => CacheProvider()),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<SavedItemsProvider>(
        create: (_) => SavedItemsProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
      routes: <String, WidgetBuilder>{
        '/main': (_) => const Scaffold(body: Text('main')),
      },
    ),
  );
}

Future<void> _setSurfaceSize(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _triggerAuthSuccess(
  WidgetTester tester, {
  AuthOrigin origin = AuthOrigin.emailPassword,
}) async {
  final state = tester.state(find.byType(SignInScreen)) as dynamic;
  await state.debugTriggerAuthSuccess(
    const <String, dynamic>{
      'data': <String, dynamic>{
        'user': <String, dynamic>{
          'id': 'user-1',
          'walletAddress': 'wallet-1',
        },
      },
    },
    origin: origin,
  );
  await tester.pump();
}

SignInScreen _signInScreen({bool embedded = false}) {
  return SignInScreen(
    embedded: embedded,
    postAuthCoordinator: _NoopPostAuthCoordinator(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('desktop post-auth loading stays inside AuthEntryShell',
      (tester) async {
    await _setSurfaceSize(tester, const Size(1200, 820));
    await tester.pumpWidget(_buildApp(_signInScreen()));

    await _triggerAuthSuccess(tester);

    expect(find.byType(AuthEntryShell), findsOneWidget);
    expect(find.byType(PostAuthLoadingScreen), findsOneWidget);
    expect(find.byType(PostAuthLoadingContent), findsOneWidget);
    final loading = tester.widget<PostAuthLoadingScreen>(
      find.byType(PostAuthLoadingScreen),
    );
    expect(
      loading.presentation,
      PostAuthLoadingPresentation.shellEmbedded,
    );
  });

  testWidgets('desktop post-auth loading hides sign-in methods',
      (tester) async {
    await _setSurfaceSize(tester, const Size(1200, 820));
    await tester.pumpWidget(_buildApp(_signInScreen()));

    await _triggerAuthSuccess(tester);

    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    expect(
        find.text(
            AppLocalizations.of(tester.element(find.byType(SignInScreen)))!
                .authNeedAccountRegister),
        findsNothing);
  });

  testWidgets('mobile post-auth loading remains full-screen', (tester) async {
    await _setSurfaceSize(tester, const Size(390, 844));
    await tester.pumpWidget(_buildApp(_signInScreen()));

    await _triggerAuthSuccess(tester);

    expect(find.byType(AuthEntryShell), findsNothing);
    final loading = tester.widget<PostAuthLoadingScreen>(
      find.byType(PostAuthLoadingScreen),
    );
    expect(loading.presentation, PostAuthLoadingPresentation.fullScreen);
  });

  testWidgets('embedded SignInScreen uses inline post-auth loading',
      (tester) async {
    await _setSurfaceSize(tester, const Size(1200, 820));
    await tester.pumpWidget(
      _buildApp(Scaffold(body: _signInScreen(embedded: true))),
    );

    await _triggerAuthSuccess(tester);

    final loading = tester.widget<PostAuthLoadingScreen>(
      find.byType(PostAuthLoadingScreen),
    );
    expect(loading.presentation, PostAuthLoadingPresentation.inline);
    expect(find.byType(PostAuthLoadingContent), findsOneWidget);
  });

  testWidgets('desktop wallet auth success uses shell-embedded loading',
      (tester) async {
    await _setSurfaceSize(tester, const Size(1200, 820));
    await tester.pumpWidget(_buildApp(_signInScreen()));

    await _triggerAuthSuccess(tester, origin: AuthOrigin.wallet);

    final loading = tester.widget<PostAuthLoadingScreen>(
      find.byType(PostAuthLoadingScreen),
    );
    expect(loading.presentation, PostAuthLoadingPresentation.shellEmbedded);
    expect(find.byType(AuthEntryShell), findsOneWidget);
  });
}

class _NoopPostAuthCoordinator extends PostAuthCoordinator {
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
    return const PostAuthResult(completed: false, error: 'test-stopped');
  }
}
