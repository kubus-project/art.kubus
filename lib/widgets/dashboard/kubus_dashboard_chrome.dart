import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_atmosphere.dart';
import '../inline_loading.dart';

/// PRODUCT v5 chrome for the advanced dashboards (Artist Studio, Institution
/// Hub, DAO). Flat surfaces, hairline rules, a structural notion line, and
/// semantic status tones instead of per-feature accent tints. No glass, no
/// tinted icon tiles, no gradients.

/// Status tone for role/application and proposal states.
enum KubusStatusTone { neutral, positive, warning, negative }

Color kubusStatusToneColor(KubusColorRoles roles, KubusStatusTone tone) {
  return switch (tone) {
    KubusStatusTone.neutral => roles.foregroundMuted,
    KubusStatusTone.positive => roles.success,
    KubusStatusTone.warning => roles.warning,
    KubusStatusTone.negative => roles.error,
  };
}

/// Flat structural notion line (Space Mono, uppercase by role).
class KubusNotionLabel extends StatelessWidget {
  const KubusNotionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: KubusTextStyles.structuralLabel.copyWith(
          color: color ?? roles.foregroundMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Dashboard page header: notion, title, lede and optional quiet actions.
///
/// With an [accent] (the hub's semantic colour: studio coral, institution
/// blue, governance green, marketplace orange) the header becomes the hub's
/// identity band: a [KubusAtmosphere] with the hub [glyph] cropped in the
/// trailing corner. The glyph is the band's one identity device; the text
/// column starts at the band's leading edge with no icon tile beside it.
/// Without an accent it stays the flat notion/title/lede block.
class KubusDashboardHeader extends StatelessWidget {
  const KubusDashboardHeader({
    super.key,
    required this.notion,
    required this.title,
    this.lede,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.fromLTRB(
      KubusSpacing.md,
      KubusSpacing.md,
      KubusSpacing.md,
      KubusSpacing.sm,
    ),
    this.accent,
    this.glyph,
  });

  /// Hub colour from [KubusColorRoles]; turns on the identity band.
  final Color? accent;

  /// Hub symbol, drawn as the band's cropped ghost glyph.
  final IconData? glyph;

  final String notion;
  final String title;
  final String? lede;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KubusNotionLabel(notion),
        const SizedBox(height: KubusSpacing.xs),
        Semantics(
          header: true,
          child: Text(
            title,
            style: (accent == null
                    ? KubusTextStyles.entityTitle
                    : KubusTextStyles.entityTitle.copyWith(fontSize: 24))
                .copyWith(color: roles.foreground),
          ),
        ),
        if (lede != null && lede!.trim().isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.xs),
          Text(
            lede!,
            style: KubusTextStyles.detailBody.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.sm),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xs,
            children: actions,
          ),
        ],
      ],
    );

    // Full width so a centring parent column never floats the header away
    // from the tabs and content below it.
    if (accent == null) {
      return SizedBox(
        width: double.infinity,
        child: Padding(padding: padding, child: textColumn),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: padding,
        child: KubusAtmosphere(
          key: const ValueKey<String>('kubus_dashboard_identity'),
          accent: accent!,
          glyph: glyph,
          glyphAlignment: Alignment.bottomRight,
          glyphExtent: 136,
          padding: const EdgeInsets.all(KubusSpacing.md + KubusSpacing.xs),
          // Keep the text clear of the glyph's corner: the cropped symbol is
          // decoration and never sits behind the lede.
          child: Padding(
            padding: EdgeInsets.only(right: glyph == null ? 0 : 72),
            child: textColumn,
          ),
        ),
      ),
    );
  }
}

/// Role / application status: a flat panel with a status-toned leading rule,
/// the status as text (never colour alone), optional detail, one action.
class KubusStatusPanel extends StatelessWidget {
  const KubusStatusPanel({
    super.key,
    required this.title,
    required this.description,
    this.statusLabel,
    this.tone = KubusStatusTone.neutral,
    this.isLoading = false,
    this.meta,
    this.detail,
    this.action,
    this.margin = const EdgeInsets.symmetric(
      horizontal: KubusSpacing.md,
      vertical: KubusSpacing.sm,
    ),
  });

