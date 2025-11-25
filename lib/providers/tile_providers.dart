import 'dart:math' as math;
import 'dart:ui' show FilterQuality, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../utils/grid_utils.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'themeprovider.dart';

class TileProviders with WidgetsBindingObserver {
  static const double _tileOverlapScale = 1.012;
  static const int _cartoMaxNativeZoom = 20;
  static const Duration _tileFadeDuration = Duration(milliseconds: 140);

  final ThemeProvider themeProvider;

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

  TileLayer getTileLayer({bool withGridOverlay = false}) {
    return _buildTileLayer(
      retinaMode: true,
      withGridOverlay: withGridOverlay,
    );
  }

  TileLayer getNonRetinaTileLayer({bool withGridOverlay = false}) {
    return _buildTileLayer(
      retinaMode: false,
      withGridOverlay: withGridOverlay,
    );
  }

  /// Snap a map position to the underlying isometric grid for a given grid level.
  /// This delegates to GridUtils so snapping logic remains consistent with the
  /// tile grid rendering.
  LatLng snapToGrid(LatLng position, double gridLevel) {
    return GridUtils.snapToGrid(position, gridLevel);
  }

  TileLayer _buildTileLayer({
    required bool retinaMode,
    required bool withGridOverlay,
  }) {
    final ThemeData activeTheme = themeProvider.isDarkMode
        ? themeProvider.darkTheme
        : themeProvider.lightTheme;
    final Color bgColor = activeTheme.colorScheme.surface;

    return TileLayer(
      urlTemplate: _getUrlTemplate(),
      userAgentPackageName: 'dev.art.kubus',
      tileProvider: CancellableNetworkTileProvider(),
      retinaMode: retinaMode,
      subdomains: const ['a', 'b', 'c', 'd'],
      maxNativeZoom: _cartoMaxNativeZoom,
      keepBuffer: 6,
      panBuffer: 3,
      tileDisplay: const TileDisplay.fadeIn(
        duration: _tileFadeDuration,
      ),
      tileBuilder: (context, tileWidget, tileImage) {
        // Apply scale only to the image to prevent gaps, but NOT to the grid
        final Widget imageLayer = Transform.scale(
          scale: _tileOverlapScale,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          child: tileWidget,
        );

        if (!withGridOverlay) {
          return ColoredBox(color: bgColor, child: imageLayer);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: bgColor, child: imageLayer),
            _TileGridOverlay(
              x: tileImage.coordinates.x,
              y: tileImage.coordinates.y,
              z: tileImage.coordinates.z,
              themeProvider: themeProvider,
            ),
          ],
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
  }
}

class _TileGridOverlay extends StatelessWidget {
  final int x;
  final int y;
  final int z;
  final ThemeProvider themeProvider;

  const _TileGridOverlay({
    required this.x,
    required this.y,
    required this.z,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.maybeOf(context);
    final double cameraZoom = camera?.zoom ?? z.toDouble();
    
    if (cameraZoom.isNaN || cameraZoom.isInfinite) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double baseAlphaFraction =
        themeProvider.themeMode == ThemeMode.dark ? 0.08 : 0.06;
    final int baseAlpha = (255 * baseAlphaFraction).clamp(0.0, 255.0).round();
    final Color primaryLineColor = scheme.onSurface.withAlpha(baseAlpha);

    return CustomPaint(
      painter: _RecursiveIsoGridPainter(
        lineColor: primaryLineColor,
        tileX: x,
        tileY: y,
        tileZ: z,
        cameraZoom: cameraZoom,
      ),
    );
  }
}

class _RecursiveIsoGridPainter extends CustomPainter {
  final Color lineColor;
  final int tileX;
  final int tileY;
  final int tileZ;
  final double cameraZoom;

