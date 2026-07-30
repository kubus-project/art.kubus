import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/features/map/shared/marker_overlay_card_metrics.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/common/kubus_marker_overlay_card.dart';
import 'package:art_kubus/widgets/common/marker_attribution_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Hotfix requirement E: the floating quick card must never scroll internally,
/// must keep a useful media area, and must stay inside its bounds on compact and
/// short viewports. The reserved height and the rendered layout both come from
/// [MarkerOverlayCardMetrics], so these tests assert they agree.

ArtMarker _eventMarker({
  String description = 'A short marker description.',
  Map<String, dynamic>? extraMetadata,
}) {
  return ArtMarker(
    id: 'marker-event-1',
    name: 'Ponjava VI',
    description: description,
    position: const LatLng(46.0569, 14.5058),
    type: ArtMarkerType.exhibition,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
    createdBy: 'tester',
    metadata: <String, dynamic>{
      'subjectType': 'exhibition',
      'subjectId': '8a1d8347-fada-4755-95d2-6024519c93cd',
      'subjectCategory': 'Group show',
      'locationName': 'Kino Siska',
      'startsAt': '2026-08-01T18:00:00.000Z',
      'endsAt': '2026-08-10T20:00:00.000Z',
      ...?extraMetadata,
    },
  );
}

String _words(int count) => List<String>.generate(
      count,
      (index) => 'word${(index + 1).toString().padLeft(3, '0')}',
    ).join(' ');

Widget _host(
  Widget card, {
  required double width,
  required double height,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true).copyWith(
      splashFactory: NoSplash.splashFactory,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          // Mirrors the overlay wrapper: a fixed slot sized to the estimator's
          // reserved height.
          child: SizedBox(width: width, height: height, child: card),
        ),
      ),
    ),
  );
}

