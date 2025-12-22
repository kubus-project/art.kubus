import 'package:flutter/material.dart';

import '../../community/community_interactions.dart';
import '../artist_badge.dart';
import '../institution_badge.dart';

/// Shared author role badges for community post UIs.
///
/// Keep this as the single source of truth to avoid drift between:
/// - feed cards
/// - post detail
/// - desktop community screens
class CommunityAuthorRoleBadges extends StatelessWidget {
  const CommunityAuthorRoleBadges({
    super.key,
    required this.post,
    this.fontSize = 10,
    this.useOnPrimary = false,
    this.iconOnly = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.spacing = 6,
  });

  final CommunityPost post;
  final double fontSize;
  final bool useOnPrimary;
  final bool iconOnly;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final showArtist = post.authorIsArtist;
    final showInstitution = post.authorIsInstitution;
    if (!showArtist && !showInstitution) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: spacing),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showArtist)
            ArtistBadge(
              fontSize: fontSize,
              padding: padding,
              useOnPrimary: useOnPrimary,
              iconOnly: iconOnly,
            ),
          if (showArtist && showInstitution) SizedBox(width: spacing),
          if (showInstitution)
            InstitutionBadge(
              fontSize: fontSize,
              padding: padding,
              useOnPrimary: useOnPrimary,
              iconOnly: iconOnly,
            ),
        ],
      ),
    );
  }
}
