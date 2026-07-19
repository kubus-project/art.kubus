import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/common/kubus_reading_surface.dart';
import '../../../widgets/inline_loading.dart';

/// Shared quiet surface for analytics report sections.
///
/// Analytics reads as an editorial report, not a dashboard: every section
/// (trend, insights, comparison) sits on the same `KubusReadingSurface`
/// tonal fill with one title treatment instead of hand-rolled containers.
/// Liquid glass stays reserved for floating chrome (filter sheet, summary
/// bar) per the glass hierarchy.
class AnalyticsSectionPanel extends StatelessWidget {
  const AnalyticsSectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.isRefreshing = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// When true a small kit loader renders beside the title while existing
  /// content stays in place, so local filter updates never blank the section.
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KubusReadingSurface(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      borderRadius: KubusRadius.circular(KubusRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KubusTypography.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        subtitle!,
                        style: KubusTypography.inter(
                          fontSize: 12,
                          height: 1.35,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isRefreshing) ...[
                const SizedBox(width: KubusSpacing.md),
                Semantics(
                  label: AppLocalizations.of(context)!.analyticsRefreshingLabel,
                  child: InlineLoading(
                    tileSize: 6,
                    color: scheme.primary,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: KubusSpacing.md),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          child,
        ],
      ),
    );
  }
}
