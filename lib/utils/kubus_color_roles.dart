import 'package:flutter/material.dart';

/// Centralized color roles for the art.kubus app.
/// All UI color decisions should go through this extension or AppColorUtils.
///
/// Usage:
///   final roles = KubusColorRoles.of(context);
///   Icon(Icons.favorite, color: roles.likeAction);
///   Chip(backgroundColor: roles.tagChipBackground);
@immutable
class KubusColorRoles extends ThemeExtension<KubusColorRoles> {
  const KubusColorRoles({
    required this.likeAction,
    required this.tagChipBackground,
    required this.tagChipForeground,
    required this.positiveAction,
    required this.negativeAction,
    required this.warningAction,
    required this.lockedFeature,
    required this.statTeal,
    required this.statCoral,
    required this.statGreen,
    required this.statAmber,
    required this.statPurple,
    required this.achievementGold,
    required this.artistStudioRed,
  });

  /// Like/favorite action color - RED across all screens
  final Color likeAction;

  /// Tag/chip background color - PURPLE across all screens
  final Color tagChipBackground;

  /// Tag/chip foreground/text color
  final Color tagChipForeground;

  /// Positive action/indicator (success, increase, etc.)
  final Color positiveAction;

  /// Negative action/indicator (error, decrease, etc.)
  final Color negativeAction;

  /// Warning action/indicator
  final Color warningAction;

  /// Locked/disabled feature indicator
  final Color lockedFeature;

  /// Stat card accent colors (consistent palette)
  final Color statTeal;
  final Color statCoral;
  final Color statGreen;
  final Color statAmber;
  final Color statPurple;

  /// Achievement/reward gold accent
  final Color achievementGold;

  /// Artist Studio red accent
  final Color artistStudioRed;

  // --------------------------------------------------------------------------
  // Web3 Hub section accents (single source of truth)
  //
  // Requested mapping (matches Web3 hub navigation intent):
  // - Artist Studio: red accents
  // - DAO: green accents
  // - Institutions: deep purple accents
  // - Marketplace: orange accents
  //
  // These are computed from existing role colors so they automatically adapt
  // to light/dark themes without introducing new ThemeExtension fields.
  // --------------------------------------------------------------------------

  /// Artist Studio accent (red)
  Color get web3ArtistStudioAccent => artistStudioRed;

  /// DAO accent (green)
  Color get web3DaoAccent => positiveAction;

  /// Institution accent (deep purple)
  Color get web3InstitutionAccent => tagChipBackground;

  /// Marketplace accent (orange)
  Color get web3MarketplaceAccent => lockedFeature;

  /// Resolve Web3 hub accent from a screen/feature key.
  ///
  /// Keys supported:
  /// - studio / artist / create
  /// - dao / dao_hub / govern / governance
  /// - institution / institution_hub / organize
  /// - marketplace / trade / buy / sell / nft
  Color web3AccentForKey(String key) {
    switch (key.toLowerCase()) {
      case 'studio':
      case 'artist':
      case 'create':
      case 'artist_studio':
      case 'artist-studio':
        return web3ArtistStudioAccent;
      case 'dao':
      case 'dao_hub':
      case 'govern':
      case 'governance':
      case 'governance_hub':
      case 'governance-hub':
        return web3DaoAccent;
      case 'institution':
      case 'institution_hub':
      case 'organize':
        return web3InstitutionAccent;
      case 'marketplace':
      case 'trade':
      case 'buy':
      case 'sell':
      case 'nft':
        return web3MarketplaceAccent;
      default:
        return web3MarketplaceAccent;
    }
  }

  /// Default dark theme roles
  static const dark = KubusColorRoles(
    likeAction: Color(0xFFFF6B6B), // Coral red - consistent across app
    tagChipBackground: Color(0xFF9575CD), // Purple - sanctioned for tags
    tagChipForeground: Colors.white,
    positiveAction: Color(0xFF4CAF50), // Green
    negativeAction: Color(0xFFFF6B6B), // Coral red
    warningAction: Color(0xFFFFB300), // Amber
    lockedFeature: Color(0xFFFF9800), // Orange
    statTeal: Color(0xFF4ECDC4),
    statCoral: Color(0xFFFF6B6B),
    statGreen: Color(0xFF4CAF50),
    statAmber: Color(0xFFFFB300),
    statPurple: Color(0xFF9575CD),
    achievementGold: Color(0xFFFFD700),
    artistStudioRed: Colors.red,
  );

