import 'dart:io';
import 'dart:math' as math;

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

  test('every directions link is built in MapDestination, nowhere else', () {
    // One navigation path. Across all of lib/, only map_destination_actions.dart
    // may name a maps provider scheme, host or directions form, construct a
    // geo: URI, or launch a URL near map code. The desktop panel and the
    // walking route once launched Google Maps URLs directly, which bypassed
    // the provider choice, the coordinate rule and the web fallbacks.
    const allowed = 'lib/utils/map_destination_actions.dart';
    const providerTokens = <String>[
      'maps/dir',
      'google.navigation',
      'comgooglemaps',
      'maps.apple.com',
      'google.com/maps',
      "'geo'",
      'geo:',
    ];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    expect(files, isNotEmpty);

    // A map reference, not the Dart type Map<K, V>.
    final mapReference = RegExp(
      r'\b(?:maps?|maplibre|openstreetmap)\b(?!\s*<)|'
      r'Map(?:Destination|Navigation|Screen|Marker|Overlay)',
      caseSensitive: false,
    );
    final offenders = <String>[];
    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith(allowed)) continue;
      final source = file.readAsStringSync();
      for (final token in providerTokens) {
        if (source.contains(token)) {
          offenders.add('$path names "$token"');
        }
      }
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('launchUrl(')) continue;
        final from = math.max(0, i - 8);
        final to = math.min(lines.length, i + 9);
        final window = lines.sublist(from, to).join('\n');
        if (mapReference.hasMatch(window)) {
          offenders.add('$path:${i + 1} launches a URL near map code');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
