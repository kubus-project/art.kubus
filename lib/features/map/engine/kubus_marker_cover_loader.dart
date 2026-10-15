import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../utils/media_failure_registry.dart';
import 'kubus_cover_perf_probe.dart';

/// Remembers which cover URL a marker resolved to, for as long as the data it
/// was resolved from is unchanged.
///
/// Resolving a cover walks several metadata fields, so the answer is cached per
/// marker, including "this marker has no cover". The entry is keyed by a
/// signature of what the resolver reads: artwork hydration is asynchronous (a
/// marker can be planned before its artwork arrives) and refreshed records carry
/// new data, so a cached answer, a missing one above all, must not outlive the
/// data it came from.
class KubusCoverUrlCache {
  final Map<String, ({String signature, String url})> _entries =
      <String, ({String signature, String url})>{};

  /// The cover URL for [markerId], or null when it has none. [resolve] runs only
  /// when nothing is cached for this [signature].
  String? lookup({
    required String markerId,
    required String signature,
    required String? Function() resolve,
  }) {
    final cached = _entries[markerId];
    if (cached != null && cached.signature == signature) {
      return cached.url.isEmpty ? null : cached.url;
    }
    final url = resolve();
    _entries[markerId] = (signature: signature, url: url ?? '');
    return url;
  }

  int get length => _entries.length;
}

/// Fetches one decoded cover image whose shorter side is scaled to roughly
/// [targetPx], subject to a long-edge and pixel ceiling for unusual geometry.
///
/// Returns null when the image cannot be loaded; it must not throw.
typedef KubusCoverFetch = Future<ui.Image?> Function(String url, int targetPx);

/// Bounded, de-duplicated loader for the artwork covers drawn inside close-up
/// map markers.
///
/// Decoded images are keyed by the canonical resolved cover URL *and* the
/// physical size it was decoded to, so markers that resolve to the same media
/// share one decode while a different device pixel ratio never reuses a
/// too-small bitmap.
///
/// It owns the three limits that keep close-up covers cheap:
///
/// * at most [maxCached] decoded images are retained (least recently used is
///   disposed), so texture memory is bounded no matter how long the visitor
///   pans, except that images the caller has pinned ([setPinned]: covers in
///   the active viewport that are not yet drawn into the map) are never
///   evicted before they are used, up to [maxPinned]. Offscreen, stale-size
///   and old-zoom entries are always evicted first;
/// * at most [maxConcurrent] loads run at once and the same URL is never
///   fetched twice while one is in flight. Covers about to be drawn always
///   start before prefetches (`prefetch: true`), and prefetches that have not
///   started can be dropped with [cancelPendingPrefetches] when the view moves
///   on, so stale warm-ups never delay what is on screen;
/// * every successful [load] hands the caller its **own handle**
///   (`Image.clone`), so eviction from the cache can never invalidate an image
///   a caller is still drawing; the caller disposes its handle;
/// * a URL that failed is not retried for [failureRetry], so a broken cover
///   costs one request and the marker simply keeps its canonical badge.
class KubusMarkerCoverLoader {
  KubusMarkerCoverLoader({
    KubusCoverFetch? fetch,
    this.maxCached = 48,
    this.maxPinned = 192,
    this.maxConcurrent = 4,
    this.failureRetry = const Duration(minutes: 5),
    DateTime Function()? now,
  })  : _fetch = fetch ?? _networkFetch,
        _now = now ?? DateTime.now;

  final KubusCoverFetch _fetch;
  final int maxCached;

  /// Most decoded images the caller may keep pinned at once. With a decode
  /// bound of 1 MiB each this caps the pinned working set; pins beyond it are
  /// ignored (those covers can still be re-loaded, just not protected).
  final int maxPinned;
  final int maxConcurrent;
  final Duration failureRetry;
  final DateTime Function() _now;

  final LinkedHashMap<String, ui.Image> _cache =
      LinkedHashMap<String, ui.Image>();
  final Map<String, Future<ui.Image?>> _inFlight =
      <String, Future<ui.Image?>>{};
  final Map<String, DateTime> _failedAt = <String, DateTime>{};
  final Queue<_LoadTicket> _waitingDisplay = Queue<_LoadTicket>();
  final Queue<_LoadTicket> _waitingPrefetch = Queue<_LoadTicket>();
  final Map<String, _LoadTicket> _queuedTickets = <String, _LoadTicket>{};
  int _running = 0;
  bool _disposed = false;

  int get cachedCount => _cache.length;
  int get inFlightCount => _inFlight.length;

  /// Approximate decoded size (RGBA) of the cache, and its high-water marks,
  /// for the performance harness.
  int get cachedBytes =>
      _cache.values.fold<int>(0, (sum, i) => sum + i.width * i.height * 4);
  int peakCachedCount = 0;
  int peakCachedBytes = 0;

