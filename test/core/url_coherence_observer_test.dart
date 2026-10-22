import 'package:art_kubus/core/url_coherence_observer.dart';
import 'package:art_kubus/core/public_entry_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/services/share/share_types.dart';

class _Harness {
  _Harness({PublicEntryNavigation? entityUrls}) {
    observer = UrlCoherenceObserver(
      enabled: true,
      report: (url) {
        reports.add(url);
        browserUrl = url;
      },
      currentBrowserUrl: () => browserUrl,
      entityUrls: entityUrls,
    );
    // Observers listen to the shared singleton; a stale one from an earlier
    // test must not consume state meant for the current test's observer.
    addTearDown(observer.dispose);
  }

  final List<String> reports = <String>[];
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String? browserUrl;
  late final UrlCoherenceObserver observer;

  Widget build({String initialRoute = '/en/artworks/a1'}) {
    browserUrl ??= initialRoute;
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('page ${settings.name}')),
        );
      },
    );
  }

  NavigatorState get navigator => navigatorKey.currentState!;
}

void main() {
  tearDown(() => PublicEntryNavigation.instance.resetForTest());

  testWidgets('the first named page is the address bar, not a change',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pump();

    expect(harness.reports, isEmpty);
    expect(harness.observer.shownUrl, '/en/artworks/a1');
  });

  testWidgets(
      'Back from /onboarding to an unnamed entity restores the entity URL',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());

    // The entity the visitor was viewing is pushed without a route name.
    harness.navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('entity detail')),
    );
    await tester.pumpAndSettle();
    expect(harness.reports, isEmpty, reason: 'an unnamed push keeps the URL');

    harness.navigator.pushNamed('/onboarding');
    await tester.pumpAndSettle();
    expect(harness.reports, <String>['/onboarding']);

    harness.navigator.pop();
    await tester.pumpAndSettle();
    expect(harness.reports, <String>['/onboarding', '/en/artworks/a1']);
    expect(harness.observer.shownUrl, '/en/artworks/a1');
  });

  testWidgets('a second visit to the same route is reported again',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    harness.navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('entity detail')),
    );
    await tester.pumpAndSettle();

    for (var visit = 0; visit < 2; visit++) {
      harness.navigator.pushNamed('/onboarding');
      await tester.pumpAndSettle();
      harness.navigator.pop();
      await tester.pumpAndSettle();
    }

    expect(harness.reports, <String>[
      '/onboarding',
      '/en/artworks/a1',
      '/onboarding',
      '/en/artworks/a1',
    ]);
  });

  testWidgets('Back out of a sign-in opened above a named page restores it',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(initialRoute: '/main'));

    harness.navigator.pushNamed('/sign-in');
    await tester.pumpAndSettle();
    harness.navigator.pop();
    await tester.pumpAndSettle();

    expect(harness.reports, <String>['/sign-in', '/main']);
  });

  testWidgets('dialogs and sheets never change the URL', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pump();

    showDialog<void>(
      context: harness.navigator.context,
      builder: (_) => const AlertDialog(title: Text('gate')),
    );
    await tester.pumpAndSettle();
    harness.navigator.pop();
    await tester.pumpAndSettle();

    expect(harness.reports, isEmpty);
  });

  testWidgets('a replaced page is reported as its replacement', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(initialRoute: '/main'));

    harness.navigator.pushReplacementNamed('/en/events/e1');
    await tester.pumpAndSettle();

    expect(harness.reports, <String>['/en/events/e1']);
  });

  testWidgets(
      'a pending public entry repairs a later Navigator shell URL overwrite',
      (tester) async {
    final entryNavigation = PublicEntryNavigation.instance;
    entryNavigation.setEntry(
      type: ShareEntityType.artwork,
      entityId: 'a1',
      browserRoute: '/en/artworks/a1?source=share#cover',
      shellRoute: '/main',
    );
    final harness = _Harness(entityUrls: entryNavigation)
      ..browserUrl = '/en/artworks/a1?source=share#cover';
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    // Navigator's startup replacement can land after the observer's first
    // frame callback. Simulate that external write, then a readiness/claim
    // notification; the observer must compare with the browser, not only its
    // stale last-reported URL.
    harness.browserUrl = '/main';
    entryNavigation.visibilityChanged();
    await tester.pumpAndSettle();

    expect(harness.reports, <String>[
      '/en/artworks/a1?source=share#cover',
    ]);
    expect(harness.browserUrl, '/en/artworks/a1?source=share#cover');
    expect(harness.observer.desiredUrl, '/en/artworks/a1?source=share#cover');
  });

  testWidgets('does nothing when disabled (non-web platforms)', (tester) async {
    final reports = <String>[];
    final observer = UrlCoherenceObserver(enabled: false, report: reports.add);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        initialRoute: '/main',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(),
        ),
      ),
    );
    await tester.pump();

    expect(reports, isEmpty);
  });

  testWidgets('a pop reports through reportBack, a push through report',
      (tester) async {
    final forward = <String>[];
    final back = <String>[];
    String? browserUrl = '/main';
    final observer = UrlCoherenceObserver(
      enabled: true,
      report: (url) {
        forward.add(url);
        browserUrl = url;
      },
      reportBack: (url) {
        back.add(url);
        browserUrl = url;
      },
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

    navigatorKey.currentState!.pushNamed('/map');
    await tester.pumpAndSettle();
    expect(forward, <String>['/map']);
    expect(back, isEmpty);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(forward, <String>['/map']);
    expect(back, <String>['/main'],
        reason: 'returning to the page below must not push another entry');
    observer.dispose();
  });

  testWidgets('dropping an unresolvable entry reports a replacing correction',
      (tester) async {
    const entryUrl = '/en/map/bad-marker';
    PublicEntryNavigation.instance.setEntry(
      type: ShareEntityType.marker,
      entityId: 'bad-marker',
      browserRoute: entryUrl,
      shellRoute: '/map',
    );
    final forward = <String>[];
    final replaced = <String>[];
    String? browserUrl = entryUrl;
    final observer = UrlCoherenceObserver(
      enabled: true,
      report: (url) {
        forward.add(url);
        browserUrl = url;
      },
      reportReplace: (url) {
        replaced.add(url);
        browserUrl = url;
      },
      currentBrowserUrl: () => browserUrl,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      initialRoute: '/map',
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Text('page ${settings.name}'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(forward, isEmpty);
    expect(replaced, isEmpty, reason: 'the pending entry holds its address');

    PublicEntryNavigation.instance
        .entryUnresolved(ShareEntityType.marker, 'bad-marker');
    await tester.pumpAndSettle();

    expect(replaced, <String>['/map']);
    expect(forward, isEmpty);
    observer.dispose();
  });

  testWidgets('a page that replaces another replaces its history entry',
      (tester) async {
    final forward = <String>[];
    final replaced = <String>[];
    String? browserUrl = '/';
    final observer = UrlCoherenceObserver(
      enabled: true,
      report: (url) {
        forward.add(url);
        browserUrl = url;
      },
      reportReplace: (url) {
        replaced.add(url);
        browserUrl = url;
      },
      currentBrowserUrl: () => browserUrl,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      initialRoute: '/',
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Text('page ${settings.name}'),
      ),
    ));
    await tester.pumpAndSettle();

    // AppInitializer opens the shell with pushReplacement: `/` becomes `/map`.
    navigatorKey.currentState!.pushReplacementNamed('/map');
    await tester.pumpAndSettle();
    expect(replaced, <String>['/map']);
    expect(forward, isEmpty);

    navigatorKey.currentState!.pushNamed('/sign-in');
    await tester.pumpAndSettle();
    expect(forward, <String>['/sign-in'],
        reason: 'an ordinary push still adds an entry');
    observer.dispose();
  });
}
