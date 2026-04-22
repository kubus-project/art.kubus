import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';

class KubusWalletResponsiveShell extends StatelessWidget {
  const KubusWalletResponsiveShell({
    super.key,
    required this.mainChildren,
    this.sideChildren = const <Widget>[],
    this.wideBreakpoint = 1100,
    this.maxContentWidth = 1480,
    this.sidebarWidth = 360,
    this.padding,
  });

  final List<Widget> mainChildren;
  final List<Widget> sideChildren;
  final double wideBreakpoint;
  final double maxContentWidth;
  final double sidebarWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= wideBreakpoint;
        final resolvedPadding = padding ??
            EdgeInsets.all(isWide ? KubusSpacing.xl : KubusSpacing.lg);

        if (!isWide) {
          return SingleChildScrollView(
            padding: resolvedPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...mainChildren,
                if (sideChildren.isNotEmpty) ...<Widget>[
                  const SizedBox(height: KubusSpacing.lg),
                  ...sideChildren,
                ],
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: resolvedPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: mainChildren,
                      ),
                    ),
                  ),
                  if (sideChildren.isNotEmpty) ...<Widget>[
                    const SizedBox(width: KubusSpacing.xl),
                    SizedBox(
                      width: sidebarWidth,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sideChildren,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class KubusWalletSectionHeader extends StatelessWidget {
  const KubusWalletSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                subtitle,
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: KubusSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class KubusWalletSectionCard extends StatelessWidget {
  const KubusWalletSectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.headerTrailing,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
      borderRadius: borderRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null && subtitle != null) ...<Widget>[
            KubusWalletSectionHeader(
              title: title!,
              subtitle: subtitle!,
              trailing: headerTrailing,
            ),
            const SizedBox(height: KubusSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

class KubusWalletMetaPill extends StatelessWidget {
  const KubusWalletMetaPill({
    super.key,
    required this.label,
    this.icon,
    this.tintColor,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final Color? tintColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = tintColor ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: emphasized ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(
          color: baseColor.withValues(alpha: emphasized ? 0.26 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: baseColor),
            const SizedBox(width: KubusSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: KubusTextStyles.detailCaption.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KubusWalletActionCard extends StatelessWidget {
  const KubusWalletActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.minHeight = 144,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor =
        enabled ? color : scheme.onSurface.withValues(alpha: 0.34);

    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              effectiveColor.withValues(alpha: enabled ? 0.18 : 0.08),
              scheme.surface.withValues(alpha: enabled ? 0.58 : 0.42),
            ],
          ),
          border: Border.all(
            color: effectiveColor.withValues(alpha: enabled ? 0.24 : 0.16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: KubusChromeMetrics.heroIconBox,
                height: KubusChromeMetrics.heroIconBox,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: enabled ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(KubusRadius.lg),
                ),
                child: Icon(
                  icon,
                  color: effectiveColor,
                  size: KubusChromeMetrics.heroIcon,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: KubusTextStyles.detailCardTitle.copyWith(
                  color: enabled
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                subtitle,
                style: KubusTextStyles.detailBody.copyWith(
                  color: enabled
                      ? scheme.onSurface.withValues(alpha: 0.68)
                      : scheme.onSurface.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KubusWalletStatsStrip extends StatelessWidget {
  const KubusWalletStatsStrip({
    super.key,
    required this.items,
  });

  final List<KubusWalletStatsStripItem> items;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final defaultAccents = <Color>[
      roles.statAmber,
      roles.statTeal,
      roles.positiveAction,
      roles.warningAction,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final children = <Widget>[
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: !isNarrow && index < items.length - 1
                      ? KubusSpacing.md
                      : KubusSpacing.none,
                  bottom: isNarrow && index.isOdd
                      ? KubusSpacing.none
                      : KubusSpacing.none,
                ),
                child: _KubusWalletStatTile(
                  item: items[index],
                  accent: items[index].accent ??
                      defaultAccents[index % defaultAccents.length],
                ),
              ),
            ),
        ];

        if (!isNarrow) {
          return Row(children: children);
        }

        return Column(
          children: <Widget>[
            Row(
              children: children.take(2).toList(),
            ),
            if (items.length > 2) ...<Widget>[
              const SizedBox(height: KubusSpacing.md),
              Row(
                children: children.skip(2).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

class KubusWalletStatsStripItem {
  const KubusWalletStatsStripItem({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;
}

class _KubusWalletStatTile extends StatelessWidget {
  const _KubusWalletStatTile({
    required this.item,
    required this.accent,
  });

  final KubusWalletStatsStripItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.label,
            style: KubusTextStyles.statLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            item.value,
            style: KubusTextStyles.statValue.copyWith(
              color: scheme.onSurface,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