  Set<String> _pinned = const <String>{};
  int get pinnedCount => _pinned.length;

  /// Pins the decoded images for [urls] at [targetPx]: they survive eviction
  /// until they are no longer pinned (call again with the current set; an empty
  /// call unpins everything). Only the first [maxPinned] are honoured.
  void setPinned(Iterable<String> urls, {required int targetPx}) {
    _pinned = <String>{
      for (final url in urls.take(maxPinned)) _key(url, targetPx),
    };
    _evictOverflow();
  }

  static String _key(String url, int targetPx) => '$targetPx|$url';

  /// A decoded image for [url] at [targetPx] if one is already held
  /// (refreshes its recency).
  ui.Image? cached(String url, {required int targetPx}) {
    final key = _key(url, targetPx);
    final image = _cache.remove(key);
    if (image == null) return null;
    _cache[key] = image;
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

  /// Loads [url] at [targetPx]. A [prefetch] waits behind every display load
  /// and may be dropped by [cancelPendingPrefetches] before it starts (it then
  /// resolves to null without counting as a failure). A display load for an
  /// image still queued as a prefetch promotes it.
  Future<ui.Image?> load(
    String url, {
    required int targetPx,
    bool prefetch = false,
  }) {
    if (_disposed) return Future<ui.Image?>.value(null);
    final hit = cached(url, targetPx: targetPx);
    if (hit != null) return Future<ui.Image?>.value(hit.clone());
    if (hasFailed(url)) return Future<ui.Image?>.value(null);
    final key = _key(url, targetPx);
    final running = _inFlight[key];
    if (running != null) {
      if (!prefetch) _promote(key);
      return _lend(running);
    }
    final owner = Completer<ui.Image?>();
    _inFlight[key] = owner.future;
    unawaited(_run(url, targetPx, prefetch: prefetch, owner: owner)
        .then(owner.complete, onError: owner.completeError));
    return _lend(owner.future);
  }

  /// A fresh handle on the shared decoded image for one caller.
  Future<ui.Image?> _lend(Future<ui.Image?> shared) =>
      shared.then((image) => image?.clone());

  /// Drops every queued load (display or prefetch) that has not started and
  /// whose image is not in [keepUrls] at [targetPx]. A viewport change calls
  /// this so covers for a view the camera has left never delay (or draw over)
  /// the covers of the new one; a dropped load resolves to null without
  /// counting as a failure. Loads already running finish and stay cached.
  void cancelPendingExcept(Iterable<String> keepUrls, {required int targetPx}) {
    final keep = <String>{for (final url in keepUrls) _key(url, targetPx)};
    for (final queue in [_waitingDisplay, _waitingPrefetch]) {
      for (final ticket in queue.toList()) {
        if (keep.contains(ticket.key)) continue;
        queue.remove(ticket);
        _queuedTickets.remove(ticket.key);
        _inFlight.remove(ticket.key);
        ticket.grant.complete(false);
      }
    }
  }

  /// Drops every prefetch that is still waiting for a slot.
  void cancelPendingPrefetches() {
    while (_waitingPrefetch.isNotEmpty) {
      final ticket = _waitingPrefetch.removeFirst();
      _queuedTickets.remove(ticket.key);
      _inFlight.remove(ticket.key);
      ticket.grant.complete(false);
    }
  }

  void _promote(String key) {
    final ticket = _queuedTickets[key];
    if (ticket == null || !_waitingPrefetch.remove(ticket)) return;
    _waitingDisplay.add(ticket);
  }

  Future<ui.Image?> _run(
    String url,
    int targetPx, {
    required bool prefetch,
    required Completer<ui.Image?> owner,
  }) async {
    final key = _key(url, targetPx);
    var acquired = false;
    try {
      acquired = await _acquire(key, prefetch: prefetch);
      if (!acquired || _disposed) return null;
      ui.Image? image;
      final watch = Stopwatch()..start();
      try {
        image = await _fetch(url, targetPx);
      } catch (_) {
        image = null;
      }
      recordKubusCoverPhase(KubusCoverPhase.fetchDecode, watch.elapsed);
      if (_disposed) {
        image?.dispose();
        return null;
      }
      if (image == null) {
        _failedAt[url] = _now();
        return null;
      }
      _cache[_key(url, targetPx)] = image;
      _evictOverflow(protect: _key(url, targetPx));
      peakCachedCount = math.max(peakCachedCount, _cache.length);
      peakCachedBytes = math.max(peakCachedBytes, cachedBytes);
      recordKubusCoverGauge('peakDecodedCount', peakCachedCount.toDouble());
      recordKubusCoverGauge('peakDecodedBytes', peakCachedBytes.toDouble());
      return image;
    } finally {
      if (identical(_inFlight[key], owner.future)) _inFlight.remove(key);
      if (acquired) _release();
    }
  }

  /// Resolves true once a slot is held, false if the wait was cancelled.
  Future<bool> _acquire(String key, {required bool prefetch}) {
    if (_running < maxConcurrent) {
      _running += 1;
      return Future<bool>.value(true);
    }
    final ticket = _LoadTicket(key);
    _queuedTickets[key] = ticket;
    (prefetch ? _waitingPrefetch : _waitingDisplay).add(ticket);
    return ticket.grant.future;
  }

  void _release() {
    final next = _waitingDisplay.isNotEmpty
        ? _waitingDisplay.removeFirst()
        : (_waitingPrefetch.isNotEmpty ? _waitingPrefetch.removeFirst() : null);
    if (next != null) {
      // Hand the slot straight to the next waiter, display loads first.
      _queuedTickets.remove(next.key);
      next.grant.complete(true);
      return;
    }
    if (_running > 0) _running -= 1;
  }

  void _evictOverflow({String? protect}) {
    // Offscreen / stale entries go first; a pinned (in-view, not yet drawn)
    // image is only ever evicted by an unpinned one's turn having passed.
    while (_cache.length > maxCached) {
      String? victim;
      for (final key in _cache.keys) {
        if (key != protect && !_pinned.contains(key)) {
          victim = key;
          break;
        }
      }
      if (victim == null) return;
      _cache.remove(victim)?.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    for (final ticket in [..._waitingDisplay, ..._waitingPrefetch]) {
      ticket.grant.complete(false);
    }
    _waitingDisplay.clear();
    _waitingPrefetch.clear();
    _queuedTickets.clear();
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _failedAt.clear();
  }

  static Future<ui.Image?> _networkFetch(String url, int targetPx) {
    final provider = _ShortSideResizeImage(NetworkImage(url), targetPx);
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
        // A real load error (not a slow network timing out): other surfaces
        // drawing this media, such as the marker's quick card, skip the
        // request instead of discovering the failure again.
        KubusMediaFailureRegistry.shared.markFailed(url);
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

class _LoadTicket {
  _LoadTicket(this.key);

  final String key;
  final Completer<bool> grant = Completer<bool>();
}

/// Decodes [imageProvider] with a short-side target and absolute long-edge /
/// pixel ceilings. All three bounds use one scale, without upscaling.
class _ShortSideResizeImage extends ImageProvider<_ShortSideKey> {
  const _ShortSideResizeImage(this.imageProvider, this.shortSide);

  final ImageProvider<Object> imageProvider;
  final int shortSide;

  @override
  Future<_ShortSideKey> obtainKey(ImageConfiguration configuration) async =>
      _ShortSideKey(await imageProvider.obtainKey(configuration), shortSide);

  @override
  ImageStreamCompleter loadImage(
    _ShortSideKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeShortSide(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      return decode(
        buffer,
        getTargetSize: (int width, int height) =>
            shortSideTargetSize(width, height, shortSide),
      );
    }

    return imageProvider.loadImage(key.providerKey, decodeShortSide);
  }
}

/// The decode size that brings the shorter of [width] x [height] down to
/// [shortSide], also bounding long edge and pixels while keeping the aspect
/// ratio (within integer rounding); never larger than the source.
@visibleForTesting
ui.TargetImageSize shortSideTargetSize(int width, int height, int shortSide) {
  final scale = math.min(
    1.0,
    math.min(
      shortSide / math.max(1, math.min(width, height)),
      math.min(
        kubusCoverMaxLongEdge / math.max(width, height),
        math.sqrt(kubusCoverMaxDecodedPixels / (width * height)),
      ),
    ),
  );
  if (scale >= 1) return ui.TargetImageSize(width: width, height: height);
  return ui.TargetImageSize(
    width: math.max(1, (width * scale).floor()),
    height: math.max(1, (height * scale).floor()),
  );
}

/// A 44 px marker needs no archival geometry: at most 1 MiB RGBA per
/// decoded cover and 48 MiB for the default cache (excluding GPU copies).
const int kubusCoverMaxLongEdge = 1024;
const int kubusCoverMaxDecodedPixels = 256 * 1024;

@immutable
class _ShortSideKey {
  const _ShortSideKey(this.providerKey, this.shortSide);

  final Object providerKey;
  final int shortSide;

  @override
  bool operator ==(Object other) =>
      other is _ShortSideKey &&
      other.providerKey == providerKey &&
      other.shortSide == shortSide;

  @override
  int get hashCode => Object.hash(providerKey, shortSide);
}
