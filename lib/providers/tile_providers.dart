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
  // Larger buffers to keep adjacent tiles visible while zoom animations settle.
  static const int _defaultKeepBuffer = 18;
  static const int _defaultKeepBufferRetina = 20;
  static const int _defaultPanBuffer = 12;
  static const int _defaultPanBufferRetina = 14;

  final ThemeProvider themeProvider;
  _BufferedTileProvider? _retinaProvider;
  _BufferedTileProvider? _standardProvider;

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

  _BufferedTileProvider _providerFor(bool retinaMode) {
    final _BufferedTileProvider? existing =
        retinaMode ? _retinaProvider : _standardProvider;
    if (existing != null && !existing.isClosed) {
      return existing;
    }

    final _BufferedTileProvider created = _BufferedTileProvider();
    if (retinaMode) {
      _retinaProvider = created;
    } else {
      _standardProvider = created;
    }
    return created;
  }

  TileLayer _buildTileLayer({
    required bool retinaMode,
  }) {
    final ThemeData activeTheme = themeProvider.isDarkMode
        ? themeProvider.darkTheme
        : themeProvider.lightTheme;
    final Color bgColor = activeTheme.colorScheme.surface;
    final _TileBufferConfig buffers = _resolveBufferConfig(retinaMode);

    return TileLayer(
      urlTemplate: _getUrlTemplate(),
      userAgentPackageName: 'dev.art.kubus',
      tileProvider: _providerFor(retinaMode),
      retinaMode: retinaMode,
      subdomains: const ['a', 'b', 'c', 'd'],
      maxNativeZoom: _cartoMaxNativeZoom,
      keepBuffer: buffers.keepBuffer,
      panBuffer: buffers.panBuffer,
      tileUpdateTransformer: TileUpdateTransformers.debounce(const Duration(milliseconds: 120)),
      // Show tiles immediately at their native opacity to avoid flashes between zoom levels.
      tileDisplay: const TileDisplay.instantaneous(),
      tileBuilder: (context, tileWidget, tileImage) {
        // Keep tiles at native scale so camera zoom drives sizing; per-tile scaling introduced visible gaps.
        return ColoredBox(
          color: bgColor,
          child: tileWidget,
        );
      },
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
    _retinaProvider?.dispose();
    _standardProvider?.dispose();
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
  final _TileMemoryCache _memoryCache;
  final Future<TileDiskCache?> _diskCache;
  final Dio _dio;
  bool _closed = false;

  _BufferedTileProvider({int? maxEntries, Future<TileDiskCache?>? diskCache})
      : _memoryCache = _TileMemoryCache(maxEntries ?? _maxEntries),
        _diskCache = diskCache ?? TileDiskCache.create(),
        _dio = Dio(
          BaseOptions(
            // Give tile fetches a bit more room to complete on slower networks before failing.
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
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

    try {
      final requestedUrl = useFallback ? (fallbackUrl ?? '') : url;
      final response = await dioClient.getUri<Uint8List>(
        Uri.parse(requestedUrl),
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );
      final data = response.data!;
      onBytes(data);
      // Persist to disk cache in background; don't block rendering.
      if (cache != null) {
        unawaited(cache.write(url, data));
      }
      final buffer = await ImmutableBuffer.fromUint8List(data);
      return decode(buffer);
    } on DioException {
      if (useFallback || fallbackUrl == null) {
        // If we have cached bytes, use them instead of surfacing an error to the tile renderer.
        final cachedBytes = await cache?.read(url);
        if (cachedBytes != null) {
          final buffer = await ImmutableBuffer.fromUint8List(cachedBytes);
          return decode(buffer);
        }
        rethrow;
      }
      return _load(decode, useFallback: true);
    }
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
