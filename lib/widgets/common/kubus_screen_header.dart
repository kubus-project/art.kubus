import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../artist_badge.dart';
import '../institution_badge.dart';

enum KubusHeaderKind { screen, section }

/// Shared greeting + identity block used by Home/Profile-style headers.
///
/// This is intentionally small and composable so both mobile and desktop
/// screens can reuse the same hierarchy (greeting -> bold name + badges ->
/// optional footer like a copyable wallet row).
class KubusGreetingIdentityBlock extends StatelessWidget {
  const KubusGreetingIdentityBlock({
    super.key,
    required this.greeting,
    required this.displayName,
    this.isArtist = false,
    this.isInstitution = false,
    this.compact = false,
    this.greetingStyle,
    this.displayNameStyle,
    this.maxNameLines = 1,
    this.footer,
    this.footerTopPadding,
  });

  final String greeting;
  final String displayName;
  final bool isArtist;
  final bool isInstitution;
  final bool compact;
  final TextStyle? greetingStyle;
  final TextStyle? displayNameStyle;
  final int maxNameLines;
  final Widget? footer;
  final double? footerTopPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final effectiveGreetingStyle = (greetingStyle ?? KubusTextStyles.navMetaLabel)
        .copyWith(color: scheme.onSurface.withValues(alpha: 0.62));
    final baseNameStyle = (displayNameStyle ?? KubusTextStyles.heroTitle)
        .copyWith(color: scheme.onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: effectiveGreetingStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: KubusSpacing.xxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final resolvedNameStyle = KubusTextStyles.responsiveTitleStyle(
                    context,
                    baseNameStyle,
                    availableWidth: availableWidth,
                    compact: true,
                  );
                  final effectiveLines = KubusTextStyles.responsiveTitleLines(
                    availableWidth,
                    maxLines: maxNameLines,
                    compact: compact,
                  );
                  return Text(
                    displayName,
                    style: resolvedNameStyle,
                    maxLines: effectiveLines,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  );
                },
              ),
            ),
            if (isArtist) ...[
              const SizedBox(width: KubusSpacing.sm),
              const ArtistBadge(iconOnly: true),
            ],
            if (isInstitution) ...[
              const SizedBox(width: KubusSpacing.sm),
              const InstitutionBadge(iconOnly: true),
            ],
          ],
        ),
        if (footer != null) ...[
          SizedBox(height: footerTopPadding ?? KubusSpacing.xs),
          footer!,
        ],
      ],
    );
  }
}

class KubusHeaderTitleBlock extends StatelessWidget {
  const KubusHeaderTitleBlock({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
    this.titleColor,
    this.subtitleColor,
    this.titleStyle,
    this.subtitleStyle,
    this.maxTitleLines = 2,
    this.maxSubtitleLines = 2,
    this.minHeight,
  });

