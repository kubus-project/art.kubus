import 'package:flutter/material.dart';

import '../../utils/kubus_color_roles.dart';
import '../common/kubus_atmosphere.dart';

/// The cover a profile shows when it has no cover image.
///
/// Instead of an empty band it is an identity field in the profile's role
/// colour, with the role's symbol cropped in the trailing corner: artist
/// coral with a palette, institution blue with a building, any other account
/// family teal with a compass (people who explore the map). The avatar sits
/// bottom-left and edit top-right, so the light comes from the top-right and
/// the symbol sits in the free bottom-right corner, cropped by the edge.
///
/// It is deliberately quiet: no texture, one hue, a faint glyph. The identity
/// plate and the avatar sit on it, and they are the subject.
///
/// The colour is a *role* signal (the same one the artist / institution
/// badges use), never the personal user accent. Owner and public profiles,
/// phone and desktop, all use this one widget.
class ProfileCoverField extends StatelessWidget {
  const ProfileCoverField({
    super.key,
    required this.isArtist,
    required this.isInstitution,
  });

  final bool isArtist;
  final bool isInstitution;

  static Color accentFor(
    KubusColorRoles roles, {
    required bool isArtist,
    required bool isInstitution,
  }) {
    if (isInstitution) return roles.institutionBadgeAccent;
    if (isArtist) return roles.artistBadgeAccent;
    return roles.active;
  }

  static IconData glyphFor({
    required bool isArtist,
    required bool isInstitution,
  }) {
    if (isInstitution) return Icons.account_balance_outlined;
    if (isArtist) return Icons.palette_outlined;
    return Icons.explore_outlined;
  }

  /// Glyph opacity: quieter than the generic ghost glyph, because this field
  /// spans a whole hero and the identity plate sits on it.
  static double glyphOpacity(Brightness b) =>
      b == Brightness.dark ? 0.075 : 0.06;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final brightness = Theme.of(context).brightness;
    final accent =
        accentFor(roles, isArtist: isArtist, isInstitution: isInstitution);
    // A quiet identity field, not a placeholder and not a shader demo: the
    // raised surface, one atmospheric wash of the role colour from the top
    // right, a directional tonal depth toward the avatar corner, and the
    // role symbol oversized and cropped off the bottom-right edge. No texture.
    return DecoratedBox(
      key: const ValueKey<String>('profile_cover_field'),
      decoration: BoxDecoration(color: roles.surfaceRaised),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.3,
                colors: [
                  accent.withValues(
                    alpha: KubusAtmosphere.accentFieldAlpha(brightness) * 0.8,
                  ),
                  accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(
                    alpha: brightness == Brightness.dark ? 0.14 : 0.04,
                  ),
                ],
              ),
            ),
          ),
          KubusGhostGlyph(
            icon: glyphFor(isArtist: isArtist, isInstitution: isInstitution),
            color: accent,
            alignment: Alignment.bottomRight,
            placement: KubusGhostGlyphPlacement.hero,
            extent: 220,
            opacity: glyphOpacity(brightness),
          ),
        ],
      ),
    );
  }
}
