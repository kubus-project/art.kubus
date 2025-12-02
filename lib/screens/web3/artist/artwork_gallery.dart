import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/artwork.dart' as art_model;
import '../../../providers/artwork_provider.dart';
import '../../../providers/themeprovider.dart';

class ArtworkGallery extends StatefulWidget {
  final VoidCallback? onCreateRequested;

  const ArtworkGallery({super.key, this.onCreateRequested});

  @override
  State<ArtworkGallery> createState() => _ArtworkGalleryState();
}

class _ArtworkGalleryState extends State<ArtworkGallery>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _selectedFilter = 'All';
  String _sortBy = 'Newest';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Consumer<ArtworkProvider>(
        builder: (context, artworkProvider, child) {
          final artworks = List<art_model.Artwork>.from(artworkProvider.artworks);
          final filteredArtworks = _getFilteredArtworks(artworks);
          final isBusy = artworkProvider.isLoading('load_artworks') ||
              artworkProvider.isLoading('create_artwork');

          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                _buildHeader(artworks.length, isBusy),
                _buildStatsRow(artworks),
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => artworkProvider.loadArtworks(),
                    child: filteredArtworks.isEmpty
                        ? _buildEmptyState()
                        : _buildArtworkGrid(filteredArtworks, artworkProvider),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(int totalArtworks, bool isBusy) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Gallery',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalArtworks artworks',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          if (isBusy) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor:
                  Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
              color: themeProvider.accentColor,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.sort,
                    color: Theme.of(context).colorScheme.onSurface, size: 20),
                onPressed: _showSortDialog,
              ),
              IconButton(
                icon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.onSurface, size: 20),
                onPressed: _showSearchDialog,
              ),
              IconButton(
                icon: Icon(Icons.add,
                    color: Theme.of(context).colorScheme.onSurface, size: 20),
                onPressed: _showCreateArtworkDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<art_model.Artwork> artworks) {
    final totalViews =
        artworks.fold<int>(0, (sum, artwork) => sum + artwork.viewsCount);
    final totalLikes =
        artworks.fold<int>(0, (sum, artwork) => sum + artwork.likesCount);
    final activeCount = artworks
        .where((a) =>
            a.status == art_model.ArtworkStatus.discovered ||
            a.status == art_model.ArtworkStatus.favorite)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Active', activeCount.toString(), Icons.visibility)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Views', totalViews.toString(), Icons.remove_red_eye)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Likes', totalLikes.toString(), Icons.favorite)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Active', 'Draft', 'Sold'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              backgroundColor: Colors.transparent,
              selectedColor: Provider.of<ThemeProvider>(context).accentColor,
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildArtworkGrid(
    List<art_model.Artwork> artworks,
    ArtworkProvider provider,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: artworks.length,
      itemBuilder: (context, index) {
        return _buildArtworkCard(artworks[index], provider);
      },
    );
  }

  Widget _buildArtworkCard(art_model.Artwork artwork, ArtworkProvider provider) {
    final statusColor = _getStatusColor(artwork);

    return GestureDetector(
      onTap: () => _showArtworkDetails(artwork),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  _buildArtworkCover(artwork),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        artwork.status.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (artwork.arEnabled)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        Icons.view_in_ar,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${artwork.actualRewards} KUB8',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye,
                            size: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6)),
                        const SizedBox(width: 2),
                        Text(
                          artwork.viewsCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.favorite,
                            size: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6)),
                        const SizedBox(width: 2),
                        Text(
                          artwork.likesCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            size: 14,
                          ),
                          onSelected: (value) =>
                              _handleArtworkAction(artwork, value, provider),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'share', child: Text('Share')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkCover(art_model.Artwork artwork) {
    final hasImage = artwork.imageUrl != null && artwork.imageUrl!.isNotEmpty;
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(16));

    if (hasImage) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: DecorationImage(
            image: NetworkImage(artwork.imageUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Icon(
        Icons.image,
        color: Theme.of(context).colorScheme.onPrimary,
        size: 36,
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.palette,
                size: 64,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No artworks yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first artwork to get started',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onCreateRequested,
                icon: const Icon(Icons.add),
                label: const Text('Create Artwork'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(art_model.Artwork artwork) {
    switch (artwork.status) {
      case art_model.ArtworkStatus.discovered:
      case art_model.ArtworkStatus.favorite:
        return Theme.of(context).colorScheme.primary;
      case art_model.ArtworkStatus.undiscovered:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  List<art_model.Artwork> _getFilteredArtworks(
      List<art_model.Artwork> artworks) {
    final filtered = List<art_model.Artwork>.from(artworks.where((artwork) {
      switch (_selectedFilter) {
        case 'Active':
          return artwork.status == art_model.ArtworkStatus.discovered ||
              artwork.status == art_model.ArtworkStatus.favorite;
        case 'Draft':
          return artwork.status == art_model.ArtworkStatus.undiscovered;
        case 'Sold':
          return false;
        default:
          return true;
      }
    }));

    switch (_sortBy) {
      case 'Newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Most Views':
        filtered.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'Most Likes':
        filtered.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
    }

    return filtered;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Sort by',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Newest', 'Oldest', 'Most Views', 'Most Likes'].map((option) {
            return RadioListTile<String>(
              title: Text(option,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              value: option,
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Search Artworks',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Enter artwork title...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54),
            ),
            border: const OutlineInputBorder(),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showCreateArtworkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Create New Artwork',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Navigate to the Create tab to upload and create your new artwork.',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCreateRequested?.call();
            },
            child: const Text('Go to Create'),
          ),
        ],
      ),
    );
  }

  void _showArtworkDetails(art_model.Artwork artwork) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: artwork.imageUrl != null && artwork.imageUrl!.isNotEmpty
                    ? Image.network(
                        artwork.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 200,
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.image,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                artwork.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artwork.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDetailItem('Rewards', '${artwork.actualRewards} KUB8'),
                  _buildDetailItem('Views', artwork.viewsCount.toString()),
                  _buildDetailItem('Likes', artwork.likesCount.toString()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.1),
                      ),
                      child: Text('Close',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onCreateRequested?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Provider.of<ThemeProvider>(context).accentColor,
                      ),
                      child: Text('Create AR marker',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _handleArtworkAction(
    art_model.Artwork artwork,
    String action,
    ArtworkProvider provider,
  ) {
    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Editing ${artwork.title}')));
        break;
      case 'share':
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sharing ${artwork.title}')));
        break;
      case 'delete':
        _confirmDelete(artwork, provider);
        break;
    }
  }

  void _confirmDelete(art_model.Artwork artwork, ArtworkProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Delete Artwork',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to delete "${artwork.title}"? This action cannot be undone.',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              provider.removeArtwork(artwork.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${artwork.title} deleted')),
              );
            },
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}





