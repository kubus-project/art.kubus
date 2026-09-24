import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// A labeled, wrapping group for actions that share one subject-page intent.
///
/// Core actions remain text-labeled and at least 48 logical pixels high on
/// compact screens. Selection is exposed as a semantic toggle, not by color
/// alone. The component uses flat v5 surfaces and structural rules.
class SubjectActionGroup extends StatelessWidget {
  const SubjectActionGroup({
    required this.label,
    required this.actions,
    super.key,
  });

  final String label;
  final List<SubjectAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.structuralLabel.copyWith(
            color: roles.foregroundMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.sm,
          children: [
            for (final action in actions) _SubjectActionButton(action: action),
          ],
        ),
      ],
    );
  }
}

@immutable
class SubjectAction {
  const SubjectAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selectedLabel,
    this.isSelected = false,
    this.selectedColor,
  });

  final IconData icon;
  final String label;
  final String? selectedLabel;
  final VoidCallback? onPressed;
  final bool isSelected;
  final Color? selectedColor;
}

class _SubjectActionButton extends StatelessWidget {
  const _SubjectActionButton({required this.action});

  final SubjectAction action;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final activeColor = action.selectedColor ?? roles.active;
    final label = action.isSelected
        ? (action.selectedLabel ?? action.label)
        : action.label;
    final background =
        action.isSelected ? activeColor.withValues(alpha: 0.10) : roles.surface;
    final foreground = action.isSelected ? activeColor : roles.foreground;

    return Semantics(
      container: true,
      button: true,
      enabled: action.onPressed != null,
      toggled: action.isSelected,
      label: label,
      onTap: action.onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          child: InkWell(
            onTap: action.onPressed,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            focusColor: roles.focus.withValues(alpha: 0.16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 92),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: action.isSelected ? activeColor : roles.rule,
                  ),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, size: 18, color: foreground),
                    const SizedBox(width: KubusSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: KubusTextStyles.actionLabel.copyWith(
                          color: foreground,
                          fontWeight: action.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
