import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the [ResizeImage] decode dimensions Flutter applies when an
/// [Image.network] is given `cacheWidth`/`cacheHeight`.
///
/// Providing BOTH dimensions decodes the bitmap to exactly those pixels,
/// ignoring the source aspect ratio — which stretches/squishes the image
/// before [BoxFit.cover] can crop it. [KubusCachedImage] must therefore drop
/// one axis for any aspect-preserving fit so the decode keeps native aspect
/// ratio and the fit does the cropping.
({int? width, int? height}) _resizeDimsOf(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  final provider = image.image;
  if (provider is ResizeImage) {
    return (width: provider.width, height: provider.height);
  }
  return (width: null, height: null);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 300, height: 150, child: child),
      ),
    ),
  );
}

void main() {
  const url = 'https://example.com/cover.png';

  testWidgets(
    'BoxFit.cover with both cache dims keeps native aspect (wider box keeps width)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusCachedImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheWidth: 600,
            cacheHeight: 300,
          ),
        ),
      );

      final dims = _resizeDimsOf(tester);
      expect(dims.width, 600);
      expect(dims.height, isNull);
    },
  );

  testWidgets(
    'BoxFit.cover with a taller cache target keeps height instead',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusCachedImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheWidth: 200,
            cacheHeight: 400,
          ),
        ),
      );

      final dims = _resizeDimsOf(tester);
      expect(dims.width, isNull);
      expect(dims.height, 400);
    },
  );

  testWidgets(
    'BoxFit.fill intentionally distorts and keeps both cache dims',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusCachedImage(
            imageUrl: url,
            fit: BoxFit.fill,
            cacheWidth: 600,
            cacheHeight: 300,
          ),
        ),
      );

      final dims = _resizeDimsOf(tester);
      expect(dims.width, 600);
      expect(dims.height, 300);
    },
  );

  testWidgets(
    'a single cache dimension is passed through untouched',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusCachedImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheWidth: 600,
          ),
        ),
      );

      final dims = _resizeDimsOf(tester);
      expect(dims.width, 600);
      expect(dims.height, isNull);
    },
  );
}
