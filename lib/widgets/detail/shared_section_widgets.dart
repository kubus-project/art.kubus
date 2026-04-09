import 'package:flutter/material.dart';

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
          const EdgeInsets.symmetric(vertical: KubusSpacing.sm + KubusSpacing.xxs),
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
                itemBuilder: (context, index) => itemBuilder(context, items[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class SharedShowcaseCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String? footer;
  final Widget? subtitleWidget;
  final VoidCallback? onTap;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalizedImage = MediaUrlResolver.resolveDisplayUrl(imageUrl) ??
        MediaUrlResolver.resolve(imageUrl) ??
        imageUrl;
    final radius = borderRadius;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.14),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.10 : 0.08,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
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
                    height: imageHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: borderRadius.topLeft,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (normalizedImage != null && normalizedImage.isNotEmpty)
                            Image.network(
                              normalizedImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                            )
                          else
                            _buildPlaceholder(context),
                          if (badge != null)
                            Positioned.fill(
                              child: Align(
                                alignment: badgeAlignment,
                                child: Padding(
                                  padding: const EdgeInsets.all(KubusSpacing.sm),
                                  child: badge!,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: contentPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle ??
                              KubusTextStyles.sectionTitle.copyWith(
                                color: scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: KubusSpacing.xxs),
                        if (subtitleWidget != null)
                          subtitleWidget!
                        else
                          Text(
                            subtitle,
                            maxLines: subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle ??
                                KubusTextStyles.navMetaLabel.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.6),
                                ),
                          ),
                        if (footer != null) ...[
                          const SizedBox(height: KubusSpacing.sm),
                          Text(
                            footer!,
                            maxLines: footerMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: footerStyle ??
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
        ),
      ),
    );
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
          placeholderIcon,
          size: 48,
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
