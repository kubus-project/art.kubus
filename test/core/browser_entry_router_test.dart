import 'package:art_kubus/core/browser_entry_router.dart';
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
