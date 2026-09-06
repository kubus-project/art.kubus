import 'package:art_kubus/features/spatial/spatial_marker_directory.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/availability_operator_provider.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/spatial/spatial_library_screen.dart';
import 'package:art_kubus/screens/node/my_nodes_screen.dart';
import 'package:art_kubus/screens/node/node_pairing_screen.dart';
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

class _DiscoveryNodeProvider extends KubusNodeProvider {
  int discoveryRequests = 0;

  @override
  Future<void> loadOwnedNodes() async {
    discoveryRequests++;
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
      'an unpaired Node shows "Connect Node" and opens account discovery',
      (tester) async {
        final observer = _RecordingObserver();
        final node = _DiscoveryNodeProvider();
        await tester.pumpWidget(_app(observer: observer, node: node));
        await tester.pumpAndSettle();

        expect(find.text('Connect Node'), findsOneWidget);
        expect(find.text('Node connected'), findsNothing);

        await tester.tap(find.text('Connect Node'));
        await tester.pumpAndSettle();
        expect(node.discoveryRequests, 1);
        expect(find.byType(MyNodesScreen), findsOneWidget);
        expect(find.byType(NodePairingScreen), findsNothing);
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
