import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../models/artwork.dart';
import '../utils/design_tokens.dart';
import '../utils/profile_handle.dart';
import '../utils/user_profile_navigation.dart';
import 'artwork_creator_byline.dart';

/// Opens a public profile by its profile id. Overridable so tests can assert
/// the id without building the profile screens.
typedef ArtworkAuthorProfileOpener = Future<void> Function(
  BuildContext context, {
  required String profileId,
  String? username,
});

Future<void> _openProfile(
  BuildContext context, {
  required String profileId,
  String? username,
}) {
  return UserProfileNavigation.open(
    context,
    userId: profileId,
    username: username,
  );
}

/// The author line of an artwork detail screen.
///
/// Keeps three concepts apart: the attributed author profile
/// ([Artwork.authorProfile]), the free-text artist name ([Artwork.artist]) and
/// the uploader (never shown here). With an attributed author profile the line
/// is a focusable control that opens that profile by its profile id. Without
/// one it is exactly today's text-only artist line, with no link.
class ArtworkAuthorLine extends StatelessWidget {
  const ArtworkAuthorLine({
    super.key,
    required this.artwork,
    this.style,
    this.maxLines = 1,
    this.openProfile = _openProfile,
  });

  final Artwork artwork;
  final TextStyle? style;
  final int maxLines;
  final ArtworkAuthorProfileOpener openProfile;

  @override
  Widget build(BuildContext context) {
    final author = artwork.authorProfile;
    if (author != null) {
      final name = author.displayName.trim();
      final handle = ProfileHandle.normalize(author.username);
      if (name.isNotEmpty || handle != null) {
        return _AuthorProfileLink(
          author: author,
          name: name,
          handle: handle,
          style: style,
          maxLines: maxLines,
          openProfile: openProfile,
        );
      }
    }
    // No explicit attribution: the artist name stays text only.
    return ArtworkCreatorByline(
      artwork: artwork,
      style: style,
      maxLines: maxLines,
      linkToProfile: false,
    );
  }
}

class _AuthorProfileLink extends StatelessWidget {
  const _AuthorProfileLink({
    required this.author,
    required this.name,
    required this.handle,
    required this.style,
    required this.maxLines,
    required this.openProfile,
  });

  final ArtworkAuthorProfile author;
  final String name;
  final String? handle;
  final TextStyle? style;
  final int maxLines;
  final ArtworkAuthorProfileOpener openProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final nameStyle = baseStyle.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );
    final handleStyle = baseStyle.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final spoken = <String>[
      if (name.isNotEmpty) name,
      if (handle != null) handle!,
    ].join(' ');

    void open() => openProfile(
          context,
          profileId: author.profileId,
          username: author.username.isEmpty ? null : author.username,
        );

    return Semantics(
      container: true,
      button: true,
      label: l10n.artworkAuthorOpenProfile(spoken),
      excludeSemantics: true,
      onTap: open,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: KubusSizes.mediaControlTarget,
          minWidth: KubusSizes.mediaControlTarget,
        ),
        child: InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (name.isNotEmpty) TextSpan(text: name, style: nameStyle),
                  if (name.isNotEmpty && handle != null)
                    TextSpan(text: ' ', style: baseStyle),
                  if (handle != null)
                    TextSpan(
                      text: handle,
                      style: name.isEmpty ? nameStyle : handleStyle,
                    ),
                ],
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
