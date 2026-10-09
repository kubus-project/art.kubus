import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/creator_workspace.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(420, 600),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final themeProvider = ThemeProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: MaterialApp(
        theme: themeProvider.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _artist = ValueKey<String>('home_web3_artist');
const _institution = ValueKey<String>('home_web3_institution');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveHomeCreatorWorkspaceOrder', () {
    test('lists both workspaces for someone holding neither role', () {
      // The defect this replaces: without a role the strip had no Artist
      // Studio or Institution Hub at all, so they could not be discovered.
      expect(
        resolveHomeCreatorWorkspaceOrder(
          persona: null,
          isArtist: false,
          isInstitution: false,
        ),
        const [CreatorWorkspace.artistStudio, CreatorWorkspace.institutionHub],
      );
    });

    test('a held role leads, the other workspace stays listed', () {
      expect(
        resolveHomeCreatorWorkspaceOrder(
          persona: UserPersona.creator,
          isArtist: true,
          isInstitution: false,
        ),
        const [CreatorWorkspace.artistStudio, CreatorWorkspace.institutionHub],
      );
      expect(
        resolveHomeCreatorWorkspaceOrder(
          persona: UserPersona.creator,
          isArtist: false,
          isInstitution: true,
        ),
        const [CreatorWorkspace.institutionHub, CreatorWorkspace.artistStudio],
      );
    });

    test('with both roles or none, the chosen persona orders them', () {
      expect(
        resolveHomeCreatorWorkspaceOrder(
          persona: UserPersona.institution,
          isArtist: true,
          isInstitution: true,
        ),
        const [CreatorWorkspace.institutionHub, CreatorWorkspace.artistStudio],
      );
      expect(
        resolveHomeCreatorWorkspaceOrder(
          persona: UserPersona.creator,
          isArtist: true,
          isInstitution: true,
        ),
        const [CreatorWorkspace.artistStudio, CreatorWorkspace.institutionHub],
      );
      expect(
        resolveHomeCreatorWorkspaceOrder(
          persona: UserPersona.institution,
          isArtist: false,
          isInstitution: false,
        ).first,
        CreatorWorkspace.institutionHub,
      );
    });
  });

  group('resolveHomeInfrastructureCardOrder', () {
    test('holds no creator workspace, Node leads when enabled', () {
      expect(
        resolveHomeInfrastructureCardOrder(nodeEnabled: true),
        <String>['node', 'dao', 'marketplace', 'wallet'],
      );
      expect(
        resolveHomeInfrastructureCardOrder(),
        <String>['dao', 'marketplace', 'wallet'],
      );
    });
  });

  group('HomeCreatorCardStrip', () {
    testWidgets(
        'a guest sees both workspaces with no lock, and a tap opens '
        'the workspace', (tester) async {
      final opened = <CreatorWorkspace>[];
      await _pump(
        tester,
        HomeCreatorCardStrip(
          persona: null,
          isArtist: false,
          isInstitution: false,
          artistStage: CreatorWorkspaceStage.discover,
          institutionStage: CreatorWorkspaceStage.discover,
          onOpenWorkspace: opened.add,
        ),
      );

      expect(find.byKey(_artist), findsOneWidget);
      expect(find.byKey(_institution), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing,
          reason: 'not holding a role is not a lock: the workspace is open '
              'to read and explains how it opens');
      expect(
        tester.getTopLeft(find.byKey(_artist)).dx,
        lessThan(tester.getTopLeft(find.byKey(_institution)).dx),
      );

      await tester.tap(find.byKey(_artist));
      await tester.tap(find.byKey(_institution));
      expect(opened, const [
        CreatorWorkspace.artistStudio,
        CreatorWorkspace.institutionHub,
      ]);
    });

    testWidgets('states only confirmed stages', (tester) async {
      await _pump(
        tester,
        HomeCreatorCardStrip(
          persona: UserPersona.creator,
          isArtist: true,
          isInstitution: false,
          artistStage: CreatorWorkspaceStage.open,
          institutionStage: CreatorWorkspaceStage.pending,
          onOpenWorkspace: (_) {},
        ),
      );
      expect(
        find.descendant(of: find.byKey(_artist), matching: find.text('Open')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_institution),
          matching: find.text('In review'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('fits a 320 px phone at 200 % text without overflow',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        HomeCreatorCardStrip(
          persona: null,
          isArtist: false,
          isInstitution: false,
          artistStage: CreatorWorkspaceStage.rejected,
          institutionStage: CreatorWorkspaceStage.pending,
          onOpenWorkspace: (_) {},
        ),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeWeb3CardStrip (network and infrastructure)', () {
    testWidgets('wallet-backed destinations ask for a wallet; Node does not',
        (tester) async {
      var walletOnboarding = 0;
      var nodeOpened = 0;
      await _pump(
        tester,
        HomeWeb3CardStrip(
          isEffectivelyConnected: false,
          onOpenDao: () => fail('DAO must not open without a wallet'),
          onOpenMarketplace: () {},
          onOpenNode: () => nodeOpened += 1,
          onOpenWallet: () {},
          onShowWalletOnboarding: () => walletOnboarding += 1,
        ),
      );

      expect(find.byKey(_artist), findsNothing);
      expect(find.byKey(_institution), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('home_web3_dao')));
      expect(walletOnboarding, 1);

      final node = find.byKey(const ValueKey<String>('home_web3_node'));
      if (node.evaluate().isNotEmpty) {
        await tester.tap(node);
        expect(nodeOpened, 1);
        expect(walletOnboarding, 1);
      }

      final wallet = find.byKey(const ValueKey<String>('home_web3_wallet'));
      await tester.dragUntilVisible(
        wallet,
        find.byType(SingleChildScrollView),
        const Offset(-200, 0),
      );
      await tester.tap(wallet);
      expect(walletOnboarding, 2);
    });

    testWidgets('with a wallet the wallet card opens the wallet',
        (tester) async {
      var walletOpened = 0;
      await _pump(
        tester,
        HomeWeb3CardStrip(
          isEffectivelyConnected: true,
          onOpenDao: () {},
          onOpenMarketplace: () {},
          onOpenNode: () {},
          onOpenWallet: () => walletOpened += 1,
          onShowWalletOnboarding: () => fail('wallet already linked'),
        ),
      );
      final wallet = find.byKey(const ValueKey<String>('home_web3_wallet'));
      await tester.dragUntilVisible(
        wallet,
        find.byType(SingleChildScrollView),
        const Offset(-200, 0),
      );
      await tester.tap(wallet);
      expect(walletOpened, 1);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });
}
