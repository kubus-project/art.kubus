import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../../utils/kubus_color_roles.dart';
import '../../art/collection_detail_screen.dart';
import '../../events/exhibition_creator_screen.dart';
import 'artwork_creator.dart';
import 'collection_creator.dart';

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
          style: GoogleFonts.inter(
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
            final navigator = Navigator.of(context);
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => ArtworkCreator(
                  onCreated: () {
                    try {
                      navigator.pop();
                    } catch (_) {}
                    onArtworkCreated?.call();
                  },
                ),
              ),
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
            final navigator = Navigator.of(context);
            final createdId = await navigator.push<String>(
              MaterialPageRoute(
                builder: (_) => CollectionCreator(
                  onCreated: (id) {
                    try {
                      navigator.pop(id);
                    } catch (_) {}
                    onCollectionCreated?.call();
                  },
                ),
              ),
            );
            if (createdId != null && createdId.isNotEmpty && context.mounted) {
              await navigator.push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailScreen(collectionId: createdId),
                ),
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
            final navigator = Navigator.of(context);
            await navigator.push(
              MaterialPageRoute(builder: (_) => const ExhibitionCreatorScreen()),
            );
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
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
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
    );
  }
}
