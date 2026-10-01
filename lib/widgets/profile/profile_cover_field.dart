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
/// the symbol sits in the free bottom-right corner.
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

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final accent =
        accentFor(roles, isArtist: isArtist, isInstitution: isInstitution);
    return KubusAtmosphere(
      key: const ValueKey<String>('profile_cover_field'),
      accent: accent,
      // One hue: a cover is one identity, not a two-colour composition.
      secondary: accent,
      base: roles.surfaceRaised,
      // Edit sits top-right and the avatar bottom-left: the symbol takes the
      // free bottom-right corner, sized to the band.
      glyphAlignment: Alignment.bottomRight,
      glyphExtent: 150,
      glyph: glyphFor(isArtist: isArtist, isInstitution: isInstitution),
      framed: false,
      padding: EdgeInsets.zero,
      child: const SizedBox.expand(),
    );
  }
}
