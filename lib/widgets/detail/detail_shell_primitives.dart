import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';
import 'detail_shell_sections.dart';
import 'detail_shell_tokens.dart';

/// A unified card component for detail screens with consistent styling.
class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showBorder;
  final double borderRadius;
  final VoidCallback? onTap;

  const DetailCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
    this.borderRadius = DetailRadius.md,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final radius = BorderRadius.circular(borderRadius);
    final glassTint = (backgroundColor ?? scheme.surface)
        .withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35))
            : null,
      ),
      child: LiquidGlassPanel(
        padding: padding ?? const EdgeInsets.all(DetailSpacing.lg),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// A section header with optional action button.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KubusHeaderText(
            title: title,
            kind: KubusHeaderKind.section,
          ),
        ),
        if (trailing != null) trailing!,
        if (onAction != null && trailing == null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(
              actionIcon ?? Icons.arrow_forward,
              size: KubusHeaderMetrics.actionIcon,
            ),
            label: Text(
              actionLabel ?? '',
              style: DetailTypography.button(context),
            ),
          ),
      ],
    );
  }
}

/// An info row with icon and label.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final TextStyle? labelStyle;
  final Color? iconColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.labelStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DetailSpacing.sm),
      child: Row(
        children: [
          Icon(
            icon,
            size: KubusHeaderMetrics.actionIcon,
            color: iconColor ?? scheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: DetailSpacing.sm),
          Expanded(
            child: Text(
              value != null ? '$label: $value' : label,
              style: labelStyle ?? DetailTypography.caption(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stat chip for displaying counts/metrics inline.
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.md,
        vertical: DetailSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DetailRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: DetailSpacing.xs),
          Text(
            value,
            style: KubusTextStyles.navMetaLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: DetailSpacing.xs),
            Text(
              label!,
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: effectiveColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A unified action button for detail screens with consistent styling.
class DetailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const DetailActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveActiveColor = activeColor ?? scheme.primary;

    final isEnabled = onPressed != null;
    final bgColor = backgroundColor ??
        (isActive
            ? effectiveActiveColor.withValues(alpha: isDark ? 0.22 : 0.16)
            : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10));
    final fgColor =
        foregroundColor ?? (isActive ? effectiveActiveColor : scheme.onSurface);

    final radius = BorderRadius.circular(DetailRadius.md);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isActive
              ? effectiveActiveColor.withValues(alpha: 0.28)
              : scheme.outlineVariant
                  .withValues(alpha: isEnabled ? 0.35 : 0.22),
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          vertical: DetailSpacing.md,
          horizontal: DetailSpacing.lg,
        ),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: bgColor,
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: DetailSpacing.sm),
            Flexible(
              child: Text(
                label,
                style:
                    DetailTypography.button(context).copyWith(color: fgColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailPrimaryCtaButton extends StatelessWidget {
  const DetailPrimaryCtaButton({
    super.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    this.foregroundColor,
    this.iconSize = 20,
    this.padding = const EdgeInsets.symmetric(
      vertical: 14,
      horizontal: 12,
    ),
    this.borderRadius = KubusRadius.md,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    // WCAG-optimal resolver (shared with the theme's on* pairs); the previous
    // estimateBrightnessForColor heuristic picked white on mid-tone accents
    // like amber gold, which lands below AA contrast.
    final resolvedForeground =
        foregroundColor ?? AppColorUtils.onColor(backgroundColor);

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: resolvedForeground,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DetailMetaItem {
  const DetailMetaItem({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
}

class DetailMetadataBlock extends StatelessWidget {
  const DetailMetadataBlock({
    super.key,
    required this.items,
    this.compact = false,
    this.spacing,
  });

  final List<DetailMetaItem> items;
  final bool compact;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dense = compact;
    final rowSpacing = spacing ?? (dense ? DetailSpacing.sm : DetailSpacing.md);

    final visible = items
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  visible[i].icon,
                  size: dense ? 15 : 16,
                  color: visible[i].iconColor ??
                      scheme.onSurfaceVariant.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(width: DetailSpacing.sm),
              Expanded(
                child: Text(
                  visible[i].label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DetailTypography.caption(context).copyWith(
                    fontSize: dense
                        ? KubusHeaderMetrics.sectionSubtitle - 2
                        : KubusHeaderMetrics.sectionSubtitle - 1,
                    color: scheme.onSurfaceVariant,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
          if (i < visible.length - 1) SizedBox(height: rowSpacing),
        ],
      ],
    );
  }
}

class DetailContextItem {
  const DetailContextItem({
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String? label;
  final Color? color;
}

class DetailContextCluster extends StatelessWidget {
  const DetailContextCluster({
    super.key,
    required this.items,
    this.spacing = DetailSpacing.sm,
    this.runSpacing = DetailSpacing.sm,
    this.compact = false,
  });

  final List<DetailContextItem> items;
  final double spacing;
  final double runSpacing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = items
        .where((item) => item.value.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    final padH = compact ? DetailSpacing.sm : DetailSpacing.md;
    final padV = compact ? DetailSpacing.xs : DetailSpacing.sm;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final item in visible)
          Container(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.28 : 0.46,
              ),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.26),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: compact ? 14 : 15,
                  color: item.color ?? scheme.onSurfaceVariant,
                ),
                const SizedBox(width: DetailSpacing.xs),
                Text(
                  item.value,
                  style: DetailTypography.button(context).copyWith(
                    fontSize: compact
                        ? KubusHeaderMetrics.sectionSubtitle - 2
                        : KubusHeaderMetrics.sectionSubtitle - 1,
                    color: item.color ?? scheme.onSurface,
                  ),
                ),
                if ((item.label ?? '').trim().isNotEmpty) ...[
                  const SizedBox(width: DetailSpacing.xs),
                  Text(
                    item.label!,
                    style: DetailTypography.label(context).copyWith(
                      fontSize: compact
                          ? KubusHeaderMetrics.sectionSubtitle - 3
                          : KubusHeaderMetrics.sectionSubtitle - 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class DetailSecondaryAction {
  const DetailSecondaryAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.activeColor,
    this.tooltip,
    this.semanticsLabel,
    this.pinned = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;
  final String? tooltip;
  final String? semanticsLabel;

  /// A pinned action leads its cluster and is never moved behind the More
  /// control, so the one action a person most needs (directions) is never
  /// hidden by a cap.
  final bool pinned;
}

/// The actions a [DetailSecondaryActionCluster] shows, and the ones it moves
/// behind an explicit More control. Nothing is cut silently.
///
/// Rules, in order: an action without a label has nothing to say and is
/// dropped; pinned actions lead and are always shown, even past the cap; when
/// everything fits in [maxVisible] nothing overflows; otherwise one slot is
/// reserved for the More control and the remaining slots take the unpinned
/// actions in their given order.
({List<DetailSecondaryAction> shown, List<DetailSecondaryAction> overflow})
    partitionDetailSecondaryActions(
  List<DetailSecondaryAction> actions, {
  required int maxVisible,
}) {
  final labelled = actions
      .where((action) => action.label.trim().isNotEmpty)
      .toList(growable: false);
  final pinned = labelled.where((action) => action.pinned).toList();
  final unpinned = labelled.where((action) => !action.pinned).toList();
  final ordered = <DetailSecondaryAction>[...pinned, ...unpinned];
  if (ordered.length <= maxVisible) {
    return (shown: ordered, overflow: const <DetailSecondaryAction>[]);
  }
  var freeSlots = maxVisible - 1 - pinned.length;
  if (freeSlots < 0) freeSlots = 0;
  final shown = <DetailSecondaryAction>[
    ...pinned,
    ...unpinned.take(freeSlots),
  ];
  final overflow = ordered
      .where((action) => !shown.any((kept) => identical(kept, action)))
      .toList(growable: false);
  return (shown: shown, overflow: overflow);
}

/// How a [DetailSecondaryActionCluster] lays its actions out.
enum DetailSecondaryActionLayout {
  /// Labeled pills that wrap onto further lines.
  wrap,

  /// Equal-width tiles, [DetailSecondaryActionCluster.columns] to a row, each
  /// with its icon above its label. Every action sits in a predictable row
  /// instead of wrapping onto a line that can fall below the fold.
  grid,
}

class DetailSectionLabel extends StatelessWidget {
  const DetailSectionLabel({
    super.key,
    required this.label,
    this.bottomSpacing = DetailSpacing.xs,
    this.fontWeight = FontWeight.w700,
  });

  final String label;
  final double? bottomSpacing;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DetailTypography.label(context).copyWith(
            fontWeight: fontWeight,
          ),
        ),
        if (bottomSpacing != null && bottomSpacing! > 0)
          SizedBox(height: bottomSpacing),
      ],
    );
  }
}

enum DetailActionLabelPosition {
  beforePrimary,
  afterPrimary,
}

class DetailActionsSection extends StatelessWidget {
  const DetailActionsSection({
    super.key,
    required this.title,
    required this.actions,
    this.primaryAction,
    this.maxVisibleActions = 4,
    this.secondaryLayout = DetailSecondaryActionLayout.wrap,
    this.labelPosition = DetailActionLabelPosition.beforePrimary,
    this.labelBottomSpacing = DetailSpacing.xs,
    this.primaryBottomSpacing = DetailSpacing.sm,
    this.primaryToLabelSpacing = DetailSpacing.md,
  });

  final String title;
  final List<DetailSecondaryAction> actions;
  final Widget? primaryAction;
  final int maxVisibleActions;
  final DetailSecondaryActionLayout secondaryLayout;
  final DetailActionLabelPosition labelPosition;
  final double? labelBottomSpacing;
  final double? primaryBottomSpacing;
  final double? primaryToLabelSpacing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (labelPosition == DetailActionLabelPosition.beforePrimary) {
      children.add(
        DetailSectionLabel(
          label: title,
          bottomSpacing: labelBottomSpacing,
        ),
      );
      if (primaryAction != null) {
        children.add(primaryAction!);
        if (primaryBottomSpacing != null && primaryBottomSpacing! > 0) {
          children.add(SizedBox(height: primaryBottomSpacing));
        }
      }
    } else {
      if (primaryAction != null) {
        children.add(primaryAction!);
        if (primaryToLabelSpacing != null && primaryToLabelSpacing! > 0) {
          children.add(SizedBox(height: primaryToLabelSpacing));
        }
      }
      children.add(
        DetailSectionLabel(
          label: title,
          bottomSpacing: labelBottomSpacing,
        ),
      );
    }

    children.add(
      DetailSecondaryActionCluster(
        maxVisible: maxVisibleActions,
        actions: actions,
        layout: secondaryLayout,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class DetailSecondaryActionCluster extends StatelessWidget {
  const DetailSecondaryActionCluster({
    super.key,
    required this.actions,
    this.maxVisible = 4,
    this.layout = DetailSecondaryActionLayout.wrap,
    this.columns = 3,
  });

  final List<DetailSecondaryAction> actions;
  final int maxVisible;
  final DetailSecondaryActionLayout layout;

  /// Tiles per row for [DetailSecondaryActionLayout.grid].
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final parts = partitionDetailSecondaryActions(
      actions,
      maxVisible: maxVisible,
    );
    if (parts.shown.isEmpty && parts.overflow.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;

    switch (layout) {
      case DetailSecondaryActionLayout.wrap:
        return Wrap(
          spacing: DetailSpacing.sm,
          runSpacing: DetailSpacing.sm,
          children: [
            for (final action in parts.shown)
              _QuietActionButton(
                action: action,
                scheme: scheme,
                isDark: isDark,
              ),
            if (parts.overflow.isNotEmpty)
              _MoreActionsButton(
                actions: parts.overflow,
                scheme: scheme,
                isDark: isDark,
                tooltip: l10n.commonMore,
                stacked: false,
              ),
          ],
        );
      case DetailSecondaryActionLayout.grid:
        final tiles = <Widget>[
          for (final action in parts.shown)
            _GridActionCell(action: action, scheme: scheme, isDark: isDark),
          if (parts.overflow.isNotEmpty)
            _MoreActionsButton(
              actions: parts.overflow,
              scheme: scheme,
              isDark: isDark,
              tooltip: l10n.commonMore,
              stacked: true,
            ),
        ];
        return _TileGrid(columns: columns < 1 ? 1 : columns, tiles: tiles);
    }
  }
}

/// Rows of equal-width tiles. Every row is as tall as its tallest tile, and a
/// short last row keeps the same column widths as the full rows above it.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.columns, required this.tiles});

  final int columns;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += columns) {
      final rowTiles = tiles.skip(start).take(columns).toList(growable: false);
      if (rows.isNotEmpty) rows.add(const SizedBox(height: DetailSpacing.sm));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: DetailSpacing.sm),
                Expanded(
                  child: i < rowTiles.length
                      ? rowTiles[i]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// One secondary action in the grid. A quiet cell like [_QuietActionButton], not
/// a destination card: destinations are `KubusActionTile`.
class _GridActionCell extends StatelessWidget {
  const _GridActionCell({
    required this.action,
    required this.scheme,
    required this.isDark,
  });

  final DetailSecondaryAction action;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor = action.activeColor ?? scheme.primary;
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DetailRadius.md),
        onTap: action.onTap,
        child: _ActionFace(
          icon: action.icon,
          label: action.label,
          stacked: true,
          isActive: action.isActive,
          activeColor: activeColor,
          scheme: scheme,
          isDark: isDark,
        ),
      ),
    );
    return _describeAction(action, tile);
  }
}

class _MoreActionsButton extends StatelessWidget {
  const _MoreActionsButton({
    required this.actions,
    required this.scheme,
    required this.isDark,
    required this.tooltip,
    required this.stacked,
  });

  /// Overflow actions in display order. Selecting one invokes its [onTap].
  final List<DetailSecondaryAction> actions;
  final ColorScheme scheme;
  final bool isDark;
  final String tooltip;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final face = _ActionFace(
      icon: Icons.more_horiz,
      label: tooltip,
      stacked: stacked,
      isActive: false,
      activeColor: scheme.primary,
      scheme: scheme,
      isDark: isDark,
    );
    return PopupMenuButton<int>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      onSelected: (index) => actions[index].onTap?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onTap != null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actions[i].icon, size: 18),
                const SizedBox(width: DetailSpacing.sm),
                Text(actions[i].label),
              ],
            ),
          ),
      ],
      child: face,
    );
  }
}

/// The shared surface of a quiet action: an icon and label in one pill or, for
/// the grid, an icon above a label in a tile.
class _ActionFace extends StatelessWidget {
  const _ActionFace({
    required this.icon,
    required this.label,
    required this.stacked,
    required this.isActive,
    required this.activeColor,
    required this.scheme,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool stacked;
  final bool isActive;
  final Color activeColor;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? activeColor : scheme.onSurfaceVariant;
    final labelStyle = DetailTypography.button(context).copyWith(
      color: fg,
      fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
    );
    final iconWidget = Icon(icon, size: stacked ? 18 : 16, color: fg);
    final text = Text(
      label,
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      textAlign: stacked ? TextAlign.center : TextAlign.start,
      style: labelStyle,
    );
    return Container(
      padding: stacked
          ? const EdgeInsets.symmetric(
              horizontal: DetailSpacing.xs,
              vertical: DetailSpacing.sm,
            )
          : const EdgeInsets.symmetric(
              horizontal: DetailSpacing.md,
              vertical: DetailSpacing.sm,
            ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DetailRadius.md),
        color: isActive
            ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
            : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10),
        border: Border.all(
          color: isActive
              ? activeColor.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(height: DetailSpacing.xs),
                text,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: DetailSpacing.xs),
                text,
              ],
            ),
    );
  }
}

