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
        themeProvider.setTheme(brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
      });
    }
  }

  TileLayer getTileLayer() {
    return TileLayer(
      urlTemplate: _getUrlTemplate(),
      userAgentPackageName: 'dev.art.kubus',
      tileProvider: CancellableNetworkTileProvider(),
      retinaMode: true,
    );
  }

  TileLayer getNonRetinaTileLayer() {
    return TileLayer(
      urlTemplate: _getUrlTemplate(),
      userAgentPackageName: 'dev.art.kubus',
      tileProvider: CancellableNetworkTileProvider(),
      retinaMode: false,
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