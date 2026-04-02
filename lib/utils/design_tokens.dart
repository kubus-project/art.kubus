import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central source of truth for all Kubus design tokens.
/// This file defines the palette, spacing, radii, and typography to be used across the app.

class KubusColors {
  // Private constructor to prevent instantiation
  KubusColors._();

  // --- Brand Colors (Primary) ---
  static const Color primary = Color(0xFF00838F); // Deep Blue-Cyan
  static const Color primaryVariantLight = Color(0xFF0097A7);
  static const Color primaryVariantDark = Color(0xFF00ACC1); // Cyan 600

  // --- Glass & Overlay ---
  static const Color glassLight = Color(0x99FFFFFF); // 60% White
  static const Color glassDark = Color(0xCC1A1A1A); // 80% Dark Grey
  static const Color glassBorderLight = Color(0x40FFFFFF);
  static const Color glassBorderDark = Color(0x40000000);

  // --- Secondary / Accents ---
  static const Color secondary = Color(0xCC00838F); // 80% opacity primary

  // --- Extended Accents (Centralized; avoid per-widget Color literals) ---
  static const Color accentOrangeDark = Color(0xFFFF9800);
  static const Color accentOrangeLight = Color(0xFFFB8C00);
  static const Color accentTealDark = Color(0xFF4ECDC4);
  static const Color accentTealLight = Color(0xFF00897B);
  static const Color achievementGoldDark = Color(0xFFFFD700);
  static const Color achievementGoldLight = Color(0xFFFFC107);
  static const Color accentBlue = Color(0xFF2979FF);

  // --- Semantic Colors ---
  static const Color error = Color(0xFFE53935); // Red 600
  static const Color errorDark = Color(0xFFFF6B6B); // Coral Red

  static const Color success = Color(0xFF43A047); // Green 600
  static const Color successDark = Color(0xFF4CAF50); // Green 500

  static const Color warning = Color(0xFFFFA000); // Amber 700
  static const Color warningDark = Color(0xFFFFB300); // Amber 600

  // --- Neutrals (Backgrounds & Surfaces) ---
  static const Color backgroundLight = Color(0xFFF8F9FA); // Off-white
  static const Color backgroundDark = Color(0xFF0A0A0A); // Deep black

  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceDark = Color(0xFF1A1A1A); // Dark grey

  static const Color outlineLight = Color(0xFFE0E0E0); // Grey 300
  static const Color outlineDark = Color(0xFF424242); // Grey 800

  // --- Text Colors ---
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  static const Color textSecondaryLight = Color(0xFF757575); // Grey 600
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Grey 400
}

class KubusSpacing {
  KubusSpacing._();

  /// 0.0
  static const double none = 0.0;

  /// 2.0 - Tiny offsets
  static const double xxs = 2.0;

  /// 4.0 - Tight grouping
  static const double xs = 4.0;

  /// 8.0 - Standard inner spacing
  static const double sm = 8.0;

  /// 16.0 - Standard padding/margin
  static const double md = 16.0;

  /// 24.0 - Section separation
  static const double lg = 24.0;

  /// 32.0 - Major separation
  static const double xl = 32.0;

  /// 48.0 - Hero or large separation
  static const double xxl = 48.0;
}

class KubusRadius {
  KubusRadius._();

  /// 4.0 - Small inner elements
  static const double xs = 4.0;

  /// 8.0 - Buttons, Inputs
  static const double sm = 8.0;

  /// 12.0 - Cards, Dialogs standard
  static const double md = 12.0;

  /// 16.0 - Large Containers, bottom sheets
  static const double lg = 16.0;

  /// 24.0 - Pills, large rounded edges
  static const double xl = 24.0;

  /// Returns a circular border radius for a given value
  static BorderRadius circular(double radius) => BorderRadius.circular(radius);
}

/// Shared layout constants that need to stay consistent across screens.
class KubusLayout {
  KubusLayout._();

  /// Approximate height of the app's custom bottom navigation bar (excluding
  /// the device safe-area inset).
  ///
  /// Used to keep bottom-anchored UI (FABs, draggable sheets, overlays) above
  /// the navbar when the root Scaffold uses `extendBody: true`.
  static const double mainBottomNavBarHeight = 64.0;
}

/// Shared component sizing tokens.
///
/// Use these instead of hardcoding magic numbers in widgets.
class KubusSizes {
  KubusSizes._();

  /// Compact icon container used in action sidebars.
  static const double sidebarActionIconBox = 40.0;

