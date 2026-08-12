import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/widgets/spatial/artwork_spatial_archive_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

void main() {
  for (final size in const [Size(390, 844), Size(1280, 900)]) {
    testWidgets(
      'spatial archive CTA and history count render at ${size.width}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = ArtworkProvider();
        provider.seedSpatialHistoryForTesting('art-1', _history());
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ArtworkSpatialArchiveSection(artwork: _artwork()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Spatial archive'), findsOneWidget);
        expect(find.text('2 spatial captures'), findsOneWidget);
        expect(find.text('View in 3D'), findsOneWidget);
        expect(find.textContaining('Aug'), findsOneWidget);
      },
    );
  }
}

Artwork _artwork() => Artwork(
      id: 'art-1',
      title: 'Layered wall',
      artist: 'Artist',
      description: 'Description',
      position: const LatLng(46.0569, 14.5058),
      rewards: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      category: 'Mural',
      spatialCaptureCount: 2,
    );

ArtworkSpatialHistory _history() => ArtworkSpatialHistory(
      history: [
        ArtworkSpatialCapture(
          id: 'capture-current',
          artworkId: 'art-1',
          capturedAt: DateTime.utc(2026, 8, 11),
          publishedAt: DateTime.utc(2026, 8, 11),
          version: 1,
          variants: const [],
          isCurrent: true,
        ),
        ArtworkSpatialCapture(
          id: 'capture-old',
          artworkId: 'art-1',
          capturedAt: DateTime.utc(2026, 4, 4),
          publishedAt: DateTime.utc(2026, 4, 4),
          version: 1,
          variants: const [],
          isCurrent: false,
        ),
      ],
    );
