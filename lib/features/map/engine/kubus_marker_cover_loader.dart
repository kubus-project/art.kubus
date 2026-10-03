import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Fetches one decoded cover image, already scaled to roughly [targetWidthPx].
///
/// Returns null when the image cannot be loaded; it must not throw.
typedef KubusCoverFetch = Future<ui.Image?> Function(
  String url,
  int targetWidthPx,
);

/// Bounded, de-duplicated loader for the artwork covers drawn inside close-up
/// map markers.
///
/// It owns the three limits that keep close-up covers cheap:
///
/// * at most [maxCached] decoded images are retained (least recently used is
///   disposed), so texture memory is bounded no matter how long the visitor
///   pans;
/// * at most [maxConcurrent] loads run at once and the same URL is never
///   fetched twice while one is in flight;
/// * a URL that failed is not retried for [failureRetry], so a broken cover
///   costs one request and the marker simply keeps its canonical badge.
class KubusMarkerCoverLoader {
  KubusMarkerCoverLoader({
    KubusCoverFetch? fetch,
    this.maxCached = 48,
    this.maxConcurrent = 4,
    this.failureRetry = const Duration(minutes: 5),
    DateTime Function()? now,
  })  : _fetch = fetch ?? _networkFetch,
        _now = now ?? DateTime.now;

  final KubusCoverFetch _fetch;
  final int maxCached;
  final int maxConcurrent;
  final Duration failureRetry;
  final DateTime Function() _now;

  final LinkedHashMap<String, ui.Image> _cache =
      LinkedHashMap<String, ui.Image>();
  final Map<String, Future<ui.Image?>> _inFlight =
      <String, Future<ui.Image?>>{};
  final Map<String, DateTime> _failedAt = <String, DateTime>{};
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  int _running = 0;
  bool _disposed = false;

  int get cachedCount => _cache.length;
  int get inFlightCount => _inFlight.length;

  /// A decoded image for [url] if one is already held (refreshes its recency).
  ui.Image? cached(String url) {
    final image = _cache.remove(url);
    if (image == null) return null;
    _cache[url] = image;
    return image;
  }

  /// Whether [url] failed recently enough that it will not be retried yet.
  bool hasFailed(String url) {
    final at = _failedAt[url];
    if (at == null) return false;
    if (_now().difference(at) >= failureRetry) {
      _failedAt.remove(url);
      return false;
    }
    return true;
  }

  Future<ui.Image?> load(String url, {required int targetWidthPx}) {
    if (_disposed) return Future<ui.Image?>.value(null);
    final hit = cached(url);
    if (hit != null) return Future<ui.Image?>.value(hit);
    if (hasFailed(url)) return Future<ui.Image?>.value(null);
    return _inFlight[url] ??= _run(url, targetWidthPx);
  }

  Future<ui.Image?> _run(String url, int targetWidthPx) async {
    try {
      await _acquire();
      if (_disposed) return null;
      ui.Image? image;
      try {
        image = await _fetch(url, targetWidthPx);
      } catch (_) {
        image = null;
      }
      if (_disposed) {
        image?.dispose();
        return null;
      }
      if (image == null) {
        _failedAt[url] = _now();
        return null;
      }
      _cache[url] = image;
      _evictOverflow();
      return image;
    } finally {
      _inFlight.remove(url);
      _release();
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running += 1;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Hand the slot straight to the next waiter.
      _waiting.removeFirst().complete();
      return;
    }
    if (_running > 0) _running -= 1;
  }

  void _evictOverflow() {
    while (_cache.length > maxCached) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)?.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _failedAt.clear();
  }

  static Future<ui.Image?> _networkFetch(String url, int targetWidthPx) {
    final provider = ResizeImage(NetworkImage(url), width: targetWidthPx);
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image?>();
    late final ImageStreamListener listener;
    void finish(ui.Image? image) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(image);
      } else {
        image?.dispose();
      }
    }

    listener = ImageStreamListener(
      (info, _) => finish(info.image.clone()),
      onError: (Object error, StackTrace? stack) {
        if (kDebugMode) {
          debugPrint('KubusMarkerCoverLoader: cover failed ($error)');
        }
        finish(null);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        finish(null);
        return null;
      },
    );
  }
}
