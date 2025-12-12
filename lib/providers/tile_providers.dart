import 'dart:async';
import 'dart:collection';
import 'dart:ui' show PlatformDispatcher, Codec, ImmutableBuffer;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../utils/grid_utils.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'tile_disk_cache.dart';

import 'themeprovider.dart';

class TileProviders with WidgetsBindingObserver {
  static const int _cartoMaxNativeZoom = 20;
  // Keep buffers modest to avoid over-fetching while still retaining nearby tiles.
  static const int _defaultKeepBuffer = 4;
  static const int _defaultKeepBufferRetina = 5;
  static const int _defaultPanBuffer = 2;
  static const int _defaultPanBufferRetina = 3;
  static const Duration _updateThrottle = Duration(milliseconds: 100);

  final ThemeProvider themeProvider;
  _BufferedTileProvider? _sharedProvider;

  TileProviders(this.themeProvider) {
    WidgetsBinding.instance.addObserver(this);
    _updateThemeMode();
    themeProvider.addListener(_updateThemeMode);
  }

  @override
  void didChangePlatformBrightness() {
    _updateThemeMode();
  }

  void _updateThemeMode() {
    final brightness = PlatformDispatcher.instance.platformBrightness;
    if (themeProvider.themeMode == ThemeMode.system) {
      Future.microtask(() {
        themeProvider.setThemeMode(
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        );
      });
    }
  }

  TileLayer getTileLayer() {
    return _buildTileLayer(
      retinaMode: true,
    );
  }

  TileLayer getNonRetinaTileLayer() {
    return _buildTileLayer(
      retinaMode: false,
    );
  }

  /// Snap a map position to the underlying isometric grid for a given grid level.
  /// This delegates to GridUtils so snapping logic remains consistent with the
  /// tile grid rendering.
  LatLng snapToVisibleGrid(LatLng position, double cameraZoom) {
    return GridUtils.snapToVisibleGrid(position, cameraZoom);
  }

  LatLng snapToGrid(LatLng position, double gridLevel) {
    return GridUtils.snapToGrid(position, gridLevel);
  }

  _TileBufferConfig _resolveBufferConfig(bool retinaMode) {
    // Favor predictable buffers to avoid visible tile pruning gaps on fast zooms.
    return retinaMode
        ? const _TileBufferConfig(
            keepBuffer: _defaultKeepBufferRetina,
            panBuffer: _defaultPanBufferRetina,
          )
        : const _TileBufferConfig(
            keepBuffer: _defaultKeepBuffer,
            panBuffer: _defaultPanBuffer,
          );
  }

  _BufferedTileProvider _provider() {
    final _BufferedTileProvider? existing = _sharedProvider;
    if (existing != null && !existing.isClosed) {
      return existing;
    }

    final _BufferedTileProvider created = _BufferedTileProvider();
    _sharedProvider = created;
    return created;
  }

  TileLayer _buildTileLayer({
    required bool retinaMode,
  }) {
    final _TileBufferConfig buffers = _resolveBufferConfig(retinaMode);

    return TileLayer(
      urlTemplate: _getUrlTemplate(),
      userAgentPackageName: 'dev.art.kubus',
      tileProvider: _provider(),
      retinaMode: retinaMode,
      subdomains: const ['a', 'b', 'c', 'd'],
      maxNativeZoom: _cartoMaxNativeZoom,
      maxZoom: _cartoMaxNativeZoom.toDouble(),
      keepBuffer: buffers.keepBuffer,
      panBuffer: buffers.panBuffer,
      tileUpdateTransformer: TileUpdateTransformers.throttle(_updateThrottle),
      tileDisplay: const TileDisplay.fadeIn(
        duration: Duration(milliseconds: 120),
        startOpacity: 0.85,
      ),
    );
  }

  String _getUrlTemplate() {
    switch (themeProvider.themeMode) {
      case ThemeMode.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case ThemeMode.light:
      case ThemeMode.system:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeProvider.removeListener(_updateThemeMode);
    _sharedProvider?.dispose();
  }
}

class _TileBufferConfig {
  final int keepBuffer;
  final int panBuffer;

