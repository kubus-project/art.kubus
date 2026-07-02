import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../empty_state_card.dart';
import '../glass_components.dart';
import '../inline_loading.dart';
import '../common/kubus_screen_header.dart';

class SharedSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SharedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = iconColor ?? scheme.primary;

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
              vertical: KubusSpacing.sm + KubusSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: KubusHeaderMetrics.actionHitArea,
              height: KubusHeaderMetrics.actionHitArea,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: accent,
                  size: KubusHeaderMetrics.actionIcon,
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KubusHeaderText(
                  title: title,
                  subtitle: subtitle,
                  kind: KubusHeaderKind.section,
                  titleColor: scheme.onSurface,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SharedShowcaseSection<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final bool isLoading;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;
  final double loadingHeight;
  final double listHeight;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;
  final IconData? icon;
  final Color? iconColor;

  const SharedShowcaseSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.itemBuilder,
    this.isLoading = false,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
    this.loadingHeight = 160,
    this.listHeight = 210,
    this.spacing = 12,
    this.padding,
    this.trailing,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SharedSectionHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            trailing: trailing,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
          if (isLoading)
            SizedBox(
              height: loadingHeight,
              child: const Center(child: InlineLoading(expand: false)),
            )
          else if (items.isEmpty)
            EmptyStateCard(
              icon: emptyIcon,
              title: emptyTitle,
              description: emptyDescription,
            )
          else
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(width: spacing),
                itemBuilder: (context, index) =>
                    itemBuilder(context, items[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class SharedShowcaseCard extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String? footer;
  final Widget? subtitleWidget;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double width;
  final double imageHeight;
  final IconData placeholderIcon;
  final Widget? badge;
  final Alignment badgeAlignment;
  final EdgeInsetsGeometry contentPadding;
  final BorderRadius borderRadius;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? footerStyle;
  final int? titleMaxLines;
  final int? subtitleMaxLines;
  final int? footerMaxLines;

  const SharedShowcaseCard({
    super.key,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    this.footer,
    this.subtitleWidget,
    this.onTap,
    this.semanticLabel,
    this.width = 200,
    this.imageHeight = 110,
    this.placeholderIcon = Icons.image_outlined,
    this.badge,
    this.badgeAlignment = Alignment.topLeft,
    this.contentPadding = const EdgeInsets.all(KubusSpacing.md),
    this.borderRadius = const BorderRadius.all(Radius.circular(KubusRadius.lg)),
    this.titleStyle,
    this.subtitleStyle,
    this.footerStyle,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.footerMaxLines = 2,
  });

  @override
  State<SharedShowcaseCard> createState() => _SharedShowcaseCardState();
}

class _SharedShowcaseCardState extends State<SharedShowcaseCard> {
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _activate() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalizedImage =
        MediaUrlResolver.resolveDisplayUrl(widget.imageUrl) ??
            MediaUrlResolver.resolve(widget.imageUrl) ??
            widget.imageUrl;
    final radius = widget.borderRadius;
    final active = _enabled && (_hovered || _focused);
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );

    final card = SizedBox(
      width: widget.width,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active
                ? scheme.primary.withValues(alpha: _focused ? 0.76 : 0.42)
                : scheme.outline.withValues(alpha: 0.14),
            width: _focused ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.10 : 0.08,
              ),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            if (active)
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: LiquidGlassCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: radius,
          blurSigma: style.blurSigma,
          showBorder: false,
          backgroundColor: style.tintColor,
          fallbackMinOpacity: style.fallbackMinOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: widget.imageHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: widget.borderRadius.topLeft,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (normalizedImage != null && normalizedImage.isNotEmpty)
                        Image.network(
                          normalizedImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(context),
                        )
                      else
                        _buildPlaceholder(context),
                      if (widget.badge != null)
                        Positioned.fill(
                          child: Align(
                            alignment: widget.badgeAlignment,
                            child: Padding(
                              padding: const EdgeInsets.all(KubusSpacing.sm),
                              child: widget.badge!,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: widget.contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: widget.titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: widget.titleStyle ??
                          KubusTextStyles.sectionTitle.copyWith(
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: KubusSpacing.xxs),
                    if (widget.subtitleWidget != null)
                      widget.subtitleWidget!
                    else
                      Text(
                        widget.subtitle,
                        maxLines: widget.subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: widget.subtitleStyle ??
                            KubusTextStyles.navMetaLabel.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    if (widget.footer != null) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      Text(
                        widget.footer!,
                        maxLines: widget.footerMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: widget.footerStyle ??
                            KubusTextStyles.detailCaption.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.72),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_enabled) {
      return card;
    }

    final interactiveCard = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (hovered) {
        if (_hovered == hovered) return;
        setState(() => _hovered = hovered);
      },
      onShowFocusHighlight: (focused) {
        if (_focused == focused) return;
        setState(() => _focused = focused);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _activate,
        child: card,
      ),
    );

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? _defaultSemanticLabel(),
      onTap: _activate,
      child: ExcludeSemantics(
        child: interactiveCard,
      ),
    );
  }

  String _defaultSemanticLabel() {
    final parts = <String>[
      widget.title,
      widget.subtitle,
      if ((widget.footer ?? '').trim().isNotEmpty) widget.footer!.trim(),
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);
    return parts.join(', ');
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.34),
            scheme.surfaceContainerHigh.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          widget.placeholderIcon,
          size: 48,
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
