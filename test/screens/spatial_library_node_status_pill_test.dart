import 'package:art_kubus/features/spatial/spatial_marker_directory.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/availability_operator_provider.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/spatial/spatial_library_screen.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The stub never reaches the wire, so the service stays inert while
/// reporting a paired state — mirrors `_StubNodeService` in
/// `spatial_network_request_test.dart`.
class _PairedNodeService extends KubusNodeService {
  _PairedNodeService() : super(isWeb: false);

  @override
  bool get isPaired => true;
}

class _RecordingObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
  }
}

Widget _app({
  KubusNodeProvider? node,
  required NavigatorObserver observer,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SpatialLibraryProvider()),
        ChangeNotifierProvider(create: (_) => node ?? KubusNodeProvider()),
        ChangeNotifierProvider(create: (_) => AvailabilityOperatorProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorObservers: [observer],
        home: SpatialLibraryScreen(markerDirectory: SpatialMarkerDirectory()),
      ),
    );

void main() {
  group('Spatial Library Node status pill (Part 3.1)', () {
    testWidgets(
      'an unpaired Node shows "Connect Node" and reaches pairing directly '
      'from the library, not via Settings',
      (tester) async {
        final observer = _RecordingObserver();
        await tester.pumpWidget(_app(observer: observer));
        await tester.pumpAndSettle();

        expect(find.text('Connect Node'), findsOneWidget);
        expect(find.text('Node connected'), findsNothing);

        await tester.tap(find.text('Connect Node'));
        // A bounded pump, not pumpAndSettle: the pairing screen starts a real
        // camera/permission request whose plugin channels never resolve in a
        // widget-test harness, so its own animations never fully settle.
        // The push itself (what this test verifies) completes in one frame.
        await tester.pump();

        expect(observer.pushedRouteNames, contains('/node-pairing'));
      },
    );

    testWidgets(
      'a paired Node shows "Node connected" and opens the Node status '
      'screen, not the pairing flow again',
      (tester) async {
        final observer = _RecordingObserver();
        await tester.pumpWidget(
          _app(
            node: KubusNodeProvider(service: _PairedNodeService()),
            observer: observer,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Node connected'), findsOneWidget);
        expect(find.text('Connect Node'), findsNothing);

        await tester.tap(find.text('Node connected'));
        await tester.pump();

        expect(observer.pushedRouteNames, contains('/node'));
        expect(observer.pushedRouteNames, isNot(contains('/node-pairing')));
      },
    );
  });
}
