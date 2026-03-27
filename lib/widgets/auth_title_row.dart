import 'package:flutter/material.dart';

import 'common/kubus_screen_header.dart';
import '../utils/design_tokens.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final resolvedSubtitle = subtitle?.trim();
    final resolvedForeground = foregroundColor ?? scheme.onSurface;
    final resolvedSubtitleColor =
        subtitleColor ?? resolvedForeground.withValues(alpha: 0.78);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: KubusHeaderMetrics.actionHitArea +
            (compact ? KubusSpacing.xs : KubusSpacing.sm),
      ),
      child: SizedBox(
        width: double.infinity,
        child: KubusHeaderText(
          title: title,
          subtitle: resolvedSubtitle,
          kind: KubusHeaderKind.screen,
          titleColor: resolvedForeground,
          subtitleColor: resolvedSubtitleColor,
          maxTitleLines: compact ? 3 : 2,
        ),
      ),
    );
  }
}
