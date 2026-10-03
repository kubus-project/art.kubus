import 'package:flutter/material.dart';
import '../common/kubus_action_tile.dart';
import '../common/kubus_atmosphere.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

enum WalletActionType {
  send,
  receive,
  swap,
  secureWallet,
  restoreSigner,
  connectExternalWallet,
  createLocalWallet,
  importWallet,
  copyAddress,
  refresh,
  nfts,
}

class WalletActionConfig {
  const WalletActionConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.run,
    this.enabled = true,
    this.loading = false,
    this.disabledReason,
  });

  final WalletActionType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback run;
  final bool enabled;
  final bool loading;
  final String? disabledReason;
}

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
    final roles = KubusColorRoles.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: roles.foreground,
                  ),
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                subtitle,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: roles.foregroundMuted,
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
    this.accent,
    this.glyph,
    this.framed = true,
  });

  /// A section that holds destination tiles is a heading over them, not a
  /// card around them (tiles are cards already): pass `false` for no surface.
  final bool framed;

  /// Turns the section into an asset hero ([KubusAtmosphere]) in this
  /// colour. Only the balance section uses it; other sections stay flat.
  final Color? accent;
  final IconData? glyph;

  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final content = Column(
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
    );
    if (!framed) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: content,
      );
    }
    if (accent != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: KubusAtmosphere(
          accent: accent!,
          glyph: glyph,
          glyphAlignment: Alignment.topRight,
          glyphExtent: 150,
          borderRadius:
              borderRadius ?? BorderRadius.circular(KubusRadius.surface),
          padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
          child: content,
        ),
      );
    }
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius:
            borderRadius ?? BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule),
      ),
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

/// How a [KubusWalletMetaPill] colors its label.
///
/// - [neutral] keeps the label in `onSurface` and uses the tint only as a
///   backdrop — for metadata (address, timestamp, network).
/// - [accent] puts the label in the tint color itself — for status that has
///   to be readable as a state at a glance (finalized, failed, pending).
enum KubusWalletPillTone { neutral, accent }

/// The canonical wallet chip.
///
/// Every wallet status/meta pill routes through here so padding, height,
/// radius, and truncation stay identical across surfaces. Labels never wrap:
/// a chip that has to break a word is the wrong chip.
class KubusWalletMetaPill extends StatelessWidget {
  const KubusWalletMetaPill({
    super.key,
    required this.label,
    this.icon,
    this.tintColor,
    this.emphasized = false,
    this.tone = KubusWalletPillTone.neutral,
    this.dense = false,
    this.onTap,
    this.maxLabelWidth,
  });

  final String label;
  final IconData? icon;
  final Color? tintColor;
  final bool emphasized;
  final KubusWalletPillTone tone;

  /// Tighter horizontal padding for chips packed into a card header row.
  final bool dense;

  final VoidCallback? onTap;

  /// Clamps very long labels (addresses, signatures) so one chip cannot push
  /// the rest of a row off screen.
  final double? maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    // PRODUCT v5: flat chip. The tint colours only the icon, and the label
    // when the chip reports a state (accent tone); the fill is neutral.
    final baseColor = tintColor ?? roles.foregroundMuted;
    final labelColor =
        tone == KubusWalletPillTone.accent ? baseColor : roles.foreground;

    Widget labelText = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: KubusTextStyles.detailCaption.copyWith(
        color: labelColor,
        fontWeight: FontWeight.w600,
      ),
    );
    if (maxLabelWidth != null) {
      labelText = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxLabelWidth!),
        child: labelText,
      );
    }

    final pill = Container(
      constraints: const BoxConstraints(minHeight: KubusSizes.chipMinHeight),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? KubusSpacing.sm : KubusSpacing.md,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? roles.surfaceRaised : roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(
          color: emphasized ? baseColor : roles.rule,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: KubusSizes.chipIcon, color: baseColor),
            const SizedBox(width: KubusSpacing.xs),
          ],
          Flexible(child: labelText),
        ],
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        child: pill,
      ),
    );
  }
}

/// A wallet action (send, receive, swap, secure…): a destination, so it is
/// the dense [KubusActionTile] in the action's own colour.
class KubusWalletActionCard extends StatelessWidget {
  const KubusWalletActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.disabledReason,
    this.minHeight = KubusSizes.walletActionCardMinHeight,
  });

  factory KubusWalletActionCard.fromConfig({
    Key? key,
    required WalletActionConfig config,
    double minHeight = KubusSizes.walletActionCardMinHeight,
  }) {
    return KubusWalletActionCard(
      key: key,
      title: config.title,
      subtitle: config.subtitle,
      icon: config.icon,
      color: config.color,
      onTap: config.run,
      enabled: config.enabled,
      loading: config.loading,
      disabledReason: config.disabledReason,
      minHeight: minHeight,
    );
  }

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;
  final String? disabledReason;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    // A wallet action is a destination: the shared dense tile in the
    // action's own colour. Disabled cards explain why in the subtitle.
    final reason = (disabledReason ?? '').trim();
    return KubusActionTile(
      title: title,
      subtitle: !enabled && reason.isNotEmpty ? reason : subtitle,
      icon: icon,
      accent: color,
      onTap: onTap,
      enabled: enabled,
      loading: loading,
      layout: KubusActionTileLayout.compact,
      minHeight: minHeight,
    );
  }
}

class KubusWalletStatsStrip extends StatelessWidget {
  const KubusWalletStatsStrip({super.key, required this.items});

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
            Row(children: children.take(2).toList()),
            if (items.length > 2) ...<Widget>[
              const SizedBox(height: KubusSpacing.md),
              Row(children: children.skip(2).toList()),
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
  const _KubusWalletStatTile({required this.item, required this.accent});

  final KubusWalletStatsStripItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.label,
            style: KubusTextStyles.statLabel.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            item.value,
            style: KubusTextStyles.statValue.copyWith(
              color: roles.foreground,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
