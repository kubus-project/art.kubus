import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/map_destination_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

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
      expect(web.queryParameters['destination'], '46.0569,14.5058');
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
      expect(
          Uri.decodeFull(opened.first.toString()), contains('46.0569,14.5058'));
    });
  });
}
