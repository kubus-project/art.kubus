import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show PlatformDispatcher;

import '../utils/app_animations.dart';
import '../utils/app_color_utils.dart';
import '../utils/kubus_color_roles.dart';
import '../utils/design_tokens.dart';

/// Modern theme provider with multiple theme options and persistence
class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _themeKey = 'app_theme_mode';
  static const String _accentColorKey = 'accent_color';

  ThemeMode _themeMode = ThemeMode.system; // Default to system theme
  Color _accentColor = KubusProductPalette.activeLight;
  bool _isInitialized = false;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreferences();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  // Returns a contrasting text color suitable for accentColor (onAccent).
  // Uses the same WCAG-optimal resolver as the ColorScheme on* pairs so
  // accent foregrounds agree everywhere.
  Color get onAccentColor => AppColorUtils.onColor(_accentColor);

  bool get isInitialized => _isInitialized;

  // Enhanced theme detection that properly handles system mode
  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness ==
            Brightness.dark;
    }
  }

  bool get isLightMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return true;
      case ThemeMode.dark:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness ==
            Brightness.light;
    }
  }

  bool get isSystemMode => _themeMode == ThemeMode.system;

  // Available accent colors: colorful, but still sober enough for the core UI.
  static const List<Color> availableAccentColors = [
    KubusColors.primary,
    Color(0xFF0F4C81), // Deep blue
    Color(0xFF3B6EA5), // Steel blue
    Color(0xFF2F6B4F), // Forest green
    Color(0xFF7A2E2E), // Oxblood
    Color(0xFFB8860B), // Amber gold
    Color(0xFFB85C38), // Terracotta
    Color(0xFF4B5D67), // Slate
    Color(0xFF485A96), // Indigo
  ];

  // Load theme preferences from storage
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme mode
      final themeModeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
      _themeMode = ThemeMode.values[themeModeIndex];

      // Load accent color
      final accentColorValue = prefs.getInt(_accentColorKey) ??
          KubusProductPalette.activeLight.toARGB32();
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
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
        textTheme: KubusTypography.textTheme.apply(
          bodyColor: KubusColors.textPrimaryDark,
          displayColor: KubusColors.textPrimaryDark,
        ),
        pageTransitionsTheme: AppAnimations.pageTransitionsTheme,
        // Structural roles stay fixed. The user's saved accent is provided
        // separately through KubusColorRoles for explicit personal highlights.
        colorScheme: ColorScheme.dark(
          primary: KubusColorRoles.dark.active,
          onPrimary: KubusColorRoles.dark.onActive,
          secondary: KubusColorRoles.dark.active,
          onSecondary: KubusColorRoles.dark.onActive,
          tertiary: KubusColorRoles.dark.active,
          onTertiary: KubusColorRoles.dark.onActive,
          surface: KubusColorRoles.dark.surface,
          onSurface: KubusColorRoles.dark.foreground,
          surfaceTint: Colors.transparent,
          primaryContainer: KubusColorRoles.dark.surfaceRaised,
          onPrimaryContainer: KubusColorRoles.dark.foreground,
          secondaryContainer: KubusColorRoles.dark.surfaceRaised,
          onSecondaryContainer: KubusColorRoles.dark.foreground,
          tertiaryContainer: KubusColorRoles.dark.surfaceRaised,
          onTertiaryContainer: KubusColorRoles.dark.foreground,
          outline: KubusColorRoles.dark.rule,
          outlineVariant: KubusColorRoles.dark.ruleStrong,
          error: KubusColorRoles.dark.error,
          onError: KubusColorRoles.dark.onError,
        ),
        scaffoldBackgroundColor: KubusColorRoles.dark.ground,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          toolbarHeight: KubusHeaderMetrics.actionHitArea +
              (KubusHeaderMetrics.appBarVerticalPadding * 2),
          iconTheme: const IconThemeData(color: KubusColors.textPrimaryDark),
          titleTextStyle: KubusTextStyles.screenTitle.copyWith(
            color: KubusColors.textPrimaryDark,
          ),
        ),
        cardTheme: CardThemeData(
          color: KubusColorRoles.dark.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: KubusRadius.circular(KubusRadius.surface),
            side: const BorderSide(color: KubusProductPalette.ruleDark),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: KubusColorRoles.dark.surfaceRaised,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: KubusRadius.circular(KubusRadius.sheet),
            side: const BorderSide(color: KubusProductPalette.ruleDark),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: KubusColorRoles.dark.surfaceRaised,
          elevation: 0,
          showDragHandle: false,
          shape: RoundedRectangleBorder(
            borderRadius: KubusRadius.circular(KubusRadius.sheet),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: KubusColorRoles.dark.active,
            foregroundColor: KubusColorRoles.dark.onActive,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: KubusRadius.circular(KubusRadius.control),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.lg, vertical: KubusSpacing.sm + 4),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: KubusColorRoles.dark.surface,
          border: OutlineInputBorder(
            borderRadius: KubusRadius.circular(KubusRadius.control),
            borderSide: const BorderSide(color: KubusProductPalette.ruleDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: KubusRadius.circular(KubusRadius.control),
            borderSide: const BorderSide(color: KubusProductPalette.ruleDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: KubusRadius.circular(KubusRadius.control),
            borderSide: const BorderSide(color: KubusProductPalette.focusDark),
          ),
          labelStyle: TextStyle(color: KubusColorRoles.dark.foregroundMuted),
          hintStyle: TextStyle(color: KubusColorRoles.dark.foregroundSubtle),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: KubusColorRoles.dark.surface,
          selectedItemColor: KubusColorRoles.dark.active,
          unselectedItemColor: KubusColorRoles.dark.foregroundSubtle,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        extensions: <ThemeExtension<dynamic>>[
          AppAnimationTheme.defaults,
          KubusColorRoles.dark.copyWith(
            userAccent: _accentColor,
            onUserAccent: onAccentColor,
          ),
        ],
      );

  // Light theme data
  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: KubusTypography.textTheme.apply(
          bodyColor: KubusColors.textPrimaryLight,
          displayColor: KubusColors.textPrimaryLight,
        ),
        pageTransitionsTheme: AppAnimations.pageTransitionsTheme,
        // Light counterpart of the dark semantic roles. Personal accents do
        // not repaint the structural ColorScheme.
        colorScheme: ColorScheme.light(
          primary: KubusColorRoles.light.active,
          onPrimary: KubusColorRoles.light.onActive,
          secondary: KubusColorRoles.light.active,
          onSecondary: KubusColorRoles.light.onActive,
          tertiary: KubusColorRoles.light.active,
          onTertiary: KubusColorRoles.light.onActive,
          surface: KubusColorRoles.light.surface,
          onSurface: KubusColorRoles.light.foreground,
          surfaceTint: Colors.transparent,
          primaryContainer: KubusColorRoles.light.surfaceRaised,
          onPrimaryContainer: KubusColorRoles.light.foreground,
          secondaryContainer: KubusColorRoles.light.surfaceRaised,
          onSecondaryContainer: KubusColorRoles.light.foreground,
          tertiaryContainer: KubusColorRoles.light.surfaceRaised,
          onTertiaryContainer: KubusColorRoles.light.foreground,
          outline: KubusColorRoles.light.rule,
          outlineVariant: KubusColorRoles.light.ruleStrong,
          error: KubusColorRoles.light.error,
          onError: KubusColorRoles.light.onError,
        ),
        scaffoldBackgroundColor: KubusColorRoles.light.ground,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          toolbarHeight: KubusHeaderMetrics.actionHitArea +
              (KubusHeaderMetrics.appBarVerticalPadding * 2),
          iconTheme: const IconThemeData(color: KubusColors.textPrimaryLight),
          titleTextStyle: KubusTextStyles.screenTitle.copyWith(
            color: KubusColors.textPrimaryLight,
          ),
        ),
        cardTheme: CardThemeData(
          color: KubusColorRoles.light.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: KubusRadius.circular(KubusRadius.surface),
            side: const BorderSide(color: KubusProductPalette.ruleLight),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: KubusColorRoles.light.surfaceRaised,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: KubusRadius.circular(KubusRadius.sheet),
            side: const BorderSide(color: KubusProductPalette.ruleLight),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: KubusColorRoles.light.surfaceRaised,
          elevation: 0,
          showDragHandle: false,
          shape: RoundedRectangleBorder(
            borderRadius: KubusRadius.circular(KubusRadius.sheet),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: KubusColorRoles.light.active,
            foregroundColor: KubusColorRoles.light.onActive,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: KubusRadius.circular(KubusRadius.control),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.lg, vertical: KubusSpacing.sm + 4),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: KubusColorRoles.light.surface,
          border: OutlineInputBorder(
            borderRadius: KubusRadius.circular(KubusRadius.control),
            borderSide: const BorderSide(color: KubusProductPalette.ruleLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: KubusRadius.circular(KubusRadius.control),
            borderSide: const BorderSide(color: KubusProductPalette.ruleLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: KubusRadius.circular(KubusRadius.control),
            borderSide: const BorderSide(color: KubusProductPalette.focusLight),
          ),
          labelStyle: TextStyle(color: KubusColorRoles.light.foregroundMuted),
          hintStyle: TextStyle(color: KubusColorRoles.light.foregroundSubtle),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: KubusColorRoles.light.surface,
          selectedItemColor: KubusColorRoles.light.active,
          unselectedItemColor: KubusColorRoles.light.foregroundSubtle,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        extensions: <ThemeExtension<dynamic>>[
          AppAnimationTheme.defaults,
          KubusColorRoles.light.copyWith(
            userAccent: _accentColor,
            onUserAccent: onAccentColor,
          ),
        ],
      );
}
