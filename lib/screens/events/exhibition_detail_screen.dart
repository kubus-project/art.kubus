import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/exhibition.dart';
import '../../models/artwork.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/collab_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../screens/collab/invites_inbox_screen.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../art/art_detail_screen.dart';

class ExhibitionDetailScreen extends StatefulWidget {
  final String exhibitionId;
  final Exhibition? initialExhibition;

  const ExhibitionDetailScreen({
    super.key,
    required this.exhibitionId,
    this.initialExhibition,
  });

  @override
  State<ExhibitionDetailScreen> createState() => _ExhibitionDetailScreenState();
}

class _ExhibitionDetailScreenState extends State<ExhibitionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ExhibitionsProvider>();
      unawaited(provider.recordExhibitionView(widget.exhibitionId, source: 'exhibition_detail'));
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final provider = context.read<ExhibitionsProvider>();
    try {
      await provider.fetchExhibition(widget.exhibitionId, force: true);
      await provider.fetchExhibitionPoap(widget.exhibitionId, force: true);
    } catch (_) {
      // Provider handles errors.
    }
  }

  bool _canManageExhibition(String? myRole) {
    final role = (myRole ?? '').trim().toLowerCase();
    if (role.isEmpty) return false;
    // Keep in sync with backend `canEditEntity` (curator+) while preserving legacy `host`.
    return role == 'owner' || role == 'admin' || role == 'publisher' || role == 'editor' || role == 'curator' || role == 'host';
  }

  bool _canPublishExhibition(String? myRole) {
    final role = (myRole ?? '').trim().toLowerCase();
    if (role.isEmpty) return false;
    // Keep in sync with backend `canPublishEntity` (publisher+).
    return role == 'owner' || role == 'admin' || role == 'publisher';
  }

  Future<void> _togglePublish(Exhibition exhibition, bool publish) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();

    final nextStatus = publish ? 'published' : 'draft';
    if ((exhibition.status ?? '').trim().toLowerCase() == nextStatus) return;

    try {
      await provider.updateExhibition(exhibition.id, <String, dynamic>{'status': nextStatus});
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.commonSavedToast, style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.commonActionFailedToast, style: GoogleFonts.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeCover(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      final fileName = (file?.name ?? '').trim();

      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.commonActionFailedToast, style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final url = await provider.uploadExhibitionCover(
        bytes: bytes,
        fileName: fileName.isEmpty ? 'cover.jpg' : fileName,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.commonActionFailedToast, style: GoogleFonts.inter()),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await provider.updateExhibition(exhibition.id, <String, dynamic>{'coverUrl': url});

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.commonSavedToast, style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.commonActionFailedToast, style: GoogleFonts.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showLinkArtworksDialog(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    final artworkProvider = context.read<ArtworkProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();
    final collabProvider = context.read<CollabProvider>();

    // Ensure we have a reasonably fresh list of artworks for selection.
    // (This screen does not guarantee ArtworkProvider has been initialized.)
    if (artworkProvider.artworks.isEmpty) {
      try {
        await artworkProvider.loadArtworks(refresh: true);
      } catch (_) {
        // ArtworkProvider reports its own errors; fall through.
      }
    }

    // Best-effort: ensure collaborator list is loaded so we can filter eligible artworks.
    // This is UX-only filtering; server enforces ownership.
    try {
      await collabProvider.loadCollaborators('exhibitions', exhibition.id);
    } catch (_) {
      // Provider handles error state.
    }

    if (!mounted) return;

    final members = collabProvider.collaboratorsFor('exhibitions', exhibition.id);
    final allowedUserIds = members
        .map((m) => m.userId.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    final allowedWalletsLower = members
        .map((m) => (m.user?.walletAddress ?? '').trim().toLowerCase())
        .where((v) => v.isNotEmpty)
        .toSet();

    bool isMemberOwned(Artwork art) {
      final meta = art.metadata ?? const <String, dynamic>{};
      final creatorId = (meta['creatorId'] ?? meta['creator_id'])?.toString().trim();
      if (creatorId != null && creatorId.isNotEmpty && allowedUserIds.contains(creatorId)) {
        return true;
      }
      final wallet = (meta['walletAddress'] ?? meta['wallet_address'])?.toString().trim().toLowerCase();
      if (wallet != null && wallet.isNotEmpty && allowedWalletsLower.contains(wallet)) {
        return true;
      }
      return false;
    }

    final artworks = List<Artwork>.from(artworkProvider.artworks.where(isMemberOwned));
    if (artworks.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.exhibitionDetailNoArtworksAvailableToLinkToast, style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final selectedIds = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(l10n.exhibitionDetailAddArtworksDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: artworks.length,
                  itemBuilder: (context, index) {
                    final art = artworks[index];
                    final checked = selectedIds.contains(art.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            selectedIds.add(art.id);
                          } else {
                            selectedIds.remove(art.id);
                          }
                        });
                      },
                      title: Text(
                        art.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        art.artist.isNotEmpty ? art.artist : '—',
                        style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.75)),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel, style: GoogleFonts.inter()),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonLink, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await exhibitionsProvider.linkExhibitionArtworks(exhibition.id, selectedIds.toList());
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.exhibitionDetailArtworksLinkedToast, style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.exhibitionDetailLinkArtworksFailedToast, style: GoogleFonts.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ExhibitionsProvider>();

    final ex = provider.exhibitions.firstWhere(
      (e) => e.id == widget.exhibitionId,
      orElse: () => widget.initialExhibition ?? Exhibition(id: widget.exhibitionId, title: 'Exhibition'),
    );

    final poap = provider.poapStatusFor(widget.exhibitionId);

    final canManage = _canManageExhibition(ex.myRole);
    final canPublish = _canPublishExhibition(ex.myRole);

    return Scaffold(
      appBar: AppBar(
        title: Text(ex.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: l10n.commonShare,
            onPressed: () {
              ShareService().showShareSheet(
                context,
                target: ShareTarget.exhibition(exhibitionId: widget.exhibitionId, title: ex.title),
                sourceScreen: 'exhibition_detail',
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: l10n.exhibitionDetailInvitesTooltip,
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvitesInboxScreen()));
            },
            icon: const Icon(Icons.inbox_outlined),
          ),
          IconButton(
            tooltip: l10n.exhibitionDetailRefreshTooltip,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(DetailSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                final details = _ExhibitionDetailsCard(
                  exhibition: ex,
                  poap: poap,
                  canManage: canManage,
                  canPublish: canPublish,
                  onPublishChanged: (v) => _togglePublish(ex, v),
                  onChangeCover: canManage ? () => _changeCover(ex) : null,
                );

                final artworksCard = Card(
                  elevation: 0,
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DetailSpacing.lg),
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DetailSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.exhibitionDetailArtworksTitle,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            if (canManage)
                              TextButton.icon(
                                onPressed: () => _showLinkArtworksDialog(ex),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.commonAdd, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                          ],
                        ),
                        const SizedBox(height: DetailSpacing.sm),
                        Text(
                          canManage
                              ? l10n.exhibitionDetailArtworksManageHint
                              : l10n.exhibitionDetailArtworksViewHint,
                          style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: DetailSpacing.md),
                        _LinkedArtworksList(exhibition: ex),
                      ],
                    ),
                  ),
                );

                final collab = CollaborationPanel(
                  entityType: 'exhibitions',
                  entityId: widget.exhibitionId,
                  myRole: ex.myRole,
                );

                if (isWide) {
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  details,
                                  const SizedBox(height: DetailSpacing.lg),
                                  artworksCard,
                                ],
                              ),
                            ),
                            const SizedBox(width: DetailSpacing.lg),
                            Expanded(flex: 5, child: collab),
                          ],
                        ),
                      ),
                      if (provider.isLoading)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(color: scheme.primary),
                        ),
                    ],
                  );
                }

                return ListView(
                  children: [
                    details,
                    const SizedBox(height: DetailSpacing.lg),
                    artworksCard,
                    const SizedBox(height: DetailSpacing.lg),
                    collab,
                    if (provider.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: DetailSpacing.lg),
                        child: LinearProgressIndicator(color: scheme.primary),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedArtworksList extends StatefulWidget {
  const _LinkedArtworksList({required this.exhibition});

  final Exhibition exhibition;

  @override
  State<_LinkedArtworksList> createState() => _LinkedArtworksListState();
}

class _LinkedArtworksListState extends State<_LinkedArtworksList> {
  final Set<String> _requested = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchMissingArtworks();
    });
  }

  @override
  void didUpdateWidget(covariant _LinkedArtworksList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exhibition.id != widget.exhibition.id) {
      _requested.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchMissingArtworks();
    });
  }

  void _prefetchMissingArtworks() {
    final provider = context.read<ArtworkProvider>();
    for (final rawId in widget.exhibition.artworkIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      if (_requested.contains(id)) continue;
      if (provider.getArtworkById(id) != null) continue;
      _requested.add(id);
      unawaited(provider.fetchArtworkIfNeeded(id).catchError((_) => null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final artworkProvider = context.watch<ArtworkProvider>();

    final ids = widget.exhibition.artworkIds;
    if (ids.isEmpty) {
      return Text(
        l10n.exhibitionDetailNoArtworksLinkedYet,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    final tiles = <Widget>[];
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      final art = artworkProvider.getArtworkById(id);
      final title = (art?.title ?? '').trim().isNotEmpty
          ? art!.title
          : l10n.commonUntitled;
      final subtitle = art?.artist.isNotEmpty == true ? art!.artist : id;
      final imageUrl = ArtworkMediaResolver.resolveCover(artwork: art);

      tiles.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtDetailScreen(artworkId: id),
              ),
            );
          },
          title: Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: imageUrl == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                        ),
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
      tiles.add(
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
      );
    }

    // Drop trailing divider.
    if (tiles.isNotEmpty) tiles.removeLast();
    return Column(children: tiles);
  }
}

