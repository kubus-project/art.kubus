import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/utils/media_failure_registry.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the [ResizeImage] decode dimensions Flutter applies when an
/// [Image.network] is given `cacheWidth`/`cacheHeight`.
///
/// Providing BOTH dimensions decodes the bitmap to exactly those pixels,
/// ignoring the source aspect ratio — which stretches/squishes the image
/// before [BoxFit.cover] can crop it. [KubusCachedImage] must therefore drop
/// one axis for any aspect-preserving fit so the decode keeps native aspect
/// ratio and the fit does the cropping.
({int? width, int? height}) _resizeDimsOf(
  WidgetTester tester, {
  int index = 0,
}) {
  final image = tester.widget<Image>(find.byType(Image).at(index));
  final provider = image.image;
  if (provider is ResizeImage) {
    return (width: provider.width, height: provider.height);
  }
  return (width: null, height: null);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 300, height: 150, child: child)),
    ),
  );
}

const _captureKey = ValueKey<String>('image-pixel-capture');
const _placeholderKey = ValueKey<String>('image-initial-placeholder');

Widget _pixelWrap(Widget child) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: RepaintBoundary(key: _captureKey, child: child),
        ),
      ),
    );

Future<Uint8List> _solidPng(ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
  final image = await recorder.endRecording().toImage(8, 8);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Color> _centerPixel(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    final offset = (50 * 100 + 50) * 4;
    return ui.Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }))!;
}

int _red8(ui.Color color) => (color.toARGB32() >> 16) & 0xff;
int _green8(ui.Color color) => (color.toARGB32() >> 8) & 0xff;
int _blue8(ui.Color color) => color.toARGB32() & 0xff;

void _expectRed(ui.Color color) {
  expect(_red8(color), greaterThanOrEqualTo(240));
  expect(_green8(color), lessThanOrEqualTo(10));
  expect(_blue8(color), lessThanOrEqualTo(10));
}

void _expectBlue(ui.Color color) {
  expect(_red8(color), lessThanOrEqualTo(10));
  expect(_green8(color), lessThanOrEqualTo(10));
  expect(_blue8(color), greaterThanOrEqualTo(240));
}

void _expectYellow(ui.Color color) {
  expect(_red8(color), greaterThanOrEqualTo(240));
  expect(_green8(color), greaterThanOrEqualTo(240));
  expect(_blue8(color), lessThanOrEqualTo(10));
}

class _ChunkedImageOverrides extends HttpOverrides {
  _ChunkedImageOverrides({required this.red, required this.blue});

  final Uint8List red;
  final Uint8List blue;
  final Completer<void> blueChunkSent = Completer<void>();
  final Completer<void> releaseBlue = Completer<void>();
  int redRequests = 0;
  int blueRequests = 0;
  int failedRequests = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _ChunkedImageClient(this);
}

class _ChunkedImageClient implements HttpClient {
  _ChunkedImageClient(this.fixture);

