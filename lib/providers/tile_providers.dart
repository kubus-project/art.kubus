import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'dart:ui' show PlatformDispatcher;
import 'themeprovider.dart'; // Import the ThemeProvider

class TileProviders with WidgetsBindingObserver {
  final ThemeProvider themeProvider;

  TileProviders(this.themeProvider) {
    WidgetsBinding.instance.addObserver(this);
    _updateThemeMode();
    themeProvider.addListener(_updateThemeMode); // Listen to theme changes
  }

  @override
  void didChangePlatformBrightness() {
    _updateThemeMode();
  }

  void _updateThemeMode() {
    final brightness = PlatformDispatcher.instance.platformBrightness;
    if (themeProvider.themeMode == ThemeMode.system) {
      Future.microtask(() {
        themeProvider.setThemeMode(brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
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

  TileLayer _buildTileLayer({
    required bool retinaMode,
    required bool withGridOverlay,
  }) {
    return TileLayer(
      urlTemplate: _getUrlTemplate(),
      userAgentPackageName: 'dev.art.kubus',
      tileProvider: CancellableNetworkTileProvider(),
      retinaMode: retinaMode,
      tileBuilder: withGridOverlay
          ? (context, tileWidget, tileImage) {
              final scheme = Theme.of(context).colorScheme;
              final primaryLineColor = scheme.onSurface.withValues(
                alpha: themeProvider.themeMode == ThemeMode.dark ? 0.18 : 0.14,
              );
              final accentColor = primaryLineColor.withValues(
                alpha: themeProvider.themeMode == ThemeMode.dark ? 0.32 : 0.22,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  tileWidget,
                  CustomPaint(
                    painter: _IsoTileOverlayPainter(
                      lineColor: primaryLineColor,
                      accentColor: accentColor,
                      spacing: 96,
                      accentInterval: 4,
                    ),
                  ),
                ],
              );
            }
          : null,
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
    themeProvider.removeListener(_updateThemeMode); // Remove listener
  }
}

class _IsoTileOverlayPainter extends CustomPainter {
  const _IsoTileOverlayPainter({
    required this.lineColor,
    required this.accentColor,
    required this.spacing,
    this.accentInterval = 4,
  });

  final Color lineColor;
  final Color accentColor;
  final double spacing;
  final int accentInterval;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final Paint basePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    final Paint accentPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    final double diagonal = size.width + size.height;
    final int totalLines = (diagonal / spacing).ceil() + 2;

    for (int i = -totalLines; i <= totalLines; i++) {
      final double offset = i * spacing;
      final bool isAccent = accentInterval > 0 && (i % accentInterval == 0);
      final Paint paint = isAccent ? accentPaint : basePaint;

      // Forward slash direction (/)
      canvas.drawLine(
        Offset(offset - diagonal, diagonal),
        Offset(offset + diagonal, -diagonal),
        paint,
      );

      // Backslash direction (\)
      canvas.drawLine(
        Offset(offset - diagonal, -diagonal),
        Offset(offset + diagonal, diagonal),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IsoTileOverlayPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.spacing != spacing;
  }
}