class _ExhibitionDetailsCard extends StatelessWidget {
  const _ExhibitionDetailsCard({
    required this.exhibition,
    required this.poap,
    required this.canManage,
    required this.canPublish,
    required this.onPublishChanged,
    required this.onChangeCover,
  });

  final Exhibition exhibition;
  final ExhibitionPoapStatus? poap;
  final bool canManage;
  final bool canPublish;
  final ValueChanged<bool> onPublishChanged;
  final VoidCallback? onChangeCover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final coverUrl = MediaUrlResolver.resolve(exhibition.coverUrl);

    String? dateRange;
    if (exhibition.startsAt != null || exhibition.endsAt != null) {
      final start = exhibition.startsAt != null ? _fmtDate(exhibition.startsAt!) : null;
      final end = exhibition.endsAt != null ? _fmtDate(exhibition.endsAt!) : null;
      dateRange = [start, end].whereType<String>().join(' • ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final location = (exhibition.locationName ?? '').trim().isNotEmpty ? exhibition.locationName!.trim() : null;

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DetailSpacing.lg),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DetailSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.exhibitionDetailOverviewTitle, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (canManage)
                  TextButton.icon(
                    onPressed: onChangeCover,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(l10n.commonChangeCover, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: DetailSpacing.md),
            if (coverUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(DetailSpacing.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: scheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DetailSpacing.md),
            ],
            if (dateRange != null) _InfoRow(icon: Icons.schedule, label: dateRange),
            if (location != null) _InfoRow(icon: Icons.place_outlined, label: location),
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: l10n.exhibitionDetailStatusRowLabel(_labelForStatus(l10n, exhibition.status)),
            ),
            if (canPublish) ...[
              const SizedBox(height: DetailSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: (exhibition.status ?? '').trim().toLowerCase() == 'published',
                onChanged: onPublishChanged,
                title: Text(l10n.commonPublish, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  (exhibition.status ?? '').trim().toLowerCase() == 'published'
                      ? l10n.commonPublished
                      : l10n.commonDraft,
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            ],
            if ((exhibition.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: DetailSpacing.md),
              Text(exhibition.description!, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: scheme.onSurface.withValues(alpha: 0.8))),
            ],
            if (poap?.poap != null) ...[
              const SizedBox(height: DetailSpacing.lg),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: DetailSpacing.md),
              Text(l10n.exhibitionDetailBadgeTitle, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: DetailSpacing.sm),
              Text(
                poap!.claimed == true ? l10n.exhibitionDetailBadgeClaimed : l10n.exhibitionDetailBadgeNotClaimed,
                style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _labelForStatus(AppLocalizations l10n, String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return l10n.commonUnknown;
    if (v == 'published') return l10n.commonPublished;
    if (v == 'draft') return l10n.commonDraft;
    return v;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DetailSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: DetailSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }
}
