import 'package:art_kubus/core/url_coherence_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  _Harness() {
    observer = UrlCoherenceObserver(enabled: true, report: reports.add);
  }

  final List<String> reports = <String>[];
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final UrlCoherenceObserver observer;

  Widget build({String initialRoute = '/en/artworks/a1'}) {
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
}
