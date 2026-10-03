import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../widgets/common/kubus_action_tile.dart';

class ArtistStudioCreateScreen extends StatelessWidget {
  final VoidCallback? onArtworkCreated;
  final VoidCallback? onCollectionCreated;
  final VoidCallback? onOpenArtworkCreator;
  final VoidCallback? onOpenCollectionCreator;
  final VoidCallback? onOpenExhibitionCreator;

  const ArtistStudioCreateScreen({
    super.key,
    this.onArtworkCreated,
    this.onCollectionCreated,
    this.onOpenArtworkCreator,
    this.onOpenCollectionCreator,
    this.onOpenExhibitionCreator,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final studioAccent = KubusColorRoles.of(context).web3ArtistStudioAccent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          l10n.artistStudioCreatePrompt,
          style: KubusTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _CreateOptionTile(
          title: l10n.artistStudioCreateOptionArtworkTitle,
          subtitle: l10n.artistStudioCreateOptionArtworkSubtitle,
          icon: Icons.add_photo_alternate_outlined,
          accent: studioAccent,
          onTap: () async {
            if (onOpenArtworkCreator != null) {
              onOpenArtworkCreator!();
              return;
            }
            await CreatorShellNavigation.openArtworkCreatorWorkspace(
              context,
              onCreated: onArtworkCreated,
            );
          },
        ),
        const SizedBox(height: 12),
        _CreateOptionTile(
          title: l10n.artistStudioCreateOptionCollectionTitle,
          subtitle: l10n.artistStudioCreateOptionCollectionSubtitle,
          icon: Icons.collections_bookmark_outlined,
          accent: studioAccent,
          onTap: () async {
            if (onOpenCollectionCreator != null) {
              onOpenCollectionCreator!();
              return;
            }
            String? createdId;
            await CreatorShellNavigation.openCollectionCreatorWorkspace(
              context,
              onCreated: (id) {
                createdId = id;
                onCollectionCreated?.call();
              },
            );
            final collectionId = createdId;
            if (collectionId != null &&
                collectionId.isNotEmpty &&
                context.mounted) {
              await CreatorShellNavigation.openCollectionDetailWorkspace(
                context,
                collectionId: collectionId,
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _CreateOptionTile(
          title: l10n.exhibitionCreatorAppBarTitle,
          subtitle: l10n.exhibitionCreatorBasicsTitle,
          icon: AppColorUtils.exhibitionIcon,
          accent: studioAccent,
          onTap: () async {
            if (onOpenExhibitionCreator != null) {
              onOpenExhibitionCreator!();
              return;
            }
            await CreatorShellNavigation.openExhibitionCreatorWorkspace(
                context);
          },
        ),
        const SizedBox(height: 12),
        _CreateOptionTile(
          title: l10n.manageMarkersTitle,
          subtitle: l10n.manageMarkersCardSubtitle,
          icon: Icons.place_outlined,
          accent: studioAccent,
          onTap: () async {
            await CreatorShellNavigation.openManageMarkersWorkspace(context);
          },
        ),
      ],
    );
  }
}

/// A creation destination: the studio's contextual colour, its glyph cropped
/// behind the title, no icon box.
class _CreateOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _CreateOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KubusActionTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      onTap: onTap,
      minHeight: 120,
    );
  }
}
