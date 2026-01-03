import 'dart:async';

import 'package:art_kubus/models/community_subject.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'package:art_kubus/screens/community/user_profile_screen.dart' as mobile_profile;
import 'package:art_kubus/screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/utils/community_subject_navigation.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  Widget buildTestApp({
    required Size size,
    required NavigatorObserver observer,
    required GlobalKey key,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ArtworkProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SavedItemsProvider()),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: Builder(builder: (context) => SizedBox(key: key)),
        ),
      ),
    );
  }

  testWidgets('openSubject uses mobile routes on narrow layouts',
      (tester) async {
    final observer = _TestNavigatorObserver();
    final key = GlobalKey();

    await tester.pumpWidget(
      buildTestApp(
        size: const Size(500, 800),
        observer: observer,
        key: key,
      ),
    );

    final context = tester.element(find.byKey(key));
    unawaited(
      CommunitySubjectNavigation.open(
        context,
        subject: const CommunitySubjectRef(type: 'artwork', id: 'a1'),
      ),
    );

    await _pumpUntilRoute(tester, observer);
    final route = observer.lastRoute as MaterialPageRoute;
    final widget = route.builder(context);
    expect(widget, isA<ArtDetailScreen>());
  });

  testWidgets('openSubject uses desktop routes on wide layouts',
      (tester) async {
    final observer = _TestNavigatorObserver();
    final key = GlobalKey();

    await tester.pumpWidget(
      buildTestApp(
        size: const Size(1200, 800),
        observer: observer,
        key: key,
      ),
    );

    final context = tester.element(find.byKey(key));
    unawaited(
      CommunitySubjectNavigation.open(
        context,
        subject: const CommunitySubjectRef(type: 'institution', id: 'wallet_1'),
      ),
    );

    await _pumpUntilRoute(tester, observer);
    final route = observer.lastRoute as MaterialPageRoute;
    final widget = route.builder(context);
    expect(widget, isA<desktop_profile.UserProfileScreen>());
    expect(widget, isNot(isA<mobile_profile.UserProfileScreen>()));
  });

  testWidgets('openSubject falls back to desktop detail screen without shell',
      (tester) async {
    final observer = _TestNavigatorObserver();
    final key = GlobalKey();

    await tester.pumpWidget(
      buildTestApp(
        size: const Size(1200, 800),
        observer: observer,
        key: key,
      ),
    );

    final context = tester.element(find.byKey(key));
    unawaited(
      CommunitySubjectNavigation.open(
        context,
        subject: const CommunitySubjectRef(type: 'artwork', id: 'a2'),
      ),
    );

    await _pumpUntilRoute(tester, observer);
    final route = observer.lastRoute as MaterialPageRoute;
    final widget = route.builder(context);
    expect(widget, isA<DesktopArtworkDetailScreen>());
  });
}
