import 'package:flutter/material.dart';

class AuthTitleRow extends StatelessWidget {
  const AuthTitleRow({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
    this.foregroundColor,
    this.subtitleColor,
  });

  final String title;
  final String? subtitle;
  final bool compact;
  final Color? foregroundColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final resolvedSubtitle = subtitle?.trim();
    final resolvedForeground = foregroundColor ?? scheme.onSurface;
    final resolvedSubtitleColor =
        subtitleColor ?? resolvedForeground.withValues(alpha: 0.78);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? 48 : 56,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 22 : 28,
                color: resolvedForeground,
                height: 1.02,
              ),
              maxLines: compact ? 3 : 2,
              overflow: TextOverflow.visible,
            ),
            if (resolvedSubtitle != null && resolvedSubtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                resolvedSubtitle,
                style: textTheme.bodyLarge?.copyWith(
                  color: resolvedSubtitleColor,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
