import 'dart:async';
import 'dart:ui' as ui;

import 'package:art_kubus/features/map/engine/kubus_marker_cover_loader.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  coverUrlCacheTests();

  test('de-duplicates concurrent loads of the same URL', () async {
    var calls = 0;
    final gate = Completer<void>();
    final loader = KubusMarkerCoverLoader(fetch: (url, width) async {
      calls += 1;
      await gate.future;
      return _image();
    });
    addTearDown(loader.dispose);

    final a = loader.load('https://x/a.jpg', targetWidthPx: 96);
    final b = loader.load('https://x/a.jpg', targetWidthPx: 96);
    expect(loader.inFlightCount, 1);
    gate.complete();
    expect(await a, isNotNull);
    expect(await b, isNotNull);
    expect(calls, 1);
    expect(loader.cachedCount, 1);
  });

  test('serves a cached image without fetching again', () async {
    var calls = 0;
    final loader = KubusMarkerCoverLoader(fetch: (url, width) async {
      calls += 1;
      return _image();
    });
    addTearDown(loader.dispose);

    await loader.load('u', targetWidthPx: 96);
    expect(loader.cached('u', targetWidthPx: 96), isNotNull);
    await loader.load('u', targetWidthPx: 96);
    expect(calls, 1);
  });

  test('keeps at most maxCached images, dropping the least recently used',
      () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 2,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);

    await loader.load('a', targetWidthPx: 96);
    await loader.load('b', targetWidthPx: 96);
    loader.cached('a', targetWidthPx: 96); // refresh a: b is now the oldest
    await loader.load('c', targetWidthPx: 96);

    expect(loader.cachedCount, 2);
    expect(loader.cached('a', targetWidthPx: 96), isNotNull);
    expect(loader.cached('b', targetWidthPx: 96), isNull);
    expect(loader.cached('c', targetWidthPx: 96), isNotNull);
  });

  test('limits concurrent fetches', () async {
    var running = 0;
    var peak = 0;
    final gates = <Completer<void>>[];
    final loader = KubusMarkerCoverLoader(
      maxConcurrent: 2,
      fetch: (url, width) async {
        running += 1;
        if (running > peak) peak = running;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        running -= 1;
        return _image();
      },
    );
    addTearDown(loader.dispose);

    final futures = <Future<ui.Image?>>[
      for (var i = 0; i < 5; i++) loader.load('u$i', targetWidthPx: 96),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(gates.length, 2, reason: 'only maxConcurrent fetches start');
    var finished = false;
    unawaited(Future.wait(futures).then((_) => finished = true));
    while (!finished) {
      await Future<void>.delayed(Duration.zero);
      if (gates.isNotEmpty) gates.removeAt(0).complete();
    }
    expect(peak, lessThanOrEqualTo(2));
  });

  test('a failed URL is not retried inside the retry window', () async {
    var calls = 0;
    var now = DateTime.utc(2026, 1, 1);
    final loader = KubusMarkerCoverLoader(
      failureRetry: const Duration(minutes: 5),
      now: () => now,
      fetch: (url, width) async {
        calls += 1;
        return null;
      },
    );
    addTearDown(loader.dispose);

    expect(await loader.load('bad', targetWidthPx: 96), isNull);
    expect(loader.hasFailed('bad'), isTrue);
    expect(await loader.load('bad', targetWidthPx: 96), isNull);
    expect(calls, 1);

    now = now.add(const Duration(minutes: 6));
    expect(loader.hasFailed('bad'), isFalse);
    await loader.load('bad', targetWidthPx: 96);
    expect(calls, 2);
  });

  test('a throwing fetch counts as a failure, never an exception', () async {
    final loader = KubusMarkerCoverLoader(
      fetch: (url, width) async => throw StateError('boom'),
    );
    addTearDown(loader.dispose);

    expect(await loader.load('x', targetWidthPx: 96), isNull);
    expect(loader.hasFailed('x'), isTrue);
  });

  test('the same URL at another size is a separate decode', () async {
    final widths = <int>[];
    final loader = KubusMarkerCoverLoader(fetch: (url, width) async {
      widths.add(width);
      return _image();
    });
    addTearDown(loader.dispose);

    await loader.load('u', targetWidthPx: 96);
    await loader.load('u', targetWidthPx: 96);
    await loader.load('u', targetWidthPx: 160);
    expect(widths, <int>[96, 160]);
    expect(loader.cached('u', targetWidthPx: 160), isNotNull);
    expect(loader.cached('u', targetWidthPx: 224), isNull);
  });

  test('a disposed loader serves nothing', () async {
    final loader =
        KubusMarkerCoverLoader(fetch: (url, width) async => _image());
    loader.dispose();
    expect(await loader.load('x', targetWidthPx: 96), isNull);
  });
}

void coverUrlCacheTests() {
  group('KubusCoverUrlCache', () {
    test('resolves once while the signature is unchanged', () {
      final cache = KubusCoverUrlCache();
      var calls = 0;
      String? lookup() => cache.lookup(
            markerId: 'm1',
            signature: 'a',
            resolve: () {
              calls += 1;
              return 'https://x/a.jpg';
            },
          );
      expect(lookup(), 'https://x/a.jpg');
      expect(lookup(), 'https://x/a.jpg');
      expect(calls, 1);
    });

    test('a marker without a cover is remembered until its data changes', () {
      final cache = KubusCoverUrlCache();
      var calls = 0;
      String? lookup(String signature, String? url) => cache.lookup(
            markerId: 'm1',
            signature: signature,
            resolve: () {
              calls += 1;
              return url;
            },
          );
      // Planned before the linked artwork has arrived: no cover yet.
      expect(lookup('no-artwork', null), isNull);
      expect(lookup('no-artwork', null), isNull);
      expect(calls, 1);
      // The artwork hydrates: the answer must be recomputed, not stay empty.
      expect(lookup('artwork-arrived', 'https://x/b.jpg'), 'https://x/b.jpg');
      expect(calls, 2);
    });

    test('a refreshed record with a new cover replaces the old one', () {
      final cache = KubusCoverUrlCache();
      expect(
        cache.lookup(
          markerId: 'm1',
          signature: 'v1',
          resolve: () => 'https://x/old.jpg',
        ),
        'https://x/old.jpg',
      );
      expect(
        cache.lookup(
          markerId: 'm1',
          signature: 'v2',
          resolve: () => 'https://x/new.jpg',
        ),
        'https://x/new.jpg',
      );
    });
  });
}
