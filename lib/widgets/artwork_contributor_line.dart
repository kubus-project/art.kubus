import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../models/artwork.dart';
import '../utils/user_profile_navigation.dart';

/// "Documented by `account`": the account that added the work to art.kubus.
///
/// This is the responsible contributor, not the artist. It is kept apart from
/// the byline on purpose: documenting or uploading a work never credits the
/// uploader as its author. Hidden when the backend names no public contributor,
/// and when the contributor is the same profile as a verified artist (the
/// byline already links that profile).
class ArtworkContributorLine extends StatelessWidget {
  const ArtworkContributorLine({
    super.key,
    required this.artwork,
    this.style,
  });

  final Artwork artwork;
  final TextStyle? style;

  static ({String profileId, String name, String? username})? contributorOf(
    Artwork artwork,
  ) {
    final meta = artwork.metadata;
    final raw = meta?['contributor'];
    if (raw is! Map) return null;
    final profileId = raw['profileId']?.toString().trim() ?? '';
    final name =
        (raw['displayName'] ?? raw['username'] ?? '').toString().trim();
    if (profileId.isEmpty || name.isEmpty) return null;
    final verified = meta?['verifiedArtist'];
    if (verified is Map && verified['profileId']?.toString() == profileId) {
      return null;
    }
    return (
      profileId: profileId,
      name: name,
      username: raw['username']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contributor = contributorOf(artwork);
    if (contributor == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final base = style ?? DefaultTextStyle.of(context).style;
    final label = l10n?.artworkDocumentedByLabel(contributor.name) ??
        'Documented by ${contributor.name}';
    return Semantics(
      link: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => UserProfileNavigation.open(
          context,
          userId: contributor.profileId,
          username: contributor.username,
        ),
        child: ConstrainedBox(
          // A comfortable touch target without changing the visual rhythm.
          constraints: const BoxConstraints(minHeight: 32),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: base.copyWith(color: scheme.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