  final _ChunkedImageOverrides fixture;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.queryParameters['v'] == 'red') {
      fixture.redRequests += 1;
      return _ChunkedImageRequest(
        response: _ChunkedImageResponse(
          bytes: fixture.red,
          statusCode: HttpStatus.ok,
        ),
      );
    }
    if (url.queryParameters['v'] == 'blue') {
      fixture.blueRequests += 1;
      return _ChunkedImageRequest(
        response: _ChunkedImageResponse(
          bytes: fixture.blue,
          statusCode: HttpStatus.ok,
          firstChunkSent: fixture.blueChunkSent,
          release: fixture.releaseBlue,
        ),
      );
    }
    fixture.failedRequests += 1;
    return _ChunkedImageRequest(
      response: const _ChunkedImageResponse(
        bytes: <int>[],
        statusCode: HttpStatus.notFound,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChunkedImageRequest implements HttpClientRequest {
  _ChunkedImageRequest({required this.response});

  final HttpClientResponse response;

  @override
  HttpHeaders get headers => _ChunkedImageHeaders();

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChunkedImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
  const _ChunkedImageResponse({
    required this.bytes,
    required this.statusCode,
    this.firstChunkSent,
    this.release,
  });

  final List<int> bytes;
  @override
  final int statusCode;
  final Completer<void>? firstChunkSent;
  final Completer<void>? release;

  @override
  int get contentLength => bytes.length;
  @override
  HttpHeaders get headers => _ChunkedImageHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final first = firstChunkSent;
    final hold = release;
    if (first == null || hold == null) {
      return Stream<List<int>>.value(bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }
    final split = bytes.length ~/ 2;
    return Stream<List<int>>.multi((sink) async {
      sink.add(bytes.sublist(0, split));
      if (!first.isCompleted) first.complete();
      await hold.future;
      sink.add(bytes.sublist(split));
      sink.close();
    }).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChunkedImageHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  List<String>? operator [](String name) => null;

  @override
  String? value(String name) => null;

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const url = 'https://example.com/cover.png';

  testWidgets(
    'retains the decoded frame while a new version streams, then falls back',
    (tester) async {
      final pngs = await tester.runAsync(
        () async => (
          await _solidPng(const ui.Color(0xFFFF0000)),
          await _solidPng(const ui.Color(0xFF0000FF)),
        ),
      );
      final fixture = _ChunkedImageOverrides(red: pngs!.$1, blue: pngs.$2);
      imageCache
        ..clear()
        ..clearLiveImages();
      final previousClientProvider = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider =
          () => fixture.createHttpClient(null);
      KubusMediaFailureRegistry.shared.clear();
      try {
        Widget image(String version) => _pixelWrap(
              KubusCachedImage(
                imageUrl: 'https://images.example.test/cover.png',
                cacheVersion: version,
                semanticLabel: 'Artwork A',
                placeholderBuilder: (_) => const ColoredBox(
                  key: _placeholderKey,
                  color: Color(0xFFFFFF00),
                ),
              ),
            );

        await tester.pumpWidget(image('red'));
        expect(
          find.byKey(_placeholderKey),
          findsOneWidget,
          reason: 'the first request has no decoded frame yet',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        _expectRed(await _centerPixel(tester));
        expect(fixture.redRequests, 1);

        await tester.pumpWidget(image('blue'));
        await tester.runAsync(
          () =>
              fixture.blueChunkSent.future.timeout(const Duration(seconds: 5)),
        );
        await tester.pump();
        expect(find.byKey(_placeholderKey), findsNothing);
        expect(
          tester.widget<Image>(find.byType(Image)).semanticLabel,
          'Artwork A',
        );
        expect(
          await _centerPixel(tester),
          isA<ui.Color>()
              .having((color) => _red8(color), 'red', greaterThanOrEqualTo(240))
              .having((color) => _green8(color), 'green', lessThanOrEqualTo(10))
              .having((color) => _blue8(color), 'blue', lessThanOrEqualTo(10)),
          reason: 'the old decoded frame remains painted during B progress',
        );

        fixture.releaseBlue.complete();
        for (var i = 0; i < 20; i += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          if (_blue8(await _centerPixel(tester)) >= 240) break;
        }
        _expectBlue(await _centerPixel(tester));
        expect(fixture.blueRequests, 1);

        await tester.pumpWidget(image('missing'));
        for (var i = 0; i < 20; i += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.byKey(_placeholderKey), findsOneWidget);
        expect(fixture.failedRequests, 1);
        expect(
          KubusMediaFailureRegistry.shared.hasRecentlyFailed(
            'https://images.example.test/cover.png?v=missing',
          ),
          isTrue,
        );
        expect(fixture.redRequests, 1);
        expect(fixture.blueRequests, 1);
      } finally {
        debugNetworkImageHttpClientProvider = previousClientProvider;
        KubusMediaFailureRegistry.shared.clear();
      }
    },
  );

  testWidgets('a replacement URL never paints the previous decoded frame', (
    tester,
  ) async {
    final pngs = await tester.runAsync(
      () async => (
        await _solidPng(const ui.Color(0xFFFF0000)),
        await _solidPng(const ui.Color(0xFF0000FF)),
      ),
    );
    final fixture = _ChunkedImageOverrides(red: pngs!.$1, blue: pngs.$2);
    imageCache
      ..clear()
      ..clearLiveImages();
    final previousClientProvider = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => fixture.createHttpClient(null);
    KubusMediaFailureRegistry.shared.clear();
    try {
      Widget image(String source, String version, String label) => _pixelWrap(
            KubusCachedImage(
              imageUrl: source,
              cacheVersion: version,
              semanticLabel: label,
              placeholderBuilder: (_) => const ColoredBox(
                  key: _placeholderKey, color: Color(0xFFFFFF00)),
            ),
          );

      await tester.pumpWidget(
        image('https://images.example.test/artwork-a.png', 'red', 'Artwork A'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      _expectRed(await _centerPixel(tester));

      await tester.pumpWidget(
        image('https://images.example.test/artwork-b.png', 'blue', 'Artwork B'),
      );
      await tester.runAsync(
        () => fixture.blueChunkSent.future.timeout(const Duration(seconds: 5)),
      );
      await tester.pump();

      expect(find.byKey(_placeholderKey), findsOneWidget);
      _expectYellow(await _centerPixel(tester));
      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Artwork B',
      );
      expect(fixture.redRequests, 1);
      expect(fixture.blueRequests, 1);

      fixture.releaseBlue.complete();
      for (var i = 0; i < 20; i += 1) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (_blue8(await _centerPixel(tester)) >= 240) break;
      }
      _expectBlue(await _centerPixel(tester));
    } finally {
      if (!fixture.releaseBlue.isCompleted) fixture.releaseBlue.complete();
      debugNetworkImageHttpClientProvider = previousClientProvider;
      KubusMediaFailureRegistry.shared.clear();
    }
  });

  testWidgets('a URL removed between images resets the initial placeholder', (
    tester,
  ) async {
    final pngs = await tester.runAsync(
      () async => (
        await _solidPng(const ui.Color(0xFFFF0000)),
        await _solidPng(const ui.Color(0xFF0000FF)),
      ),
    );
    final fixture = _ChunkedImageOverrides(red: pngs!.$1, blue: pngs.$2);
    imageCache
      ..clear()
      ..clearLiveImages();
    final previousClientProvider = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => fixture.createHttpClient(null);
    try {
      Widget image(String? imageUrl, String version) => _pixelWrap(
            KubusCachedImage(
              imageUrl: imageUrl,
              cacheVersion: version,
              placeholderBuilder: (_) => const ColoredBox(
                  key: _placeholderKey, color: Color(0xFFFFFF00)),
            ),
          );

      await tester.pumpWidget(
        image('https://images-lifecycle.example.test/cover.png', 'red'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      _expectRed(await _centerPixel(tester));

      await tester.pumpWidget(image(null, 'none'));
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(_placeholderKey), findsOneWidget);
      _expectYellow(await _centerPixel(tester));

      await tester.pumpWidget(
        image('https://images-lifecycle.example.test/cover.png', 'blue'),
      );
      await tester.runAsync(
        () => fixture.blueChunkSent.future.timeout(const Duration(seconds: 5)),
      );
      await tester.pump();
      expect(find.byKey(_placeholderKey), findsOneWidget);
      _expectYellow(await _centerPixel(tester));
      fixture.releaseBlue.complete();
    } finally {
      debugNetworkImageHttpClientProvider = previousClientProvider;
    }
  });

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

  testWidgets('BoxFit.cover with a taller cache target keeps height instead', (
    tester,
  ) async {
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
  });

  testWidgets(
    'display-sized decodes use DPR pixels, cap large targets, and reuse keys',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);

      final png = await tester.runAsync(
        () => _solidPng(const ui.Color(0xFFFF0000)),
      );
      final fixture = _ChunkedImageOverrides(red: png!, blue: png);
      imageCache
        ..clear()
        ..clearLiveImages();
      final previousClientProvider = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider =
          () => fixture.createHttpClient(null);
      const repeatedUrl = 'https://images.example.test/cover.png?v=red';

      try {
        Widget preview() => const SizedBox(
              width: 44,
              height: 44,
              child: KubusCachedImage(
                imageUrl: repeatedUrl,
                fit: BoxFit.cover,
                decodeToDisplaySize: true,
              ),
            );

        await tester.pumpWidget(
          MaterialApp(home: Row(children: [preview(), preview()])),
        );

        expect(_resizeDimsOf(tester, index: 0), (width: 132, height: null));
        expect(_resizeDimsOf(tester, index: 1), (width: 132, height: null));

        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        expect(
          fixture.redRequests,
          1,
          reason: 'same URL and ResizeImage dimensions should share one load',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 600,
                height: 400,
                child: const KubusCachedImage(
                  imageUrl: repeatedUrl,
                  fit: BoxFit.cover,
                  decodeToDisplaySize: true,
                ),
              ),
            ),
          ),
        );
        expect(_resizeDimsOf(tester), (width: 1440, height: null));
      } finally {
        debugNetworkImageHttpClientProvider = previousClientProvider;
        imageCache
          ..clear()
          ..clearLiveImages();
      }
    },
  );

  testWidgets('BoxFit.fill intentionally distorts and keeps both cache dims', (
    tester,
  ) async {
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
  });

  testWidgets('a single cache dimension is passed through untouched', (
    tester,
  ) async {
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
  });

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

  testWidgets('labels fallback images when no URL is available', (
    tester,
  ) async {
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

  testWidgets('an IPFS reference starts on the primary gateway URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const KubusCachedImage(
          imageUrl:
              'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<NetworkImage>());
    expect(
      (provider as NetworkImage).url,
      startsWith(
        'https://dweb.link/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
      ),
    );
  });

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
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
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

    Widget image(String? imageUrl) =>
        _wrap(KubusCachedImage(imageUrl: imageUrl, skipRecentlyFailed: true));

    testWidgets('a failed first gateway hands over to the second', (
      tester,
    ) async {
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

    testWidgets('the marker card path (first candidate only) advances too', (
      tester,
    ) async {
      // The marker card hands KubusCachedImage resolveDisplayUrl(), i.e. the
      // first gateway URL, which resolves again as a stored IPFS https URL.
      final cardUrl = MediaUrlResolver.resolveDisplayUrl('ipfs://$cid');
      expect(cardUrl, dweb);
      KubusMediaFailureRegistry.shared.markFailed(dweb);
      await tester.pumpWidget(image(cardUrl));
      expect(shownUrl(tester), ipfsIo);
    });

    testWidgets('the placeholder shows only once every gateway has failed', (
      tester,
    ) async {
      KubusMediaFailureRegistry.shared
        ..markFailed(dweb)
        ..markFailed(ipfsIo)
        ..markFailed(pinata);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('a changed reference starts over on its own first gateway', (
      tester,
    ) async {
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

    testWidgets('an in-flight failure skips a gateway that failed earlier', (
      tester,
    ) async {
      // The test HTTP client answers 400: the first gateway fails here and is
      // recorded; the second already failed, so the third is the next try.
      KubusMediaFailureRegistry.shared.markFailed(ipfsIo);
      await tester.pumpWidget(image('ipfs://$cid'));
      expect(shownUrl(tester), dweb);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(KubusMediaFailureRegistry.shared.hasRecentlyFailed(dweb), isTrue);
      expect(
        KubusMediaFailureRegistry.shared.hasRecentlyFailed(pinata),
        isTrue,
        reason: 'the walk reached the third gateway past the failed second',
      );
      // Everything failed: placeholder, not a loop of requests.
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('a surface that did not opt in still starts on the first', (
      tester,
    ) async {
      KubusMediaFailureRegistry.shared.markFailed(dweb);
      await tester.pumpWidget(
        _wrap(const KubusCachedImage(imageUrl: 'ipfs://$cid')),
      );
      expect(shownUrl(tester), dweb);
    });
  });
}
