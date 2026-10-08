import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/map/marker_info_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ArtMarker _marker({LatLng position = const LatLng(46.0569, 14.5058)}) {
  return ArtMarker(
    id: 'marker-1',
    name: 'Cankarjev dom',
    description: 'A cultural centre.',
    position: position,
    type: ArtMarkerType.institution,
    createdAt: DateTime(2024),
    createdBy: 'uploader-wallet',
  );
}

Future<void> _pump(WidgetTester tester, ArtMarker marker) {
  // Tall enough that the action row is on screen without scrolling.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MarkerInfoDetailScreen(marker: marker),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('a located marker offers directions next to open-on-map',
      (tester) async {
    await _pump(tester, _marker());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Get directions'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
  });

  testWidgets('no directions without a usable coordinate', (tester) async {
    await _pump(tester, _marker(position: const LatLng(0, 0)));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Get directions'), findsNothing);
    expect(find.byTooltip('Share'), findsOneWidget);
  });

  testWidgets('directions open the shared navigation sheet, not one provider',
      (tester) async {
    await _pump(tester, _marker());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.directions));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Navigate to Cankarjev dom'), findsOneWidget);
    expect(find.byKey(const ValueKey('navigation-option-googleMaps')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('navigation-option-openStreetMap')),
        findsOneWidget);
  });

  test('no map surface hard-codes a single directions provider', () {
    // The desktop panel used to launch a Google Maps URL directly, bypassing
    // the provider choice, the coordinate validity rule and the web fallbacks.
    for (final path in <String>[
      'lib/screens/desktop/desktop_map_screen.dart',
      'lib/screens/map_screen.dart',
      'lib/screens/map/marker_info_detail_screen.dart',
      'lib/features/map/shared/map_marker_overlay_actions.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('google.com/maps/dir')), reason: path);
      expect(source, isNot(contains('canLaunchUrl')), reason: path);
    }
  });
}