  final String title;
  final String? subtitle;
  final bool compact;
  final Color? titleColor;
  final Color? subtitleColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final int maxTitleLines;
  final int maxSubtitleLines;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedSubtitle = subtitle?.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeight ??
            (compact
                ? KubusHeaderMetrics.compactHeaderMinHeight
                : KubusHeaderMetrics.headerMinHeight),
      ),
      child: SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : (MediaQuery.maybeOf(context)?.size.width ?? 360);
            final baseTitleStyle =
                (titleStyle ?? KubusTextStyles.screenTitle).copyWith(
              color: titleColor ?? scheme.onSurface,
            );
            final resolvedTitleStyle = KubusTextStyles.responsiveTitleStyle(
              context,
              baseTitleStyle,
              availableWidth: availableWidth,
              compact: compact,
            );
            final resolvedSubtitleStyle =
                (subtitleStyle ?? KubusTextStyles.screenSubtitle).copyWith(
              color: subtitleColor ?? scheme.onSurface.withValues(alpha: 0.72),
            );
            final effectiveTitleLines = KubusTextStyles.responsiveTitleLines(
              availableWidth,
              // Preserve the caller's requested line cap; responsive logic may
              // still relax ultra-narrow layouts for readability.
              maxLines: maxTitleLines,
              compact: compact,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: resolvedTitleStyle,
                  maxLines: effectiveTitleLines,
                  overflow: TextOverflow.ellipsis,
                ),
                if (resolvedSubtitle != null &&
                    resolvedSubtitle.isNotEmpty) ...[
                  SizedBox(
                    height: compact
                        ? KubusHeaderMetrics.sectionSubtitleGap
                        : KubusHeaderMetrics.subtitleGap,
                  ),
                  Text(
                    resolvedSubtitle,
                    style: resolvedSubtitleStyle,
                    maxLines: maxSubtitleLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class KubusHeaderText extends StatelessWidget {
  const KubusHeaderText({
    super.key,
    required this.title,
    this.subtitle,
    this.kind = KubusHeaderKind.screen,
    this.compact = false,
    this.titleColor,
    this.subtitleColor,
    this.titleStyle,
    this.subtitleStyle,
    this.maxTitleLines = 2,
    this.maxSubtitleLines = 2,
  });

  final String title;
  final String? subtitle;
  final KubusHeaderKind kind;
  final bool compact;
  final Color? titleColor;
  final Color? subtitleColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final int maxTitleLines;
  final int maxSubtitleLines;

  @override
  Widget build(BuildContext context) {
    final isSection = kind == KubusHeaderKind.section;
    final isMobileWidth = (MediaQuery.maybeOf(context)?.size.width ?? 0) < 900;
    final defaultTitleStyle = isSection
        ? KubusTextStyles.sectionTitle
        : (isMobileWidth
            ? KubusTextStyles.responsiveMobileAppBarTitle(context)
            : KubusTextStyles.responsiveScreenTitle(context));
    return KubusHeaderTitleBlock(
      title: title,
      subtitle: subtitle,
      compact: compact || isSection,
      titleColor: titleColor,
      subtitleColor: subtitleColor,
      titleStyle: titleStyle ?? defaultTitleStyle,
      subtitleStyle: subtitleStyle ??
          (isSection
              ? KubusTextStyles.sectionSubtitle
              : KubusTextStyles.screenSubtitle),
      maxTitleLines: isSection ? 1 : maxTitleLines,
      maxSubtitleLines: maxSubtitleLines,
      minHeight: isSection ? KubusHeaderMetrics.compactHeaderMinHeight : null,
    );
  }
}

class KubusSectionHeader extends StatelessWidget {
  const KubusSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.action,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedIconColor = iconColor ?? scheme.primary;

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
              vertical: KubusSpacing.sm + KubusSpacing.xxs),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: KubusHeaderMetrics.actionHitArea,
              height: KubusHeaderMetrics.actionHitArea,
              decoration: BoxDecoration(
                color: resolvedIconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
              child: Icon(
                icon,
                color: resolvedIconColor,
                size: KubusHeaderMetrics.actionIcon,
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
          ],
          Expanded(
            child: KubusHeaderTitleBlock(
              title: title,
              subtitle: subtitle,
              compact: true,
              titleStyle: titleStyle ?? KubusTextStyles.sectionTitle,
              subtitleStyle: subtitleStyle ?? KubusTextStyles.sectionSubtitle,
              minHeight: KubusHeaderMetrics.compactHeaderMinHeight,
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: KubusSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

class KubusScreenHeaderBar extends StatelessWidget {
  const KubusScreenHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.padding,
    this.compact = false,
    this.minHeight,
    this.titleStyle,
    this.subtitleStyle,
    this.titleColor,
    this.subtitleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool compact;
  final double? minHeight;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: KubusHeaderMetrics.appBarHorizontalPadding,
            vertical: KubusHeaderMetrics.appBarVerticalPadding,
          ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: KubusSpacing.sm),
          ],
          Expanded(
            child: KubusHeaderTitleBlock(
              title: title,
              subtitle: subtitle,
              compact: compact,
              minHeight: minHeight,
              titleStyle: titleStyle,
              subtitleStyle: subtitleStyle,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: KubusSpacing.sm),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

class KubusSheetHeader extends StatelessWidget {
  const KubusSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showHandle = true,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showHandle;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHandle)
            Align(
              alignment: Alignment.center,
              child: Container(
                width: KubusChromeMetrics.sheetHandleWidth,
                height: KubusChromeMetrics.sheetHandleHeight,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(KubusRadius.xs),
                ),
              ),
            ),
          if (showHandle) const SizedBox(height: KubusSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KubusHeaderTitleBlock(
                  title: title,
                  subtitle: subtitle,
                  compact: false,
                  titleStyle: titleStyle ?? KubusTextStyles.sheetTitle,
                  subtitleStyle: subtitleStyle ?? KubusTextStyles.sheetSubtitle,
                  minHeight: 0,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: KubusSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
