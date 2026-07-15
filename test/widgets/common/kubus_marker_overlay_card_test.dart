import 'dart:convert';
import 'dart:io' as io;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/utils/design_tokens.dart';
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

String _buildWordSequence(int count) {
  final words = List<String>.generate(
    count,
    (index) => 'word${(index + 1).toString().padLeft(3, '0')}',
  );
  return words.join(' ');
}

Widget _wrap(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true).copyWith(
      splashFactory: NoSplash.splashFactory,
    ),
    darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
      splashFactory: NoSplash.splashFactory,
    ),
    themeMode: themeMode,
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
    'compact mobile preview stays map-first and keeps core actions accessible',
    (tester) async {
      final marker = _marker();
      var closeCount = 0;
      var detailsCount = 0;
      var nextCount = 0;
      var previousCount = 0;
      var quickActionCount = 0;

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            child: KubusMarkerOverlayCard(
              marker: marker,
              baseColor: Colors.teal,
              displayTitle: 'A deliberately long marker title',
              canPresentExhibition: false,
              description:
                  'A compact description that should remain a single calm line.',
              onClose: () => closeCount += 1,
              onPrimaryAction: () => detailsCount += 1,
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'View details',
              presentation: KubusMarkerOverlayCardPresentation.compactMobile,
              stackCount: 3,
              stackIndex: 1,
              onPreviousStacked: () => previousCount += 1,
              onNextStacked: () => nextCount += 1,
              onHorizontalDragEnd: (_) => nextCount += 1,
              actions: [
                MarkerOverlayActionSpec(
                  icon: Icons.favorite_outline,
                  label: 'Favorite',
                  isActive: false,
                  activeColor: Colors.teal,
                  onTap: () => quickActionCount += 1,
                ),
              ],
              maxWidth: 320,
              maxHeight: 208,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surface = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
      );
      expect(surface.width, lessThanOrEqualTo(320));
      expect(surface.height, lessThanOrEqualTo(208));
      expect(find.text('2/3'), findsOneWidget);
      final previewSemantics = tester.widget<Semantics>(
        find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
      );
      expect(
        previewSemantics.properties.label,
        'A deliberately long marker title',
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.tap(find.byTooltip('Next page'));
      await tester.tap(find.byTooltip('Previous page'));
      await tester.tap(find.text('View details'));
      await tester.pump();

      expect(closeCount, 1);
      expect(nextCount, 1);
      expect(previousCount, 1);
      expect(detailsCount, 1);
      expect(quickActionCount, 0);

      final primary = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_primary_action')),
      );
      expect(primary.height, greaterThanOrEqualTo(44));
    },
  );

  testWidgets('compact mobile preview supports large accessibility text',
      (tester) async {
    final marker = _marker();
    await tester.pumpWidget(
      _wrap(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: SizedBox(
            width: 328,
            child: KubusMarkerOverlayCard(
              marker: marker,
              baseColor: Colors.teal,
              displayTitle: 'Accessible marker title',
              canPresentExhibition: false,
              description: 'Description yields to essential content.',
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'View details',
              presentation: KubusMarkerOverlayCardPresentation.compactMobile,
              maxWidth: 328,
              maxHeight: 288,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.getRect(
      find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
    );
    expect(surface.height, lessThanOrEqualTo(288));
    expect(find.text('Accessible marker title'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(
      tester
          .getRect(find
              .byKey(const ValueKey<String>('marker_overlay_primary_action')))
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets(
    'constrained marker overlay card keeps cover image filling media box',
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
              maxHeight: 360,
            ),
          ),
        ),
      );

      expect(find.byType(FittedBox), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(GlassSurface), findsWidgets);

      final imageWidget = tester.widget<KubusCachedImage>(
        find.byType(KubusCachedImage),
      );
      expect(imageWidget.fit, BoxFit.cover);
      expect(imageWidget.width, double.infinity);
      expect(imageWidget.height, isNotNull);
      expect(imageWidget.height!, inInclusiveRange(132, 180));

      expect(find.text('More info'), findsOneWidget);

      expect(find.text('More info'), findsOneWidget);
    },
  );

  testWidgets(
    'title and card area taps can trigger detail callbacks',
    (tester) async {
      final marker = _marker();
      final artwork = _artwork();
      var titleTapCount = 0;
      var cardTapCount = 0;

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
              description: marker.description,
              onClose: () {},
              onPrimaryAction: () {},
              onCardTap: () => cardTapCount += 1,
              onTitleTap: () => titleTapCount += 1,
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 360,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Artwork'));
      await tester.pump();
      expect(titleTapCount, 1);

      await tester.tap(find.byType(KubusCachedImage));
      await tester.pump();
      expect(cardTapCount, 1);
    },
  );

  testWidgets(
    'rapid primary marker action taps stay local to the overlay',
    (tester) async {
      final marker = _marker();
      final artwork = _artwork();
      var primaryTapCount = 0;

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
              description: marker.description,
              onClose: () {},
              onPrimaryAction: () => primaryTapCount += 1,
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 360,
            ),
          ),
        ),
      );

      final primaryAction =
          find.byKey(const ValueKey<String>('marker_overlay_primary_action'));
      await tester.tap(primaryAction);
      await tester.tap(primaryAction);
      await tester.tap(primaryAction);
      await tester.pump();

      expect(primaryTapCount, 3);
      expect(tester.takeException(), isNull);
      expect(find.text('More info'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile marker overlay actions keep minimum touch height',
    (tester) async {
      final marker = _marker();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: KubusMarkerOverlayCard(
              marker: marker,
              baseColor: Colors.teal,
              displayTitle: marker.name,
              canPresentExhibition: false,
              description: _buildWordSequence(80),
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              actions: const [
                MarkerOverlayActionSpec(
                  icon: Icons.favorite,
                  label: 'Save',
                  isActive: false,
                  activeColor: Colors.teal,
                ),
              ],
              maxWidth: 300,
              maxHeight: 320,
            ),
          ),
        ),
      );

      final secondary = find.byKey(
        const ValueKey<String>('marker_overlay_secondary_action'),
      );
      final primary = find.byKey(
        const ValueKey<String>('marker_overlay_primary_action'),
      );

      expect(secondary, findsOneWidget);
      expect(primary, findsOneWidget);
      expect(tester.getSize(secondary).height,
          greaterThanOrEqualTo(KubusHeaderMetrics.actionHitArea));
      expect(tester.getSize(primary).height,
          greaterThanOrEqualTo(KubusHeaderMetrics.actionHitArea));
    },
  );

  testWidgets(
    'renders marker title first and linked subject context separately',
    (tester) async {
      final marker = _marker();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 340,
            child: KubusMarkerOverlayCard(
              marker: marker,
              baseColor: Colors.teal,
              displayTitle: 'North Plaza Marker',
              canPresentExhibition: false,
              linkedSubjectTypeLabel: 'Artwork',
              linkedSubjectTitle: 'Main Artwork',
              linkedSubjectSubtitle: 'Gallery Hall - 2025-05-01',
              description: marker.description,
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 360,
            ),
          ),
        ),
      );

      expect(find.text('North Plaza Marker'), findsOneWidget);
      expect(find.text('Artwork'), findsOneWidget);
      expect(find.text('Main Artwork'), findsOneWidget);
      expect(find.text('Gallery Hall - 2025-05-01'), findsOneWidget);
    },
  );

  testWidgets(
    'long description uses a compact floating-card preview budget',
    (tester) async {
      final marker = _marker();
      final artwork = _artwork();
      final longDescription = _buildWordSequence(220);

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
              description: longDescription,
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 360,
            ),
          ),
        ),
      );

      final descriptionFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.startsWith('word001 word002 word003') ?? false),
      );

      expect(descriptionFinder, findsOneWidget);

      final descriptionWidget = tester.widget<Text>(descriptionFinder);
      final descriptionData = descriptionWidget.data ?? '';
      final words = descriptionData
          .split(RegExp(r'\s+'))
          .where((segment) => segment.trim().isNotEmpty)
          .length;

      expect(words, lessThanOrEqualTo(90));
      expect(descriptionData.length, lessThanOrEqualTo(703));
    },
  );

  testWidgets(
    'short description card does not expand to maximum height',
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
              description: 'Short preview.',
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 460,
            ),
          ),
        ),
      );

      final cardSize = tester.getSize(
        find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
      );
      expect(cardSize.height, lessThan(460));
      expect(find.text('More info'), findsOneWidget);
    },
  );

  testWidgets(
    'long description stays bounded and keeps footer visible',
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
              description: _buildWordSequence(180),
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              actions: const [
                MarkerOverlayActionSpec(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  isActive: false,
                  activeColor: Colors.teal,
                ),
                MarkerOverlayActionSpec(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  isActive: false,
                  activeColor: Colors.teal,
                ),
              ],
              maxWidth: 340,
              maxHeight: 360,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('More info'), findsOneWidget);
      final cardRect = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
      );
      final primaryRect = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_primary_action')),
      );
      expect(primaryRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    },
  );

  testWidgets(
    'footer actions are compact and narrow cards use icon-only secondary actions',
    (tester) async {
      final marker = _marker();
      final artwork = _artwork();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 280,
            child: KubusMarkerOverlayCard(
              marker: marker,
              artwork: artwork,
              baseColor: Colors.teal,
              displayTitle: artwork.title,
              canPresentExhibition: false,
              description: 'Short preview.',
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              actions: const [
                MarkerOverlayActionSpec(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  isActive: false,
                  activeColor: Colors.teal,
                  tooltip: 'Save',
                ),
                MarkerOverlayActionSpec(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  isActive: false,
                  activeColor: Colors.teal,
                  tooltip: 'Share',
                ),
                MarkerOverlayActionSpec(
                  icon: Icons.favorite_border,
                  label: 'Like',
                  isActive: false,
                  activeColor: Colors.teal,
                  tooltip: 'Like',
                ),
              ],
              maxWidth: 280,
              maxHeight: 380,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('Like'), findsNothing);
      expect(find.byTooltip('Save'), findsOneWidget);
      expect(
        tester
            .getSize(
              find
                  .byKey(
                      const ValueKey<String>('marker_overlay_secondary_action'))
                  .first,
            )
            .height,
        KubusHeaderMetrics.actionHitArea,
      );
      expect(
        tester
            .getSize(
              find.byKey(
                  const ValueKey<String>('marker_overlay_primary_action')),
            )
            .height,
        KubusHeaderMetrics.actionHitArea,
      );
    },
  );

  testWidgets('distance badge renders when distance text is passed',
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
            distanceText: '1.2 km',
            description: 'Short preview.',
            onClose: () {},
            onPrimaryAction: () {},
            primaryActionIcon: Icons.arrow_forward,
            primaryActionLabel: 'More info',
            maxWidth: 340,
            maxHeight: 420,
          ),
        ),
      ),
    );

    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.byIcon(Icons.near_me), findsOneWidget);
  });

  testWidgets('primary CTA foreground follows brightness contrast rule',
      (tester) async {
    Future<Color?> pumpAndReadColor(ThemeMode mode) async {
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
              description: 'Short preview.',
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 420,
            ),
          ),
          themeMode: mode,
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('More info'));
      return text.style?.color;
    }

    expect(await pumpAndReadColor(ThemeMode.light), Colors.black);
    expect(await pumpAndReadColor(ThemeMode.dark), Colors.white);
  });

  testWidgets(
    'missing image uses fallback without stretching network image widget',
    (tester) async {
      final marker = _marker();
      final artworkWithoutImage = Artwork(
        id: 'art-no-image',
        title: 'No Image Artwork',
        artist: 'Artist',
        description: 'Description without a cover image.',
        imageUrl: '',
        position: const LatLng(46.0569, 14.5058),
        rewards: 0,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        category: 'Painting',
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 340,
            child: KubusMarkerOverlayCard(
              marker: marker,
              artwork: artworkWithoutImage,
              baseColor: Colors.teal,
              displayTitle: artworkWithoutImage.title,
              canPresentExhibition: false,
              description: artworkWithoutImage.description,
              onClose: () {},
              onPrimaryAction: () {},
              primaryActionIcon: Icons.arrow_forward,
              primaryActionLabel: 'More info',
              maxWidth: 340,
              maxHeight: 360,
            ),
          ),
        ),
      );

      expect(find.byType(KubusCachedImage), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    },
  );
}