  const _TileBufferConfig({
    required this.keepBuffer,
    required this.panBuffer,
  });
}

/// In-memory caching tile provider to avoid refetching already downloaded tiles.
/// Extends the cancellable provider so we retain request cancellation on pan/zoom.
base class _BufferedTileProvider extends CancellableNetworkTileProvider {
  static const int _maxEntries = 4096;
  static const Duration _tileConnectTimeout = Duration(seconds: 12);
  static const Duration _tileReceiveTimeout = Duration(seconds: 12);
  static const Duration _tileSendTimeout = Duration(seconds: 10);
  static const int _tileRetries = 2;
  static const Duration _tileRetryDelay = Duration(milliseconds: 200);
  final _TileMemoryCache _memoryCache;
  final Future<TileDiskCache?> _diskCache;
  final Dio _dio;
  bool _closed = false;

  _BufferedTileProvider({int? maxEntries, Future<TileDiskCache?>? diskCache})
      : _memoryCache = _TileMemoryCache(maxEntries ?? _maxEntries),
        _diskCache = diskCache ?? TileDiskCache.create(),
        _dio = Dio(
          BaseOptions(
            // Keep requests snappy so we retry quickly when users are panning/zooming fast.
            connectTimeout: _tileConnectTimeout,
            receiveTimeout: _tileReceiveTimeout,
            // sendTimeout is not supported for GET on web; disable it there.
            sendTimeout: kIsWeb ? null : _tileSendTimeout,
            responseType: ResponseType.bytes,
          ),
        ),
        super(silenceExceptions: true);

  bool get isClosed => _closed;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    if (_closed) {
      return MemoryImage(TileProvider.transparentImage);
    }

    final String url = getTileUrl(coordinates, options);
    final Uint8List? cached = _memoryCache.read(url);
    if (cached != null) {
      return MemoryImage(cached);
    }

    final String? fallback = getTileFallbackUrl(coordinates, options);
    return _CachingNetworkImageProvider(
      url: url,
      fallbackUrl: fallback,
      headers: headers,
      dioClient: _dio,
      cancelLoading: cancelLoading,
      diskCache: _diskCache,
      onBytes: (bytes) => _memoryCache.write(url, bytes),
    );
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _memoryCache.clear();
    _dio.close(force: true);
    return super.dispose();
  }
}

class _TileMemoryCache {
  final int _maxEntries;
  final LinkedHashMap<String, Uint8List> _store = LinkedHashMap<String, Uint8List>();

  _TileMemoryCache(this._maxEntries);

  Uint8List? read(String key) {
    final Uint8List? bytes = _store.remove(key);
    if (bytes != null) {
      _store[key] = bytes;
    }
    return bytes;
  }

  void write(String key, Uint8List bytes) {
    if (_maxEntries > 0 && _store.length >= _maxEntries && _store.isNotEmpty) {
      _store.remove(_store.keys.first);
    }
    _store[key] = bytes;
  }

  void clear() => _store.clear();
}

class _CachingNetworkImageProvider extends ImageProvider<_CachingNetworkImageProvider> {
  final String url;
  final String? fallbackUrl;
  final Map<String, String> headers;
  final Dio dioClient;
  final Future<void> cancelLoading;
  final Future<TileDiskCache?> diskCache;
  final void Function(Uint8List bytes) onBytes;

