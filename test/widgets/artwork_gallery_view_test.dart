import 'package:art_kubus/widgets/artwork_gallery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _urls = <String>[
  'https://example.invalid/art-1.png',
  'https://example.invalid/art-2.png',
  'https://example.invalid/art-3.png',
];

Widget _wrapGallery({
  required Widget child,
  required double width,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: child,
          ),
        ),
      ),
    ),
  );
}

bool _semanticsFlagIsTrue(Object value) {
  return value == true || value.toString() == 'Tristate.isTrue';
}

void main() {
  testWidgets('desktop thumbnails expose index and selected state',
      (tester) async {
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

    final selectedFinder =
        find.bySemanticsLabel('Sun Garden image 1 of 3 thumbnail, selected');
    expect(
        find.bySemanticsLabel('Open Sun Garden image 1 of 3'), findsOneWidget);
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
        find.bySemanticsLabel('Open Sun Garden image 2 of 3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Sun Garden image 2 of 3 thumbnail, selected'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('mobile gallery announces the selected image index',
      (tester) async {
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
        find.bySemanticsLabel('Open Sun Garden image 1 of 3'), findsOneWidget);
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
