import 'package:flutter/material.dart';
import 'design_tokens.dart';

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
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.foreground,
    required this.foregroundMuted,
    required this.foregroundSubtle,
    required this.rule,
    required this.ruleStrong,
    required this.active,
    required this.onActive,
    required this.secondary,
    required this.userAccent,
    required this.onUserAccent,
    required this.focus,
    required this.destructive,
    required this.onDestructive,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
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
    required this.statBlue,
    required this.achievementGold,
    required this.artistStudioRed,
  });

  /// Application/page base.
  final Color ground;

  /// Ordinary flat PRODUCT content surface.
  final Color surface;

  /// Dialogs and sheets that need a distinct surface level.
  final Color surfaceRaised;

  /// Transient surface placed over map, image, or spatial media.
  final Color surfaceOverlay;

  final Color foreground;
  final Color foregroundMuted;
  final Color foregroundSubtle;
  final Color rule;
  final Color ruleStrong;

  /// Family primary (kubus teal): active/selection, focus, primary action.
  /// Independent of the personal accent.
  final Color active;
  final Color onActive;

  /// Family secondary (blue): information, analytics, institution and
  /// secondary discovery context. Never selection or the primary action.
  final Color secondary;

  /// Optional personalized accent, exposed only for explicit highlighting.
  final Color userAccent;
  final Color onUserAccent;
  final Color focus;
  final Color destructive;
  final Color onDestructive;
  final Color success;
  final Color warning;
  final Color error;
  final Color onError;

  /// Like/favorite action color - RED across all screens
  final Color likeAction;

  /// Tag/chip background color used across the app.
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
  final Color statBlue;

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
  // - Institutions: deep accent (no purple)
  // - Marketplace: orange accents
  //
  // These are computed from existing role colors so they automatically adapt
  // to light/dark themes without introducing new ThemeExtension fields.
  // --------------------------------------------------------------------------

  /// Artist Studio accent (red)
  Color get web3ArtistStudioAccent => artistStudioRed;

  /// DAO accent (green)
  Color get web3DaoAccent => positiveAction;

  /// Artist identity accent (amber)
  Color get artistBadgeAccent => artistStudioRed;

  /// Institution identity accent (blue)
  Color get institutionBadgeAccent => statBlue;

  /// Institution accent (blue, shared across institution surfaces)
  Color get web3InstitutionAccent => institutionBadgeAccent;

  /// Marketplace accent (orange)
  Color get web3MarketplaceAccent => lockedFeature;

  /// kubus Node accent.
  ///
  /// Its own hue, distinct from the five capability colours: Node is runtime
  /// infrastructure, not a practice surface and not the wallet. Treating it as
  /// the wallet's colour would imply it needs wallet authority, which it does
  /// not.
  Color get web3NodeAccent => statPurple;

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
      case 'node':
      case 'kubus_node':
      case 'kubus-node':
        return web3NodeAccent;
      default:
        return web3MarketplaceAccent;
    }
  }

  /// Resolve a semantic screen accent from a shared key.
  ///
  /// Kubus teal ([active]) is the family identity for structural screens
  /// (home, settings, profile, wallet shell, map). Contextual hubs keep their
  /// orientation colours. The personal accent never drives a screen accent.
  Color screenAccentForKey(String key) {
    switch (key.toLowerCase()) {
      case 'studio':
      case 'artist':
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
      case 'institution-hub':
      case 'organize':
        return web3InstitutionAccent;
      case 'marketplace':
      case 'trade':
      case 'nft':
        return web3MarketplaceAccent;
      case 'node':
      case 'kubus_node':
      case 'kubus-node':
        return web3NodeAccent;
      case 'community':
      case 'connect':
      case 'analytics':
        return secondary;
      case 'map':
      case 'explore':
      case 'discovery':
      case 'ar':
      case 'wallet':
      case 'profile':
      case 'settings':
      case 'home':
      default:
        return active;
    }
  }

  /// Default dark theme roles
  static const dark = KubusColorRoles(
    ground: KubusProductPalette.groundDark,
    surface: KubusProductPalette.surfaceDark,
    surfaceRaised: KubusProductPalette.surfaceRaisedDark,
    surfaceOverlay: KubusProductPalette.surfaceOverlayDark,
    foreground: KubusProductPalette.foregroundDark,
    foregroundMuted: KubusProductPalette.foregroundMutedDark,
    foregroundSubtle: KubusProductPalette.foregroundSubtleDark,
    rule: KubusProductPalette.ruleDark,
    ruleStrong: KubusProductPalette.ruleStrongDark,
    active: KubusProductPalette.activeDark,
    onActive: KubusProductPalette.foregroundLight,
    secondary: KubusProductPalette.secondaryDark,
    userAccent: KubusProductPalette.activeDark,
    onUserAccent: Colors.white,
    focus: KubusProductPalette.focusDark,
    destructive: KubusProductPalette.destructiveDark,
    onDestructive: Color(0xFF26090B),
    success: KubusProductPalette.successDark,
    warning: KubusProductPalette.warningDark,
    error: KubusProductPalette.destructiveDark,
    onError: Color(0xFF26090B),
    likeAction: KubusColors.errorDark, // Coral red - consistent across app
    tagChipBackground: KubusProductPalette.surfaceRaisedDark,
    tagChipForeground: KubusProductPalette.foregroundDark,
    positiveAction: KubusColors.successDark,
    negativeAction: KubusColors.errorDark,
    warningAction: KubusColors.warningDark,
    lockedFeature: KubusColors.accentOrangeDark,
    statTeal: KubusColors.accentTealDark,
    statCoral: KubusColors.errorDark,
    statGreen: KubusColors.successDark,
    statAmber: KubusColors.warningDark,
    statPurple: KubusColors.primaryVariantDark,
    statBlue: KubusColors.accentBlue,
    achievementGold: KubusColors.achievementGoldDark,
    artistStudioRed: KubusColors.errorDark,
  );

  /// Default light theme roles
  static const light = KubusColorRoles(
    ground: KubusProductPalette.groundLight,
    surface: KubusProductPalette.surfaceLight,
    surfaceRaised: KubusProductPalette.surfaceRaisedLight,
    surfaceOverlay: KubusProductPalette.surfaceOverlayLight,
    foreground: KubusProductPalette.foregroundLight,
    foregroundMuted: KubusProductPalette.foregroundMutedLight,
    foregroundSubtle: KubusProductPalette.foregroundSubtleLight,
    rule: KubusProductPalette.ruleLight,
    ruleStrong: KubusProductPalette.ruleStrongLight,
    active: KubusProductPalette.activeLight,
    onActive: Colors.white,
    secondary: KubusProductPalette.secondaryLight,
    userAccent: KubusProductPalette.activeLight,
    onUserAccent: Colors.white,
    focus: KubusProductPalette.focusLight,
    destructive: KubusProductPalette.destructiveLight,
    onDestructive: Colors.white,
    success: KubusProductPalette.successLight,
    warning: KubusProductPalette.warningLight,
    error: KubusProductPalette.destructiveLight,
    onError: Colors.white,
    likeAction: KubusColors.error, // Material red 600
    tagChipBackground: KubusProductPalette.surfaceRaisedLight,
    tagChipForeground: KubusProductPalette.foregroundLight,
    positiveAction: KubusColors.success, // Green 600
    negativeAction: KubusColors.error, // Red 600
    warningAction: KubusColors.warning, // Amber 700
    lockedFeature: KubusColors.accentOrangeLight,
    statTeal: KubusColors.accentTealLight,
    statCoral: KubusColors.error, // Red 600
    statGreen: KubusColors.success, // Green 600
    statAmber: KubusColors.warning, // Amber 700
    statBlue: KubusColors.accentBlue,
    statPurple: KubusColors.primaryVariantLight,
    achievementGold: KubusColors.achievementGoldLight,
    artistStudioRed: KubusColors.error,
  );

  /// Convenience accessor from BuildContext
  static KubusColorRoles of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<KubusColorRoles>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  KubusColorRoles copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? foreground,
    Color? foregroundMuted,
    Color? foregroundSubtle,
    Color? rule,
    Color? ruleStrong,
    Color? active,
    Color? onActive,
    Color? secondary,
    Color? userAccent,
    Color? onUserAccent,
    Color? focus,
    Color? destructive,
    Color? onDestructive,
    Color? success,
    Color? warning,
    Color? error,
    Color? onError,
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
    Color? statBlue,
    Color? achievementGold,
    Color? artistStudioRed,
  }) {
    return KubusColorRoles(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      foregroundSubtle: foregroundSubtle ?? this.foregroundSubtle,
      rule: rule ?? this.rule,
      ruleStrong: ruleStrong ?? this.ruleStrong,
      active: active ?? this.active,
      onActive: onActive ?? this.onActive,
      secondary: secondary ?? this.secondary,
      userAccent: userAccent ?? this.userAccent,
      onUserAccent: onUserAccent ?? this.onUserAccent,
      focus: focus ?? this.focus,
      destructive: destructive ?? this.destructive,
      onDestructive: onDestructive ?? this.onDestructive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      onError: onError ?? this.onError,
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
      statBlue: statBlue ?? this.statBlue,
      achievementGold: achievementGold ?? this.achievementGold,
      artistStudioRed: artistStudioRed ?? this.artistStudioRed,
    );
  }

  @override
  KubusColorRoles lerp(covariant KubusColorRoles? other, double t) {
    if (other == null) return this;
    return KubusColorRoles(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      foregroundSubtle:
          Color.lerp(foregroundSubtle, other.foregroundSubtle, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      ruleStrong: Color.lerp(ruleStrong, other.ruleStrong, t)!,
      active: Color.lerp(active, other.active, t)!,
      onActive: Color.lerp(onActive, other.onActive, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      userAccent: Color.lerp(userAccent, other.userAccent, t)!,
      onUserAccent: Color.lerp(onUserAccent, other.onUserAccent, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      onDestructive: Color.lerp(onDestructive, other.onDestructive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
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
      statBlue: Color.lerp(statBlue, other.statBlue, t)!,
      achievementGold: Color.lerp(achievementGold, other.achievementGold, t)!,
      artistStudioRed: Color.lerp(artistStudioRed, other.artistStudioRed, t)!,
    );
  }
}
