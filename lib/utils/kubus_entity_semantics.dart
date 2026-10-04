import 'package:flutter/material.dart';

import '../models/promotion.dart';
import 'app_color_utils.dart';
import 'kubus_color_roles.dart';

/// The kinds of thing the product previews as an entity card.
///
/// Wider than [PromotionEntityType] because a profile previews collections too,
/// and narrower than the map's marker taxonomy because a card is an editorial
/// preview, not a cartographic object.
enum KubusEntityKind {
  artwork,
  collection,
  event,
  exhibition,
  profile,
  institution,
}

/// Single source of truth for entity accent and glyph across the product.
///
/// A Home rail card, a profile portfolio card and a studio gallery card for the
/// same kind of thing must read as the same entity family, so they all resolve
/// their colour and their fallback glyph here rather than each picking their
/// own. [HomeRailSemantics] delegates to this, which is why the rail mapping is
/// unchanged.
///
/// Colour is only ever a *secondary* signal: the card's title and glyph keep
/// each entity kind identifiable without it.
class KubusEntitySemantics {
  const KubusEntitySemantics._();

  /// Restrained, theme-aware accent from the [KubusColorRoles] stat palette.
  ///
  /// Four of the six match [AppColorUtils.markerSubjectColor] so a marker on
  /// the map and its card read as the same family; `profile` takes a calm blue
  /// because artist identity red would clash with the event coral.
  static Color accentFor(KubusEntityKind kind, KubusColorRoles roles) {
    switch (kind) {
      case KubusEntityKind.artwork:
        return roles.statTeal;
      case KubusEntityKind.collection:
        return roles.statAmber;
      case KubusEntityKind.event:
        return roles.statCoral;
      case KubusEntityKind.exhibition:
        return roles.achievementGold;
      case KubusEntityKind.profile:
        return roles.statBlue;
      case KubusEntityKind.institution:
        return roles.statGreen;
    }
  }

  /// The decorative glyph an entity card shows when it has no usable media.
  ///
  /// It is the category's own symbol, cropped into the authored role field —
  /// not a small grey "no image" icon in the middle of a grey rectangle.
  static IconData glyphFor(KubusEntityKind kind) {
    switch (kind) {
      case KubusEntityKind.artwork:
        return Icons.palette_outlined;
      case KubusEntityKind.collection:
        return Icons.collections_outlined;
      case KubusEntityKind.event:
        return Icons.event_outlined;
      case KubusEntityKind.exhibition:
        return AppColorUtils.exhibitionIcon;
      case KubusEntityKind.profile:
        return Icons.person_outline;
      case KubusEntityKind.institution:
        return Icons.apartment_outlined;
    }
  }

  static Color of(BuildContext context, KubusEntityKind kind) =>
      accentFor(kind, KubusColorRoles.of(context));

  static KubusEntityKind fromPromotion(PromotionEntityType type) {
    switch (type) {
      case PromotionEntityType.artwork:
        return KubusEntityKind.artwork;
      case PromotionEntityType.profile:
        return KubusEntityKind.profile;
      case PromotionEntityType.institution:
        return KubusEntityKind.institution;
      case PromotionEntityType.event:
        return KubusEntityKind.event;
      case PromotionEntityType.exhibition:
        return KubusEntityKind.exhibition;
    }
  }
}
