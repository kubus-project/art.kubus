import 'package:flutter/material.dart';

import 'app_color_utils.dart';

class CategoryAccentColor {
  static Color resolve(BuildContext context, String category) {
    final base = Theme.of(context).colorScheme.primary;
    final normalized = category.trim().toLowerCase();

    switch (normalized) {
      case 'ar exploration':
        return base;
      case 'exploration':
        return AppColorUtils.shiftLightness(base, 0.08);
      case 'community':
        return AppColorUtils.shiftLightness(base, -0.06);
      case 'collection':
        return AppColorUtils.shiftLightness(base, 0.14);
      case 'web3':
        return AppColorUtils.shiftLightness(base, -0.10);
      case 'special':
        return AppColorUtils.shiftLightness(base, 0.04);
      default:
        return base;
    }
  }
}

