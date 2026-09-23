/// # Kubus UI Kit — canonical component index
///
/// Import this file when building screens. If a component you need exists
/// here, you MUST use it instead of hand-rolling. Decision table:
///
/// | Need | Use |
/// |---|---|
/// | Screen background | `KubusProductBackground` |
/// | Ordinary content surface | `KubusCard` (flat by default) |
/// | Spatial/media overlay | `LiquidGlassPanel` / `LiquidGlassCard` (explicit) |
/// | Long-form reading section (descriptions, bios, curatorial text) | `KubusReadingSurface` (never glass) |
/// | Small floating media controls | `FrostedContainer` (explicit spatial use) |
/// | Bottom sheet | `BackdropGlassSheet` (inside `showModalBottomSheet`) |
/// | Dialog | `KubusAlertDialog` via `showKubusDialog` |
/// | Primary/secondary/quiet/destructive action | `KubusButton` |
/// | Icon button on glass/map | `KubusGlassIconButton` |
/// | Neutral filter/selection chip | `KubusChip` |
/// | Chip floating over map/media | `KubusGlassChip` |
/// | Status/count/label pill | `KubusBadge` |
/// | Text input | `KubusTextField` (creator flows: `CreatorTextField`) |
/// | Search input | `KubusSearchBar` |
/// | Screen/section header | `KubusScreenHeader` |
/// | Stat tile | `KubusStatCard` |
/// | Empty state | `EmptyStateCard` |
/// | Loading (inline/indeterminate) | `InlineLoading` / `InlineProgress` (never raw `CircularProgressIndicator`) |
/// | Determinate meter (vote share, upload %, usage) | `KubusMeterBar` (never a raw Material progress bar) |
/// | Toast/snackbar | `KubusSnackbar` |
/// | Borders | `KubusBorders.*` (never raw `Border.all`) |
/// | Contextual gradients | `KubusAccentGradients.*` (never inline colors) |
///
/// Colors: `KubusColorRoles.of(context)` for ground, surfaces, rules, active,
/// focus and semantic status; use `ColorScheme` for Material integration.
/// Map/category colors remain in their data token family. Typography:
/// `KubusTextStyles` or `KubusTypography.content/structural/machine`.
/// Spacing/radius: `KubusSpacing`, `KubusRadius`. Enforced by
/// `packages/kubus_lints`.
library;

export '../utils/design_tokens.dart';
export '../utils/kubus_accent_gradients.dart';
export '../utils/kubus_color_roles.dart';
export 'common/kubus_badge.dart';
export 'common/kubus_glass_chip.dart';
export 'common/kubus_meter_bar.dart';
export 'common/kubus_glass_icon_button.dart';
export 'common/kubus_reading_surface.dart';
export 'common/kubus_screen_header.dart';
export 'common/kubus_stat_card.dart';
export 'common/kubus_text_field.dart';
export 'empty_state_card.dart';
export 'glass_components.dart';
export 'inline_loading.dart';
export 'inline_progress.dart';
export 'kubus_button.dart';
export 'kubus_card.dart';
export 'kubus_snackbar.dart';
export 'search/kubus_search_bar.dart';
