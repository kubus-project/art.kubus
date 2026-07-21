import 'package:flutter/material.dart';

import '../models/promotion.dart';
import 'kubus_color_roles.dart';

/// Single source of truth for Home discovery-rail entity semantics.
///
/// Every rail entity type maps to a distinct, restrained, theme-aware accent
/// drawn from [KubusColorRoles]'s stat palette. Four of the five mappings match
/// [AppColorUtils.markerSubjectColor] so a marker on the map and its rail card
/// read as the same entity family; `profile`/artist takes a distinct calm blue
/// (artist identity red would clash with the event coral).
///
/// Mobile and desktop Home must both resolve accents through this class so the
/// two surfaces never drift apart. Colour is only ever a *secondary* signal —
/// the card's icon and text keep each entity type identifiable without it.
class HomeRailSemantics {
  const HomeRailSemantics._();

  /// Restrained accent for [type] using the supplied [roles].
  static Color accentFor(PromotionEntityType type, KubusColorRoles roles) {
    switch (type) {
      case PromotionEntityType.artwork:
        return roles.statTeal;
      case PromotionEntityType.profile:
        return roles.statBlue;
      case PromotionEntityType.institution:
        return roles.statGreen;
      case PromotionEntityType.event:
        return roles.statCoral;
      case PromotionEntityType.exhibition:
        return roles.achievementGold;
    }
  }

  /// Convenience accessor that reads roles from [context].
  static Color of(BuildContext context, PromotionEntityType type) =>
      accentFor(type, KubusColorRoles.of(context));
}
