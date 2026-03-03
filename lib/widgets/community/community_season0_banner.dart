import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/design_tokens.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final isMobile = variant == CommunitySeason0BannerVariant.mobile;
    final content = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? KubusSpacing.md : 16),
        padding: EdgeInsets.all(isMobile ? KubusSpacing.md : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: isMobile ? 0.15 : 0.12),
              scheme.primaryContainer.withValues(alpha: isMobile ? 0.4 : 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: isMobile
              ? KubusRadius.circular(KubusRadius.md)
              : BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: isMobile ? 0.3 : 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 40 : 48,
              height: isMobile ? 40 : 48,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isMobile ? 0.18 : 0.15),
                borderRadius: isMobile
                    ? KubusRadius.circular(KubusRadius.sm)
                    : BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.rocket_launch_outlined,
                color: accentColor,
                size: isMobile ? 22 : 26,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isMobile
                        ? KubusTypography.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          )
                        : GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                  ),
                  SizedBox(height: isMobile ? 2 : 3),
                  Text(
                    subtitle,
                    style: isMobile
                        ? KubusTypography.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          )
                        : GoogleFonts.inter(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onSurface.withValues(alpha: isMobile ? 0.4 : 0.35),
            ),
          ],
        ),
      ),
    );

    if (isMobile) {
      return content;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: content,
    );
  }
}
