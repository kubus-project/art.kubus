import 'package:flutter/material.dart';

import '../models/recent_activity.dart';
import 'kubus_color_roles.dart';
import 'design_tokens.dart';

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
        // Requested: Institutions should be deep purple.
        return roles?.web3InstitutionAccent ?? const Color(0xFF7E57C2);

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
        return [
          const Color(0xFF7E57C2),
          const Color(0xFF7E57C2).withValues(alpha: 0.7)
        ];
      default:
        return [fallback, fallback.withValues(alpha: 0.8)];
    }
  }

  /// Get contrasting text color for a background
  static Color contrastText(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
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

  /// Dedicated color for Exhibition markers - distinct from events
  static const Color exhibitionColor = Color(0xFF8E24AA); // Deep purple

  /// Dedicated color for Event markers
  static const Color eventColor = Color(0xFFFF7043); // Deep orange

  /// Dedicated color for Institution markers
  static const Color institutionColor = Color(0xFF5C6BC0); // Indigo

  /// Get color for a map marker based on its type and metadata.
  /// This is the single source of truth for marker colors across desktop/mobile.
  static Color markerSubjectColor({
    required String markerType,
    Map<String, dynamic>? metadata,
    required ColorScheme scheme,
  }) {
    final subjectType = (metadata?['subjectType'] ?? metadata?['subject_type'])
        ?.toString()
        .toLowerCase();
    final category =
        (metadata?['subjectCategory'] ?? metadata?['subject_category'])
            ?.toString()
            .toLowerCase();

    // Check if this is an exhibition marker
    if (_isExhibitionMarker(markerType, subjectType, category, metadata)) {
      return exhibitionColor;
    }

    // Check subject type metadata first
    if (subjectType != null && subjectType.isNotEmpty) {
      if (subjectType.contains('institution') ||
          subjectType.contains('museum')) {
        return institutionColor;
      }
      if (subjectType.contains('event')) {
        return eventColor;
      }
      if (subjectType.contains('group') ||
          subjectType.contains('dao') ||
          subjectType.contains('collective')) {
        return purpleAccent;
      }
    }

    // Fall back to marker type
    final normalizedType = markerType.toLowerCase();
    switch (normalizedType) {
      case 'artwork':
        return tealAccent;
      case 'institution':
        return institutionColor;
      case 'event':
        return eventColor;
      case 'residency':
        return purpleAccent;
      case 'drop':
        return coralAccent;
      case 'experience':
        return cyanAccent;
      case 'other':
      default:
        return scheme.outline;
    }
  }

  /// Check if a marker represents an exhibition
  static bool _isExhibitionMarker(
    String markerType,
    String? subjectType,
    String? category,
    Map<String, dynamic>? metadata,
  ) {
    // Check explicit exhibition indicators
    if (subjectType != null && subjectType.contains('exhibition')) return true;
    if (category != null && category.contains('exhibition')) return true;

    // Check if marker has exhibition summaries
    final exhibitions = metadata?['exhibitionSummaries'] ??
        metadata?['exhibition_summaries'] ??
        metadata?['exhibitions'];
    if (exhibitions is List && exhibitions.isNotEmpty) return true;
    if (exhibitions is Map && exhibitions.isNotEmpty) return true;

    return false;
  }

  /// Get icon for a map marker type
  static IconData markerSubjectIcon(String markerType) {
    switch (markerType.toLowerCase()) {
      case 'artwork':
        return Icons.auto_awesome;
      case 'institution':
        return Icons.museum_outlined;
      case 'event':
        return Icons.event_available;
      case 'residency':
        return Icons.apartment;
      case 'drop':
        return Icons.wallet_giftcard;
      case 'experience':
        return Icons.view_in_ar;
      case 'other':
      default:
        return Icons.location_on_outlined;
    }
  }

  /// Get icon specifically for exhibition markers
  static IconData get exhibitionIcon => Icons.museum;
}
