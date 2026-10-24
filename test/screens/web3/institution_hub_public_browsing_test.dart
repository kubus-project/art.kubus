import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
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
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public institution browsing must never open Web3 onboarding, and the DAO
/// application must not block an email-only account before the user has
/// chosen to submit it.
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

Future<List<String>> _pumpHub(
  WidgetTester tester, {
  UserProfile? user,
  required List<String> requests,
  bool signedIn = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final api = BackendApiService();
  api.setAuthTokenForTesting(signedIn ? 'test-token' : null);
  api.setHttpClient(MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');
    const headers = <String, String>{'content-type': 'application/json'};
    if (request.url.path.startsWith('/api/dao/reviews')) {
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
  final daoProvider =
      DAOProvider(solanaWalletService: _NoSignerWalletService());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<DAOProvider>.value(value: daoProvider),
        ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
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
          // The wallet guard may push the app's onboarding route; the test
          // app has no route table, so answer it with an empty page.
          onUnknownRoute: (settings) {
            requests.add('route ${settings.name}');
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
          home: const InstitutionHub(),
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

KubusButton _applyButton(WidgetTester tester, String label) {
  return tester.widget<KubusButton>(
    find.ancestor(of: find.text(label), matching: find.byType(KubusButton)),
  );
}

void main() {
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

  testWidgets(
      'email-only account can tap the apply action; the wallet explanation is shown',
      (tester) async {
    final requests = <String>[];
    await _pumpHub(
      tester,
      user: _emailOnlyUser(),
      requests: requests,
      signedIn: true,
    );

    final context = tester.element(find.byType(InstitutionHub));
    final l10n = AppLocalizations.of(context)!;

    // The CTA names the application, not a wallet step, and stays tappable so
    // browsing and filling in the application never require a wallet.
    expect(find.text(l10n.institutionHubCtaConnectWalletToApply), findsNothing);
    expect(
      _applyButton(tester, l10n.institutionHubCtaApplyAsInstitution).onPressed,
      isNotNull,
    );

    await tester.tap(find.text(l10n.institutionHubCtaApplyAsInstitution));
    await tester.pumpAndSettle();

    final sheet = find.byType(BackdropGlassSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.institutionHubApplicationWalletWhy),
      ),
      findsOneWidget,
      reason: 'the sheet explains why the submission needs a wallet',
    );
    expect(
      requests.where((r) => r.startsWith('POST ')),
      isEmpty,
      reason: 'opening the form sends nothing',
    );
  });

  testWidgets(
      'email-only submit goes through the wallet guard and sends no DAO review',
      (tester) async {
    final requests = <String>[];
    await _pumpHub(
      tester,
      user: _emailOnlyUser(),
      requests: requests,
      signedIn: true,
    );

    final context = tester.element(find.byType(InstitutionHub));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.text(l10n.institutionHubCtaApplyAsInstitution));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(BackdropGlassSheet),
      matching: find.byType(TextFormField),
    );
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'Kubus Gallery');
    await tester.enterText(fields.at(1), 'hello@example.com');
    await tester.enterText(fields.at(2), 'Digital art');
    await tester.enterText(
      fields.at(3),
      'We host public programmes for emerging artists.',
    );

    await tester.tap(find.text(l10n.institutionHubApplicationSubmitButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(
      requests.where((r) => r.startsWith('POST ')),
      isEmpty,
      reason: 'without a wallet signer the review is never submitted',
    );
    expect(
      requests.any((r) => r.startsWith('route ')),
      isTrue,
      reason:
          'the wallet guard opened the account flow for the email-only user',
    );
  });
}
