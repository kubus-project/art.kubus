import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_navigation.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/node/kubus_node_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// kubus Node is discoverable with the other advanced capabilities — a desktop
/// destination and a card on the mobile capability strip — without becoming a
/// sixth permanent bottom tab, and without being treated as a wallet surface.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mobile capability strip', () {
    test('Node sits last, after the practice and financial capabilities', () {
      expect(
        resolveHomeWeb3CardOrder(
          persona: UserPersona.creator,
          isArtist: true,
          isInstitution: false,
          nodeEnabled: true,
        ),
        <String>['artist', 'dao', 'marketplace', 'node'],
      );
      expect(
        resolveHomeWeb3CardOrder(
          persona: null,
          isArtist: false,
          isInstitution: false,
          nodeEnabled: true,
        ),
        <String>['dao', 'marketplace', 'node'],
      );
    });

    test('Node is absent when its rollout flag is off', () {
      expect(
        resolveHomeWeb3CardOrder(
          persona: null,
          isArtist: false,
          isInstitution: false,
        ),
        isNot(contains('node')),
      );
    });

    testWidgets('the Node card opens Node and needs no wallet', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.binding.setSurfaceSize(const Size(420, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var nodeOpened = 0;
      var walletOnboarding = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: HomeWeb3CardStrip(
                // Signed out of any wallet: Node must still open directly.
                isEffectivelyConnected: false,
                persona: null,
                isArtist: false,
                isInstitution: false,
                onOpenDao: () {},
                onOpenArtistStudio: () {},
                onOpenInstitutionHub: () {},
                onOpenMarketplace: () {},
                onOpenNode: () => nodeOpened += 1,
                onShowWalletOnboarding: () => walletOnboarding += 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey<String>('home_web3_node'));
      await tester.dragUntilVisible(
        card,
        find.byType(SingleChildScrollView),
        const Offset(-200, 0),
      );
      await tester.tap(card);
      await tester.pump();

      expect(nodeOpened, 1);
      expect(walletOnboarding, 0,
          reason: 'Node pairing is runtime ownership, not a signing action');
    });
  });

  group('desktop navigation', () {
    List<DesktopNavLabelKey> keys(
      List<DesktopNavItem> items,
    ) =>
        items.map((item) => item.labelKey).toList();

    test('a signed-in account finds Node beside the capability destinations',
        () {
      final items = resolveDesktopNavItems(
        true,
        isArtist: false,
        isInstitution: false,
      );
      final order = keys(items);

      expect(order, contains(DesktopNavLabelKey.node));
      expect(
        order.indexOf(DesktopNavLabelKey.node),
        greaterThan(order.indexOf(DesktopNavLabelKey.trade)),
      );
      // It is a destination of the advanced group, not a Labs-gated financial
      // capability.
      final node =
          items.firstWhere((i) => i.labelKey == DesktopNavLabelKey.node);
      expect(node.labsFeature, isNull);
    });

    test('Node stays available whichever creator role the account has', () {
      for (final roles in const [(true, false), (false, true), (true, true)]) {
        expect(
          keys(resolveDesktopNavItems(
            true,
            isArtist: roles.$1,
            isInstitution: roles.$2,
          )),
          contains(DesktopNavLabelKey.node),
          reason: 'roles $roles',
        );
      }
    });

    test('a guest is not offered Node', () {
      expect(
        keys(resolveDesktopNavItems(
          false,
          isArtist: false,
          isInstitution: false,
        )),
        isNot(contains(DesktopNavLabelKey.node)),
      );
    });
  });

  group('the dashboard hosted in the desktop shell', () {
    Future<void> pump(WidgetTester tester, {required bool embedded}) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<KubusNodeProvider>(
          create: (_) => KubusNodeProvider(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: KubusNodeScreen(embedded: embedded),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('standalone owns an AppBar', (tester) async {
      await pump(tester, embedded: false);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('embedded leaves the chrome to the shell', (tester) async {
      await pump(tester, embedded: true);
      expect(find.byType(AppBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
