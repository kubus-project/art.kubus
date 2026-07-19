import 'package:flutter/material.dart';

import '../../../widgets/empty_state_card.dart';

/// Which flavor of non-data state an analytics region is in. Each kind keeps
/// its own icon treatment so empty, unsupported, error, and permission
/// states are visually distinct at a glance.
enum AnalyticsInlineStateKind {
  empty,
  unsupported,
  error,
}

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
          icon: Icons.lock_outline,
          title: title,
          description: description,
          showAction: false,
        ),
      ),
    );
  }
}

class AnalyticsInlineEmptyState extends StatelessWidget {
  const AnalyticsInlineEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.kind = AnalyticsInlineStateKind.empty,
    this.icon,
  });

  final String title;
  final String description;
  final AnalyticsInlineStateKind kind;

  /// Optional icon override; when absent the [kind] picks a distinct icon.
  final IconData? icon;

  IconData get _resolvedIcon {
    if (icon != null) return icon!;
    switch (kind) {
      case AnalyticsInlineStateKind.empty:
        return Icons.query_stats_outlined;
      case AnalyticsInlineStateKind.unsupported:
        return Icons.timeline_outlined;
      case AnalyticsInlineStateKind.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmptyStateCard(
      icon: _resolvedIcon,
      title: title,
      description: description,
      showAction: false,
    );
  }
}