  const _CachingNetworkImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.headers,
    required this.dioClient,
    required this.cancelLoading,
    required this.diskCache,
    required this.onBytes,
  });

  @override
  ImageStreamCompleter loadImage(
    _CachingNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: url,
    );
  }

  Future<Codec> _load(ImageDecoderCallback decode, {bool useFallback = false}) async {
    final cache = await diskCache;

    if (!useFallback && cache != null) {
      final cachedBytes = await cache.read(url);
      if (cachedBytes != null) {
        onBytes(cachedBytes);
        final buffer = await ImmutableBuffer.fromUint8List(cachedBytes);
        return decode(buffer);
      }
    }

    final String? targetUrl = useFallback ? fallbackUrl : url;
    if (targetUrl == null || targetUrl.isEmpty) {
      // No reachable URL; fall back to cache or a transparent tile to avoid throwing.
      final cachedBytes = await cache?.read(url);
      if (cachedBytes != null) {
        final buffer = await ImmutableBuffer.fromUint8List(cachedBytes);
        return decode(buffer);
      }
      final buffer = await ImmutableBuffer.fromUint8List(TileProvider.transparentImage);
      return decode(buffer);
    }

    try {
      final response = await dioClient.getUri<Uint8List>(
          Uri.parse(targetUrl),
          options: Options(
            headers: headers,
            responseType: ResponseType.bytes,
            sendTimeout: kIsWeb ? null : _BufferedTileProvider._tileSendTimeout,
          ),
        )
            .timeout(_BufferedTileProvider._tileReceiveTimeout);
      final data = response.data!;
      final contentType = response.headers.value('content-type') ?? '';
      if (_isNonImageResponse(contentType, data)) {
        debugPrint('Tile fetch returned non-image content-type="$contentType" for $targetUrl');
        return _fallbackFromCacheOrTransparent(cache, url, decode);
      }
      onBytes(data);
      // Persist to disk cache in background; don't block rendering.
      if (cache != null) {
        unawaited(cache.write(url, data));
      }
      final buffer = await ImmutableBuffer.fromUint8List(data);
      return decode(buffer);
    } on DioException catch (e) {
      debugPrint('Tile fetch failed for $targetUrl (${e.type}); falling back.');
      if (!useFallback && fallbackUrl != null) {
        // Retry against fallback URL after a short delay to improve hit rate while panning quickly.
        await Future.delayed(_BufferedTileProvider._tileRetryDelay);
        return _load(decode, useFallback: true);
      }
      // If we have cached bytes, use them instead of surfacing an error to the tile renderer.
      return _fallbackFromCacheOrTransparent(cache, url, decode);
    } on TimeoutException {
      // Keep UX responsive on timeouts by retrying a limited number of times before falling back.
      for (int attempt = 0; attempt < _BufferedTileProvider._tileRetries; attempt++) {
        try {
          await Future.delayed(_BufferedTileProvider._tileRetryDelay);
          final retryBytes = await dioClient.getUri<Uint8List>(
            Uri.parse(targetUrl),
            options: Options(
              headers: headers,
              responseType: ResponseType.bytes,
              sendTimeout: kIsWeb ? null : _BufferedTileProvider._tileSendTimeout,
            ),
          );
          final data = retryBytes.data!;
          final contentType = retryBytes.headers.value('content-type') ?? '';
          if (_isNonImageResponse(contentType, data)) {
            continue;
          }
          onBytes(data);
          if (cache != null) {
            unawaited(cache.write(url, data));
          }
          final buffer = await ImmutableBuffer.fromUint8List(data);
          return decode(buffer);
        } catch (_) {
          // try next attempt
        }
      }
      return _fallbackFromCacheOrTransparent(cache, url, decode);
    }
  }

  Future<Codec> _fallbackFromCacheOrTransparent(TileDiskCache? cache, String url, ImageDecoderCallback decode) async {
    final cachedBytes = await cache?.read(url);
    if (cachedBytes != null && cachedBytes.isNotEmpty && _looksLikeImageBytes(cachedBytes)) {
      final buffer = await ImmutableBuffer.fromUint8List(cachedBytes);
      return decode(buffer);
    }
    final buffer = await ImmutableBuffer.fromUint8List(TileProvider.transparentImage);
    return decode(buffer);
  }

  bool _isNonImageResponse(String contentType, Uint8List data) {
    final ct = contentType.toLowerCase();
    if (ct.isNotEmpty && ct.startsWith('image/')) return false;
    return !_looksLikeImageBytes(data);
  }

  bool _looksLikeImageBytes(Uint8List data) {
    if (data.length < 4) return false;
    if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) return true; // PNG
    if (data[0] == 0xFF && data[1] == 0xD8) return true; // JPEG
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) return true; // GIF
    if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46) return true; // WebP/RIFF
    return false;
  }

  @override
  SynchronousFuture<_CachingNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachingNetworkImageProvider>(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CachingNetworkImageProvider && url == other.url && fallbackUrl == other.fallbackUrl);

  @override
  int get hashCode => Object.hash(url, fallbackUrl);
}
