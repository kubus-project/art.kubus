import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/exhibition.dart';
import '../../models/artwork.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/collab_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../screens/collab/invites_inbox_screen.dart';
import '../../widgets/collaboration_panel.dart';

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

  Future<void> _showLinkArtworksDialog(Exhibition exhibition) async {
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
            content: Text('No artworks available to link.', style: GoogleFonts.inter()),
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
              title: Text('Add artworks', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                  child: Text('Cancel', style: GoogleFonts.inter()),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text('Link', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
          content: Text('Artworks linked to exhibition.', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to link artworks. Please try again.', style: GoogleFonts.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ExhibitionsProvider>();

    final ex = provider.exhibitions.firstWhere(
      (e) => e.id == widget.exhibitionId,
      orElse: () => widget.initialExhibition ?? Exhibition(id: widget.exhibitionId, title: 'Exhibition'),
    );

    final poap = provider.poapStatusFor(widget.exhibitionId);

    final canManage = _canManageExhibition(ex.myRole);

    return Scaffold(
      appBar: AppBar(
        title: Text(ex.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Invites',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvitesInboxScreen()));
            },
            icon: const Icon(Icons.inbox_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                final details = _ExhibitionDetailsCard(exhibition: ex, poap: poap);

                final artworksCard = Card(
                  elevation: 0,
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Artworks',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            if (canManage)
                              TextButton.icon(
                                onPressed: () => _showLinkArtworksDialog(ex),
                                icon: const Icon(Icons.add),
                                label: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canManage
                              ? 'Link artworks so visitors can discover them from this exhibition.'
                              : 'Artworks linked to this exhibition will appear here.',
                          style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 12),
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
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: 14),
                            artworksCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: collab),
                    ],
                  );
                }

                return ListView(
                  children: [
                    details,
                    const SizedBox(height: 14),
                    artworksCard,
                    const SizedBox(height: 14),
                    collab,
                    if (provider.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
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

class _LinkedArtworksList extends StatelessWidget {
  const _LinkedArtworksList({required this.exhibition});

  final Exhibition exhibition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artworkProvider = context.watch<ArtworkProvider>();

    final ids = exhibition.artworkIds;
    if (ids.isEmpty) {
      return Text(
        'No artworks linked yet.',
        style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7)),
      );
    }

    final tiles = <Widget>[];
    for (final id in ids) {
      final art = artworkProvider.getArtworkById(id);
      tiles.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            art?.title ?? 'Artwork',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            art?.artist.isNotEmpty == true ? art!.artist : id,
            style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.75)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: Icon(Icons.image_outlined, color: scheme.onSurface.withValues(alpha: 0.7)),
        ),
      );
      tiles.add(Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)));
    }

    // Drop trailing divider.
    if (tiles.isNotEmpty) tiles.removeLast();
    return Column(children: tiles);
  }
}

class _ExhibitionDetailsCard extends StatelessWidget {
  const _ExhibitionDetailsCard({required this.exhibition, required this.poap});

  final Exhibition exhibition;
  final ExhibitionPoapStatus? poap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (dateRange != null) _InfoRow(icon: Icons.schedule, label: dateRange),
            if (location != null) _InfoRow(icon: Icons.place_outlined, label: location),
            _InfoRow(icon: Icons.event_available_outlined, label: 'Status: ${_labelForStatus(exhibition.status)}'),
            if ((exhibition.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(exhibition.description!, style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.8))),
            ],
            if (poap?.poap != null) ...[
              const SizedBox(height: 14),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 10),
              Text('Badge', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                poap!.claimed == true ? 'Claimed' : 'Not claimed',
                style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.8)),
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

  static String _labelForStatus(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'Unknown';
    if (v == 'published') return 'Published';
    if (v == 'draft') return 'Draft';
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
