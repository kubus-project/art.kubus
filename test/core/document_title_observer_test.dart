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
}
