import 'package:art_kubus/core/public_entry_navigation.dart';
import 'package:art_kubus/core/url_coherence_observer.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final navigation = PublicEntryNavigation.instance;

  setUp(navigation.resetForTest);
  tearDown(navigation.resetForTest);

  testWidgets('the canonical entry owns one exit and preserves its full URL',
      (tester) async {
    const entryUrl = '/en/artworks/a1?utm_source=qa#gallery';
    navigation.setEntry(
      type: ShareEntityType.artwork,
      entityId: 'a1',
      browserRoute: entryUrl,
      shellRoute: '/main',
    );
    var exitCount = 0;
    navigation.exitApp = () async => exitCount++;
    final harness = _Harness(
      navigation: navigation,
      initialRoute: entryUrl,
      initialType: ShareEntityType.artwork,
      initialId: 'a1',
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(navigation.visibleEntityUrl, entryUrl);
    expect(harness.reports, isEmpty);

    harness.navigator.pushNamed('/sign-in');
    await tester.pumpAndSettle();
    expect(await navigation.didPopRoute(), isFalse,
        reason: 'Back must pop the in-app route above the entry');
    harness.navigator.pop();
    await tester.pumpAndSettle();

    expect(navigation.entryIsTop, isTrue);
    expect(await navigation.didPopRoute(), isTrue);
    expect(exitCount, 1);
    expect(navigation.visibleEntityUrl, entryUrl,
        reason: 'a refused browser exit must retain query and fragment');
    expect(await navigation.didPopRoute(), isFalse,
        reason: 'a refused exit is offered to the Navigator only once');
    expect(exitCount, 1);
  });

  testWidgets('canonical route falls back to its shell path after takeover',
      (tester) async {
    const entryUrl = '/sl/umetnine/a1?source=qa#opis';
    navigation.setEntry(
      type: ShareEntityType.artwork,
      entityId: 'a1',
      browserRoute: entryUrl,
      shellRoute: '/main',
    );
    final harness = _Harness(
      navigation: navigation,
      initialRoute: entryUrl,
      initialType: ShareEntityType.artwork,
      initialId: 'a1',
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(navigation.visibleEntityUrl, entryUrl);

    await tester.tap(find.text('close entry screen'));
    await tester.pumpAndSettle();

    expect(navigation.visibleEntityUrl, isNull);
    expect(harness.reports, <String>['/main']);
    expect(navigation.underlyingShellRouteFor('/sl/umetnine/a1?source=qa'),
        '/main');
  });

  testWidgets('disabled URL observer keeps native navigation unchanged',
      (tester) async {
    const entryUrl = '/en/artworks/a1?campaign=native#detail';
    navigation.setEntry(
      type: ShareEntityType.artwork,
      entityId: 'a1',
      browserRoute: entryUrl,
      shellRoute: '/main',
    );
    final observer = UrlCoherenceObserver(
      enabled: false,
      report: (_) => fail('native mode must not update browser history'),
      entityUrls: navigation,
    );
    final harness = _Harness(
      navigation: navigation,
      initialRoute: entryUrl,
      initialType: ShareEntityType.artwork,
      initialId: 'a1',
      observer: observer,
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    harness.navigator.pushNamed('/sign-in');
    await tester.pumpAndSettle();
    harness.navigator.pop();
    await tester.pumpAndSettle();

    expect(navigation.visibleEntityUrl, entryUrl);
    observer.dispose();
  });

  group('an entry that never loads', () {
    const entryUrl = '/en/artworks/bad-id?utm_source=qa#gallery';

    void seedEntry() => navigation.setEntry(
          type: ShareEntityType.artwork,
          entityId: 'bad-id',
          browserRoute: entryUrl,
          shellRoute: '/main',
        );

    test('keeps its address for its own shell and path, drops it for others',
        () {
      seedEntry();
      navigation.pageOpened('/en/artworks/bad-id?utm_source=qa#gallery');
      navigation.pageOpened('/');
      navigation.pageOpened(null);
      navigation.pageOpened('/en');
      // An account gate is not plumbing; the sign-in test below covers it.
      expect(navigation.pendingEntryUrl, entryUrl,
          reason: 'pages before the shell appears are startup plumbing');

      navigation.pageOpened('/main');
      expect(navigation.pendingEntryUrl, entryUrl);
      navigation.pageOpened('/sign-in');
      expect(navigation.pendingEntryUrl, isNull,
          reason: 'a different page replaces the never-shown entry');
    });

    test('an unresolvable entry is dropped and its correction replaces', () {
      seedEntry();
      expect(navigation.takeReplaceNextAddress(), isFalse);

      navigation.entryUnresolved(ShareEntityType.marker, 'bad-id');
      expect(navigation.pendingEntryUrl, entryUrl,
          reason: 'another type is not this entry');

      navigation.entryUnresolved(ShareEntityType.artwork, 'bad-id');
      expect(navigation.pendingEntryUrl, isNull);
      expect(navigation.takeReplaceNextAddress(), isTrue);
      expect(navigation.takeReplaceNextAddress(), isFalse);
    });

    testWidgets(
        're-seeding the entry while its old screen is torn down keeps it',
        (tester) async {
      seedEntry();
      late BuildContext screen;
      await tester.pumpWidget(Builder(builder: (context) {
        screen = context;
        return const SizedBox.shrink();
      }));
      final token = navigation.claim(
        screen,
        type: ShareEntityType.artwork,
        entityId: 'bad-id',
        localizedPath: (_) => '/en/artworks/bad-id',
      );
      expect(navigation.visibleEntityUrl, entryUrl);

      // Browser Back restores the page: the same entry is seeded again, then
      // the screen it replaces is disposed.
      seedEntry();
      navigation.release(token, retireEntryIfUnused: true);
      await tester.pump();
      await tester.pump();

      expect(navigation.pendingEntryUrl, entryUrl,
          reason: 'the restored screen has not claimed yet');
    });

    testWidgets('a screen that really leaves still retires its entry',
        (tester) async {
      seedEntry();
      late BuildContext screen;
      await tester.pumpWidget(Builder(builder: (context) {
        screen = context;
        return const SizedBox.shrink();
      }));
      final token = navigation.claim(
        screen,
        type: ShareEntityType.artwork,
        entityId: 'bad-id',
        localizedPath: (_) => '/en/artworks/bad-id',
      );
      expect(navigation.visibleEntityUrl, entryUrl);

      navigation.release(token, retireEntryIfUnused: true);
      await tester.pump();
      await tester.pump();

      expect(navigation.pendingEntryUrl, isNull);
    });

    testWidgets('a claimed entry is not abandoned by later pages',
        (tester) async {
      seedEntry();
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          navigation.claim(
            context,
            type: ShareEntityType.artwork,
            entityId: 'bad-id',
            localizedPath: (_) => '/en/artworks/bad-id',
          );
          return const SizedBox.shrink();
        }),
      ));
      expect(navigation.visibleEntityUrl, entryUrl);

      navigation.pageOpened('/sign-in');
      expect(navigation.visibleEntityUrl, entryUrl);
      expect(navigation.entryIsTop, isTrue);
    });

    testWidgets('claiming a different entity releases the unclaimed entry',
        (tester) async {
      seedEntry();
      expect(navigation.pendingEntryUrl, entryUrl);
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          navigation.claim(
            context,
            type: ShareEntityType.marker,
            entityId: 'other',
            localizedPath: (_) => '/en/map/other',
          );
          return const SizedBox.shrink();
        }),
      ));

      expect(navigation.pendingEntryUrl, isNull);
      expect(navigation.visibleEntityUrl, '/en/map/other');
    });

    testWidgets(
        'Back from a not-found entity page reports the shell, not the '
        'phantom entity URL', (tester) async {
      seedEntry();
      final reports = <String>[];
      String? browserUrl = entryUrl;
      final observer = UrlCoherenceObserver(
        enabled: true,
        report: (url) {
          reports.add(url);
          browserUrl = url;
        },
        entityUrls: navigation,
        currentBrowserUrl: () => browserUrl,
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[observer],
        initialRoute: '/main',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('page ${settings.name}'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(reports, isEmpty, reason: 'the pending entry keeps its address');

      // The visitor opens another page; the entity never rendered.
      navigatorKey.currentState!.pushNamed('/map');
      await tester.pumpAndSettle();

      expect(reports, <String>['/map']);
      expect(navigation.pendingEntryUrl, isNull);
      observer.dispose();
    });

    testWidgets(
        'a sign-in gate that replaces a pending entry before its shell shows '
        'takes over the address', (tester) async {
      const entryUrl = '/en/artworks/a1?utm_source=qa';
      navigation.setEntry(
        type: ShareEntityType.artwork,
        entityId: 'a1',
        browserRoute: entryUrl,
        shellRoute: '/main',
      );
      final pushes = <String>[];
      final replaces = <String>[];
      String? browserUrl = entryUrl;
      final observer = UrlCoherenceObserver(
        enabled: true,
        report: (url) {
          pushes.add(url);
          browserUrl = url;
        },
        reportReplace: (url) {
          replaces.add(url);
          browserUrl = url;
        },
        entityUrls: navigation,
        currentBrowserUrl: () => browserUrl,
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[observer],
        initialRoute: entryUrl,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('page ${settings.name}'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(pushes, isEmpty, reason: 'the pending entry keeps its address');
      expect(replaces, isEmpty, reason: 'the pending entry keeps its address');

      // AppInitializer hands an account-only entity to sign-in before the shell
      // has appeared. The sign-in page is what the visitor sees now.
      navigatorKey.currentState!.pushReplacementNamed(
        '/sign-in',
        arguments: <String, Object?>{'redirectRoute': entryUrl},
      );
      await tester.pumpAndSettle();

      expect(replaces, <String>['/sign-in'],
          reason: 'the gate replaces the entry it took over, never adds one');
      expect(pushes, isEmpty);
      expect(browserUrl, '/sign-in');
      expect(navigation.pendingEntryUrl, isNull);
      observer.dispose();
    });
  });
}

class _Harness {
  _Harness({
    required this.navigation,
    required this.initialRoute,
    required this.initialType,
    required this.initialId,
    this.observer,
  });

  final PublicEntryNavigation navigation;
  final String initialRoute;
  final ShareEntityType initialType;
  final String initialId;
  final UrlCoherenceObserver? observer;
  final List<String> reports = <String>[];
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String? browserUrl;

  NavigatorState get navigator => navigatorKey.currentState!;

  Widget build() {
    final urlObserver = observer ??
        UrlCoherenceObserver(
          enabled: true,
          report: (url) {
            reports.add(url);
            browserUrl = url;
          },
          entityUrls: navigation,
          currentBrowserUrl: () => browserUrl,
        );
    browserUrl ??= initialRoute;
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[urlObserver],
      locale: initialRoute.startsWith('/sl/')
          ? const Locale('sl')
          : const Locale('en'),
      supportedLocales: const <Locale>[Locale('en'), Locale('sl')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _EntryPage(
          navigation: navigation,
          type: initialType,
          id: initialId,
          entryRoute: settings.name == initialRoute,
        ),
      ),
    );
  }
}

class _EntryPage extends StatefulWidget {
  const _EntryPage({
    required this.navigation,
    required this.type,
    required this.id,
    required this.entryRoute,
  });

  final PublicEntryNavigation navigation;
  final ShareEntityType type;
  final String id;
  final bool entryRoute;

  @override
  State<_EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<_EntryPage> {
  Object? _claim;
  bool _showEntry = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.entryRoute || _claim != null) return;
    _claim = widget.navigation.claim(
      context,
      type: widget.type,
      entityId: widget.id,
      localizedPath: (languageCode) => languageCode == 'sl'
          ? '/sl/umetnine/${widget.id}'
          : '/en/artworks/${widget.id}',
    );
  }

  @override
  void dispose() {
    widget.navigation.release(_claim);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.entryRoute) return const Scaffold(body: Text('other page'));
    if (!_showEntry) return const Scaffold(body: Text('shell'));
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() {
            _showEntry = false;
            widget.navigation.release(_claim);
            _claim = null;
          }),
          child: const Text('close entry screen'),
        ),
      ),
    );
  }
}
