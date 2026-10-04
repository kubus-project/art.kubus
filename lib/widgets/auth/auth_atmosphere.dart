import 'package:flutter/material.dart';

import '../../utils/kubus_color_roles.dart';
import '../common/kubus_atmosphere.dart';

/// The one atmospheric field the whole account-entry family shares.
///
/// Account entry is an entry state and a focused transitional context, which
/// makes it one of the few legitimate places in the product for an atmospheric
/// ground — the design programme always treated it that way, and the auth shell
/// had drifted to a flat page colour while the rest of the family still carried
/// an older animated gradient. Both are replaced by this: one restrained
/// PRODUCT v5 [KubusAtmosphere], so Sign in, Register, Forgot password, Reset
/// password and Verify email are visibly the same place rather than five
/// different gradients.
///
/// Restraint is the point:
/// * two diffuse fields, the family teal from one corner and the information
///   blue from the opposite one, at the atmosphere's own theme-aware strengths;
/// * no glyph, because a cropped symbol behind a credential form competes with
///   it, and the shell already has its own hero mark;
/// * full bleed, so there is no card edge or rule around the page;
/// * content sits on the plain ground colour underneath, so the form keeps
///   ordinary page contrast and stays highly readable.
class AuthAtmosphere extends StatelessWidget {
  const AuthAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return KubusAtmosphere(
      key: const ValueKey<String>('auth_atmosphere'),
      // Kubus teal is the family identity for structural surfaces, and account
      // entry is the most structural surface there is.
      accent: roles.active,
      secondary: roles.secondary,
      base: roles.ground,
      framed: false,
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}
