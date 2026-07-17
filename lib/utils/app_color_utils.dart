import 'package:flutter/material.dart';

import '../models/art_marker.dart';
import '../models/recent_activity.dart';
import 'kubus_color_roles.dart';
import 'design_tokens.dart';
import 'custom_icons.dart';

/// Semantic color palette for UI elements throughout the app.
/// These provide visual variety while maintaining design consistency.
class AppColorUtils {
  // Semantic accent colors for varied UI elements
  static const Color tealAccent = Color(0xFF4ECDC4);
  static const Color coralAccent = KubusColors.errorDark; // 0xFFFF6B6B
  static const Color greenAccent = KubusColors.successDark; // 0xFF4CAF50
  static const Color amberAccent = KubusColors.warningDark; // 0xFFFFB300
  static const Color purpleAccent = Color(0xFF9575CD);
  static const Color blueAccent = Color(0xFF42A5F5);
  static const Color pinkAccent = Color(0xFFEC407A);
  static const Color indigoAccent = Color(0xFF5C6BC0);
  static const Color orangeAccent = Color(0xFFFF7043);
  static const Color cyanAccent = Color(0xFF26C6DA);

  static Color shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final next = (hsl.lightness + delta).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(next).toColor();
  }

  /// Get semantic color for a feature/section key
  static Color featureColor(String key, ColorScheme scheme,
      {KubusColorRoles? roles}) {
    switch (key.toLowerCase()) {
      // Exploration / Discovery
      case 'map':
      case 'explore':
      case 'discovery':
      case 'ar':
      case 'view':
        return tealAccent;

      // Community / Social
      case 'community':
      case 'connect':
      case 'social':
      case 'follow':
      case 'friends':
        return scheme.secondary;

      // Creation / Art
      case 'studio':
      case 'artist':
      case 'create':
      case 'artwork':
      case 'gallery':
        // Requested: Artist Studio should have red accents.
        return roles?.web3ArtistStudioAccent ?? coralAccent;

      // Institutions / Organizations
      case 'institution':
      case 'institution_hub':
      case 'organize':
      case 'museum':
      case 'event':
        return roles?.web3InstitutionAccent ?? blueAccent;

      // Governance / DAO
      case 'dao':
      case 'dao_hub':
      case 'govern':
      case 'vote':
      case 'proposal':
        // Requested: DAO should be all green accents.
        return roles?.web3DaoAccent ?? greenAccent;

      // Marketplace / Trade
      case 'marketplace':
      case 'trade':
      case 'buy':
      case 'sell':
      case 'nft':
        // Requested: Marketplace should be orange.
        return roles?.web3MarketplaceAccent ?? orangeAccent;

      // Wallet / Finance
      case 'wallet':
      case 'balance':
      case 'token':
      case 'rewards':
      case 'earnings':
        return amberAccent;

      // Analytics / Stats
      case 'analytics':
      case 'stats':
      case 'insights':
      case 'metrics':
        return coralAccent;

      // Achievements / Rewards
      case 'achievements':
      case 'badges':
      case 'level':
      case 'progress':
        return Colors.amber;

      // Settings / Profile
      case 'settings':
      case 'profile':
      case 'account':
        return scheme.onSurface.withValues(alpha: 0.7);

      // Notifications / Alerts
      case 'notification':
      case 'alert':
      case 'message':
        return blueAccent;

      // Like / Favorite
      case 'like':
      case 'favorite':
      case 'heart':
        return coralAccent;

      // Comment / Discussion
      case 'comment':
      case 'discussion':
      case 'chat':
        return scheme.secondary;

      // Share
      case 'share':
        return scheme.tertiary;

      default:
        return scheme.primary;
    }
  }

  /// Get color for activity/notification categories
  static Color activityColor(String category, ColorScheme scheme) {
    switch (category.toLowerCase()) {
      case 'discovery':
        return tealAccent;
      case 'like':
      case 'favorite':
        return coralAccent;
      case 'comment':
        return scheme.secondary;
      case 'follow':
        return purpleAccent;
      case 'nft':
      case 'collectible':
        return amberAccent;
      case 'ar':
        return tealAccent;
      case 'reward':
        return greenAccent;
      case 'share':
        return scheme.tertiary;
      case 'mention':
        return scheme.primary;
      case 'achievement':
        return Colors.amber;
      case 'save':
        return scheme.secondary;
      case 'system':
        return scheme.onSurface.withValues(alpha: 0.6);
      default:
        return scheme.primary;
    }
  }

  /// Get color for stat/metric cards
  static Color statColor(int index, ColorScheme scheme) {
    final colors = [
      tealAccent,
      scheme.tertiary,
      scheme.secondary,
      scheme.primary,
      amberAccent,
      greenAccent,
      purpleAccent,
      coralAccent,
    ];
    return colors[index % colors.length];
  }

  /// Get gradient colors for hero sections
  static List<Color> heroGradient(String type, Color fallback) {
    switch (type.toLowerCase()) {
      case 'explore':
      case 'map':
        return [tealAccent, tealAccent.withValues(alpha: 0.7)];
      case 'community':
        return [purpleAccent, purpleAccent.withValues(alpha: 0.7)];
      case 'marketplace':
        return [orangeAccent, orangeAccent.withValues(alpha: 0.7)];
      case 'wallet':
        return [amberAccent, amberAccent.withValues(alpha: 0.7)];
      case 'achievements':
        return [Colors.amber, Colors.amber.withValues(alpha: 0.7)];
      case 'dao':
        return [greenAccent, greenAccent.withValues(alpha: 0.7)];
      case 'institution':
      case 'institution_hub':
        return [blueAccent, blueAccent.withValues(alpha: 0.7)];
      default:
        return [fallback, fallback.withValues(alpha: 0.8)];
    }
  }

  /// Get contrasting text color for a background
  static Color contrastText(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  /// WCAG-optimal foreground for a solid [background] fill.
  ///
  /// Picks pure white or pure black — whichever has the higher contrast
  /// ratio against [background]. Unlike [contrastText] (a 0.5-luminance
  /// heuristic for decorative text), this maximizes measured contrast and is
  /// the canonical resolver for on-accent/on-fill roles (theme `on*` pairs,
  /// accent-filled buttons). Guarantees >= 4.5:1 for every color in
  /// `ThemeProvider.availableAccentColors` (enforced by
  /// `test/utils/theme_scheme_contrast_test.dart`).
  static Color onColor(Color background) {
    final luminance = background.computeLuminance();
    final whiteContrast = 1.05 / (luminance + 0.05);
    final blackContrast = (luminance + 0.05) / 0.05;
    return whiteContrast >= blackContrast ? Colors.white : Colors.black;
  }

  /// Get icon for activity category (consistent across desktop/mobile)
  static IconData activityIcon(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.discovery:
        return Icons.explore_outlined;
      case ActivityCategory.like:
        return Icons.favorite;
      case ActivityCategory.comment:
        return Icons.chat_bubble_outline;
      case ActivityCategory.follow:
        return Icons.person_add_outlined;
      case ActivityCategory.nft:
        return Icons.token_outlined;
      case ActivityCategory.ar:
        return Icons.view_in_ar_outlined;
      case ActivityCategory.reward:
        return Icons.star_outline;
      case ActivityCategory.share:
        return Icons.share_outlined;
      case ActivityCategory.mention:
        return Icons.alternate_email;
      case ActivityCategory.achievement:
        return Icons.emoji_events_outlined;
      case ActivityCategory.save:
        return Icons.bookmark_outline;
      case ActivityCategory.system:
        return Icons.info_outline;
    }
  }

  /// Get color for activity category using enum (type-safe variant)
  static Color activityColorFor(ActivityCategory category, ColorScheme scheme) {
    return activityColor(category.name, scheme);
  }

  // --------------------------------------------------------------------------
  // Map Marker Subject Colors - centralized color definitions for marker types
  // --------------------------------------------------------------------------

  /// Dedicated color for Exhibition markers (theme-aware when roles are provided).
  static const Color exhibitionColor = KubusColors.achievementGoldDark;

  /// Dedicated color for Event markers (fallback)
  static const Color eventColor = KubusColors.accentOrangeDark;

  /// Dedicated color for Street Art markers (fallback)
  static const Color streetArtColor = KubusColors.warningDark;

  /// Dedicated color for Institution markers (fallback)
  static const Color institutionColor = KubusColors.successDark;

  /// Get color for a map marker based on its type and metadata.
  /// This is the single source of truth for marker colors across desktop/mobile.
  static Color markerSubjectColor({
    required String markerType,
    Map<String, dynamic>? metadata,
    required ColorScheme scheme,
    KubusColorRoles? roles,
  }) {
    final resolvedRoles = roles;
    final exhibitionAccent = resolvedRoles?.achievementGold ?? exhibitionColor;
    final eventAccent = resolvedRoles?.statCoral ?? eventColor;
    final streetArtAccent = resolvedRoles?.statAmber ?? streetArtColor;
    final institutionAccent = resolvedRoles?.statGreen ?? institutionColor;
    final artworkAccent = resolvedRoles?.statTeal ?? KubusColors.accentTealDark;
    final residencyAccent = resolvedRoles?.statAmber ?? KubusColors.warningDark;
    final dropAccent =
        resolvedRoles?.lockedFeature ?? KubusColors.accentOrangeDark;
    final experienceAccent = scheme.primary;

    switch (ArtMarker.parseMarkerType(markerType, metadata)) {
      case ArtMarkerType.artwork:
        return artworkAccent;
      case ArtMarkerType.streetArt:
        return streetArtAccent;
      case ArtMarkerType.institution:
        return institutionAccent;
      case ArtMarkerType.event:
        return eventAccent;
      case ArtMarkerType.exhibition:
        return exhibitionAccent;
      case ArtMarkerType.residency:
        return residencyAccent;
      case ArtMarkerType.drop:
        return dropAccent;
      case ArtMarkerType.experience:
        return experienceAccent;
      case ArtMarkerType.other:
        return scheme.outline;
    }
  }

  /// Get icon for a map marker type
  static IconData markerSubjectIcon(String markerType) {
    switch (ArtMarker.parseMarkerType(markerType)) {
      case ArtMarkerType.artwork:
        return Icons.auto_awesome;
      case ArtMarkerType.streetArt:
        return streetArtIcon;
      case ArtMarkerType.institution:
        return Icons.museum_outlined;
      case ArtMarkerType.event:
        return Icons.event_available;
      case ArtMarkerType.exhibition:
        return exhibitionIcon;
      case ArtMarkerType.residency:
        return Icons.apartment;
      case ArtMarkerType.drop:
        return Icons.wallet_giftcard;
      case ArtMarkerType.experience:
        return Icons.view_in_ar;
      case ArtMarkerType.other:
        return Icons.location_on_outlined;
    }
  }

  /// Get icon specifically for exhibition markers
  static const IconData exhibitionIcon = CustomIcons.wallArt;

  /// Get icon specifically for street/public art markers
  static const IconData streetArtIcon = CustomIcons.fragrance;
}
