import 'package:art_kubus/core/browser_entry_router.dart';
import 'package:art_kubus/core/public_entry_navigation.dart';
import 'package:art_kubus/core/url_coherence_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BrowserEntryRouteInformationParser();

  test('English and Slovenian public routes round-trip query and fragment',
      () async {
    for (final url in <String>[
      '/en/artworks/a1?utm_source=qa#gallery',
      '/sl/umetnine/a1?utm_source=qa#opis',
    ]) {
      final original = BrowserEntryRoute.fromUri(Uri.parse(url));
      final restored = await parser.parseRouteInformation(
        parser.restoreRouteInformation(original),
      );

      expect(restored, original);
      expect(restored.visibleUri.toString(), url);
      expect(restored.shellRoute, '/main');
      expect(restored.entityType, 'artwork');
      expect(restored.entityId, 'a1');
    }
  });

  test('marker config keeps map shell and selected marker separate', () async {
    const url = '/sl/zemljevid/marker-1?source=qa#map';
    final initial = BrowserEntryRoute.fromUri(Uri.parse(url));
    final restored = await parser.parseRouteInformation(
      parser.restoreRouteInformation(initial),
    );

    expect(restored.visibleUri.toString(), url);
    expect(restored.shellRoute, '/map');
    expect(restored.entityType, 'marker');
    expect(restored.entityId, 'marker-1');
    expect(restored.markerId, 'marker-1');
  });

  test('map viewport is serializable without converting it to an entity', () {
    final route = BrowserEntryRoute.fromUri(
      Uri.parse('/map?lat=46.05&lng=14.51&z=12'),
    );

    expect(route.shellRoute, '/map');
    expect(route.entityType, 'map');
    expect(route.entityId, isNull);
    expect(route.latitude, 46.05);
    expect(route.longitude, 14.51);
    expect(route.zoom, 12);
  });

  test('changing from an entity to the shell drops entry query and fragment',
      () {
    final entry = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1?utm_source=qa#gallery'),
    );
    final shell = entry.withVisibleUri(Uri.parse('/main'));

    expect(shell.visibleUri.toString(), '/main');
    expect(shell.shellRoute, '/main');
    expect(shell.entityType, isNull);
    expect(shell.entityId, isNull);
  });

  test('history state serializes the exact visible URI including fragment',
      () async {
    final entry = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1?utm_source=qa#gallery'),
    );
    final state = entry.toHistoryState();
    final restored = await parser.parseRouteInformation(
      RouteInformation(uri: entry.visibleUri, state: state),
    );

    expect(state['visibleUri'], '/en/artworks/a1?utm_source=qa#gallery');
    expect(restored.visibleUri.toString(), entry.visibleUri.toString());
  });

  test('browser route URI wins when it differs from the serialized snapshot',
      () async {
    final previous = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1?utm_source=qa#gallery'),
    );
    final incoming = Uri.parse('/en/artworks/a1?utm_source=related');
    final restored = await parser.parseRouteInformation(
      RouteInformation(uri: incoming, state: previous.toHistoryState()),
    );

    expect(restored.visibleUri, incoming);
    expect(restored.visibleUri.fragment, isEmpty);
    expect(restored.visibleUri.query, 'utm_source=related');
  });

  test('related collection route keeps its own URI and main shell state',
      () async {
    const url = '/en/collections/a0842200-0000-4000-8000-0000000000c1'
        '?source=related#members';
    final route = BrowserEntryRoute.fromUri(Uri.parse(url));
    final restored = await parser.parseRouteInformation(
      parser.restoreRouteInformation(route),
    );

    expect(restored.visibleUri.toString(), url);
    expect(restored.shellRoute, '/main');
    expect(restored.entityType, 'collection');
    expect(restored.entityId, 'a0842200-0000-4000-8000-0000000000c1');
  });

  testWidgets('browser route restoration receives the serialized config',
      (tester) async {
    final initial = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1?utm_source=qa#gallery'),
    );
    final previous = BrowserEntryRoute.fromUri(
      Uri.parse('/sl/umetnine/a2?source=related#opis'),
      historyState: <String, Object?>{'shellRoute': '/main'},
    );
    final restored = <BrowserEntryRoute>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: navigatorKey,
      initialConfiguration: initial,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('initial route')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('restored route')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) async => restored.add(configuration),
    );
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: initial.toRouteInformation(),
    );

    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    await delegate.setNewRoutePath(previous);

    expect(restored, <BrowserEntryRoute>[previous]);
    expect(delegate.currentConfiguration, previous);
    expect(
        previous.visibleUri.toString(), '/sl/umetnine/a2?source=related#opis');
    expect(previous.shellRoute, '/main');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets('hash-only browser navigation keeps the current screen',
      (tester) async {
    final initial = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1?utm_source=qa#gallery'),
    );
    final changedFragment = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1?utm_source=qa#details'),
      historyState: initial.toHistoryState(),
    );
    final restored = <BrowserEntryRoute>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: navigatorKey,
      initialConfiguration: initial,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('current artwork')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('restored route')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) async => restored.add(configuration),
    );
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: initial.toRouteInformation(),
    );

    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    await delegate.setNewRoutePath(changedFragment);
    await tester.pumpAndSettle();

    expect(find.text('current artwork'), findsOneWidget);
    expect(find.text('restored route'), findsNothing);
    expect(restored, isEmpty);
    expect(delegate.currentConfiguration.visibleUri.fragment, 'details');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  group('BrowserHistoryMirror', () {
    Uri u(String s) => Uri.parse(s);

    test('push, replace and step-back eligibility follow the reports', () {
      final mirror = BrowserHistoryMirror()
        ..recordReport(u('/main'), replace: true)
        ..recordReport(u('/en/artworks/a1'), replace: false);

      expect(mirror.cursor, 1);
      expect(mirror.canStepBackTo(u('/main')), isTrue);
      expect(mirror.canStepBackTo(u('/map')), isFalse);

      mirror.recordReport(u('/en/artworks/a1?x=1'), replace: true);
      expect(mirror.cursor, 1);
      expect(mirror.canStepBackTo(u('/main')), isTrue);
    });

    test('the first entry has nothing below it', () {
      final mirror = BrowserHistoryMirror()
        ..recordReport(u('/en/artworks/a1'), replace: true);
      expect(mirror.canStepBackTo(u('/main')), isFalse);
    });

    test('browser Back/Forward move the cursor; unknown entries restart', () {
      final mirror = BrowserHistoryMirror()
        ..recordReport(u('/main'), replace: true)
        ..recordReport(u('/map'), replace: false)
        ..recordReport(u('/en/artworks/a1'), replace: false);

      mirror.browserNavigated(u('/main'), 0);
      expect(mirror.cursor, 0);
      mirror.browserNavigated(u('/en/artworks/a1'), 2);
      expect(mirror.cursor, 2);

      mirror.browserNavigated(u('/somewhere'), 7);
      expect(mirror.cursor, 0);
      expect(mirror.current, u('/somewhere'));
      expect(mirror.canStepBackTo(u('/main')), isFalse);
    });

    test('pushing after stepping back discards the forward entries', () {
      final mirror = BrowserHistoryMirror()
        ..recordReport(u('/main'), replace: true)
        ..recordReport(u('/map'), replace: false);
      mirror.browserNavigated(u('/main'), 0);
      mirror.recordReport(u('/community'), replace: false);

      expect(mirror.cursor, 1);
      expect(mirror.canStepBackTo(u('/main')), isTrue);
      mirror.browserNavigated(u('/map'), 1);
      expect(mirror.current, u('/map'),
          reason: 'a stale index for a different URL restarts the mirror');
    });

    test('query order does not make two locations different', () {
      expect(
        BrowserHistoryMirror.sameLocation(u('/a?x=1&y=2'), u('/a?y=2&x=1')),
        isTrue,
      );
      expect(
        BrowserHistoryMirror.sameLocation(u('/a#one'), u('/a#two')),
        isFalse,
      );
    });
  });

  testWidgets(
      'an in-app Back steps the browser back instead of adding an entry',
      (tester) async {
    final home = BrowserEntryRoute.fromUri(Uri.parse('/main'));
    final history = BrowserHistoryMirror();
    final restored = <BrowserEntryRoute>[];
    var steps = 0;
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: home,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('home')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) => restored.add(configuration),
      history: history,
      stepBrowserBack: () => steps++,
    );
    final provider = StartupBrowserRouteInformationProvider(
      home,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    // Home -> artwork reports a new entry.
    delegate.reportVisibleUri(Uri.parse('/en/artworks/a1'));
    await tester.pumpAndSettle();
    expect(history.cursor, 1);

    // The in-app back arrow returns to Home: step the browser, add nothing.
    delegate.reportVisibleBack(Uri.parse('/main'));
    await tester.pumpAndSettle();
    expect(steps, 1);
    expect(history.cursor, 1, reason: 'no entry was pushed for Home');

    // The popstate that follows arrives with the recorded index and must not
    // rebuild the page the Navigator already shows.
    await delegate.setNewRoutePath(BrowserEntryRoute.fromUri(
      Uri.parse('/main'),
      historyState: <String, Object?>{'historyIndex': 0},
    ));
    expect(restored, isEmpty);
    expect(history.cursor, 0);
    expect(delegate.currentConfiguration.visibleUri.path, '/main');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets('an in-app Back with no matching entry below is a normal report',
      (tester) async {
    final entry = BrowserEntryRoute.fromUri(Uri.parse('/en/artworks/a1'));
    final history = BrowserHistoryMirror();
    var steps = 0;
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: entry,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('entry')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) {},
      history: history,
      stepBrowserBack: () => steps++,
    );
    final provider = StartupBrowserRouteInformationProvider(
      entry,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    // The entity was the first entry: Home is not below it, so Home is pushed.
    delegate.reportVisibleBack(Uri.parse('/main'));
    await tester.pumpAndSettle();

    expect(steps, 0);
    expect(history.cursor, 1);
    expect(delegate.currentConfiguration.visibleUri.path, '/main');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets(
      'an in-app Back from a reloaded entry replaces it when the entry below is app history',
      (tester) async {
    // The state the engine returns after a reload of an artwork opened from
    // the collection, as measured in Chromium: the Router's entry wrapped in
    // the engine's {serialCount, state} record (serialCount is a double), with
    // historyBack naming the collection entry below it.
    const artwork = '/en/artworks/b4e7026c-4ee8-52b5-80e5-a3625117ef3b';
    const collection = '/en/collections/a0842200-0000-4000-8000-0000000000c1';
    final entry = BrowserEntryRoute.fromUri(
      Uri.parse(artwork),
      historyState: <Object?, Object?>{
        'serialCount': 1.0,
        'state': <Object?, Object?>{
          'version': 1,
          'visibleUri': artwork,
          'shellRoute': '/main',
          'entityType': 'artwork',
          'entityId': 'b4e7026c-4ee8-52b5-80e5-a3625117ef3b',
          'historyIndex': 1,
          'historyBack': collection,
        },
      },
    );
    final history = BrowserHistoryMirror();
    var steps = 0;
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: entry,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('entry')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) {},
      history: history,
      stepBrowserBack: () => steps++,
    );
    final provider = StartupBrowserRouteInformationProvider(
      entry,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    // The reload restored the browser entries: the collection is below.
    expect(history.cursor, 1);
    expect(history.below, Uri.parse(collection));

    // The in-app Back pops the artwork to Home. The browser cannot step to
    // Home, so Home replaces the artwork: the entry count is unchanged and the
    // collection stays below Home, not a second Home above the artwork.
    delegate.reportVisibleBack(Uri.parse('/main'));
    await tester.pumpAndSettle();

    expect(steps, 0);
    expect(history.cursor, 1, reason: 'no entry was pushed for Home');
    expect(history.current, Uri.parse('/main'));
    expect(history.below, Uri.parse(collection));
    expect(delegate.currentConfiguration.visibleUri.path, '/main');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets(
      'an in-app change the browser cannot step to pushes when no entry was '
      'restored, so Back still returns to the entry left', (tester) async {
    // A cold visit to a collection, then an artwork pushed from it: the
    // entry below is app history this page recorded, not a restored one.
    final collection = BrowserEntryRoute.fromUri(
      Uri.parse('/en/collections/c1'),
    );
    final history = BrowserHistoryMirror();
    var steps = 0;
    final delegate = _restoringDelegate(
      collection,
      <String>[],
      history: history,
      stepBrowserBack: () => steps++,
    );
    final provider = StartupBrowserRouteInformationProvider(
      collection,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    delegate.reportVisibleUri(Uri.parse('/en/artworks/a1'));
    await tester.pumpAndSettle();
    expect(history.cursor, 1);

    // A related artwork opened without a page push (a desktop panel) is a new
    // entry: it must not overwrite artwork a1 in the browser history.
    delegate.reportVisibleBack(Uri.parse('/en/artworks/b2'));
    await tester.pumpAndSettle();

    expect(steps, 0, reason: 'the browser cannot step to artwork b2');
    expect(history.cursor, 2);
    expect(history.below, Uri.parse('/en/artworks/a1'));
    expect(history.current, Uri.parse('/en/artworks/b2'));

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets(
      'a reloaded entry opened forward pushes the related page instead of '
      'replacing the reloaded entry', (tester) async {
    final artwork = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1'),
      historyState: <String, Object?>{
        'serialCount': 2.0,
        'state': <String, Object?>{
          'historyIndex': 1,
          'historyBack': '/en/collections/c1',
        },
      },
    );
    final history = BrowserHistoryMirror();
    final delegate = _restoringDelegate(
      artwork,
      <String>[],
      history: history,
      stepBrowserBack: () {},
    );
    final provider = StartupBrowserRouteInformationProvider(
      artwork,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();
    expect(history.below, Uri.parse('/en/collections/c1'));

    // Opening a related artwork on the reloaded page is not an in-app Back to
    // its shell: the reloaded artwork a1 keeps its browser entry.
    delegate.reportVisibleBack(Uri.parse('/en/artworks/b2'));
    await tester.pumpAndSettle();

    expect(history.cursor, 2);
    expect(history.below, Uri.parse('/en/artworks/a1'));
    expect(history.current, Uri.parse('/en/artworks/b2'));

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets('a replacing report rewrites the entry instead of adding one',
      (tester) async {
    final entry = BrowserEntryRoute.fromUri(Uri.parse('/en/map/bad-marker'));
    final reports = <(Uri, RouteInformationReportingType)>[];
    final history = BrowserHistoryMirror();
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: entry,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('map')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) {},
      history: history,
    );
    final provider = _RecordingProvider(
      entry,
      history,
      (info, type) => reports.add((info.uri, type)),
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();
    reports.clear();

    delegate.reportVisibleUri(Uri.parse('/map'), replace: true);
    await tester.pumpAndSettle();

    expect(reports.map((r) => r.$1.path), <String>['/map']);
    expect(reports.single.$2, RouteInformationReportingType.neglect);
    expect(history.cursor, 0, reason: 'replaced, not appended');

    delegate.reportVisibleUri(Uri.parse('/main'));
    await tester.pumpAndSettle();
    expect(history.cursor, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets(
      'history traversals during a restore are coalesced to the latest one',
      (tester) async {
    final initial = BrowserEntryRoute.fromUri(Uri.parse('/main'));
    final restored = <String>[];
    final delegate = BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: initial,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('shell')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) =>
          restored.add(configuration.visibleUri.path),
      restoreCooldown: const Duration(milliseconds: 800),
    );
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: initial.toRouteInformation(),
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    BrowserEntryRoute at(String path) =>
        BrowserEntryRoute.fromUri(Uri.parse(path));
    await delegate.setNewRoutePath(at('/en/collections/c1'));
    expect(restored, <String>['/en/collections/c1']);

    // Forward arrives while the first restore is still starting up, then a
    // third traversal: only the last one is restored, once, after the cooldown.
    await delegate.setNewRoutePath(at('/en/artworks/a1'));
    await delegate.setNewRoutePath(at('/en/events/e1'));
    expect(restored, <String>['/en/collections/c1'],
        reason: 'nothing may be restored inside the cooldown');
    expect(delegate.currentConfiguration.visibleUri.path, '/en/events/e1',
        reason: 'the serialized address still follows the browser');

    await tester.pump(const Duration(milliseconds: 801));
    expect(restored, <String>['/en/collections/c1', '/en/events/e1']);

    // Nothing pending: the next traversal after the cooldown is immediate.
    await tester.pump(const Duration(milliseconds: 801));
    await delegate.setNewRoutePath(at('/en/artworks/a1'));
    expect(restored.last, '/en/artworks/a1');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets(
      'a page starting up during a deferred traversal cannot overwrite the '
      'entry the browser moved to', (tester) async {
    final navigation = PublicEntryNavigation.instance;
    navigation.resetForTest();
    addTearDown(navigation.resetForTest);
    const home = '/main';
    const first = '/en/artworks/a1';
    const second = '/en/events/e1';
    String? browserUrl = home;
    final browserReports = <String>[];
    final restored = <String>[];
    // The observer is wired exactly as main.dart wires it to the delegate.
    late final BrowserEntryRouterDelegate delegate;
    final observer = UrlCoherenceObserver(
      enabled: true,
      report: (url) => delegate.reportVisibleUri(Uri.parse(url)),
      reportBack: (url) => delegate.reportVisibleBack(Uri.parse(url)),
      reportReplace: (url) =>
          delegate.reportVisibleUri(Uri.parse(url), replace: true),
      entityUrls: navigation,
      currentBrowserUrl: () => browserUrl,
    );
    addTearDown(observer.dispose);
    delegate = BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: BrowserEntryRoute.fromUri(Uri.parse(home)),
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('shell')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: <NavigatorObserver>[observer],
      restoreRoute: (configuration, navigator) {
        final name = configuration.visibleUri.toString();
        restored.add(name);
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: name),
            builder: (_) => Scaffold(body: Text('page $name')),
          ),
          (_) => false,
        );
      },
    );
    final provider = _RecordingProvider(
      BrowserEntryRoute.fromUri(Uri.parse(home)),
      BrowserHistoryMirror(),
      (info, type) {
        browserReports.add(info.uri.toString());
        browserUrl = info.uri.toString();
      },
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    // Back to the artwork: its restore starts and the cooldown begins.
    browserUrl = first;
    await delegate.setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse(first)));
    await tester.pumpAndSettle();
    expect(restored, <String>[first]);
    expect(find.text('page $first'), findsOneWidget);
    browserReports.clear();

    // Back again to the event before the artwork has finished starting. Its
    // startup then reports its own address while the browser shows the event.
    browserUrl = second;
    await delegate
        .setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse(second)));
    navigation.visibilityChanged();
    await tester.pump();
    expect(browserReports, isNot(contains(first)),
        reason: 'the starting page must not overwrite the entry the browser '
            'moved to');

    // The cooldown ends: only the event is restored, and nothing re-pushes the
    // artwork.
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pumpAndSettle();
    expect(restored, <String>[first, second]);
    expect(find.text('page $second'), findsOneWidget);
    expect(browserUrl, second);
    expect(browserReports, isNot(contains(first)));

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets(
      'a traversal back to the page on screen drops the restore it deferred',
      (tester) async {
    const first = '/en/artworks/a1';
    final restored = <String>[];
    final delegate = _restoringDelegate(
      BrowserEntryRoute.fromUri(Uri.parse('/main')),
      restored,
    );
    await _pumpDelegate(tester, delegate);

    await delegate.setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse(first)));
    await delegate
        .setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse('/en/events/e1')));
    // The browser returns to the artwork (with a fragment) inside the cooldown.
    await delegate.setNewRoutePath(
        BrowserEntryRoute.fromUri(Uri.parse('$first#details')));
    await tester.pump(const Duration(milliseconds: 801));

    expect(restored, <String>[first],
        reason: 'the artwork already on screen must not start a second time');
    expect(delegate.currentConfiguration.visibleUri.fragment, 'details');
    await tester.pumpWidget(const SizedBox.shrink());
    delegate.dispose();
  });

  testWidgets(
      'a fragment-only traversal during a cooldown restores the latest '
      'fragment, not the deferred one', (tester) async {
    final restored = <String>[];
    final delegate = _restoringDelegate(
      BrowserEntryRoute.fromUri(Uri.parse('/main')),
      restored,
    );
    await _pumpDelegate(tester, delegate);

    await delegate.setNewRoutePath(
        BrowserEntryRoute.fromUri(Uri.parse('/en/artworks/a1')));
    await delegate.setNewRoutePath(
        BrowserEntryRoute.fromUri(Uri.parse('/en/events/e1#a')));
    await delegate.setNewRoutePath(
        BrowserEntryRoute.fromUri(Uri.parse('/en/events/e1#b')));
    await tester.pump(const Duration(milliseconds: 801));

    final replayed = Uri.parse(restored.last);
    expect(replayed.path, '/en/events/e1');
    expect(replayed.fragment, 'b',
        reason: 'the deferred restore must show the live fragment');
    await tester.pumpWidget(const SizedBox.shrink());
    delegate.dispose();
  });

  testWidgets(
      'a reloaded page restores the entry below it, so an in-app Back steps '
      'the browser instead of pushing a second Home', (tester) async {
    // The engine's wrapper, as a reload returns it from history.state.
    final artwork = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/a1'),
      historyState: <String, Object?>{
        'serialCount': 2.0,
        'state': <String, Object?>{
          'historyIndex': 1,
          'historyBack': '/main',
        },
      },
    );
    final history = BrowserHistoryMirror();
    var steps = 0;
    final delegate = _restoringDelegate(
      artwork,
      <String>[],
      history: history,
      stepBrowserBack: () => steps++,
    );
    final provider = StartupBrowserRouteInformationProvider(
      artwork,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    expect(history.cursor, 1, reason: 'the reloaded entry keeps its place');
    delegate.reportVisibleBack(Uri.parse('/main'));
    await tester.pumpAndSettle();

    expect(steps, 1, reason: 'Home is the entry below: step back to it');
    expect(history.cursor, 1, reason: 'no duplicate Home was pushed');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  test('an engine-wrapped history state is read through the route parser',
      () async {
    final route = await const BrowserEntryRouteInformationParser()
        .parseRouteInformation(RouteInformation(
      uri: Uri.parse('/en/artworks/a1'),
      state: <String, Object?>{
        'serialCount': 2.0,
        'state': <String, Object?>{
          'historyIndex': 1,
          'historyBack': '/main',
        },
      },
    ));

    expect(route.historyIndex, 1);
    expect(route.historyBack, Uri.parse('/main'));
    expect(
      unwrapEngineHistoryState(
          <String, Object?>{'serialCount': 2.0, 'state': 'x'}),
      'x',
    );
    expect(unwrapEngineHistoryState('plain'), 'plain');
  });

  testWidgets(
      'a traversal to an entry this page did not record keeps the entry below '
      'it, so a second in-app Back still steps', (tester) async {
    final entry = BrowserEntryRoute.fromUri(
      Uri.parse('/en/artworks/c'),
      historyState: <String, Object?>{
        'serialCount': 3.0,
        'state': <String, Object?>{
          'historyIndex': 2,
          'historyBack': '/en/events/b',
        },
      },
    );
    final history = BrowserHistoryMirror();
    var steps = 0;
    final restored = <String>[];
    final delegate = _restoringDelegate(
      entry,
      restored,
      history: history,
      stepBrowserBack: () => steps++,
    );
    final provider = StartupBrowserRouteInformationProvider(
      entry,
      history: history,
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    delegate.reportVisibleBack(Uri.parse('/en/events/b'));
    await tester.pumpAndSettle();
    expect(steps, 1);

    // The browser lands on B at a position this page never recorded (7). B's
    // own state names A beneath it.
    await delegate.setNewRoutePath(BrowserEntryRoute.fromUri(
      Uri.parse('/en/events/b'),
      historyState: <String, Object?>{
        'serialCount': 8.0,
        'state': <String, Object?>{
          'historyIndex': 7,
          'historyBack': '/en/collections/a',
        },
      },
    ));
    await tester.pumpAndSettle();
    expect(restored, isEmpty, reason: 'the browser Back was the in-app step');

    delegate.reportVisibleBack(Uri.parse('/en/collections/a'));
    await tester.pumpAndSettle();
    expect(steps, 2, reason: 'A is the entry below B: step, never push it');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });

  testWidgets(
      'an in-app change reported during a deferred restore is replayed when '
      'the browser returns to the page on screen', (tester) async {
    const first = '/en/artworks/a1';
    const second = '/en/events/e1';
    const tapped = '/en/artworks/a1/more';
    final restored = <String>[];
    final browserReports = <String>[];
    final delegate = _restoringDelegate(
      BrowserEntryRoute.fromUri(Uri.parse('/main')),
      restored,
    );
    final provider = _RecordingProvider(
      BrowserEntryRoute.fromUri(Uri.parse('/main')),
      BrowserHistoryMirror(),
      (info, type) => browserReports.add(info.uri.toString()),
    );
    await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: provider,
      routeInformationParser: parser,
      routerDelegate: delegate,
    ));
    await tester.pumpAndSettle();

    await delegate.setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse(first)));
    await delegate
        .setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse(second)));
    // The visitor acts on the page on screen inside the cooldown.
    delegate.reportVisibleUri(Uri.parse(tapped));
    expect(delegate.currentConfiguration.visibleUri.toString(), second,
        reason: 'a visible report waits while the restore is pending');

    // The browser returns to the artwork on screen before the cooldown ends.
    await delegate.setNewRoutePath(BrowserEntryRoute.fromUri(Uri.parse(first)));
    await tester.pumpAndSettle();
    expect(delegate.currentConfiguration.visibleUri.toString(), tapped,
        reason: 'the in-app change still reaches the address');
    expect(browserReports.last, tapped);

    await tester.pump(const Duration(milliseconds: 801));
    expect(restored, <String>[first],
        reason: 'the deferred page is no longer wanted');

    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    delegate.dispose();
  });
}

