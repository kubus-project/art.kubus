import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'package:art_kubus/utils/artwork_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRoute = route;
    super.didPush(route, previousRoute);
  }
}

Future<void> _pumpUntilRoute(
  WidgetTester tester,
  _TestNavigatorObserver observer,
) async {
  for (var i = 0; i < 6 && observer.lastRoute == null; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('openArtwork passes attendanceMarkerId to mobile detail screen', (tester) async {
    final observer = _TestNavigatorObserver();
    final key = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(500, 800)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: Builder(builder: (context) => SizedBox(key: key)),
        ),
      ),
    );

    final context = tester.element(find.byKey(key));
    unawaited(openArtwork(context, 'art_1', attendanceMarkerId: 'marker_1'));

    await _pumpUntilRoute(tester, observer);
    final route = observer.lastRoute as MaterialPageRoute;
    final widget = route.builder(context);
    expect(widget, isA<ArtDetailScreen>());
    expect((widget as ArtDetailScreen).attendanceMarkerId, 'marker_1');
  });

  testWidgets('openArtwork passes attendanceMarkerId to desktop detail screen', (tester) async {
    final observer = _TestNavigatorObserver();
    final key = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1200, 800)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: Builder(builder: (context) => SizedBox(key: key)),
        ),
      ),
    );

    final context = tester.element(find.byKey(key));
    unawaited(openArtwork(context, 'art_2', attendanceMarkerId: 'marker_2'));

    await _pumpUntilRoute(tester, observer);
    final route = observer.lastRoute as MaterialPageRoute;
    final widget = route.builder(context);
    expect(widget, isA<DesktopArtworkDetailScreen>());
    expect((widget as DesktopArtworkDetailScreen).attendanceMarkerId, 'marker_2');
  });
}

