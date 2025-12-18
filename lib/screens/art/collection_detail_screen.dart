import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../services/backend_api_service.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/collaboration_panel.dart';
import '../../config/config.dart';
import 'art_detail_screen.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackendApiService().getCollection(widget.collectionId);
  }

  void _reload() {
    setState(() {
      _future = BackendApiService().getCollection(widget.collectionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 34),
                    const SizedBox(height: 12),
                    Text(
                      l10n.collectionDetailLoadFailedMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            );
          }

          final raw = snapshot.data ?? const <String, dynamic>{};
          final name = (raw['name'] ?? raw['title'] ?? l10n.userProfileCollectionFallbackTitle).toString();
          final description = (raw['description'] ?? '').toString().trim();
          final thumbRaw = (raw['thumbnailUrl'] ?? raw['thumbnail_url'] ?? raw['image'] ?? raw['coverImage'])?.toString();
          final thumbnailUrl = MediaUrlResolver.resolve(thumbRaw);

          final dynamic artworksDynamic = raw['artworks'] ?? raw['items'] ?? const [];
          final artworks = artworksDynamic is List
              ? artworksDynamic
                  .whereType<dynamic>()
                  .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
                  .toList()
              : <Map<String, dynamic>>[];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: scheme.surface,
                elevation: 0,
                foregroundColor: scheme.onSurface,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.22),
                          scheme.secondary.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                    child: thumbnailUrl == null
                        ? Center(
                            child: Icon(
                              Icons.collections,
                              size: 72,
                              color: scheme.onSurface.withValues(alpha: 0.35),
                            ),
                          )
                        : Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 56,
                                color: scheme.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (AppConfig.isFeatureEnabled('collabInvites')) ...[
                        CollaborationPanel(
                          entityType: 'collections',
                          entityId: widget.collectionId,
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (description.isNotEmpty) ...[
                        Text(
                          l10n.collectionDetailDescription,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.4,
                            color: scheme.onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        l10n.collectionDetailArtworks,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (artworks.isEmpty)
                        Text(
                          l10n.collectionDetailNoArtworksYet,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        )
                      else
                        ...artworks.map((art) => _ArtworkRow(artwork: art)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArtworkRow extends StatelessWidget {
  final Map<String, dynamic> artwork;

  const _ArtworkRow({required this.artwork});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = (artwork['id'] ?? artwork['artworkId'] ?? artwork['artwork_id'])?.toString();
    final title = (artwork['title'] ?? artwork['name'] ?? 'Untitled').toString();
    final imgRaw = (artwork['imageUrl'] ?? artwork['image_url'] ?? artwork['coverImage'] ?? artwork['cover_image'])?.toString();
    final imageUrl = MediaUrlResolver.resolve(imgRaw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: id == null || id.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArtDetailScreen(artworkId: id),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: scheme.surfaceContainerHighest,
                    child: imageUrl == null
                        ? Icon(Icons.image_outlined, color: scheme.onSurface.withValues(alpha: 0.5))
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurface.withValues(alpha: 0.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