/// Builds a delegate whose restores are recorded in [restored] and do not
/// touch the Navigator. Restores start from the navigator the router shows.
BrowserEntryRouterDelegate _restoringDelegate(
  BrowserEntryRoute initial,
  List<String> restored, {
  BrowserHistoryMirror? history,
  VoidCallback? stepBrowserBack,
}) =>
    BrowserEntryRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialConfiguration: initial,
      onGenerateInitialRoutes: (name) => <Route<dynamic>>[
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const Scaffold(body: Text('shell')),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other')),
      ),
      observers: const <NavigatorObserver>[],
      restoreRoute: (configuration, _) =>
          restored.add(configuration.visibleUri.toString()),
      history: history,
      stepBrowserBack: stepBrowserBack,
    );

Future<void> _pumpDelegate(
  WidgetTester tester,
  BrowserEntryRouterDelegate delegate,
) async {
  const parser = BrowserEntryRouteInformationParser();
  final provider = PlatformRouteInformationProvider(
    initialRouteInformation: delegate.currentConfiguration.toRouteInformation(),
  );
  addTearDown(provider.dispose);
  await tester.pumpWidget(MaterialApp.router(
    routeInformationProvider: provider,
    routeInformationParser: parser,
    routerDelegate: delegate,
  ));
  await tester.pumpAndSettle();
}

class _RecordingProvider extends StartupBrowserRouteInformationProvider {
  _RecordingProvider(
      super.initialRoute, BrowserHistoryMirror history, this.onReport)
      : super(history: history);

  final void Function(RouteInformation, RouteInformationReportingType) onReport;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    onReport(routeInformation, type);
    super.routerReportsNewRouteInformation(routeInformation, type: type);
  }
}
