import 'package:flutter/material.dart';

import '../models/promotion.dart';
import 'kubus_color_roles.dart';
import 'kubus_entity_semantics.dart';

/// Home discovery-rail entity semantics.
///
/// Kept as the rail's own name, but it is no longer a second mapping: it
/// delegates to [KubusEntitySemantics], which is the single source of truth
/// shared by the Home rails, profile portfolio cards and the studio gallery.
/// A rail card and a profile card for the same kind of thing therefore cannot
/// drift apart.
class HomeRailSemantics {
  const HomeRailSemantics._();

  /// Restrained accent for [type] using the supplied [roles].
  static Color accentFor(PromotionEntityType type, KubusColorRoles roles) =>
      KubusEntitySemantics.accentFor(
        KubusEntitySemantics.fromPromotion(type),
        roles,
      );

  /// Convenience accessor that reads roles from [context].
  static Color of(BuildContext context, PromotionEntityType type) =>
      accentFor(type, KubusColorRoles.of(context));
}
