import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// The one primary surface of a focused account-entry task, placed directly
/// on [AuthAtmosphere].
///
/// The atmosphere is already the page-level context, so the task gets exactly
/// one flat panel: the raised surface and a hairline rule, the same surface
/// the desktop sign-in shell uses. Never put this inside another card, and
/// never put a card inside it: content laid into it is plain.
class AuthFormPanel extends StatelessWidget {
  const AuthFormPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KubusSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const ValueKey<String> surfaceKey =
      ValueKey<String>('auth_form_panel');

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: roles.surfaceRaised,
        borderRadius: BorderRadius.circular(KubusRadius.sheet),
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
