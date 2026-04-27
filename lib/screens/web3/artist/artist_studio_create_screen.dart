import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../widgets/glass_components.dart';

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
        _CreateOptionCard(
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
        _CreateOptionCard(
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
            if (collectionId != null && collectionId.isNotEmpty && context.mounted) {
              await CreatorShellNavigation.openCollectionDetailWorkspace(
                context,
                collectionId: collectionId,
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _CreateOptionCard(
          title: l10n.exhibitionCreatorAppBarTitle,
          subtitle: l10n.exhibitionCreatorBasicsTitle,
          icon: Icons.event_available_outlined,
          accent: studioAccent,
          onTap: () async {
            if (onOpenExhibitionCreator != null) {
              onOpenExhibitionCreator!();
              return;
            }
            await CreatorShellNavigation.openExhibitionCreatorWorkspace(context);
          },
        ),
        const SizedBox(height: 12),
        _CreateOptionCard(
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

class _CreateOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _CreateOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      backgroundColor: accent.withValues(alpha: 0.05),
      showBorder: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KubusRadius.lg),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: KubusTypography.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: KubusTypography.inter(
                          fontSize: 12,
                          height: 1.25,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
