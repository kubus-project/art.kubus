import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/inline_loading.dart';

class AnalyticsPermissionState extends StatelessWidget {
  const AnalyticsPermissionState({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: EmptyStateCard(
          icon: Icons.analytics_outlined,
          title: title,
          description: description,
          showAction: false,
        ),
      ),
    );
  }
}

class AnalyticsLoadingState extends StatelessWidget {
  const AnalyticsLoadingState({super.key, this.label = 'Loading analytics'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InlineLoading(tileSize: 10, color: scheme.primary),
          const SizedBox(height: KubusSpacing.md),
          Text(
            label,
            style: KubusTypography.inter(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsInlineEmptyState extends StatelessWidget {
  const AnalyticsInlineEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.query_stats_outlined,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyStateCard(
      icon: icon,
      title: title,
      description: description,
      showAction: false,
    );
  }
}
