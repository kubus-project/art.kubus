import 'package:flutter/material.dart';

import '../../models/community_group.dart';
import '../../utils/design_tokens.dart';

class CommunityGroupPickerContent extends StatelessWidget {
  const CommunityGroupPickerContent({
    super.key,
    required this.title,
    required this.groups,
    required this.onSelect,
    required this.subtitleBuilder,
    this.showHandle = false,
    this.headerTrailing,
    this.footer,
    this.headerPadding = const EdgeInsets.fromLTRB(
      KubusSpacing.lg,
      KubusSpacing.lg,
      KubusSpacing.lg,
      KubusSpacing.sm,
    ),
    this.listPadding = const EdgeInsets.all(KubusSpacing.lg),
  });

  final String title;
  final List<CommunityGroupSummary> groups;
  final ValueChanged<CommunityGroupSummary> onSelect;
  final String Function(CommunityGroupSummary group) subtitleBuilder;
  final bool showHandle;
  final Widget? headerTrailing;
  final Widget? footer;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: KubusChromeMetrics.sheetHandleWidth,
              height: KubusChromeMetrics.sheetHandleHeight,
              margin: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(KubusRadius.xs),
              ),
            ),
          ),
        Padding(
          padding: headerPadding,
          child: Row(
            children: [
              Text(
                title,
                style: KubusTextStyles.sheetTitle
                    .copyWith(color: scheme.onSurface),
              ),
              const Spacer(),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
        ),
        if (!showHandle) const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: listPadding,
            itemCount: groups.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: scheme.outline.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  group.name,
                  style: KubusTypography.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  subtitleBuilder(group),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.navMetaLabel.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
                onTap: () => onSelect(group),
              );
            },
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}
