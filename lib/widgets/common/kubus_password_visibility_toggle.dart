import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Password show/hide control for a password field's suffix.
///
/// The accessible name is set explicitly and follows the state: "Show
/// password" while the field is obscured, "Hide password" once it is visible.
/// [Tooltip] alone only adds a secondary description on most platforms, so the
/// name is carried by a [Semantics] label merged into the button's own node.
class KubusPasswordVisibilityToggle extends StatelessWidget {
  const KubusPasswordVisibilityToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  /// Whether the paired field is currently obscured.
  final bool obscured;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = obscured ? l10n.formShowPassword : l10n.formHidePassword;
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(
            obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
