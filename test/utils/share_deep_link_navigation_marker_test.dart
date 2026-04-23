import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_map_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/events/exhibition_detail_screen.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/share_deep_link_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('marker deep link selects map tab and enqueues marker intent', (tester) async {
    final tabs = MainTabProvider();
    final mapIntents = MapDeepLinkProvider();
    const target = ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tabs),
          ChangeNotifierProvider.value(value: mapIntents),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    ShareDeepLinkNavigation.open(context, target);
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(tabs.index, 0);
    expect(mapIntents.pending?.markerId, 'm1');
  });

  testWidgets('marker deep link uses desktop shell explore route',
      (tester) async {
    String? navigatedRoute;
    Widget? pushedScreen;
    const target = ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1');

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShellScope(
          pushScreen: (screen) => pushedScreen = screen,
          popScreen: () {},
          navigateToRoute: (route) => navigatedRoute = route,
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: false,
          child: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    ShareDeepLinkNavigation.open(context, target);
                  },
                  child: const Text('open desktop'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open desktop'));
    await tester.pump();

    expect(navigatedRoute, '/explore');
    expect(pushedScreen, isA<DesktopSubScreen>());
    final subScreen = pushedScreen! as DesktopSubScreen;
    expect(subScreen.child, isA<DesktopMapScreen>());
    final mapScreen = subScreen.child as DesktopMapScreen;
    expect(mapScreen.initialMarkerId, 'm1');
    expect(mapScreen.autoFollow, isFalse);
  });

  testWidgets('claim-ready exhibition deep link forwards attendance marker',
      (tester) async {
    String? navigatedRoute;
    Widget? pushedScreen;
    const target = ShareDeepLinkTarget(
      type: ShareEntityType.exhibition,
      id: 'expo-1',
      attendanceMarkerId: 'marker-1',
      claimReady: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShellScope(
          pushScreen: (screen) => pushedScreen = screen,
          popScreen: () {},
          navigateToRoute: (route) => navigatedRoute = route,
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: false,
          child: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    ShareDeepLinkNavigation.open(context, target);
                  },
                  child: const Text('open claim ready'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open claim ready'));
    await tester.pump();

    expect(navigatedRoute, '/home');
    expect(pushedScreen, isA<DesktopSubScreen>());
    final subScreen = pushedScreen! as DesktopSubScreen;
    expect(subScreen.child, isA<ExhibitionDetailScreen>());
    final detailScreen = subScreen.child as ExhibitionDetailScreen;
    expect(detailScreen.exhibitionId, 'expo-1');
    expect(detailScreen.attendanceMarkerId, 'marker-1');
  });
}
