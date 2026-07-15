import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/screens/desktop/desktop_map_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/artwork_location_actions.dart';
import 'package:art_kubus/utils/map_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

Artwork _artwork({
  LatLng position = const LatLng(46.056946, 14.505751),
  String? markerId = 'marker-hint',
}) {
  return Artwork(
    id: 'artwork-1',
    title: 'Črna mačka / 100%',
    artist: 'Artist',
    description: 'Description',
    position: position,
    rewards: 0,
    createdAt: DateTime.utc(2026),
    arMarkerId: markerId,
  );
}

void main() {
  group('ArtworkLocationActions', () {
    test('accepts bounded coordinates and rejects invalid locations', () {
      expect(ArtworkLocationActions.hasValidLocation(_artwork()), isTrue);
      expect(
        ArtworkLocationActions.hasValidLocation(
          _artwork(position: const LatLng(0, 0)),
        ),
        isFalse,
      );
      expect(
        ArtworkLocationActions.hasValidLocation(
          _artwork(position: const LatLng(91, 14)),
        ),
        isFalse,
      );
    });

    testWidgets(
      'showOnMap forwards exact artwork target and marker hint',
      (tester) async {
        late LatLng openedCenter;
        double? openedZoom;
        bool? openedAutoFollow;
        String? openedMarkerId;
        String? openedArtworkId;
        String? openedLabel;
        bool? preservedDesktopBackStack;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  ArtworkLocationActions.showOnMap(
                    context,
                    _artwork(),
                    mapOpener: (
                      context, {
                      required center,
                      zoom,
                      autoFollow = false,
                      initialMarkerId,
                      initialArtworkId,
                      initialSubjectId,
                      initialSubjectType,
                      initialTargetLabel,
                      preserveDesktopBackStack = false,
                    }) {
                      openedCenter = center;
                      openedZoom = zoom;
                      openedAutoFollow = autoFollow;
                      openedMarkerId = initialMarkerId;
                      openedArtworkId = initialArtworkId;
                      openedLabel = initialTargetLabel;
                      preservedDesktopBackStack = preserveDesktopBackStack;
                    },
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));

        expect(openedCenter, const LatLng(46.056946, 14.505751));
        expect(openedZoom, 16);
        expect(openedAutoFollow, isFalse);
        expect(openedArtworkId, 'artwork-1');
        expect(openedMarkerId, 'marker-hint');
        expect(openedLabel, 'Črna mačka / 100%');
        expect(preservedDesktopBackStack, isTrue);
      },
    );

    test('external navigation URIs encode labels and coordinates safely', () {
      final artwork = _artwork();
      final appleUris = ArtworkLocationActions.destinationUris(
        artwork,
        ArtworkExternalMapDestination.appleMaps,
        platform: TargetPlatform.iOS,
      );
      final androidUris = ArtworkLocationActions.destinationUris(
        artwork,
        ArtworkExternalMapDestination.platformDefault,
        platform: TargetPlatform.android,
      );

      expect(appleUris.first.queryParameters['q'], artwork.title);
      expect(appleUris.first.queryParameters['ll'], '46.056946,14.505751');
      expect(appleUris.first.toString(), isNot(contains('Črna mačka')));
      expect(
        androidUris.single.queryParameters['q'],
        '46.056946,14.505751 (${artwork.title})',
      );
    });

    test('platform policies expose only appropriate native map choices', () {
      expect(
        ArtworkLocationActions.shouldShowAppleMaps(TargetPlatform.iOS),
        isTrue,
      );
      expect(
        ArtworkLocationActions.shouldShowAppleMaps(TargetPlatform.macOS),
        isTrue,
      );
      expect(
        ArtworkLocationActions.shouldShowAppleMaps(TargetPlatform.android),
        isFalse,
      );
      expect(
        ArtworkLocationActions.shouldShowPlatformDefaultMaps(
          TargetPlatform.android,
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        ArtworkLocationActions.shouldShowPlatformDefaultMaps(
          TargetPlatform.android,
          isWeb: true,
        ),
        isFalse,
      );
    });

    test('launcher falls back from native app URI to HTTPS', () async {
      final launched = <Uri>[];
      final modes = <LaunchMode>[];

      final didLaunch = await ArtworkLocationActions.launchDestination(
        _artwork(),
        ArtworkExternalMapDestination.googleMaps,
        platform: TargetPlatform.android,
        canLaunch: (_) async => true,
        launcher: (uri, mode) async {
          launched.add(uri);
          modes.add(mode);
          return uri.scheme == 'https';
        },
      );

      expect(didLaunch, isTrue);
      expect(launched.map((uri) => uri.scheme), ['google.navigation', 'https']);
      expect(
          modes, [LaunchMode.platformDefault, LaunchMode.externalApplication]);
    });

    testWidgets('copy failure is localized and leaves the page usable',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sl'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ArtworkLocationActions.showNavigationOptions(
                  context,
                  _artwork(),
                  platform: TargetPlatform.android,
                  isWeb: false,
                  clipboardWriter: (_) async => throw StateError('blocked'),
                ),
                child: const Text('Navigate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(bottomSheet.backgroundColor, isNot(Colors.transparent));
      expect(find.text('Google Zemljevidi'), findsOneWidget);
      expect(find.text('Drugi zemljevidi'), findsOneWidget);
      expect(find.text('Apple Zemljevidi'), findsNothing);

      await tester.tap(find.text('Kopiraj koordinate'));
      await tester.pumpAndSettle();

      expect(find.text('Koordinat ni bilo mogoče kopirati'), findsOneWidget);
    });
  });

  testWidgets(
    'MapNavigation preserves the desktop detail stack for location actions',
    (tester) async {
      var navigateCalls = 0;
      Widget? pushedScreen;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: DesktopShellScope(
              pushScreen: (screen) => pushedScreen = screen,
              popScreen: () {},
              navigateToRoute: (_) => navigateCalls += 1,
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: true,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => MapNavigation.open(
                    context,
                    center: const LatLng(46, 14),
                    initialArtworkId: 'artwork-1',
                    preserveDesktopBackStack: true,
                  ),
                  child: const Text('Open map'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open map'));
      await tester.pump();

      expect(navigateCalls, 0);
      expect(pushedScreen, isA<DesktopSubScreen>());
      final mapScreen = (pushedScreen! as DesktopSubScreen).child;
      expect(mapScreen, isA<DesktopMapScreen>());
      expect((mapScreen as DesktopMapScreen).initialArtworkId, 'artwork-1');
    },
  );
}
