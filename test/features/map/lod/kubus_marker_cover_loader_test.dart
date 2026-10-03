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
    expect(loader.cached('u'), isNotNull);
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
    loader.cached('a'); // refresh a: b is now the oldest
    await loader.load('c', targetWidthPx: 96);

    expect(loader.cachedCount, 2);
    expect(loader.cached('a'), isNotNull);
    expect(loader.cached('b'), isNull);
    expect(loader.cached('c'), isNotNull);
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

  test('a disposed loader serves nothing', () async {
    final loader =
        KubusMarkerCoverLoader(fetch: (url, width) async => _image());
    loader.dispose();
    expect(await loader.load('x', targetWidthPx: 96), isNull);
  });
}
