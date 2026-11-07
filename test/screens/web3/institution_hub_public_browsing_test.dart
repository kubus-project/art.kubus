import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/account_verification_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/onboarding/web3/web3_onboarding.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/secure_storage_absent.dart';
import '../../support/verification_fixtures.dart';

/// Public institution browsing must never open Web3 onboarding, and an
/// account without a wallet is a normal account.
///
/// Every test starts with NO onboarding-completed flag, so the first-visit
/// onboarding path would run if it still existed.
class _NoSignerWalletService extends SolanaWalletService {
  @override
  Future<double> getSplTokenBalance({
    required String owner,
    required String mint,
    int? expectedDecimals,
  }) async {
    return 0;
  }
}

UserProfile _emailOnlyUser() {
  return UserProfile(
    id: 'user-email-only',
    walletAddress: '',
    username: 'emailonly',
    displayName: 'Email only',
    bio: '',
    avatar: '',
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
  );
}

const _walletAddress = 'WalletHub1111111111111111111111111111111111';

UserProfile _walletUser() {
  return UserProfile(
    id: 'user-wallet',
    walletAddress: _walletAddress,
    username: 'walletgallery',
    displayName: 'Wallet gallery',
    bio: '',
    avatar: '',
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
  );
}

Future<List<String>> _pumpHub(
  WidgetTester tester, {
  UserProfile? user,
  required List<String> requests,
  bool signedIn = false,
  bool embedded = false,
  WalletProvider? walletProvider,
  DAOProvider? daoProvider,
  AccountVerificationProvider? verification,
  Map<String, Object> initialPrefs = const <String, Object>{},
  Locale? locale,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{...initialPrefs});
  final api = BackendApiService();
  api.setAuthTokenForTesting(signedIn ? 'test-token' : null);
  api.setHttpClient(MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');
    const headers = <String, String>{'content-type': 'application/json'};
    // Only the list endpoint gets an empty body. The single-wallet endpoint
    // answers 404 so no review is parsed for the wallet under test.
    if (request.url.path == '/api/dao/reviews') {
      return http.Response(
        jsonEncode(<String, Object?>{'reviews': <Object?>[]}),
        200,
        headers: headers,
      );
    }
    return http.Response('', 404, headers: headers);
  }));
  addTearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });

  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themeProvider = ThemeProvider();
  final profileProvider = ProfileProvider();
  if (user != null) {
    profileProvider.setCurrentUser(user);
  }
  final dao =
      daoProvider ?? DAOProvider(solanaWalletService: _NoSignerWalletService());
  final verificationProvider =
      verification ?? await unavailableVerificationProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<DAOProvider>.value(value: dao),
        ChangeNotifierProvider<AccountVerificationProvider>.value(
          value: verificationProvider,
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => walletProvider ?? WalletProvider(),
        ),
        ChangeNotifierProvider<Web3Provider>(create: (_) => Web3Provider()),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider<ExhibitionsProvider>(
          create: (_) => ExhibitionsProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          // The wallet guard may push the app's onboarding route; the test
          // app has no route table, so answer it with an empty page.
          onUnknownRoute: (settings) {
            requests.add('route ${settings.name}');
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
          home: InstitutionHub(embedded: embedded),
        ),
      ),
    ),
  );

  // The first-visit check is async (SharedPreferences), so give it real time
  // to resolve before asserting that nothing was pushed.
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  return requests;
}

void main() {
  installEmptySecureStorage();
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest opens the institution hub without Web3 onboarding',
      (tester) async {
    await _pumpHub(tester, requests: <String>[]);

    expect(find.byType(InstitutionHub), findsOneWidget);
    expect(find.byType(Web3OnboardingScreen), findsNothing);
  });

  testWidgets(
      'email-only account opens the institution hub without Web3 onboarding',
      (tester) async {
    await _pumpHub(
      tester,
      user: _emailOnlyUser(),
      requests: <String>[],
      signedIn: true,
    );

    expect(find.byType(InstitutionHub), findsOneWidget);
    expect(find.byType(Web3OnboardingScreen), findsNothing);
  });

  // The application form is gone. An account without a wallet is a normal
  // account, and the institution claim panel opens to it without one.
  for (final locale in <Locale>[const Locale('en'), const Locale('sl')]) {
    testWidgets(
        'email-only account sees the institution claim panel without a wallet (${locale.languageCode})',
        (tester) async {
      final requests = <String>[];
      await _pumpHub(
        tester,
        user: _emailOnlyUser(),
        requests: requests,
        signedIn: true,
        locale: locale,
        verification: await readyVerificationProvider(verificationState()),
      );

      final context = tester.element(find.byType(InstitutionHub));
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.verificationInstitutionClaimTitle), findsWidgets);
      expect(find.text('Connect wallet to apply'), findsNothing);
      expect(
        requests.where((r) => r.startsWith('POST ')),
        isEmpty,
        reason: 'opening the hub sends nothing',
      );
    });
  }

  testWidgets('wallet holder sees Web3 onboarding on the first visit',
      (tester) async {
    await _pumpHub(
      tester,
      user: _walletUser(),
      requests: <String>[],
      signedIn: true,
    );

    expect(find.byType(Web3OnboardingScreen), findsOneWidget);
  });

  testWidgets('embedded institution hub exposes the help entry',
      (tester) async {
    await _pumpHub(
      tester,
      user: _emailOnlyUser(),
      requests: <String>[],
      signedIn: true,
      embedded: true,
    );

    // The embedded layout has no app bar; the help action sits in the header
    // and opens the same explanation the mobile app bar does.
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byType(Web3OnboardingScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.byType(Web3OnboardingScreen), findsOneWidget);
  });
}
