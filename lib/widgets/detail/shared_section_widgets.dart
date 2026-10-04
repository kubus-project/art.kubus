import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../empty_state_card.dart';
import '../inline_loading.dart';
import '../common/kubus_screen_header.dart';

/// Section title, optional subtitle and a trailing control. Typographic
/// only: the title names the section, so no glyph repeats it.
class SharedSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SharedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
              vertical: KubusSpacing.sm + KubusSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
