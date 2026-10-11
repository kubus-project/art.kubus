import 'package:art_kubus/utils/media_failure_registry.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
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

  testWidgets('passes semantic labels to network images', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KubusCachedImage(
          imageUrl: url,
          semanticLabel: 'Artwork cover image',
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.semanticLabel, 'Artwork cover image');
    expect(image.excludeFromSemantics, isFalse);
  });

  testWidgets('labels fallback images when no URL is available',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const KubusCachedImage(
          imageUrl: null,
          semanticLabel: 'Missing artwork image',
        ),
      ),
    );

    expect(find.bySemanticsLabel('Missing artwork image'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'an unsafe reference renders the fallback icon and never a network image',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const KubusCachedImage(imageUrl: 'javascript:alert(1)')),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'an IPFS reference starts on the primary gateway URL',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const KubusCachedImage(
          imageUrl:
              'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        )),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      expect(provider, isA<NetworkImage>());
      expect(
        (provider as NetworkImage).url,
        startsWith(
            'https://dweb.link/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi'),
      );
    },
  );

  testWidgets(
    'a failed image shows the placeholder, never a broken-image glyph',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusCachedImage(
            imageUrl: 'https://cdn.example.com/missing-artwork.png',
          ),
        ),
      );
      // The test HTTP client answers 400, so the load fails in real async time.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(
              const Duration(milliseconds: 10),
            ));
        await tester.pump();
      }

      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    },
  );

  group('skipRecentlyFailed walks the gateway chain', () {
    const cid = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';
    const dweb = 'https://dweb.link/ipfs/$cid';
    const ipfsIo = 'https://ipfs.io/ipfs/$cid';
    const pinata = 'https://gateway.pinata.cloud/ipfs/$cid';

    tearDown(KubusMediaFailureRegistry.shared.clear);

    String shownUrl(WidgetTester tester) =>
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url;

    Widget image(String? imageUrl) => _wrap(
          KubusCachedImage(imageUrl: imageUrl, skipRecentlyFailed: true),
        );

    testWidgets('a failed first gateway hands over to the second',
        (tester) async {
      KubusMediaFailureRegistry.shared.markFailed(dweb);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(shownUrl(tester), ipfsIo);
    });

    testWidgets('two failed gateways hand over to the third', (tester) async {
      KubusMediaFailureRegistry.shared
        ..markFailed(dweb)
        ..markFailed(ipfsIo);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(shownUrl(tester), pinata);
    });

    testWidgets('the marker card path (first candidate only) advances too',
        (tester) async {
      // The marker card hands KubusCachedImage resolveDisplayUrl(), i.e. the
      // first gateway URL, which resolves again as a stored IPFS https URL.
      final cardUrl = MediaUrlResolver.resolveDisplayUrl('ipfs://$cid');
      expect(cardUrl, dweb);
      KubusMediaFailureRegistry.shared.markFailed(dweb);
      await tester.pumpWidget(image(cardUrl));
      expect(shownUrl(tester), ipfsIo);
    });

    testWidgets('the placeholder shows only once every gateway has failed',
        (tester) async {
      KubusMediaFailureRegistry.shared
        ..markFailed(dweb)
        ..markFailed(ipfsIo)
        ..markFailed(pinata);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('a changed reference starts over on its own first gateway',
        (tester) async {
      KubusMediaFailureRegistry.shared
        ..markFailed(dweb)
        ..markFailed(ipfsIo)
        ..markFailed(pinata);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(find.byType(Image), findsNothing);

      const other = 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG';
      await tester.pumpWidget(image('ipfs://$other'));
      expect(shownUrl(tester), 'https://dweb.link/ipfs/$other');
    });

    testWidgets('an in-flight failure skips a gateway that failed earlier',
        (tester) async {
      // The test HTTP client answers 400: the first gateway fails here and is
      // recorded; the second already failed, so the third is the next try.
      KubusMediaFailureRegistry.shared.markFailed(ipfsIo);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(shownUrl(tester), dweb);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(
              const Duration(milliseconds: 10),
            ));
        await tester.pump();
      }
      expect(KubusMediaFailureRegistry.shared.hasRecentlyFailed(dweb), isTrue);
      expect(KubusMediaFailureRegistry.shared.hasRecentlyFailed(pinata), isTrue,
          reason: 'the walk reached the third gateway past the failed second');
      // Everything failed: placeholder, not a loop of requests.
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('a surface that did not opt in still starts on the first',
        (tester) async {
      KubusMediaFailureRegistry.shared.markFailed(dweb);
      await tester.pumpWidget(
        _wrap(const KubusCachedImage(imageUrl: 'ipfs://$cid')),
      );
      expect(shownUrl(tester), dweb);
    });
  });
}
