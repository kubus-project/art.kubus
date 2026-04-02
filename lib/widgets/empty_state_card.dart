import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool showAction;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateCard({
    super.key,
    this.icon = Icons.info_outline,
    required this.title,
    required this.description,
    this.showAction = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(KubusRadius.lg);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

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
                Icon(
                  icon,
                  size: 48,
                  color: scheme.onSurface.withAlpha((0.32 * 255).round()),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: KubusTypography.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withAlpha((0.6 * 255).round()),
                  ),
                ),
                if (showAction && onAction != null && actionLabel != null) ...[
                  const SizedBox(height: KubusSpacing.sm),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        );

        if (hasBoundedWidth || hasBoundedHeight) {
          content = SizedBox(
            width: hasBoundedWidth ? constraints.maxWidth : null,
            height: hasBoundedHeight ? constraints.maxHeight : null,
            child: content,
          );
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.14),
            ),
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(
              vertical: KubusSpacing.lg,
              horizontal: KubusSpacing.md,
            ),
            margin: EdgeInsets.zero,
            borderRadius: radius,
            showBorder: false,
            backgroundColor: glassTint,
            child: content,
          ),
        );
      },
    );
  }
}