  /// Icon size inside [sidebarActionIconBox].
  static const double sidebarActionIcon = 20.0;

  /// Trailing chevron icon size used in list tiles.
  static const double trailingChevron = 16.0;

  /// Small badge label size without changing typography tokens.
  ///
  /// Prefer [KubusTypography.textTheme.labelSmall] where possible; this exists
  /// for compact count badges that must stay readable.
  static const double badgeCountFontSize = 11.0;

  /// Hairline borders used on glass surfaces.
  static const double hairline = 1.0;

  /// Common max widths for modal/dialog content.
  static const double dialogWidthMd = 420.0;
  static const double dialogWidthLg = 520.0;
}

/// Canonical sizing for screen headers, app bars, and section chrome.
class KubusHeaderMetrics {
  KubusHeaderMetrics._();

  static const double mobileAppBarTitle = 18.0;
  static const double screenTitle = 20.0;
  static const double screenSubtitle = 14.0;
  static const double sectionTitle = 16.0;
  static const double sectionSubtitle = 13.0;
  static const double actionIcon = 20.0;
  static const double actionHitArea = 44.0;
  static const double headerMinHeight = 56.0;
  static const double compactLogo = 36.0;
  static const double logo = 40.0;
  static const double searchBarHeight = 48.0;
  static const double compactHeaderMinHeight = 48.0;
  static const double subtitleGap = KubusSpacing.xs;
  static const double sectionSubtitleGap = 2.0;
  static const double appBarVerticalPadding = KubusSpacing.sm;
  static const double appBarHorizontalPadding = KubusSpacing.md;
  static const double appBarHorizontalPaddingLg = KubusSpacing.lg;
}

/// Shared metrics for body chrome that sits below the main app bar/header.
class KubusChromeMetrics {
  KubusChromeMetrics._();

  static const double cardPadding = 20.0;
  static const double compactCardPadding = 16.0;
  static const double statValue = 24.0;
  static const double statLabel = 13.0;
  static const double statChange = 12.0;
  static const double heroTitle = 24.0;
  static const double heroSubtitle = 14.0;
  static const double heroIconBox = 56.0;
  static const double heroIcon = 28.0;
  static const double sheetTitle = 20.0;
  static const double sheetSubtitle = 14.0;
  static const double sheetHandleWidth = 40.0;
  static const double sheetHandleHeight = 4.0;
  static const double navLabel = 14.0;
  static const double navMetaLabel = 12.0;
  static const double navIcon = 24.0;
  static const double navCompactIcon = 20.0;
  static const double navBadgeDot = 8.0;
  static const double navBadgeLabel = 9.0;
  static const double railExpandedLogo = 32.0;
  static const double railCompactLogo = 28.0;
  static const double profileName = 14.0;
  static const double profileHandle = 12.0;
}

class KubusTypography {
  KubusTypography._();

  /// Backward-compatible shortcut for creating an Inter [TextStyle].
  ///
  /// Prefer [KubusTypography.textTheme] (and [KubusTextStyles]) for most UI,
  /// but keep this helper to avoid breaking older screens.
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme get textTheme {
    // Important: build a color-agnostic text theme so it can inherit the active
    // ThemeData text colors (fixes dark-mode regressions where GoogleFonts
    // defaults to light theme colors).
    return GoogleFonts.interTextTheme(const TextTheme()).copyWith(
      displayLarge:
          GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 32),
      displayMedium:
          GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 28),
      displaySmall:
          GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24),
      headlineMedium:
          GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
      headlineSmall:
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 16),
      bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
      labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10),
    );
  }
}

/// App-specific semantic text styles built on top of [KubusTypography].
///
/// Prefer these for UI elements that need consistent weights/sizing without
/// sprinkling `copyWith(fontWeight: ...)` across the codebase.
class KubusTextStyles {
  KubusTextStyles._();

  static TextStyle get mobileAppBarTitle =>
      screenTitle.copyWith(fontSize: KubusHeaderMetrics.mobileAppBarTitle);

  static TextStyle get screenTitle =>
      KubusTypography.textTheme.headlineMedium!.copyWith(
        fontSize: KubusHeaderMetrics.screenTitle,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get screenSubtitle =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        fontSize: KubusHeaderMetrics.screenSubtitle,
        fontWeight: FontWeight.w500,
        height: 1.45,
      );

  static TextStyle get sectionTitle =>
      KubusTypography.textTheme.titleMedium!.copyWith(
        fontSize: KubusHeaderMetrics.sectionTitle,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get sectionSubtitle =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        fontSize: KubusHeaderMetrics.sectionSubtitle,
        fontWeight: FontWeight.w400,
        height: 1.35,
      );

