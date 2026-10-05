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

    final a = loader.load('https://x/a.jpg', targetPx: 96);
    final b = loader.load('https://x/a.jpg', targetPx: 96);
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

    await loader.load('u', targetPx: 96);
    expect(loader.cached('u', targetPx: 96), isNotNull);
    await loader.load('u', targetPx: 96);
    expect(calls, 1);
  });

  test('pinned (in-view) covers are never evicted before unpinned ones',
      () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 2,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);

    loader.setPinned(['a', 'b'], targetPx: 96);
    await loader.load('a', targetPx: 96);
    await loader.load('b', targetPx: 96);
    await loader.load('c', targetPx: 96); // unpinned: the one that goes
    await loader.load('d', targetPx: 96);

    expect(loader.cached('a', targetPx: 96), isNotNull);
    expect(loader.cached('b', targetPx: 96), isNotNull);
    // A fresh image is never evicted by its own insertion, so the cache may sit
    // one over maxCached until the next load; the pinned two always survive.
    expect(loader.cachedCount, lessThanOrEqualTo(3));
    expect(loader.cached('c', targetPx: 96), isNull);
  });

  test(
      'every in-view cover can be held at once; unpinning makes them evictable',
      () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 2,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);
    final urls = [for (var i = 0; i < 10; i++) 'u$i'];

    loader.setPinned(urls, targetPx: 96);
    for (final url in urls) {
      await loader.load(url, targetPx: 96);
    }
    expect(loader.cachedCount, 10,
        reason: 'not capped by the LRU while pinned');
    expect(loader.peakCachedCount, 10);
    expect(loader.cachedBytes, 10 * 4 * 4 * 4);

    loader.setPinned(const <String>[], targetPx: 96);
    expect(loader.cachedCount, 2, reason: 'offscreen entries evicted first');
  });

  test('pins beyond maxPinned are ignored so memory stays bounded', () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 1,
      maxPinned: 3,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);
    final urls = [for (var i = 0; i < 8; i++) 'u$i'];
    loader.setPinned(urls, targetPx: 96);
    for (final url in urls) {
      await loader.load(url, targetPx: 96);
    }
    expect(loader.pinnedCount, 3);
    expect(loader.cachedCount, lessThanOrEqualTo(3 + 1));
  });

  test('a stale-size pin does not protect another size', () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 1,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);
    loader.setPinned(['a'], targetPx: 96);
    await loader.load('a', targetPx: 160);
    await loader.load('b', targetPx: 160);
    expect(loader.cached('a', targetPx: 160), isNull);
  });

  test('a viewport change cancels queued display loads that are not wanted',
      () async {
    final gate = Completer<void>();
    final fetched = <String>[];
    final loader = KubusMarkerCoverLoader(
      maxConcurrent: 1,
      fetch: (url, width) async {
        fetched.add(url);
        await gate.future;
        return _image();
      },
    );
    addTearDown(loader.dispose);

    final running = loader.load('a', targetPx: 96);
    final stale = loader.load('stale', targetPx: 96);
    final wanted = loader.load('wanted', targetPx: 96);
    loader.cancelPendingExcept(['wanted'], targetPx: 96);
    gate.complete();

    expect(await stale, isNull, reason: 'dropped before it started');
    expect(await running, isNotNull, reason: 'running loads finish');
    expect(await wanted, isNotNull, reason: 'the new view is not starved');
    expect(fetched, ['a', 'wanted']);
    expect(loader.hasFailed('stale'), isFalse,
        reason: 'a cancellation is not a failure');
    // And it can be requested again later.
    expect(await loader.load('stale', targetPx: 96), isNotNull);
  });

  test('a freshly loaded image is never evicted by its own insertion',
      () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 1,
      maxPinned: 1,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);
    loader.setPinned(['a'], targetPx: 96);
    final a = await loader.load('a', targetPx: 96);
    final b = await loader.load('b', targetPx: 96);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(b!.debugDisposed, isFalse);
    expect(loader.cached('b', targetPx: 96), isNotNull);
  });

  test('a caller keeps a valid image after the cache evicts it', () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 1,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);
    final held = await loader.load('a', targetPx: 96);
    await loader.load('b', targetPx: 96);
    await loader.load('c', targetPx: 96);
    expect(loader.cached('a', targetPx: 96), isNull);
    expect(held!.debugDisposed, isFalse);
    expect(held.width, 4);
    held.dispose();
  });

  test('keeps at most maxCached images, dropping the least recently used',
      () async {
    final loader = KubusMarkerCoverLoader(
      maxCached: 2,
      fetch: (url, width) async => _image(),
    );
    addTearDown(loader.dispose);

    await loader.load('a', targetPx: 96);
    await loader.load('b', targetPx: 96);
    loader.cached('a', targetPx: 96); // refresh a: b is now the oldest
    await loader.load('c', targetPx: 96);

    expect(loader.cachedCount, 2);
    expect(loader.cached('a', targetPx: 96), isNotNull);
    expect(loader.cached('b', targetPx: 96), isNull);
    expect(loader.cached('c', targetPx: 96), isNotNull);
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
      for (var i = 0; i < 5; i++) loader.load('u$i', targetPx: 96),
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

  group('display covers before prefetches', () {
    late List<String> started;
    late Map<String, Completer<void>> gates;
    late KubusMarkerCoverLoader loader;

    setUp(() {
      started = <String>[];
      gates = <String, Completer<void>>{};
      loader = KubusMarkerCoverLoader(
        maxConcurrent: 1,
        fetch: (url, width) async {
          started.add(url);
          final gate = gates[url] = Completer<void>();
          await gate.future;
          return _image();
        },
      );
    });
    tearDown(() => loader.dispose());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('a display load starts before queued prefetches', () async {
      unawaited(loader.load('busy', targetPx: 96));
      await settle();
      final p1 = loader.load('p1', targetPx: 96, prefetch: true);
      final p2 = loader.load('p2', targetPx: 96, prefetch: true);
      final shown = loader.load('shown', targetPx: 96);
      gates['busy']!.complete();
      await settle();
      expect(started, <String>['busy', 'shown']);
      gates['shown']!.complete();
      expect(await shown, isNotNull);
      await settle();
      gates['p1']!.complete();
      await settle();
      gates['p2']!.complete();
      expect(await p1, isNotNull);
      expect(await p2, isNotNull);
    });

    test('cancelled prefetches never fetch and never count as failures',
        () async {
      unawaited(loader.load('busy', targetPx: 96));
      await settle();
      final stale = loader.load('stale', targetPx: 96, prefetch: true);
      loader.cancelPendingPrefetches();
      expect(await stale, isNull);
      expect(loader.hasFailed('stale'), isFalse);
      gates['busy']!.complete();
      await settle();
      expect(started, <String>['busy']);
      // The slot is free again: a new load starts at once.
      unawaited(loader.load('next', targetPx: 96));
      await settle();
      expect(started, <String>['busy', 'next']);
      gates['next']!.complete();
    });

    test('replacement plan immediately requeues a cancelled cover', () async {
      final busy = loader.load('busy', targetPx: 96);
      await settle();
      final stale = loader.load('x', targetPx: 96, prefetch: true);
      loader.cancelPendingPrefetches();
      final replacement = loader.load('x', targetPx: 96, prefetch: true);
      expect(identical(stale, replacement), isFalse);
      expect(await stale, isNull);
      // The old task's finally has run, but must not erase the new owner.
      expect(loader.inFlightCount, 2);
      unawaited(loader.load('x', targetPx: 96)); // joins, never re-fetches
      loader.cancelPendingPrefetches(); // promoted replacement survives
      gates['busy']!.complete();
      await busy;
      await settle();
      expect(started, ['busy', 'x']);
      unawaited(loader.load('x', targetPx: 96)); // joins, never re-fetches
      gates['x']!.complete();
      expect(await replacement, isNotNull);
      expect(started.where((url) => url == 'x').length, 1);
      expect(loader.inFlightCount, 0);
    });

    test('a display load promotes a queued prefetch of the same image',
        () async {
      unawaited(loader.load('busy', targetPx: 96));
      await settle();
      final warm = loader.load('a', targetPx: 96, prefetch: true);
      unawaited(loader.load('other', targetPx: 96, prefetch: true));
      final shown = loader.load('a', targetPx: 96);
      loader.cancelPendingPrefetches();
      gates['busy']!.complete();
      await settle();
      expect(started, <String>['busy', 'a']);
      gates['a']!.complete();
      expect(await shown, isNotNull);
      expect(await warm, isNotNull);
    });
  });

  test('covers decode to their shorter side, never upscaled', () {
    final landscape = shortSideTargetSize(1600, 900, 160);
    expect(landscape.height, 160);
    expect(landscape.width, 284);
    final portrait = shortSideTargetSize(900, 1600, 160);
    expect(portrait.width, 160);
    expect(portrait.height, 284);
    final small = shortSideTargetSize(120, 80, 160);
    expect(small.width, 120);
    expect(small.height, 80);
  });

  test('decode geometry bounds panoramas, portraits and decoded pixels', () {
    for (final source in [
      (16000, 100),
      (16000, 500),
      (100, 16000),
      (500, 16000),
      (16000, 16000),
      (4000, 2000),
      (2000, 4000),
      (1, 16000),
    ]) {
      final size = shortSideTargetSize(source.$1, source.$2, 256);
      final width = size.width!;
      final height = size.height!;
      expect(width, lessThanOrEqualTo(kubusCoverMaxLongEdge));
      expect(height, lessThanOrEqualTo(kubusCoverMaxLongEdge));
      expect(width * height, lessThanOrEqualTo(kubusCoverMaxDecodedPixels));
      expect(width, lessThanOrEqualTo(source.$1));
      expect(height, lessThanOrEqualTo(source.$2));
      // Integer decode dimensions preserve the ratio within one pixel.
      expect((width - height * source.$1 / source.$2).abs(),
          lessThanOrEqualTo(1 + source.$1 / source.$2));
    }
    expect(48 * kubusCoverMaxDecodedPixels * 4, 48 * 1024 * 1024);
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

    expect(await loader.load('bad', targetPx: 96), isNull);
    expect(loader.hasFailed('bad'), isTrue);
    expect(await loader.load('bad', targetPx: 96), isNull);
    expect(calls, 1);

    now = now.add(const Duration(minutes: 6));
    expect(loader.hasFailed('bad'), isFalse);
    await loader.load('bad', targetPx: 96);
    expect(calls, 2);
  });

  test('a throwing fetch counts as a failure, never an exception', () async {
    final loader = KubusMarkerCoverLoader(
      fetch: (url, width) async => throw StateError('boom'),
    );
    addTearDown(loader.dispose);

    expect(await loader.load('x', targetPx: 96), isNull);
    expect(loader.hasFailed('x'), isTrue);
  });

  test('the same URL at another size is a separate decode', () async {
    final widths = <int>[];
    final loader = KubusMarkerCoverLoader(fetch: (url, width) async {
      widths.add(width);
      return _image();
    });
    addTearDown(loader.dispose);

    await loader.load('u', targetPx: 96);
    await loader.load('u', targetPx: 96);
    await loader.load('u', targetPx: 160);
    expect(widths, <int>[96, 160]);
    expect(loader.cached('u', targetPx: 160), isNotNull);
    expect(loader.cached('u', targetPx: 224), isNull);
  });

  test('a disposed loader serves nothing', () async {
    final loader =
        KubusMarkerCoverLoader(fetch: (url, width) async => _image());
    loader.dispose();
    expect(await loader.load('x', targetPx: 96), isNull);
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
