// Browser harness for the Flutter web spatial viewer.
//
// Mounts the real ArtworkSpatialArchiveSection (the widget both the desktop and
// the mobile artwork detail screens show) with the real ArtworkProvider, so the
// history request, the inline viewer, the iframe and the bundled Spark page all
// run as shipped. The backend is not contacted: scripts/qa/spatial_viewer_flutter_smoke.mjs
// answers `/api/artworks/<id>/spatial` and `/api/upload/file/<cid>` from a fixture.
//
//   flutter build web --release -t tool/qa/spatial_viewer_web_harness_main.dart \
//     --output build/spatial-harness
//   node scripts/qa/spatial_viewer_flutter_smoke.mjs
//
// Query: ?spacer=<px> pushes the section below the fold (lazy-load check).
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/widgets/spatial/artwork_spatial_archive_section.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

const String kHarnessArtworkId = '53b99c8b-8503-545c-8a13-55f60cfb8342';

void main() {
  final spacer = double.tryParse(Uri.base.queryParameters['spacer'] ?? '') ?? 0;
  runApp(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<ArtworkProvider>(
          create: (_) => ArtworkProvider(),
        ),
        ChangeNotifierProvider<KubusNodeProvider>(
          create: (_) => KubusNodeProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                SizedBox(height: spacer),
                ArtworkSpatialArchiveSection(
                  artwork: Artwork(
                    id: kHarnessArtworkId,
                    title: 'Synthetic flower',
                    artist: 'Test fixture',
                    description: 'Synthetic data; not an artwork.',
                    position: const LatLng(46.0569, 14.5058),
                    rewards: 0,
                    createdAt: DateTime.utc(2026, 1, 1),
                    category: 'Mural',
                    spatialCaptureCount: 1,
                  ),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
