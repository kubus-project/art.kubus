import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/screens/node/node_pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => KubusNodeProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const NodePairingScreen(),
      ),
    );

void main() {
  group('NodePairingScreen full-screen scanner (Part 7 / Finding E)', () {
    testWidgets(
      'the scanning stage is not wrapped in an opaque Scaffold AppBar',
      (tester) async {
        await tester.pumpWidget(_app());
        // One bounded frame: the camera plugin never resolves permission
        // requests in a widget-test harness, so the screen never reaches a
        // settled state (matching its real cold-camera-permission behavior),
        // but the structural chrome around it is already built after the
        // first frame.
        await tester.pump();

        // Finding E was precisely this: a solid Material AppBar sitting
        // above the live camera. The scanning stage must not have one.
        expect(find.byType(AppBar), findsNothing);

        // The camera surface must be a genuine root layer (Stack.expand),
        // not boxed inside Scaffold -> SafeArea -> body.
        expect(
          find.byWidgetPredicate(
            (w) => w is Stack && w.fit == StackFit.expand,
          ),
          findsWidgets,
        );
      },
    );
  });
}
