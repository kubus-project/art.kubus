import 'dart:convert';
import 'dart:io' as io;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:art_kubus/widgets/common/kubus_marker_overlay_card.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

late io.HttpServer _imageServer;
late String _imageUrl;

ArtMarker _marker() {
  return ArtMarker(
    id: 'marker-1',
    name: 'Marker',
    description:
        'Marker description that is intentionally long so the constrained body has to scroll.',
    position: const LatLng(46.0569, 14.5058),
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
    metadata: const <String, dynamic>{
      'subjectCategory': 'Digital',
      'locationName': 'Gallery',
    },
  );
}

Artwork _artwork() {
  return Artwork(
    id: 'art-1',
    title: 'Artwork',
    artist: 'Artist',
    description:
        'Artwork description that is intentionally long so the card body needs a scroll container.',
    imageUrl: _imageUrl,
    position: const LatLng(46.0569, 14.5058),
    rewards: 3,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 2),
    category: 'Painting',
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _imageServer = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO8B9fQAAAAASUVORK5CYII=',
    );
    _imageServer.listen((request) {
      request.response.headers.contentType = io.ContentType('image', 'png');
      request.response.add(pngBytes);
      request.response.close();
    });
    _imageUrl = 'http://127.0.0.1:${_imageServer.port}/artwork.png';
  });

  tearDownAll(() async {
    await _imageServer.close(force: true);
  });

  testWidgets(
    'constrained marker overlay card keeps cover image and scrollable body',
    (tester) async {
      final marker = _marker();
      final artwork = _artwork();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 340,
            child: KubusMarkerOverlayCard(
              marker: marker,
              artwork: artwork,
              baseColor: Colors.teal,
              displayTitle: artwork.title,
              canPresentExhibition: false,
              description:
                  '${marker.description} ${artwork.description} ${marker.description} ${artwork.description} ${marker.description}',
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              actions: const [
                MarkerOverlayActionSpec(
                  icon: Icons.favorite,
                  label: 'Like',
                  isActive: false,
                  activeColor: Colors.teal,
                ),
              ],
              stackCount: 3,
              stackIndex: 1,
              onNextStacked: () {},
              onPreviousStacked: () {},
              onSelectStackIndex: (_) {},
              maxWidth: 340,
              maxHeight: 260,
            ),
          ),
        ),
      );

      expect(find.byType(FittedBox), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(GlassSurface), findsOneWidget);

      final imageWidget = tester.widget<KubusCachedImage>(
        find.byType(KubusCachedImage),
      );
      expect(imageWidget.fit, BoxFit.cover);

      expect(find.text('More info'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -160),
      );
      await tester.pump();

      expect(find.text('More info'), findsOneWidget);
    },
  );
}
