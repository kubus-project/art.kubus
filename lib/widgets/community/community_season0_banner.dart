import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

enum CommunitySeason0BannerVariant {
  mobile,
  desktop,
}

class CommunitySeason0Banner extends StatelessWidget {
  const CommunitySeason0Banner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    required this.variant,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final CommunitySeason0BannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final isMobile = variant == CommunitySeason0BannerVariant.mobile;
    final radius = BorderRadius.circular(KubusRadius.surface);
    // A flat, tappable programme notice: surface + hairline, no gradient or
    // tinted icon tile. [accentColor] stays in the API for callers but no
    // longer paints structural chrome.
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: roles.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: roles.rule, width: KubusSizes.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              focusColor: roles.focus.withValues(alpha: 0.16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.rocket_launch_outlined,
                        color: roles.foregroundMuted,
                        size: 22,
                      ),
                      const SizedBox(width: KubusSpacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: (isMobile
                                      ? KubusTypography.textTheme.bodyMedium
                                      : KubusTypography.textTheme.bodyLarge)
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: roles.foreground,
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xxs),
                            Text(
                              subtitle,
                              style: KubusTypography.textTheme.bodySmall
                                  ?.copyWith(color: roles.foregroundMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: roles.foregroundSubtle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
