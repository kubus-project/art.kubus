import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/artwork_provider.dart';
import '../widgets/empty_state_card.dart';
import 'art_detail_screen.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      try {
        context.read<ArtworkProvider>().ensureHistoryLoaded();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'View History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<ArtworkProvider>(
        builder: (context, artworkProvider, child) {
          final entries = artworkProvider.viewHistoryEntries;
          final items = artworkProvider.getViewHistoryArtworks();

          if (entries.isEmpty || items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyStateCard(
                icon: Icons.history,
                title: 'No views yet',
                description: 'Start exploring artworks, AR markers, and collections to see your history here.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final artwork = artworkProvider.getArtworkById(entry.artworkId);
              if (artwork == null) {
                return const SizedBox.shrink();
              }
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: artwork.imageUrl != null && artwork.imageUrl!.isNotEmpty
                      ? Image.network(
                          artwork.imageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(Icons.image_not_supported, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                ),
                title: Text(
                  artwork.title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  entry.markerId != null && entry.markerId!.isNotEmpty
                      ? 'Linked marker: ${entry.markerId}'
                      : 'Viewed ${_formatRelative(entry.viewedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtDetailScreen(artworkId: artwork.id)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatRelative(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
