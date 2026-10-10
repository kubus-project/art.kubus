import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// A single profile utility action (Share, Analytics, More, Close, Back).
///
/// Utility actions are deliberately modelled separately from *relationship*
/// actions (Follow/Message, see `ProfileRelationshipActions`): they are compact,
/// icon-led, unlabelled affordances, whereas relationship actions are the
/// primary labelled calls to action.
@immutable
class ProfileUtilityAction {
  const ProfileUtilityAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.semanticsLabel,
  });

  final IconData icon;

  /// Shown on hover/long-press and used as the accessible name when
  /// [semanticsLabel] is not supplied.
  final String tooltip;

  /// `null` disables the control (rendered in its disabled state).
  final VoidCallback? onPressed;

  final String? semanticsLabel;
}

/// Canonical toolbar for profile utility actions.
///
/// Every profile surface routes Share / Analytics / More / Close / Back through
/// this one widget, so the geometry, hit area, focus treatment, tooltips and
/// semantics can no longer diverge between mobile, desktop and the community
/// overlay. It replaces the profile-specific use of `DesktopActionButton`,
/// which rendered a wider `ElevatedButton.icon` that competed with the identity
/// for horizontal width.
///
/// Guarantees:
/// * every target is at least [minTargetSize] (44) logical pixels square;
/// * geometry uses [KubusRadius.md], never an ad hoc radius;
/// * PRODUCT v5 utility chrome: flat, neutral foreground on a hairline, no
///   glass, no per-action colour; hover and keyboard focus answer in the
///   family teal ([KubusColorRoles.active] / [KubusColorRoles.focus]);
/// * each control carries a tooltip and an explicit semantics label;
/// * the toolbar wraps instead of overflowing on narrow overlays.
///
/// It intentionally contains **no** text: it must never be placed in a row that
/// also holds the profile handle. Compose it above or below
/// `ProfileIdentityBlock`, never beside its handle line.
class ProfileUtilityActions extends StatelessWidget {
  const ProfileUtilityActions({
    super.key,
    required this.actions,
    this.alignment = WrapAlignment.end,
    this.minTargetSize = KubusHeaderMetrics.actionHitArea,
    this.tooltipVerticalOffset = KubusSpacing.lg,
  });

  final List<ProfileUtilityAction> actions;
  final WrapAlignment alignment;

  /// Minimum square target size; the Kubus header metric is 44.
  final double minTargetSize;

  final double tooltipVerticalOffset;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final roles = KubusColorRoles.of(context);
    final shape = WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
      final focused = states.contains(WidgetState.focused);
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        side: focused
            ? KubusBorders.activeSide(context, accent: roles.focus)
            : KubusBorders.hairlineSide(context),
      );
    });
    final style = ButtonStyle(
      fixedSize: WidgetStatePropertyAll(Size.square(minTargetSize)),
      minimumSize: WidgetStatePropertyAll(Size.square(minTargetSize)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      iconSize: const WidgetStatePropertyAll(KubusHeaderMetrics.actionIcon),
      shape: shape,
      // Same governed side as the shape, so the theme's focus side does not
      // replace this button's own keyline.
      side: WidgetStateProperty.resolveWith<BorderSide?>(
        (states) => states.contains(WidgetState.focused)
            ? KubusBorders.activeSide(context, accent: roles.focus)
            : KubusBorders.hairlineSide(context),
      ),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return roles.foregroundSubtle;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return roles.active;
        }
        return roles.foreground;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return roles.active.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return roles.active.withValues(alpha: 0.08);
        }
        return null;
      }),
    );

    return Wrap(
      alignment: alignment,
      spacing: KubusSpacing.xs,
      runSpacing: KubusSpacing.xs,
      children: [
        for (final action in actions)
          Semantics(
            label: action.semanticsLabel ?? action.tooltip,
            button: true,
            enabled: action.onPressed != null,
            excludeSemantics: true,
            onTap: action.onPressed,
            child: Tooltip(
              message: action.tooltip,
              preferBelow: true,
              verticalOffset: tooltipVerticalOffset,
              child: IconButton(
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                style: style,
              ),
            ),
          ),
      ],
    );
  }
}