  /// Default light theme roles
  static const light = KubusColorRoles(
    likeAction: Color(0xFFE53935), // Material red 600
    tagChipBackground: Color(0xFF7E57C2), // Deep purple 400
    tagChipForeground: Colors.white,
    positiveAction: Color(0xFF43A047), // Green 600
    negativeAction: Color(0xFFE53935), // Red 600
    warningAction: Color(0xFFFFA000), // Amber 700
    lockedFeature: Color(0xFFFB8C00), // Orange 600
    statTeal: Color(0xFF00897B), // Teal 600
    statCoral: Color(0xFFE53935), // Red 600
    statGreen: Color(0xFF43A047), // Green 600
    statAmber: Color(0xFFFFA000), // Amber 700
    statPurple: Color(0xFF7E57C2), // Deep purple 400
    achievementGold: Color(0xFFFFC107), // Amber 500
    artistStudioRed: Colors.red,
  );
  


  /// Convenience accessor from BuildContext
  static KubusColorRoles of(BuildContext context) {
    return Theme.of(context).extension<KubusColorRoles>() ?? dark;
  }

  @override
  KubusColorRoles copyWith({
    Color? likeAction,
    Color? tagChipBackground,
    Color? tagChipForeground,
    Color? positiveAction,
    Color? negativeAction,
    Color? warningAction,
    Color? lockedFeature,
    Color? statTeal,
    Color? statCoral,
    Color? statGreen,
    Color? statAmber,
    Color? statPurple,
    Color? achievementGold,
    Color? artistStudioRed,
  }) {
    return KubusColorRoles(
      likeAction: likeAction ?? this.likeAction,
      tagChipBackground: tagChipBackground ?? this.tagChipBackground,
      tagChipForeground: tagChipForeground ?? this.tagChipForeground,
      positiveAction: positiveAction ?? this.positiveAction,
      negativeAction: negativeAction ?? this.negativeAction,
      warningAction: warningAction ?? this.warningAction,
      lockedFeature: lockedFeature ?? this.lockedFeature,
      statTeal: statTeal ?? this.statTeal,
      statCoral: statCoral ?? this.statCoral,
      statGreen: statGreen ?? this.statGreen,
      statAmber: statAmber ?? this.statAmber,
      statPurple: statPurple ?? this.statPurple,
      achievementGold: achievementGold ?? this.achievementGold, 
      artistStudioRed: artistStudioRed ?? this.artistStudioRed,
    );
  }

  @override
  KubusColorRoles lerp(covariant KubusColorRoles? other, double t) {
    if (other == null) return this;
    return KubusColorRoles(
      likeAction: Color.lerp(likeAction, other.likeAction, t)!,
      tagChipBackground:
          Color.lerp(tagChipBackground, other.tagChipBackground, t)!,
      tagChipForeground:
          Color.lerp(tagChipForeground, other.tagChipForeground, t)!,
      positiveAction: Color.lerp(positiveAction, other.positiveAction, t)!,
      negativeAction: Color.lerp(negativeAction, other.negativeAction, t)!,
      warningAction: Color.lerp(warningAction, other.warningAction, t)!,
      lockedFeature: Color.lerp(lockedFeature, other.lockedFeature, t)!,
      statTeal: Color.lerp(statTeal, other.statTeal, t)!,
      statCoral: Color.lerp(statCoral, other.statCoral, t)!,
      statGreen: Color.lerp(statGreen, other.statGreen, t)!,
      statAmber: Color.lerp(statAmber, other.statAmber, t)!,
      statPurple: Color.lerp(statPurple, other.statPurple, t)!,
      achievementGold: Color.lerp(achievementGold, other.achievementGold, t)!,
      artistStudioRed: Color.lerp(artistStudioRed, other.artistStudioRed, t)!, 
    );
  }
}
