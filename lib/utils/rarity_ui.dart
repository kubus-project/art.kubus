import 'package:flutter/material.dart';

import '../models/artwork.dart';
import '../models/collectible.dart';
import 'app_color_utils.dart';

class RarityUi {
  static Color artworkColor(BuildContext context, ArtworkRarity rarity) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    switch (rarity) {
      case ArtworkRarity.common:
        return scheme.outline.withValues(alpha: 0.9);
      case ArtworkRarity.rare:
        return accent;
      case ArtworkRarity.epic:
        return AppColorUtils.shiftLightness(accent, -0.08);
      case ArtworkRarity.legendary:
        return AppColorUtils.shiftLightness(accent, 0.10);
    }
  }

  static Color collectibleColor(BuildContext context, CollectibleRarity rarity) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    switch (rarity) {
      case CollectibleRarity.common:
        return scheme.outline.withValues(alpha: 0.9);
      case CollectibleRarity.uncommon:
        return AppColorUtils.shiftLightness(accent, 0.14);
      case CollectibleRarity.rare:
        return accent;
      case CollectibleRarity.epic:
        return AppColorUtils.shiftLightness(accent, -0.06);
      case CollectibleRarity.legendary:
        return AppColorUtils.shiftLightness(accent, 0.08);
      case CollectibleRarity.mythic:
        return AppColorUtils.shiftLightness(accent, -0.12);
    }
  }
}

