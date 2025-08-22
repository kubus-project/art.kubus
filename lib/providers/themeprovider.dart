import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show PlatformDispatcher;

/// Modern theme provider with multiple theme options and persistence
class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _themeKey = 'app_theme_mode';
  static const String _accentColorKey = 'accent_color';
  
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark theme
  Color _accentColor = const Color(0xFF6C63FF);
  bool _isInitialized = false;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreferences();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // Available accent colors
  static const List<Color> availableAccentColors = [
    Color(0xFF6C63FF), // Primary Purple
    Color(0xFF00D4AA), // Teal
    Color(0xFFFFD93D), // Yellow
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Cyan
    Color(0xFFFFBE0B), // Orange
    Color(0xFF8B5CF6), // Violet
  ];

  // Load theme preferences from storage
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme mode
      final themeModeIndex = prefs.getInt(_themeKey) ?? 2; // Default to dark
      _themeMode = ThemeMode.values[themeModeIndex];
      
      // Load accent color
      final accentColorValue = prefs.getInt(_accentColorKey) ?? 0xFF6C63FF;
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
      await prefs.setInt(_accentColorKey, _accentColor.value);
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
    colorScheme: ColorScheme.dark(
      primary: _accentColor,
      secondary: _accentColor.withOpacity(0.8),
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
  );

  // Light theme data
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _accentColor,
      secondary: _accentColor.withOpacity(0.8),
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
      shadowColor: Colors.black.withOpacity(0.1),
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
  );
}