  final String title;
  final String description;
  final String? statusLabel;
  final KubusStatusTone tone;
  final bool isLoading;

  /// Secondary status line (for example "Synced from DAO").
  final String? meta;
  final String? detail;
  final Widget? action;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final toneColor = kubusStatusToneColor(roles, tone);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: toneColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: KubusTextStyles.detailCardTitle.copyWith(
              color: roles.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            description,
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
          if (statusLabel != null || isLoading) ...[
            const SizedBox(height: KubusSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.xs,
              children: [
                if (statusLabel != null)
                  KubusStatusText(label: statusLabel!, tone: tone),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: InlineLoading(
                      expand: true,
                      shape: BoxShape.circle,
                      tileSize: 3,
                    ),
                  )
                else if (meta != null)
                  Text(
                    meta!,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
              ],
            ),
          ],
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              detail!,
              style: KubusTextStyles.detailBody.copyWith(
                color: roles.foreground,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: KubusSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Status as a dot plus a structural label; the text carries the meaning.
class KubusStatusText extends StatelessWidget {
  const KubusStatusText({super.key, required this.label, required this.tone});

  final String label;
  final KubusStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final color = kubusStatusToneColor(roles, tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: KubusTextStyles.structuralLabel.copyWith(
              color: roles.foreground,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// One tab of [KubusDashboardTabs].
class KubusDashboardTab {
  const KubusDashboardTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Flat dashboard tabs: equal-width items, 48 px targets, the selected item
/// marked by foreground weight and an active underline (not a colour fill).
/// Locked tabs stay focusable and explain why through [onLockedTap].
class KubusDashboardTabs extends StatelessWidget {
  const KubusDashboardTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.enabled = true,
    this.onLockedTap,
    this.margin = const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
  });

  final List<KubusDashboardTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool enabled;
  final VoidCallback? onLockedTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: roles.rule)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _DashboardTabButton(
                tab: tabs[i],
                selected: i == selectedIndex,
                enabled: enabled,
                onTap: enabled ? () => onSelected(i) : onLockedTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardTabButton extends StatelessWidget {
  const _DashboardTabButton({
    required this.tab,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final KubusDashboardTab tab;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final foreground = !enabled
        ? roles.foregroundSubtle
        : (selected ? roles.foreground : roles.foregroundMuted);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        focusColor: roles.focus.withValues(alpha: 0.12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.xs,
            vertical: KubusSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected && enabled ? roles.active : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(tab.icon, size: 20, color: foreground),
              ),
              const SizedBox(height: KubusSpacing.xxs),
              Text(
                tab.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: KubusTypography.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explanation banner (role conflicts, restrictions): flat, a warning or
/// negative leading rule, icon + title + message.
class KubusNoticeBanner extends StatelessWidget {
  const KubusNoticeBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.tone = KubusStatusTone.warning,
    this.margin = const EdgeInsets.symmetric(
      horizontal: KubusSpacing.md,
      vertical: KubusSpacing.sm,
    ),
  });

  final String title;
  final String message;
  final IconData icon;
  final KubusStatusTone tone;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final color = kubusStatusToneColor(roles, tone);
    return Semantics(
      container: true,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: roles.surface,
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          border: Border.all(color: roles.rule),
        ),
        foregroundDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KubusTextStyles.detailCardTitle.copyWith(
                      color: roles.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    message,
                    style: KubusTextStyles.detailBody.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading for dashboard side panels: notion + optional caption.
class KubusPanelSection extends StatelessWidget {
  const KubusPanelSection({
    super.key,
    required this.notion,
    required this.children,
    this.caption,
    this.spacing = KubusSpacing.sm,
  });

  final String notion;
  final String? caption;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KubusNotionLabel(notion),
        if (caption != null) ...[
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            caption!,
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
        ],
        const SizedBox(height: KubusSpacing.sm),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}

/// Pending-count badge (machine value) for side-panel rows.
class KubusCountBadge extends StatelessWidget {
  const KubusCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.xs + KubusSpacing.xxs,
        vertical: KubusSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: roles.active,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: KubusTextStyles.machineValue.copyWith(
          color: roles.onActive,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
