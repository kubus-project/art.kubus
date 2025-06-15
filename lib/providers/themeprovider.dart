import 'package:flutter/material.dart';
import 'dart:ui' show PlatformDispatcher;

class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _updateThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    _updateThemeMode();
  }
  void _updateThemeMode() {
    if (_themeMode == ThemeMode.system) {
      final brightness = PlatformDispatcher.instance.platformBrightness;
      setTheme(brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}