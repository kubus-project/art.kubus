import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/detail/shared_settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 5A settings hierarchy: email preferences read as Marketing /
/// Activity / Essential groups, app notifications are their own section,
/// essential mail is always on and locked, and ON is the structural teal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(
    WidgetTester tester, {
    required Widget home,
    required Size size,
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'settings-hierarchy-profile',
        walletAddress: 'settings-hierarchy-wallet',
        username: 'tester',
        displayName: 'Tester',
        bio: '',
        avatar: '',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ));
    await profileProvider.initialize();
    final solana = SolanaWalletService();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: profileProvider),
        ChangeNotifierProvider(
          create: (_) => Web3Provider(solanaWalletService: solana),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              WalletProvider(solanaWalletService: solana, deferInit: true),
        ),
        ChangeNotifierProvider(create: (_) => PlatformProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(
          create: (_) =>
              EmailPreferencesProvider(backendApi: BackendApiService()),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).first).dy;

  void expectHierarchy(WidgetTester tester) {
    final l10n = l10nOf(tester);
    final marketing = l10n.settingsEmailGroupMarketing.toUpperCase();
    final activity = l10n.settingsEmailGroupActivity.toUpperCase();
    final essential = l10n.settingsEmailGroupEssential.toUpperCase();

    // Group labels are structural (Space Mono) and appear in order.
    for (final label in [marketing, activity, essential]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontFamily, KubusTypography.structuralFamily);
    }
    final order = [
      marketing,
      l10n.settingsEmailPreferencesProductUpdatesTitle,
      l10n.settingsEmailPreferencesCommunityDigestTitle,
      activity,
      l10n.settingsEmailPreferencesActivityArtTitle,
      l10n.settingsEmailPreferencesActivityPromotionTitle,
      essential,
      l10n.settingsEmailPreferencesCriticalAccountSecurityTitle,
      l10n.settingsEmailPreferencesTransactionalTitle,
      l10n.settingsAppNotificationsSectionTitle,
      l10n.settingsPushNotificationsTitle,
      l10n.settingsInAppNotificationsPromotionTitle,
    ];
    for (var i = 1; i < order.length; i++) {
      expect(topOf(tester, order[i]), greaterThan(topOf(tester, order[i - 1])),
          reason: '"${order[i]}" follows "${order[i - 1]}"');
    }

    // Essential mail: on, locked, and explained.
    expect(find.text(l10n.settingsEmailGroupEssentialNote), findsOneWidget);
    final essentialRows = find.byWidgetPredicate(
      (w) => w is SharedSettingsToggleRow && w.mandatory,
    );
    expect(essentialRows, findsNWidgets(3));
    for (final row in essentialRows.evaluate()) {
      final toggle = tester.widget<Switch>(
        find.descendant(
            of: find.byWidget(row.widget), matching: find.byType(Switch)),
      );
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNull);
    }

    // Structural ON is the family teal on every settings toggle row.
    final rowSwitches = find.descendant(
      of: find.byType(SharedSettingsToggleRow),
      matching: find.byType(Switch),
    );
    final roles = KubusColorRoles.of(tester.element(rowSwitches.first));
    for (final element in rowSwitches.evaluate()) {
      expect((element.widget as Switch).activeTrackColor, roles.active);
    }
  }

  for (final locale in const [Locale('en'), Locale('sl')]) {
    testWidgets('desktop notifications hierarchy (${locale.languageCode})',
        (tester) async {
      await pumpSettings(
        tester,
        home: const DesktopSettingsScreen(),
        size: const Size(1600, 3200),
        locale: locale,
      );
      await tester
          .tap(find.byKey(const ValueKey('desktop_settings_sidebar_item_2')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expectHierarchy(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop sidebar is flat with a teal selected indicator',
      (tester) async {
    await pumpSettings(
      tester,
      home: const DesktopSettingsScreen(),
      size: const Size(1600, 1200),
    );
    final item = find.byKey(const ValueKey('desktop_settings_sidebar_item_2'));
    await tester.tap(item);
    await tester.pump(const Duration(milliseconds: 300));

    final roles = KubusColorRoles.of(tester.element(item));
    final decoration =
        tester.widget<Container>(item).decoration! as BoxDecoration;
    expect((decoration.border! as Border).left.color, roles.active);

    final unselected = tester
        .widget<Container>(
            find.byKey(const ValueKey('desktop_settings_sidebar_item_1')))
        .decoration! as BoxDecoration;
    expect((unselected.border! as Border).left.color, Colors.transparent);

    final sidebar = find.ancestor(of: item, matching: find.byType(ListView));
    expect(
      find.ancestor(of: sidebar, matching: find.byType(BackdropFilter)),
      findsNothing,
      reason: 'settings sidebar is a flat structural surface',
    );
  });

  testWidgets('mobile account management uses the same hierarchy',
      (tester) async {
    await pumpSettings(
      tester,
      home: const SettingsScreen(),
      size: const Size(430, 3400),
    );
    final tile = find.byKey(const Key('settings_tile_account_management'));
    await tester.scrollUntilVisible(tile, 400);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expectHierarchy(tester);
  });
}