  _RecursiveIsoGridPainter({
    required this.lineColor,
    required this.tileX,
    required this.tileY,
    required this.tileZ,
    required this.cameraZoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cameraZoom.isNaN || cameraZoom.isInfinite) return;

    // Use the actual tile size for calculations to ensure alignment
    final double tileSize = size.width;
    
    // Iterate grid levels L.
    // L represents the zoom level where the grid cells are 1 tile size (256px) wide.
    // We want to show grids that are roughly 20px to 400px on screen.
    // Screen spacing = tileSize * 2^(cameraZoom - L)
    
    final List<_GridLevel> levels = _resolveGridLevels(cameraZoom);

    for (final level in levels) {
      final double screenSpacing = tileSize * math.pow(2, cameraZoom - level.zoomLevel);
      if (_shouldSkipSpacing(screenSpacing)) continue;

      final double baseOpacity = _opacityForSpacing(screenSpacing) * level.intensity;
      if (baseOpacity <= 0.01) continue;

      final double drawSpacing = tileSize * math.pow(2, tileZ - level.zoomLevel);
      if (drawSpacing <= 0.1) continue;

      double strokeWidth = level.zoomLevel < cameraZoom
          ? 1.5 + (cameraZoom - level.zoomLevel) * 0.35
          : 1.0;
      strokeWidth = strokeWidth.clamp(0.5, 3.0);

        final double dynamicAlpha =
          (lineColor.a * 255.0 * baseOpacity).clamp(0.0, 255.0);
      final Paint paint = Paint()
        ..color = lineColor.withAlpha(dynamicAlpha.round())
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final double phaseX = -tileX * tileSize;
      final double phaseY = -tileY * tileSize;

      _drawDiamonds(
        canvas: canvas,
        size: size,
        spacing: drawSpacing,
        paint: paint,
        sumPhase: _positiveMod(phaseX + phaseY, drawSpacing),
        diffPhase: _positiveMod(phaseX - phaseY, drawSpacing),
      );
    }
  }

  bool _shouldSkipSpacing(double spacing) {
    return spacing.isNaN || spacing.isInfinite || spacing < 14 || spacing > 420;
  }

  double _opacityForSpacing(double spacing) {
    if (spacing < 24) return 0.0;
    if (spacing < 48) return (spacing - 24) / 24;
    if (spacing < 180) return 1.0;
    if (spacing < 360) return 1.0 - (spacing - 180) / 180;
    return 0.0;
  }

  List<_GridLevel> _resolveGridLevels(double zoom) {
    final int primary = (zoom + 1.5).floor();
    final int secondary = primary - 3;
    final List<_GridLevel> levels = [
      _GridLevel(zoomLevel: primary, intensity: 1.0),
    ];

    if (secondary >= 0) {
      levels.add(_GridLevel(zoomLevel: secondary, intensity: 0.35));
    }

    return levels;
  }

  double _positiveMod(double value, double modulus) {
    final double result = value % modulus;
    return result < 0 ? result + modulus : result;
  }

  void _drawDiamonds({
    required Canvas canvas,
    required Size size,
    required double spacing,
    required Paint paint,
    required double sumPhase,
    required double diffPhase,
  }) {
    if (spacing <= 0.1) return;
    
    final double diagonal = size.width + size.height;
    final int count = (diagonal / spacing).ceil() + 2;
    
    // Draw Sum lines ( / )
    for (int i = -count; i <= count; i++) {
      final double offset = i * spacing + sumPhase;
      // Line: x + y = offset
      // Intersects (0, offset) and (offset, 0)
      // We draw a long line perpendicular to x=y
      
      // Start point: x=0, y=offset
      // End point: x=offset, y=0
      // But we want to cover the tile.
      // The line direction is (-1, 1) for x+y=c? No.
      // x+y=c => y = -x + c. Slope -1.
      // Vector (1, -1).
      
      // We can just draw from (offset - size.height, size.height) to (offset, 0)
      // At y=size.height, x = offset - size.height.
      // At y=0, x = offset.
      
      canvas.drawLine(
        Offset(offset - size.height, size.height),
        Offset(offset, 0),
        paint,
      );
    }

    // Draw Diff lines ( \ )
    // x - y = offset => y = x - offset. Slope 1.
    for (int i = -count; i <= count; i++) {
      final double offset = i * spacing + diffPhase;
      // At y=0, x=offset.
      // At y=size.height, x=offset + size.height.
      
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecursiveIsoGridPainter oldDelegate) {
    return oldDelegate.tileX != tileX ||
        oldDelegate.tileY != tileY ||
        oldDelegate.tileZ != tileZ ||
        oldDelegate.cameraZoom != cameraZoom ||
        oldDelegate.lineColor != lineColor;
  }
}

class _GridLevel {
  final int zoomLevel;
  final double intensity;

  const _GridLevel({required this.zoomLevel, required this.intensity});
}
