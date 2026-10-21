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
}
