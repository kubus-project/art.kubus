import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show PlatformDispatcher;

import '../utils/app_animations.dart';

/// Modern theme provider with multiple theme options and persistence
class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _themeKey = 'app_theme_mode';
  static const String _accentColorKey = 'accent_color';
  
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark theme
  Color _accentColor = const Color(0xFF00838F); // Deep blue-cyan
  bool _isInitialized = false;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreferences();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  // Returns a contrasting text color suitable for accentColor (onAccent)
  Color get onAccentColor {
    final brightness = ThemeData.estimateBrightnessForColor(_accentColor);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
  bool get isInitialized => _isInitialized;
  
  // Enhanced theme detection that properly handles system mode
  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }
  
  bool get isLightMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return true;
      case ThemeMode.dark:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness == Brightness.light;
    }
  }
  
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // Available accent colors with deep blue-cyan theme
  static const List<Color> availableAccentColors = [
    Color(0xFF00838F), // Deep Blue-Cyan (Primary)
    Color(0xFF0097A7), // Cyan 700
    Color(0xFF00ACC1), // Cyan 600
    Color(0xFF26C6DA), // Cyan 400
    Color(0xFF006064), // Cyan 900 (Darker)
    Color(0xFF00BCD4), // Cyan 500
    Color(0xFF4DD0E1), // Cyan 300
    Color(0xFF0288D1), // Light Blue 700
  ];

  // Load theme preferences from storage
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme mode
      final themeModeIndex = prefs.getInt(_themeKey) ?? 2; // Default to dark
      _themeMode = ThemeMode.values[themeModeIndex];
      
      // Load accent color
      final accentColorValue = prefs.getInt(_accentColorKey) ?? 0xFF00838F;
      _accentColor = Color(accentColorValue);
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Save theme preferences to storage
  Future<void> _saveThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _themeMode.index);
      await prefs.setInt(_accentColorKey, _accentColor.toARGB32());
    } catch (e) {
      debugPrint('Error saving theme preferences: $e');
    }
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode != themeMode) {
      _themeMode = themeMode;
      await _saveThemePreferences();
      notifyListeners();
    }
  }

  // Set accent color
  Future<void> setAccentColor(Color color) async {
    if (_accentColor != color) {
      _accentColor = color;
      await _saveThemePreferences();
      notifyListeners();
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark 
        ? ThemeMode.light 
        : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  // Get current brightness based on theme mode
  Brightness getCurrentBrightness() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness;
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Dark theme data
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    pageTransitionsTheme: AppAnimations.pageTransitionsTheme,
    colorScheme: ColorScheme.dark(
      primary: _accentColor,
      secondary: _accentColor.withValues(alpha: 0.8),
      surface: const Color(0xFF0A0A0A),
      onSurface: Colors.white,
      primaryContainer: const Color(0xFF1A1A1A),
      secondaryContainer: const Color(0xFF2A2A2A),
      outline: Colors.grey[800]!,
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1A1A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[800]!),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentColor),
      ),
      labelStyle: TextStyle(color: Colors.grey[400]),
      hintStyle: TextStyle(color: Colors.grey[600]),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      selectedItemColor: _accentColor,
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppAnimationTheme.defaults,
    ],
  );

  // Light theme data
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    pageTransitionsTheme: AppAnimations.pageTransitionsTheme,
    colorScheme: ColorScheme.light(
      primary: _accentColor,
      secondary: _accentColor.withValues(alpha: 0.8),
      surface: Colors.white,
      onSurface: Colors.black,
      primaryContainer: const Color(0xFFF5F5F7),
      secondaryContainer: const Color(0xFFE5E5EA),
      outline: Colors.grey[300]!,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentColor),
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
      hintStyle: TextStyle(color: Colors.grey[500]),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: _accentColor,
      unselectedItemColor: Colors.grey[500],
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppAnimationTheme.defaults,
    ],
  );
}
