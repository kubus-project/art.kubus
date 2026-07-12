/// Files (by path suffix, forward slashes) where raw colors are legitimate:
/// these ARE the central definitions.
const rawColorAllowedSuffixes = <String>[
  'lib/utils/design_tokens.dart',
  'lib/utils/kubus_color_roles.dart',
  'lib/utils/kubus_accent_gradients.dart',
  'lib/utils/kubus_brand_colors.dart',
  'lib/utils/app_color_utils.dart',
  'lib/utils/category_accent_color.dart',
  'lib/utils/rarity_ui.dart',
  'lib/widgets/map_marker_style_config.dart',
  'lib/providers/themeprovider.dart',
];

/// Files allowed to use BackdropFilter directly (the canonical glass stack).
const backdropFilterAllowedSuffixes = <String>[
  'lib/widgets/glass/glass_surface.dart',
  'lib/widgets/glass_components.dart',
];

/// Files allowed to call GoogleFonts directly.
const googleFontsAllowedSuffixes = <String>[
  'lib/utils/design_tokens.dart',
];

/// Files allowed to construct raw Material progress indicators
/// (the canonical kubus loading primitives).
const progressIndicatorAllowedSuffixes = <String>[
  'lib/widgets/inline_loading.dart',
  'lib/widgets/inline_progress.dart',
  'lib/widgets/app_loading.dart',
];

/// Whether [path] is exempt from a rule with the given [suffixes] allowlist.
///
/// Test files are always exempt: fixtures legitimately construct raw colors.
bool isAllowed(String path, List<String> suffixes) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.endsWith('_test.dart') || normalized.contains('/test/')) {
    return true;
  }
  return suffixes.any(normalized.endsWith);
}
