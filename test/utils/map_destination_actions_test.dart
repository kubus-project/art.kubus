import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/utils/artwork_location_actions.dart';
import 'package:art_kubus/utils/map_coordinate_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const _ljubljana = LatLng(46.0569, 14.5058);

MapDestination _destination({
  LatLng position = _ljubljana,
  String title = 'Vodnik Square',
}) =>
    MapDestination(id: 'subject-1', title: title, position: position);

Widget _host(MapDestination destination, {List<Uri>? opened}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => destination.showNavigationOptions(
            context,
            platform: TargetPlatform.android,
            isWeb: false,
            canLaunch: (_) async => true,
            launcher: (uri, _) async {
              opened?.add(uri);
              return true;
            },
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('directions eligibility', () {
    test('a real coordinate is a destination', () {
      expect(_destination().isValid, isTrue);
      expect(MapDestination.isValidCoordinate(const LatLng(-33.86, 151.2)),
          isTrue);
    });

    test('the (0, 0) default of an unlocated record is not', () {
      expect(MapDestination.isValidCoordinate(const LatLng(0, 0)), isFalse);
      expect(MapDestination.isValidCoordinate(const LatLng(0.00005, -0.00005)),
          isFalse);
    });

    test('a coordinate on the equator or meridian alone is still valid', () {
      expect(MapDestination.isValidCoordinate(const LatLng(0, 14.5)), isTrue);
      expect(MapDestination.isValidCoordinate(const LatLng(46.0, 0)), isTrue);
    });

    test('non-finite coordinates are rejected', () {
      expect(
          MapDestination.isValidCoordinate(LatLng(double.nan, 14.5)), isFalse);
      expect(MapDestination.isValidCoordinate(LatLng(46.0, double.infinity)),
          isFalse);
    });

    test('out-of-range latitude or longitude is rejected', () {
      expect(
          MapDestination.isValidCoordinate(const LatLng(90.5, 14.5)), isFalse);
      expect(
          MapDestination.isValidCoordinate(const LatLng(-91, 14.5)), isFalse);
      expect(
          MapDestination.isValidCoordinate(const LatLng(46.0, 180.5)), isFalse);
      expect(
          MapDestination.isValidCoordinate(const LatLng(46.0, -181)), isFalse);
      expect(MapDestination.isValidCoordinate(const LatLng(90, 180)), isTrue);
    });
  });

  group('external launching', () {
    test('an invalid destination never launches anything', () async {
      var launched = false;
      final didOpen = await _destination(position: const LatLng(0, 0)).launch(
        ArtworkExternalMapDestination.googleMaps,
        canLaunch: (_) async => true,
        launcher: (_, __) async {
          launched = true;
          return true;
        },
      );
      expect(didOpen, isFalse);
      expect(launched, isFalse);
    });

    test('Android tries the native navigation intent before the web URL', () {
      final uris = _destination().externalUris(
        ArtworkExternalMapDestination.googleMaps,
        platform: TargetPlatform.android,
      );
      expect(uris.first.scheme, 'google.navigation');
      expect(uris.last.host, 'www.google.com');
      expect(uris.every((u) => u.toString().contains('46.0569')), isTrue);
    });

    test('the Google Maps web fallback opens directions, not a search pin', () {
      final uris = _destination().externalUris(
        ArtworkExternalMapDestination.googleMaps,
        platform: TargetPlatform.windows,
      );
      final web = uris.singleWhere((u) => u.scheme == 'https');
      expect(web.scheme, 'https');
      expect(web.host, 'www.google.com');
      expect(web.path, '/maps/dir/');
      expect(web.queryParameters['api'], '1');
      expect(web.queryParameters['destination'], '46.056900,14.505800');
      expect(web.path, isNot(contains('search')));
      expect(web.queryParameters.containsKey('query'), isFalse);
    });

    test('web-safe https fallbacks exist for every provider', () {
      for (final provider in [
        ArtworkExternalMapDestination.googleMaps,
        ArtworkExternalMapDestination.appleMaps,
        ArtworkExternalMapDestination.openStreetMap,
      ]) {
        final uris = _destination().externalUris(
          provider,
          platform: TargetPlatform.windows,
        );
        expect(uris.any((u) => u.scheme == 'https'), isTrue,
            reason: '$provider');
      }
    });

    test('the Android-only geo: provider is absent elsewhere', () {
      expect(
        _destination().externalUris(
          ArtworkExternalMapDestination.platformDefault,
          platform: TargetPlatform.iOS,
        ),
        isEmpty,
      );
    });

    test('falls through to the next candidate when the first cannot open',
        () async {
      final tried = <Uri>[];
      final didOpen = await _destination().launch(
        ArtworkExternalMapDestination.googleMaps,
        platform: TargetPlatform.android,
        canLaunch: (uri) async => uri.scheme == 'https',
        launcher: (uri, _) async {
          tried.add(uri);
          return true;
        },
      );
      expect(didOpen, isTrue);
      expect(tried.single.scheme, 'https');
    });
  });

  group('navigation sheet', () {
    testWidgets('does nothing for a destination without a coordinate',
        (tester) async {
      await tester.pumpWidget(
        _host(_destination(position: const LatLng(0, 0))),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('navigation-option-copy')), findsNothing);
    });

    testWidgets('names the place and offers providers and coordinates',
        (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(_host(_destination(), opened: opened));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Navigate to Vodnik Square'), findsOneWidget);
      expect(find.byKey(const ValueKey('navigation-option-googleMaps')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('navigation-option-copy')), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('navigation-option-googleMaps')));
      await tester.pumpAndSettle();
      expect(opened, isNotEmpty);
      expect(Uri.decodeFull(opened.first.toString()),
          contains('46.056900,14.505800'));
    });
  });

  group('one coordinate rule', () {
    Artwork artworkAt(LatLng position) => Artwork(
          id: 'artwork-rule',
          title: 'Rule',
          artist: 'Artist',
          description: 'Description',
          position: position,
          rewards: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          category: 'Mural',
        );

    test('artwork, location actions and destination agree on every case', () {
      final cases = <LatLng>[
        const LatLng(46.0569, 14.5058),
        const LatLng(0, 0),
        const LatLng(0.00005, -0.00005),
        const LatLng(0, 14.5),
        const LatLng(90, 180),
        const LatLng(90.5, 14.5),
        const LatLng(46, 180.5),
        LatLng(double.nan, 14.5),
        LatLng(46, double.infinity),
      ];
      for (final position in cases) {
        final expected = isValidMapCoordinate(position);
        expect(MapDestination.isValidCoordinate(position), expected,
            reason: '$position');
        expect(artworkAt(position).hasValidLocation, expected,
            reason: '$position');
        expect(
          ArtworkLocationActions.hasValidLocation(artworkAt(position)),
          expected,
          reason: '$position',
        );
      }
    });
  });

  group('serialization and walking handoff', () {
    test('coordinates serialize at fixed precision, never as exponents', () {
      final destination = MapDestination(
        id: 'tiny',
        title: 'Tiny',
        position: const LatLng(0.0000001, 14.5),
      );
      final osm = destination.externalUris(
        ArtworkExternalMapDestination.openStreetMap,
        platform: TargetPlatform.windows,
      );
      expect(osm.single.queryParameters['mlat'], '0.000000');
      expect(osm.single.queryParameters['mlon'], '14.500000');
      final google = destination.externalUris(
        ArtworkExternalMapDestination.googleMaps,
        platform: TargetPlatform.windows,
      );
      expect(google.last.queryParameters['destination'], '0.000000,14.500000');
      for (final uri in [...osm, ...google]) {
        expect(uri.toString(), isNot(contains('e-')), reason: '$uri');
      }
    });

    test('walking directions open externally in walking mode', () async {
      Uri? opened;
      LaunchMode? mode;
      final didOpen = await MapDestination.fromWalkingIntent(
        const WalkingNavigationIntent(
          destinationId: 'artwork-1',
          destinationLabel: 'Artwork',
          destination: LatLng(46.056946, 14.505751),
        ),
      ).openWalkingExternally(
        launcher: (uri, launchMode) async {
          opened = uri;
          mode = launchMode;
          return true;
        },
      );

      expect(didOpen, isTrue);
      expect(opened!.host, 'www.google.com');
      expect(opened!.path, '/maps/dir/');
      expect(opened!.queryParameters['api'], '1');
      expect(opened!.queryParameters['destination'], '46.056946,14.505751');
      expect(opened!.queryParameters['travelmode'], 'walking');
      expect(opened!.queryParameters.containsKey('query'), isFalse);
      expect(mode, LaunchMode.externalApplication);
    });

    test('an unlocated walking destination launches nothing', () async {
      var launched = false;
      final didOpen = await MapDestination.fromWalkingIntent(
        const WalkingNavigationIntent(
          destinationId: 'artwork-2',
          destinationLabel: 'Unlocated',
          destination: LatLng(0, 0),
        ),
      ).openWalkingExternally(
        launcher: (_, __) async {
          launched = true;
          return true;
        },
      );
      expect(didOpen, isFalse);
      expect(launched, isFalse);
    });

    test('the walking handoff keeps the route destination identity', () {
      final destination = MapDestination.fromWalkingIntent(
        const WalkingNavigationIntent(
          destinationId: 'artwork-3',
          destinationLabel: 'Route end',
          destination: LatLng(46.0569, 14.5058),
        ),
      );
      expect(destination.id, 'artwork-3');
      expect(destination.title, 'Route end');
      expect(destination.position, const LatLng(46.0569, 14.5058));
    });
  });

  group('keyboard focus around the sheet', () {
    testWidgets('closing the sheet returns focus to the control that opened it',
        (tester) async {
      final invoker = FocusNode(debugLabel: 'directions-invoker');
      addTearDown(invoker.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                focusNode: invoker,
                onPressed: () => _destination().showNavigationOptions(
                  context,
                  platform: TargetPlatform.android,
                  isWeb: false,
                  canLaunch: (_) async => true,
                  launcher: (uri, _) async => true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      invoker.requestFocus();
      await tester.pump();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Navigate to Vodnik Square'), findsOneWidget);

      Navigator.of(tester.element(find.text('Navigate to Vodnik Square')))
          .pop();
      await tester.pumpAndSettle();

      expect(find.text('Navigate to Vodnik Square'), findsNothing);
      expect(invoker.hasPrimaryFocus, isTrue);
    });
  });
}