  static TextStyle get actionTileTitle => KubusTypography.textTheme.labelLarge!;

  static TextStyle get actionTileSubtitle =>
      KubusTypography.textTheme.labelMedium!;

  static TextStyle get badgeCount => GoogleFonts.inter(
        fontSize: KubusSizes.badgeCountFontSize,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get compactBadge => GoogleFonts.inter(
        fontSize: KubusChromeMetrics.navBadgeLabel,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get heroTitle =>
      KubusTypography.textTheme.displaySmall!.copyWith(
        fontSize: KubusChromeMetrics.heroTitle,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get heroSubtitle =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        fontSize: KubusChromeMetrics.heroSubtitle,
        fontWeight: FontWeight.w500,
        height: 1.45,
      );

  static TextStyle get statValue =>
      KubusTypography.textTheme.displaySmall!.copyWith(
        fontSize: KubusChromeMetrics.statValue,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get statLabel =>
      KubusTypography.textTheme.labelMedium!.copyWith(
        fontSize: KubusChromeMetrics.statLabel,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get statChange =>
      KubusTypography.textTheme.labelMedium!.copyWith(
        fontSize: KubusChromeMetrics.statChange,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get sheetTitle =>
      KubusTypography.textTheme.headlineMedium!.copyWith(
        fontSize: KubusChromeMetrics.sheetTitle,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get sheetSubtitle =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        fontSize: KubusChromeMetrics.sheetSubtitle,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get navLabel =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        fontSize: KubusChromeMetrics.navLabel,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get navMetaLabel =>
      KubusTypography.textTheme.labelMedium!.copyWith(
        fontSize: KubusChromeMetrics.navMetaLabel,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get profileName =>
      KubusTypography.textTheme.labelLarge!.copyWith(
        fontSize: KubusChromeMetrics.profileName,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get profileHandle =>
      KubusTypography.textTheme.labelMedium!.copyWith(
        fontSize: KubusChromeMetrics.profileHandle,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get detailScreenTitle => screenTitle;

  static TextStyle get detailSectionTitle =>
      sectionTitle.copyWith(fontWeight: FontWeight.w700);

  static TextStyle get detailCardTitle =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get detailBody =>
      KubusTypography.textTheme.bodyMedium!.copyWith(
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get detailCaption =>
      screenSubtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w400);

  static TextStyle get detailLabel =>
      KubusTypography.textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w500,
      );

  static TextStyle get detailButton =>
      KubusTypography.textTheme.labelLarge!.copyWith(
        fontWeight: FontWeight.w600,
      );
}

class KubusGradients {
  KubusGradients._();

  /// Builds a smooth 3-stop gradient from two endpoint colors.
  ///
  /// This is used by auth/onboarding surfaces where we want a subtle midpoint
  /// highlight without hardcoding a third color.
  static LinearGradient fromColors(
    Color start,
    Color end, {
    Alignment begin = Alignment.topLeft,
    Alignment finish = Alignment.bottomRight,
    double midStop = 0.7,
    double midT = 0.6,
  }) {
    final mid = Color.lerp(start, end, midT) ?? end;
    return LinearGradient(
      begin: begin,
      end: finish,
      colors: [start, mid, end],
      stops: [0.0, midStop, 1.0],
    );
  }

  static const LinearGradient primary = LinearGradient(
    colors: [KubusColors.primary, KubusColors.primaryVariantDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glass(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return LinearGradient(
        colors: [
          KubusColors.surfaceDark.withValues(alpha: 0.7),
          KubusColors.surfaceDark.withValues(alpha: 0.3),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [
          KubusColors.surfaceLight.withValues(alpha: 0.8),
          KubusColors.surfaceLight.withValues(alpha: 0.4),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  static const LinearGradient darkBackground = LinearGradient(
    colors: [
      Color(0xFF05070A), // Near-black
      Color(0xFF0B1D33), // Deep navy blue
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient authDark = LinearGradient(
    colors: [
      Color(0xFF05070A),
      Color(0xFF102A43),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightBackground = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(
          0xFFE6F0FF), // Subtle blue-white wash (prevents flat whitinstancee look)
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxDecoration scaffoldDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark ? darkBackground : lightBackground,
    );
  }

  // --- Animated Gradient Color Stops ---
  // These are designed for smooth interpolation via AnimatedContainer or TweenSequence

  /// Dark mode animated gradient - black to deep navy with subtle motion
  static const List<Color> animatedDarkColors = [
    Color(0xFF05070A), // Near-black
    Color(0xFF060B12), // Black-blue
    Color(0xFF081B2E), // Deep navy
    Color(0xFF0B2A4A), // Navy highlight
  ];

  /// Light mode animated gradient - subtle white with a deep-blue tint
  static const List<Color> animatedLightColors = [
    Color(0xFFF9FBFF), // Cool white
    Color(0xFFF1F7FF), // Very light blue
    Color(0xFFE3EFFF), // Light blue wash
    Color(0xFFF7FAFF), // Soft white
  ];

  /// Hero/accent gradient for feature highlights
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      KubusColors.primaryVariantDark,
      KubusColors.accentTealDark,
      KubusColors.accentOrangeLight,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Shimmer overlay gradient for glass effects
  static const LinearGradient glassShimmer = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x15FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.5, -1.5),
    end: Alignment(1.5, 1.5),
  );
}

/// Constants for glass/blur effects throughout the app
class KubusGlassEffects {
  KubusGlassEffects._();

  /// Standard blur intensity for glass panels
  static const double blurSigma = 12.0;

  /// Light blur for subtle depth
  static const double blurSigmaLight = 6.0;

  /// Heavy blur for modal overlays
  static const double blurSigmaHeavy = 20.0;

  /// Glass panel opacity in dark mode
  static const double glassOpacityDark = 0.60;

  /// Glass panel opacity in light mode
  static const double glassOpacityLight = 0.72;

  /// Border opacity for glass panels
  static const double glassBorderOpacity = 0.15;

  /// Backdrop dimming for modals
  static const double backdropDimming = 0.4;

  /// Blur-disabled glass should stay intentionally opaque to preserve legibility.
  static const double fallbackOpaqueOpacity = 0.85;

  /// Shared tint opacity when blur is enabled.
  static const double blurTintOpacityDark = 0.20;
  static const double blurTintOpacityLight = 0.14;

  /// Shared border opacity roles for tokenized glass shells.
  static const double glassBorderOpacityStrong = 0.30;
  static const double glassBorderOpacityMedium = 0.22;
  static const double glassBorderOpacitySubtle = 0.18;

  /// Shared shadow roles for glass surfaces.
  static const double shadowOpacityDark = 0.16;
  static const double shadowOpacityLight = 0.10;

  /// Accent blend amount used to preserve intent in blur-disabled mode while
  /// keeping the resulting surface opaque and theme-aligned.
  static const double fallbackTintBlend = 0.14;
}

@immutable
class KubusGlassSurfaceProfile {
  const KubusGlassSurfaceProfile({
    required this.blurSigma,
    required this.tintAlphaDark,
    required this.tintAlphaLight,
    required this.shadowBlurRadius,
    required this.shadowOffset,
  });

  final double blurSigma;
  final double tintAlphaDark;
  final double tintAlphaLight;
  final double shadowBlurRadius;
  final Offset shadowOffset;
}

class KubusGlassSurfaceTokens {
  KubusGlassSurfaceTokens._();

  static const header = KubusGlassSurfaceProfile(
    blurSigma: KubusGlassEffects.blurSigmaLight,
    tintAlphaDark: 0.18,
    tintAlphaLight: 0.14,
    shadowBlurRadius: 14.0,
    shadowOffset: Offset(0, 4),
  );

  static const sidebar = KubusGlassSurfaceProfile(
    blurSigma: KubusGlassEffects.blurSigmaLight,
    tintAlphaDark: 0.16,
    tintAlphaLight: 0.12,
    shadowBlurRadius: 16.0,
    shadowOffset: Offset(0, 4),
  );

  static const panel = KubusGlassSurfaceProfile(
    blurSigma: KubusGlassEffects.blurSigmaLight,
    tintAlphaDark: 0.18,
    tintAlphaLight: 0.14,
    shadowBlurRadius: 18.0,
    shadowOffset: Offset(0, 4),
  );

  static const card = KubusGlassSurfaceProfile(
    blurSigma: KubusGlassEffects.blurSigmaLight,
    tintAlphaDark: 0.22,
    tintAlphaLight: 0.18,
    shadowBlurRadius: 14.0,
    shadowOffset: Offset(0, 3),
  );

  static const button = KubusGlassSurfaceProfile(
    blurSigma: KubusGlassEffects.blurSigmaLight,
    tintAlphaDark: 0.20,
    tintAlphaLight: 0.16,
    shadowBlurRadius: 12.0,
    shadowOffset: Offset(0, 2),
  );
}
