import 'package:flutter/material.dart';

import 'kubus_color_roles.dart';

class CategoryAccentColor {
  static Color resolve(BuildContext context, String category) {
    final roles = KubusColorRoles.of(context);
    final normalized = category.trim().toLowerCase();

    switch (normalized) {
      case 'ar exploration':
        return roles.statTeal;
      case 'exploration':
        return roles.statGreen;
      case 'community':
        return roles.statAmber;
      case 'collection':
        return roles.positiveAction;
      case 'web3':
        return roles.statCoral;
      case 'special':
        return roles.achievementGold;
      default:
        return roles.statTeal;
    }
  }
}

