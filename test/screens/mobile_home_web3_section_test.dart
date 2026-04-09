import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHomeWeb3Strip(
  WidgetTester tester, {
  required Size size,
  required bool isArtist,
  required bool isInstitution,
  required UserPersona? persona,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themeProvider = ThemeProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: HomeWeb3CardStrip(
                isEffectivelyConnected: false,
                persona: persona,
                isArtist: isArtist,
                isInstitution: isInstitution,
                onOpenDao: () {},
                onOpenArtistStudio: () {},
                onOpenInstitutionHub: () {},
                onOpenMarketplace: () {},
                onShowWalletOnboarding: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolveHomeWeb3CardOrder returns creator persona order', () {
    expect(
      resolveHomeWeb3CardOrder(
        persona: UserPersona.creator,
        isArtist: true,
        isInstitution: false,
      ),
      <String>['artist', 'dao', 'marketplace'],
    );
  });

  test('resolveHomeWeb3CardOrder returns institution persona order', () {
    expect(
      resolveHomeWeb3CardOrder(
        persona: UserPersona.institution,
        isArtist: false,
        isInstitution: true,
      ),
      <String>['institution', 'dao', 'marketplace'],
    );
  });

  test('resolveHomeWeb3CardOrder returns both-role creator order', () {
    expect(
      resolveHomeWeb3CardOrder(
        persona: UserPersona.creator,
        isArtist: true,
        isInstitution: true,
      ),
      <String>['artist', 'dao', 'institution', 'marketplace'],
    );
  });

  test('resolveHomeWeb3CardOrder returns both-role institution order', () {
    expect(
      resolveHomeWeb3CardOrder(
        persona: UserPersona.institution,
        isArtist: true,
        isInstitution: true,
      ),
      <String>['institution', 'dao', 'artist', 'marketplace'],
    );
  });

  test('resolveHomeWeb3CardOrder returns no-role order', () {
    expect(
      resolveHomeWeb3CardOrder(
        persona: null,
        isArtist: false,
        isInstitution: false,
      ),
      <String>['dao', 'marketplace'],
    );
  });

  testWidgets(
      'mobile home web3 section uses horizontal row ordering and keeps marketplace offscreen initially',
      (tester) async {
    await _pumpHomeWeb3Strip(
      tester,
      size: const Size(420, 600),
      isArtist: true,
      isInstitution: true,
      persona: UserPersona.creator,
    );

    final artistFinder = find.byKey(const ValueKey<String>('home_web3_artist'));
    final daoFinder = find.byKey(const ValueKey<String>('home_web3_dao'));
    final institutionFinder =
        find.byKey(const ValueKey<String>('home_web3_institution'));
    final marketplaceFinder =
        find.byKey(const ValueKey<String>('home_web3_marketplace'));

    expect(artistFinder, findsOneWidget);
    expect(daoFinder, findsOneWidget);
    expect(institutionFinder, findsOneWidget);
    expect(marketplaceFinder, findsOneWidget);

    final horizontalScrollView = find.ancestor(
      of: daoFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
    );
    expect(horizontalScrollView, findsOneWidget);

    final artistLeft = tester.getTopLeft(artistFinder).dx;
    final daoLeft = tester.getTopLeft(daoFinder).dx;
    final institutionLeft = tester.getTopLeft(institutionFinder).dx;
    final marketplaceLeft = tester.getTopLeft(marketplaceFinder).dx;

    expect(artistLeft, lessThan(daoLeft));
    expect(daoLeft, lessThan(institutionLeft));
    expect(institutionLeft, lessThan(marketplaceLeft));
    expect(marketplaceLeft, greaterThan(420));

    await tester.drag(horizontalScrollView, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(marketplaceFinder).dx, lessThan(420));
  });

  testWidgets('mobile home web3 strip hides role cards when no approvals exist',
      (tester) async {
    await _pumpHomeWeb3Strip(
      tester,
      size: const Size(420, 600),
      isArtist: false,
      isInstitution: false,
      persona: null,
    );

    expect(
        find.byKey(const ValueKey<String>('home_web3_artist')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home_web3_institution')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('home_web3_dao')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home_web3_marketplace')),
      findsOneWidget,
    );
  });
}
