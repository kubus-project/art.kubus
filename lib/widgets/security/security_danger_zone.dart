import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import 'security_method_row.dart';
import 'security_state_pill.dart';

class SecurityDangerZone extends StatelessWidget {
  const SecurityDangerZone({
    super.key,
    required this.rows,
  });

  final List<SecurityMethodRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('security-danger-zone'),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.10),
        borderRadius: KubusRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.error, size: 20),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  'Danger zone',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SecurityStatePill(
                status: SecurityHubStatus.destructive,
                label: 'Confirm required',
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          ...rows.expand(
            (row) => [
              row,
              const SizedBox(height: KubusSpacing.sm),
            ],
          ),
        ],
      ),
    );
  }
}
