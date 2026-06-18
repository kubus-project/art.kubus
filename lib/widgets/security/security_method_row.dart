import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import 'security_state_pill.dart';

class SecurityMethodAction {
  const SecurityMethodAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;
}

class SecurityMethodRow extends StatelessWidget {
  const SecurityMethodRow({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.statusLabel,
    this.helper,
    this.actions = const <SecurityMethodAction>[],
  });

  final String title;
  final String description;
  final IconData icon;
  final SecurityHubStatus status;
  final String? statusLabel;
  final String? helper;
  final List<SecurityMethodAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status.color(scheme);

    final actionWidgets = actions
        .map(
          (action) => action.destructive
              ? OutlinedButton.icon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon ?? Icons.delete_outline, size: 18),
                  label: Text(action.label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.52),
                    ),
                  ),
                )
              : FilledButton.tonalIcon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon ?? Icons.arrow_forward_rounded,
                      size: 18),
                  label: Text(action.label),
                ),
        )
        .toList(growable: false);

    return Container(
      key: ValueKey<String>('security-method-${title.toLowerCase()}'),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.30),
        borderRadius: KubusRadius.circular(KubusRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: KubusRadius.circular(KubusRadius.sm),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: KubusSpacing.sm),
                          SecurityStatePill(
                            status: status,
                            label: statusLabel,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.70),
                            height: 1.35,
                          ),
                    ),
                    if (helper != null && helper!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        helper!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if (compact) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      SecurityStatePill(status: status, label: statusLabel),
                    ],
                  ],
                ),
              ),
            ],
          );

          if (actionWidgets.isEmpty) return details;

          final actionsWrap = Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: actionWidgets,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: KubusSpacing.md),
                actionsWrap,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: KubusSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: actionsWrap,
              ),
            ],
          );
        },
      ),
    );
  }
}
