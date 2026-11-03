import 'package:art_kubus/core/document_title_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const entityPath = '/en/artworks/first';

  Future<DocumentTitleObserver> boot(
    WidgetTester tester,
    GlobalKey<NavigatorState> navigator,
  ) async {
    final observer = DocumentTitleObserver(
      retainedTitle: 'First artwork | art.kubus',
      retainedPath: entityPath,
      fallbackTitle: () => 'art.kubus',
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [observer],
      initialRoute: entityPath,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text(settings.name ?? 'unnamed')),
      ),
    ));
    await tester.pump();
    return observer;
  }

  testWidgets('retained title survives takeover, then follows the route',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = await boot(tester, navigator);
    expect(observer.title.value, 'First artwork | art.kubus');

    navigator.currentState!.pushNamed('/map');
    await tester.pumpAndSettle();
    expect(observer.title.value, 'art.kubus');

    navigator.currentState!.pushNamed('/settings');
    await tester.pumpAndSettle();
    expect(observer.title.value, 'art.kubus');

    navigator.currentState!.pop();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.title.value, 'First artwork | art.kubus');
  });

  testWidgets('another entity gets its own title and back restores the first',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = await boot(tester, navigator);

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => DocumentTitle(
        observer: observer,
        title: 'Second artwork | art.kubus',
        child: const Scaffold(body: Text('second')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(observer.title.value, 'Second artwork | art.kubus');

    navigator.currentState!.pushNamed('/map');
    await tester.pumpAndSettle();
    expect(observer.title.value, 'art.kubus');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.title.value, 'Second artwork | art.kubus');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.title.value, 'First artwork | art.kubus');
  });

  testWidgets(
      'the retained title does not move to a later route that reuses '
      'the same URL', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = await boot(tester, navigator);
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('unnamed profile')),
    ));
    await tester.pumpAndSettle();
    expect(observer.title.value, 'art.kubus');
  });

  testWidgets('retained title follows its page through a replacement',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = await boot(tester, navigator);
    navigator.currentState!.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('shell')),
    ));
    await tester.pumpAndSettle();
    expect(observer.title.value, 'First artwork | art.kubus');
  });

  test('the application title is localized, never the generic brand name', () {
    expect(localizedDocumentTitle(const Locale('en')),
        'art.kubus — Open Art Map and Community Platform');
    expect(localizedDocumentTitle(const Locale('sl')),
        'art.kubus — Odprti zemljevid umetnosti in skupnostna platforma');
    expect(localizedDocumentTitle(const Locale('de')),
        localizedDocumentTitle(const Locale('en')));
  });

  testWidgets(
      'leaving an entity clears its title (null = localized application title) and back restores it',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = DocumentTitleObserver(
      retainedTitle: 'First artwork | art.kubus',
      retainedPath: entityPath,
      fallbackTitle: () => null,
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [observer],
      initialRoute: entityPath,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text(settings.name ?? 'unnamed')),
      ),
    ));
    await tester.pump();
    expect(observer.title.value, 'First artwork | art.kubus');
    navigator.currentState!.pushNamed('/map');
    await tester.pumpAndSettle();
    expect(observer.title.value, isNull);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.title.value, 'First artwork | art.kubus');
  });

  test('an artwork title matches the server-rendered one', () {
    expect(artworkDocumentTitle('River Memory', 'Maja Novak'),
        'River Memory by Maja Novak | art.kubus');
    expect(artworkDocumentTitle(' River Memory ', ''),
        'River Memory | art.kubus');
    expect(artworkDocumentTitle('River Memory', 'Unknown artist'),
        'River Memory | art.kubus');
  });

  testWidgets(
      'replacing the entity page with another named URL ends the retained title',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = await boot(tester, navigator);
    expect(observer.title.value, 'First artwork | art.kubus');
    navigator.currentState!.pushReplacementNamed('/main');
    await tester.pumpAndSettle();
    expect(observer.title.value, 'art.kubus'); // the test observer's fallback; the app's fallback is null
  });
}
