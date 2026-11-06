import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/account_closure.dart';
import 'package:art_kubus/models/email_preferences.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/services/account_closure_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/account_closure_flow.dart';
import 'package:art_kubus/widgets/detail/shared_settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _closureRouteText = 'closure-status-route';

/// Counts closure attempts. The DELETE response is lost after the stages, so
/// the outcome is pending and the test needs no real storage or sign-out.
class _CountingClosureApi implements AccountClosureApi {
  int calls = 0;

  @override
  int get authSessionEpoch => 1;

  @override
  Future<int> deleteMyAccount({AccountClosureStageListener? onStage}) async {
    calls += 1;
    onStage?.call(AccountClosureStage.preparing, authSessionEpoch);
    onStage?.call(AccountClosureStage.deleting, authSessionEpoch);
    throw TimeoutException('synthetic lost response');
  }
}

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);
}

Widget _app(Widget home) {
  final wallet = _Wallet();
  final web3Provider = Web3Provider()..bindWalletProvider(wallet);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<GlassCapabilitiesProvider>(
        create: (_) => GlassCapabilitiesProvider(),
      ),
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(value: wallet),
      ChangeNotifierProvider<Web3Provider>.value(value: web3Provider),
      ChangeNotifierProvider<PlatformProvider>(
        create: (_) => PlatformProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider()
          ..setCurrentUser(
            UserProfile(
              id: 'closure-entry-profile',
              walletAddress: '',
              username: 'tester',
              displayName: 'Tester',
              bio: '',
              avatar: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
      ),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
      ChangeNotifierProvider<EmailPreferencesProvider>(
        create: (_) => _FakeEmailPreferencesProvider(),
      ),
      ChangeNotifierProvider<SupportCenterProvider>(
        create: (_) => SupportCenterProvider(supportEnabled: true),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routes: {
        '/account-closure': (_) =>
            const Scaffold(body: Text(_closureRouteText)),
      },
      home: home,
    ),
  );
}

class _FakeEmailPreferencesProvider extends EmailPreferencesProvider {
  _FakeEmailPreferencesProvider() : super();

  @override
  bool get initialized => true;

  @override
  bool get isLoading => false;

  @override
  EmailPreferences get preferences => EmailPreferences.defaults();
}

/// Opens the account-deletion tile and confirms both dialogs.
///
/// Desktop taps the tile. Mobile scrolls its lazy sliver list to build the
/// tile, then invokes the tile's own `onTap`. The mobile list sits under a
/// slide transition, so a hit-test tap lands outside the tile. The handler
/// path is still the screen's own code, and the dialogs are tapped normally.
Future<void> _deleteThroughUi(WidgetTester tester, AppLocalizationsEn l10n,
    {Finder? scrollable}) async {
  final tile = find.text(l10n.settingsDeleteAccountTileTitle);
  if (scrollable != null) {
    await tester.scrollUntilVisible(tile, 300, scrollable: scrollable);
    final destination = tester.widget<SharedSettingsDestinationTile>(
      find.ancestor(
        of: tile,
        matching: find.byType(SharedSettingsDestinationTile),
      ),
    );
    destination.onTap();
  } else {
    await tester.tap(tile);
  }
  await tester.pump(const Duration(milliseconds: 500));

  await tester.tap(
      find.widgetWithText(ElevatedButton, l10n.settingsDeleteForeverButton));
  await tester.pump(const Duration(milliseconds: 500));

  await tester.tap(find.widgetWithText(TextButton, l10n.settingsConfirmButton));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setHttpClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'success': false}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      ),
    );
  });

  tearDown(() {
    debugAccountClosureCoordinator = null;
  });

  testWidgets(
      'desktop and mobile deletion entry points run the same coordinator',
      (tester) async {
    final api = _CountingClosureApi();
    debugAccountClosureCoordinator = AccountClosureCoordinator(api: api);

    // Desktop: the danger zone is sidebar item 9.
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const DesktopSettingsScreen()));
    await tester.pump(const Duration(seconds: 2));
    await tester
        .tap(find.byKey(const ValueKey('desktop_settings_sidebar_item_9')));
    await tester.pump(const Duration(milliseconds: 300));

    await _deleteThroughUi(tester, l10n);

    expect(api.calls, 1, reason: 'desktop must use the shared coordinator');
    expect(find.text(_closureRouteText), findsOneWidget,
        reason: 'pending must open the closure status route');

    // Mobile: a fresh tree, the same coordinator instance.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(_app(const SettingsScreen()));
    await tester.pump(const Duration(seconds: 2));

    await _deleteThroughUi(
      tester,
      l10n,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );

    expect(api.calls, 2, reason: 'mobile must use the shared coordinator');
    expect(find.text(_closureRouteText), findsOneWidget);
  });
}
