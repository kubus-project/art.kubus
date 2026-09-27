import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'kubus_button.dart';

/// Flat PRODUCT v5 empty/error state: a surface with a hairline rule, a
/// subtle icon, a title, one sentence of guidance and — only when the viewer
/// can actually perform it — one secondary next-step action. Never glass.

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool showAction;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticsLabel;

  const EmptyStateCard({
    super.key,
    this.icon = Icons.info_outline,
    required this.title,
    required this.description,
    this.showAction = false,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final radius = BorderRadius.circular(KubusRadius.surface);
    final resolvedSemanticsLabel = semanticsLabel ?? '$title. $description';

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        Widget content = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              // Center content both vertically and horizontally so the icon/text
              // do not hug the top or bottom when the card is placed in a fixed
              // height container (e.g. SizedBox).
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: roles.foregroundSubtle),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: roles.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: KubusTypography.textTheme.bodyMedium?.copyWith(
                    color: roles.foregroundMuted,
                    height: 1.4,
                  ),
                ),
                if (showAction && onAction != null && actionLabel != null) ...[
                  const SizedBox(height: KubusSpacing.md),
                  KubusButton(
                    onPressed: onAction,
                    label: actionLabel!,
                    variant: KubusButtonVariant.secondary,
                  ),
                ],
              ],
            ),
          ),
        );

        if (hasBoundedWidth || hasBoundedHeight) {
          // The surface below adds padding and a hairline; size the content
          // to what remains so a fixed-height slot never overflows.
          const horizontalInset = KubusSpacing.md * 2 + KubusSizes.hairline * 2;
          const verticalInset = KubusSpacing.lg * 2 + KubusSizes.hairline * 2;
          content = SizedBox(
            width: hasBoundedWidth
                ? (constraints.maxWidth - horizontalInset)
                    .clamp(0.0, double.infinity)
                : null,
            height: hasBoundedHeight
                ? (constraints.maxHeight - verticalInset)
                    .clamp(0.0, double.infinity)
                : null,
            child: content,
          );
        }

        return Semantics(
          container: true,
          explicitChildNodes: true,
          liveRegion: true,
          label: resolvedSemanticsLabel,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: KubusSpacing.lg,
              horizontal: KubusSpacing.md,
            ),
            decoration: BoxDecoration(
              color: roles.surface,
              borderRadius: radius,
              border: Border.all(
                color: roles.rule,
                width: KubusSizes.hairline,
              ),
            ),
            child: content,
          ),
        );
      },
    );
  }
}