KubusMarkerOverlayCard _card({
  required ArtMarker marker,
  required double width,
  required double height,
  String? description,
  int stackCount = 1,
  List<MarkerOverlayActionSpec> actions = const <MarkerOverlayActionSpec>[],
  String? distanceText,
}) {
  return KubusMarkerOverlayCard(
    marker: marker,
    baseColor: Colors.teal,
    displayTitle: marker.name,
    canPresentExhibition: false,
    description: description ?? marker.description,
    linkedSubjectTypeLabel: 'Exhibition',
    linkedSubjectSubtitle: 'Kino Siska - 2026-08-01 -> 2026-08-10',
    distanceText: distanceText,
    onClose: () {},
    onPrimaryAction: () {},
    primaryActionIcon: Icons.info_outline,
    primaryActionLabel: 'More info',
    actions: actions,
    stackCount: stackCount,
    stackIndex: 0,
    onNextStacked: stackCount > 1 ? () {} : null,
    onPreviousStacked: stackCount > 1 ? () {} : null,
    onSelectStackIndex: stackCount > 1 ? (_) {} : null,
    maxWidth: width,
    maxHeight: height,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const desktopWidth = 336.0;
  const compactWidth = 272.0;

  group('composition resolver', () {
    MarkerOverlayCardContentSpec spec({
      int descriptionWords = 40,
      int badgeCount = 3,
      int attributionRows = 2,
      bool hasPager = false,
      int secondaryActionRows = 1,
    }) {
      return MarkerOverlayCardContentSpec(
        description: _words(descriptionWords),
        badgeCount: badgeCount,
        attributionRows: attributionRows,
        hasKicker: true,
        hasLinkedTitle: false,
        hasLinkedSubtitle: true,
        hasByline: false,
        secondaryActionRows: secondaryActionRows,
        hasPager: hasPager,
      );
    }

    test('normal viewport keeps the full 180px-class media area', () {
      final composition = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(),
        availableHeight: 700,
        isCompactWidth: false,
        textScale: 1.0,
      );

      expect(
        composition.mediaHeight,
        MarkerOverlayCardMetrics.mediaHeightRegular,
      );
      expect(composition.showAttribution, isTrue);
      expect(composition.estimatedHeight, lessThanOrEqualTo(700));
    });

    test('normal viewport reserves far more than the old five-line budget', () {
      final composition = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(descriptionWords: 90),
        availableHeight: 700,
        isCompactWidth: false,
        textScale: 1.0,
      );

      // The pre-hotfix card capped the description at five lines inside a 92px
      // box; the restored budget must clear both numbers by a wide margin.
      expect(composition.descriptionMaxLines, greaterThan(5));
      expect(composition.descriptionHeight, greaterThan(92));
    });

    test('estimated height never exceeds the available height', () {
      for (final available in <double>[240, 300, 360, 420, 520, 700, 900]) {
        for (final compact in <bool>[true, false]) {
          final contentSpec = spec(descriptionWords: 120, hasPager: true);
          final composition = MarkerOverlayCardMetrics.resolveComposition(
            spec: contentSpec,
            availableHeight: available,
            isCompactWidth: compact,
            textScale: 1.0,
          );
          expect(
            composition.estimatedHeight,
            lessThanOrEqualTo(available + 0.001),
            reason: 'available=$available compact=$compact',
          );
        }
      }
    });

    test('an irreducible layout scales into the viewport', () {
      final contentSpec = spec(descriptionWords: 120, hasPager: true);
      final composition = MarkerOverlayCardMetrics.resolveComposition(
        spec: contentSpec,
        availableHeight: 120,
        isCompactWidth: true,
        textScale: 1.0,
      );

      expect(composition.showMedia, isFalse);
      expect(composition.showDescription, isFalse);
      expect(composition.estimatedHeight, 120);
      expect(composition.contentHeight, greaterThan(120));
      expect(composition.needsViewportScale, isTrue);
    });

    test('a short viewport trims the composition instead of scrolling', () {
      final tall = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(descriptionWords: 120, hasPager: true),
        availableHeight: 700,
        isCompactWidth: false,
        textScale: 1.0,
      );
      final short = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(descriptionWords: 120, hasPager: true),
        availableHeight: 360,
        isCompactWidth: false,
        textScale: 1.0,
      );

      expect(short.estimatedHeight, lessThan(tall.estimatedHeight));
      final trimmedMedia = short.mediaHeight < tall.mediaHeight;
      final trimmedLines = short.descriptionMaxLines < tall.descriptionMaxLines;
      expect(
        trimmedMedia || trimmedLines,
        isTrue,
        reason: 'a short viewport must trim media or preview lines',
      );
    });

    testWidgets('an irreducible card scales into a short viewport',
        (tester) async {
      final marker = _eventMarker(description: _words(120));

      await tester.pumpWidget(
        _host(
          _card(marker: marker, width: compactWidth, height: 120),
          width: compactWidth,
          height: 120,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.text('More info'), findsOneWidget);
    });

    test('a short description produces a short card, not an empty one', () {
      final short = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(descriptionWords: 3),
        availableHeight: 700,
        isCompactWidth: false,
        textScale: 1.0,
      );

      expect(short.estimatedHeight, lessThan(560));
      expect(short.descriptionMaxLines, greaterThanOrEqualTo(1));
    });

    test('accessibility text scaling is reflected in the reserved height', () {
      final normal = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(),
        availableHeight: 900,
        isCompactWidth: false,
        textScale: 1.0,
      );
      final scaled = MarkerOverlayCardMetrics.resolveComposition(
        spec: spec(),
        availableHeight: 900,
        isCompactWidth: false,
        textScale: 2.0,
      );

      expect(scaled.estimatedHeight, greaterThan(normal.estimatedHeight));
    });

    test('compact cards are detected from the card width, not the viewport',
        () {
      expect(MarkerOverlayCardMetrics.isCompactCard(compactWidth), isTrue);
      expect(MarkerOverlayCardMetrics.isCompactCard(desktopWidth), isFalse);
      expect(MarkerOverlayCardMetrics.isCompactCard(null), isFalse);
      expect(MarkerOverlayCardMetrics.isCompactCard(double.infinity), isFalse);
    });
  });

  group('estimator and widget agree', () {
    test('estimateCardHeight returns the shared composition height', () {
      final marker = _eventMarker(description: _words(60));
      final expected = MarkerOverlayCardMetrics.resolveComposition(
        spec: MarkerOverlayCardMetrics.resolveContentSpec(
          marker: marker,
          hasSecondaryActions: true,
          stackCount: 1,
        ),
        availableHeight: 640,
        isCompactWidth: false,
        textScale: 1.0,
      );

      final estimated = KubusMarkerOverlayHelpers.estimateCardHeight(
        marker: marker,
        artwork: null,
        event: null,
        exhibition: null,
        maxCardHeight: 640,
        cardWidth: desktopWidth,
        hasSecondaryActions: true,
      );

      expect(estimated, greaterThanOrEqualTo(expected.estimatedHeight));
      expect(estimated, lessThanOrEqualTo(640));
    });

    test('long credits reserve two lines per attribution row', () {
      // Long artist/photo/source credits wrap onto a second line. Reserving one
      // line each is what previously squeezed the description block and clipped
      // it mid-line on the orphaned-marker fixture.
      final longCredits = _eventMarker(
        description: _words(40),
        extraMetadata: <String, dynamic>{
          'artistName':
              'Klara Perusek in collaboration with the neighbourhood workshop',
          'imageAuthor':
              'Kino Siska documentation team, photographed by A. Novak',
          'imageLicense':
              'CC BY-SA 4.0 (Creative Commons Attribution-ShareAlike)',
          'sourceAttribution':
              'Data: OpenStreetMap contributors and the municipal cultural register',
        },
      );
      final shortCredits = _eventMarker(
        description: _words(40),
        extraMetadata: <String, dynamic>{
          'artistName': 'K. P.',
          'imageAuthor': 'KS',
          'imageLicense': 'CC0',
          'sourceAttribution': 'OSM',
        },
      );

      final longSpec = MarkerOverlayCardMetrics.resolveContentSpec(
        marker: longCredits,
      );
      final shortSpec = MarkerOverlayCardMetrics.resolveContentSpec(
        marker: shortCredits,
      );

      expect(longSpec.attributionRows, 3);
      expect(shortSpec.attributionRows, 3);
      expect(longSpec.effectiveAttributionLines, greaterThan(3));
      expect(shortSpec.effectiveAttributionLines, 3);
      expect(
        MarkerOverlayCardMetrics.attributionHeight(longSpec, 1.0),
        greaterThan(MarkerOverlayCardMetrics.attributionHeight(shortSpec, 1.0)),
      );
    });

    test('a one-line title does not reserve two title lines', () {
      expect(
        MarkerOverlayCardMetrics.titleLinesFor('Short', isCompactWidth: false),
        1,
      );
      expect(
        MarkerOverlayCardMetrics.titleLinesFor(
          'A considerably longer marker title that has to wrap',
          isCompactWidth: false,
        ),
        2,
      );
    });

    test('attribution row count matches what the section renders', () {
      final marker = _eventMarker(
        extraMetadata: <String, dynamic>{
          'artistName': 'Klara Perusek',
          'imageAuthor': 'Kino Siska',
          'imageLicense': 'CC BY-SA 4.0',
          'sourceAttribution': 'OpenStreetMap contributors',
        },
      );

      expect(
        MarkerAttributionSection.rowCountForMarkerAndArtwork(marker, null),
        3,
      );
      expect(
        MarkerAttributionSection.rowCountForMarkerAndArtwork(
          _eventMarker(),
          null,
        ),
        0,
      );
    });
  });

  group('rendered card', () {
    testWidgets('contains no internal vertical scroller', (tester) async {
      final marker = _eventMarker(description: _words(160));
      await tester.pumpWidget(
        _host(
          _card(marker: marker, width: desktopWidth, height: 620),
          width: desktopWidth,
          height: 620,
        ),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the full media area on a normal-height card',
        (tester) async {
      final marker = _eventMarker(description: _words(60));
      await tester.pumpWidget(
        _host(
          _card(marker: marker, width: desktopWidth, height: 640),
          width: desktopWidth,
          height: 640,
        ),
      );

      final mediaBox = tester.getSize(
        find.byKey(const ValueKey<String>('marker_overlay_media')),
      );
      expect(mediaBox.height, MarkerOverlayCardMetrics.mediaHeightRegular);
      expect(tester.takeException(), isNull);
    });

    testWidgets('multi-line description and attribution stay visible',
        (tester) async {
      final marker = _eventMarker(
        description: _words(120),
        extraMetadata: <String, dynamic>{
          'imageAuthor': 'Kino Siska',
          'imageLicense': 'CC BY-SA 4.0',
          'sourceAttribution': 'OpenStreetMap contributors',
        },
      );
      await tester.pumpWidget(
        _host(
          _card(marker: marker, width: desktopWidth, height: 700),
          width: desktopWidth,
          height: 700,
        ),
      );

      final descriptionFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('word001') ?? false),
      );
      expect(descriptionFinder, findsOneWidget);
      final descriptionText = tester.widget<Text>(descriptionFinder);
      expect(descriptionText.maxLines, greaterThan(5));

      expect(find.byType(MarkerAttributionSection), findsOneWidget);
      expect(find.textContaining('Kino Siska'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('footer actions and primary CTA stay inside the card bounds',
        (tester) async {
      final marker = _eventMarker(description: _words(160));
      await tester.pumpWidget(
        _host(
          _card(
            marker: marker,
            width: desktopWidth,
            height: 620,
            stackCount: 3,
            actions: <MarkerOverlayActionSpec>[
              MarkerOverlayActionSpec(
                icon: Icons.bookmark_border,
                label: 'Save',
                isActive: false,
                activeColor: Colors.teal,
                onTap: () {},
              ),
              MarkerOverlayActionSpec(
                icon: Icons.share_outlined,
                label: 'Share',
                isActive: false,
                activeColor: Colors.teal,
                onTap: () {},
              ),
            ],
          ),
          width: desktopWidth,
          height: 620,
        ),
      );

      final cardRect = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
      );
      final ctaRect = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_primary_action')),
      );
      expect(ctaRect.bottom, lessThanOrEqualTo(cardRect.bottom + 0.5));
      expect(ctaRect.top, greaterThanOrEqualTo(cardRect.top - 0.5));

      for (final actionRect in tester
          .widgetList(
            find.byKey(
              const ValueKey<String>('marker_overlay_secondary_action'),
            ),
          )
          .toList()
          .asMap()
          .keys
          .map((index) => tester.getRect(
                find
                    .byKey(const ValueKey<String>(
                      'marker_overlay_secondary_action',
                    ))
                    .at(index),
              ))) {
        expect(actionRect.bottom, lessThanOrEqualTo(cardRect.bottom + 0.5));
      }

      expect(find.text('More info'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact width and short height do not overflow',
        (tester) async {
      for (final size in <Size>[
        const Size(compactWidth, 300),
        const Size(compactWidth, 360),
        const Size(compactWidth, 420),
        const Size(desktopWidth, 300),
        const Size(desktopWidth, 900),
      ]) {
        final marker = _eventMarker(description: _words(200));
        final maxHeight = size.height;
        final width = size.width;
        final composition = MarkerOverlayCardMetrics.resolveComposition(
          spec: MarkerOverlayCardMetrics.resolveContentSpec(
            marker: marker,
            hasSecondaryActions: true,
            stackCount: 2,
          ),
          availableHeight: maxHeight,
          isCompactWidth: MarkerOverlayCardMetrics.isCompactCard(width),
          textScale: 1.0,
        );

        await tester.pumpWidget(
          _host(
            _card(
              marker: marker,
              width: width,
              height: maxHeight,
              stackCount: 2,
              actions: <MarkerOverlayActionSpec>[
                MarkerOverlayActionSpec(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  isActive: false,
                  activeColor: Colors.teal,
                  onTap: () {},
                ),
              ],
            ),
            width: width,
            // The slot is sized to the reserved height, exactly like the map
            // overlay wrapper does.
            height: composition.estimatedHeight,
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at ${size.width}x${size.height}',
        );
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.text('More info'), findsOneWidget);
      }
    });

    testWidgets('large accessibility text does not overflow', (tester) async {
      final marker = _eventMarker(description: _words(120));
      const width = compactWidth;
      const maxHeight = 640.0;
      final composition = MarkerOverlayCardMetrics.resolveComposition(
        spec: MarkerOverlayCardMetrics.resolveContentSpec(marker: marker),
        availableHeight: maxHeight,
        isCompactWidth: true,
        textScale: 2.0,
      );

      await tester.pumpWidget(
        _host(
          _card(marker: marker, width: width, height: maxHeight),
          width: width,
          height: composition.estimatedHeight,
          textScale: 2.0,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('mobile and desktop widths use the same presentation rules',
        (tester) async {
      final marker = _eventMarker(description: _words(80));
      final sizes = <double, MarkerOverlayCardComposition>{};

      for (final width in <double>[320.0, desktopWidth]) {
        final composition = MarkerOverlayCardMetrics.resolveComposition(
          spec: MarkerOverlayCardMetrics.resolveContentSpec(marker: marker),
          availableHeight: 700,
          isCompactWidth: MarkerOverlayCardMetrics.isCompactCard(width),
          textScale: 1.0,
        );
        sizes[width] = composition;

        await tester.pumpWidget(
          _host(
            _card(marker: marker, width: width, height: 700),
            width: width,
            height: composition.estimatedHeight,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey<String>('marker_overlay_media')),
              )
              .height,
          MarkerOverlayCardMetrics.mediaHeightRegular,
        );
      }

      // Both widths land on the same media tier and attribution decision; only
      // the per-line text budget may differ.
      expect(
        sizes[320.0]!.mediaHeight,
        sizes[desktopWidth]!.mediaHeight,
      );
      expect(
        sizes[320.0]!.showAttribution,
        sizes[desktopWidth]!.showAttribution,
      );
    });
  });
}