/// Gives a grid tile its spoken label, activation and tooltip. The tile's own
/// semantics are excluded so the label is spoken once, as a button.
///
/// The spoken label is the explicit semantics label, else the tooltip, else the
/// visible label. The visible label can be a bare count ("12"), which is not
/// something to read aloud on its own.
Widget _describeAction(DetailSecondaryAction action, Widget child) {
  var described = child;
  final semanticsLabel = (action.semanticsLabel ?? '').trim();
  final tooltip = (action.tooltip ?? '').trim();
  final spoken = semanticsLabel.isNotEmpty
      ? semanticsLabel
      : (tooltip.isNotEmpty ? tooltip : action.label);
  described = Semantics(
    container: true,
    button: true,
    enabled: action.onTap != null,
    focusable: action.onTap != null,
    label: spoken,
    onTap: action.onTap,
    child: ExcludeSemantics(child: described),
  );
  if ((action.tooltip ?? '').trim().isNotEmpty) {
    described = Tooltip(message: action.tooltip!, child: described);
  }
  return described;
}

class _QuietActionButton extends StatelessWidget {
  const _QuietActionButton({
    required this.action,
    required this.scheme,
    required this.isDark,
  });

  final DetailSecondaryAction action;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor = action.activeColor ?? scheme.primary;
    final fg = action.isActive ? activeColor : scheme.onSurfaceVariant;

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DetailRadius.md),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DetailSpacing.md,
            vertical: DetailSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DetailRadius.md),
            color: action.isActive
                ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
                : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10),
            border: Border.all(
              color: action.isActive
                  ? activeColor.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 16, color: fg),
              const SizedBox(width: DetailSpacing.xs),
              Text(
                action.label,
                style: DetailTypography.button(context).copyWith(
                  color: fg,
                  fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if ((action.semanticsLabel ?? '').trim().isNotEmpty) {
      button = Semantics(
        label: action.semanticsLabel,
        button: true,
        child: button,
      );
    }

    if ((action.tooltip ?? '').trim().isNotEmpty) {
      button = Tooltip(message: action.tooltip!, child: button);
    }

    return button;
  }
}

class DetailIdentityBlock extends StatelessWidget {
  const DetailIdentityBlock({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.trailing,
    this.titleStyle,
  });

  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((kicker ?? '').trim().isNotEmpty) ...[
                Text(
                  kicker!,
                  style: DetailTypography.label(context).copyWith(
                    fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: roles.foregroundMuted,
                  ),
                ),
                const SizedBox(height: DetailSpacing.xs),
              ],
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: titleStyle ??
                    DetailTypography.screenTitle(context).copyWith(
                      fontSize: KubusHeaderMetrics.screenTitle,
                      height: 1.16,
                    ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: DetailSpacing.sm),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DetailTypography.caption(context).copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DetailSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class DetailManagementSection extends StatelessWidget {
  const DetailManagementSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DetailCard(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
      child: DetailSection(
        title: title,
        collapsible: true,
        initiallyExpanded: initiallyExpanded,
        child: child,
      ),
    );
  }
}
