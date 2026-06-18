import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../kubus_card.dart';
import 'security_state_pill.dart';

class SecuritySummaryCard extends StatelessWidget {
  const SecuritySummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.status,
    this.detail,
  });

  final String title;
  final String value;
  final IconData icon;
  final SecurityHubStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status.color(scheme);
    return KubusCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      color: Color.lerp(scheme.surface, color, 0.08),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: KubusRadius.circular(KubusRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const Spacer(),
                SecurityStatePill(status: status),
              ],
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if (detail != null && detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.68),
                      height: 1.3,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
