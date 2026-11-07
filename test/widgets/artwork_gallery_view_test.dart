import 'package:art_kubus/widgets/artwork_gallery_view.dart';
import 'package:art_kubus/widgets/disk_cached_artwork_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _urls = <String>[
  'https://example.invalid/art-1.png',
  'https://example.invalid/art-2.png',
  'https://example.invalid/art-3.png',
];

Widget _wrapGallery({required Widget child, required double width}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

bool _semanticsFlagIsTrue(Object value) {
  return value == true || value.toString() == 'Tristate.isTrue';
}

void main() {
  testWidgets(
    'gallery uses source-bound variants after filtering and reorder',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrapGallery(
          width: 1200,
          child: ArtworkGalleryView(
            imageUrls: [_urls[1], '', _urls[0]],
            height: 180,
            sourceImageVariants: [
              {
                'sourceUrl': _urls[0],
                'variants': [
                  {
                    'url': 'https://example.invalid/one-small.png',
                    'width': 320,
                    'height': 240,
                  },
                  {
                    'url': 'https://example.invalid/one-detail.png',
                    'width': 1280,
                    'height': 960,
                  },
                ],
              },
              {
                'sourceUrl': _urls[1],
                'variants': [
                  {
                    'url': 'https://example.invalid/two-small.png',
                    'width': 320,
                    'height': 240,
                  },
                  {
                    'url': 'https://example.invalid/two-detail.png',
                    'width': 1280,
                    'height': 960,
                  },
                ],
              },
            ],
          ),
        ),
      );
      final images = tester
          .widgetList<DiskCachedArtworkImage>(
            find.byType(DiskCachedArtworkImage),
          )
          .map((image) => image.url)
          .toList();
      expect(images.first, 'https://example.invalid/two-detail.png');
      expect(images, contains('https://example.invalid/two-small.png'));
      expect(images, contains('https://example.invalid/one-small.png'));
      expect(images, isNot(contains(_urls[0])));
      await tester.tap(find.bySemanticsLabel('Open Artwork image 1 of 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final lightboxImages = tester
          .widgetList<DiskCachedArtworkImage>(
            find.byType(DiskCachedArtworkImage),
          )
          .map((image) => image.url)
          .toList();
      expect(
          lightboxImages, contains('https://example.invalid/two-detail.png'));
      expect(lightboxImages,
          isNot(contains('https://example.invalid/one-detail.png')));
      semantics.dispose();
    },
  );

  testWidgets('desktop thumbnails expose index and selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrapGallery(
        width: 1200,
        child: ArtworkGalleryView(
          imageUrls: _urls,
          semanticLabel: 'Sun Garden image',
          height: 180,
        ),
      ),
    );

    final selectedFinder = find.bySemanticsLabel(
      'Sun Garden image 1 of 3 thumbnail, selected',
    );
    expect(
      find.bySemanticsLabel('Open Sun Garden image 1 of 3'),
      findsOneWidget,
    );
    expect(selectedFinder, findsOneWidget);

    final selectedData = tester.getSemantics(selectedFinder).getSemanticsData();
    expect(_semanticsFlagIsTrue(selectedData.flagsCollection.isButton), isTrue);
    expect(
      _semanticsFlagIsTrue(selectedData.flagsCollection.isSelected),
      isTrue,
    );

    await tester.tap(
      find.bySemanticsLabel('Sun Garden image 2 of 3 thumbnail'),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Open Sun Garden image 2 of 3'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Sun Garden image 2 of 3 thumbnail, selected'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('mobile gallery announces the selected image index', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrapGallery(
        width: 390,
        child: const ArtworkGalleryView(
          imageUrls: _urls,
          semanticLabel: 'Sun Garden image',
          height: 180,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Open Sun Garden image 1 of 3'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Sun Garden image 1 of 3, selected'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('lightbox exposes the current image context', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrapGallery(
        width: 1200,
        child: const ArtworkGalleryView(
          imageUrls: _urls,
          semanticLabel: 'Sun Garden image',
          height: 180,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Open Sun Garden image 1 of 3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.bySemanticsLabel('Viewing Sun Garden image 1 of 3'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Sun Garden image 1 of 3'), findsOneWidget);
    semantics.dispose();
  });
}
