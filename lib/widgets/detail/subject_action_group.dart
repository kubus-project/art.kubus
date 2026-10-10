import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// How a group lays its actions out.
///
/// [wrap] is the default: labeled buttons that wrap onto further lines.
/// [rowWithPrimary] is opt-in for narrow, fixed-width sidebars: the first
/// action is a full-width labeled button, and the rest share one row of
/// equal-width icon buttons, each with a tooltip and the same spoken label.
enum SubjectActionLayout { wrap, rowWithPrimary }

/// A labeled, wrapping group for actions that share one subject-page intent.
///
/// Core actions remain text-labeled and at least 48 logical pixels high on
/// compact screens. Selection is exposed as a semantic toggle, not by color
/// alone. The component uses flat v5 surfaces and structural rules.
class SubjectActionGroup extends StatelessWidget {
  const SubjectActionGroup({
    required this.label,
    required this.actions,
    this.layout = SubjectActionLayout.wrap,
    super.key,
  });

  final String label;
  final List<SubjectAction> actions;
  final SubjectActionLayout layout;

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
        switch (layout) {
          SubjectActionLayout.wrap => Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                for (final action in actions)
                  _SubjectActionButton(action: action),
              ],
            ),
          SubjectActionLayout.rowWithPrimary => _buildRowWithPrimary(),
        },
      ],
    );
  }

  Widget _buildRowWithPrimary() {
    if (actions.isEmpty) return const SizedBox.shrink();
    final primary = actions.first;
    final secondary = actions.skip(1).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubjectActionButton(
          key: ValueKey<String>('subject_action_primary:${primary.label}'),
          action: primary,
        ),
        // A lone secondary action keeps its label: stretched across the full
        // width, an icon-only tile would be an unlabeled bar.
        if (secondary.length == 1) ...[
          const SizedBox(height: KubusSpacing.sm),
          _SubjectActionButton(
            key: ValueKey<String>(
                'subject_action_secondary:${secondary[0].label}'),
            action: secondary[0],
          ),
        ] else if (secondary.length > 1) ...[
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < secondary.length; i++) ...[
                if (i > 0) const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: _SubjectActionIconButton(action: secondary[i]),
                ),
              ],
            ],
          ),
        ],
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
    this.isSelected,
    this.selectedColor,
  });

  final IconData icon;
  final String label;
  final String? selectedLabel;
  final VoidCallback? onPressed;

  /// `null` for one-shot actions; set for persistent toggle actions.
  final bool? isSelected;
  final Color? selectedColor;
}

class _SubjectActionButton extends StatelessWidget {
  const _SubjectActionButton({super.key, required this.action});

  final SubjectAction action;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final activeColor = action.selectedColor ?? roles.active;
    final isSelected = action.isSelected == true;
    final label =
        isSelected ? (action.selectedLabel ?? action.label) : action.label;
    final background =
        isSelected ? activeColor.withValues(alpha: 0.10) : roles.surface;
    final foreground = isSelected ? activeColor : roles.foreground;

    return Semantics(
      container: true,
      button: true,
      enabled: action.onPressed != null,
      focusable: action.onPressed != null,
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
                    color: isSelected ? activeColor : roles.rule,
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
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
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

/// Icon-only sibling of [_SubjectActionButton] for [SubjectActionLayout.rowWithPrimary].
/// The spoken label is the same localized label as the labeled button; the
/// tooltip shows it on hover and long press.
class _SubjectActionIconButton extends StatelessWidget {
  const _SubjectActionIconButton({required this.action});

  final SubjectAction action;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final activeColor = action.selectedColor ?? roles.active;
    final isSelected = action.isSelected == true;
    final label =
        isSelected ? (action.selectedLabel ?? action.label) : action.label;
    final background =
        isSelected ? activeColor.withValues(alpha: 0.10) : roles.surface;
    final foreground = isSelected ? activeColor : roles.foreground;

    return Semantics(
      container: true,
      button: true,
      enabled: action.onPressed != null,
      focusable: action.onPressed != null,
      toggled: action.isSelected,
      label: label,
      onTap: action.onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            key: ValueKey<String>('subject_action_icon:${action.label}'),
            color: background,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            child: InkWell(
              onTap: action.onPressed,
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              focusColor: roles.focus.withValues(alpha: 0.16),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? activeColor : roles.rule,
                  ),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: Icon(action.icon, size: 18, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
