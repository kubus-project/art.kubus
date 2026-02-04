import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/artwork.dart' as art_model;
import '../../../providers/artwork_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/artwork_navigation.dart';
import '../../../utils/artwork_edit_navigation.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';

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

  String _filterLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'All':
        return l10n.artistGalleryFilterAll;
      case 'Active':
        return l10n.artistGalleryFilterActive;
      case 'Draft':
        return l10n.artistGalleryFilterDraft;
      case 'Sold':
        return l10n.artistGalleryFilterSold;
      default:
        return key;
    }
  }

  String _sortLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'Newest':
        return l10n.artistGallerySortNewest;
      case 'Oldest':
        return l10n.artistGallerySortOldest;
      case 'Most Views':
        return l10n.artistGallerySortMostViews;
      case 'Most Likes':
        return l10n.artistGallerySortMostLikes;
      default:
        return key;
    }
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
          final artworks =
              List<art_model.Artwork>.from(artworkProvider.artworks);
          final filteredArtworks = _getFilteredArtworks(artworks);
          final isBusy = artworkProvider.isLoading('load_artworks') ||
              artworkProvider.isLoading('create_artwork');

          return Container(
            color: Colors.transparent,
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.artistGalleryTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.artistGalleryArtworkCount(totalArtworks),
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
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.05),
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
    final l10n = AppLocalizations.of(context)!;
    final totalViews =
        artworks.fold<int>(0, (sum, artwork) => sum + artwork.viewsCount);
    final totalLikes =
        artworks.fold<int>(0, (sum, artwork) => sum + artwork.likesCount);
    final activeCount = artworks.where((a) => a.isPublic).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard(l10n.artistGalleryStatActiveLabel,
                  activeCount.toString(), Icons.visibility)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatCard(l10n.artistGalleryStatViewsLabel,
                  totalViews.toString(), Icons.remove_red_eye)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatCard(l10n.artistGalleryStatLikesLabel,
                  totalLikes.toString(), Icons.favorite)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    final statColor = scheme.primary;
    final glassTint = statColor.withValues(alpha: isDark ? 0.12 : 0.08);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: statColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Column(
          children: [
            Icon(icon,
                color: statColor,
                size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final l10n = AppLocalizations.of(context)!;
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
                _filterLabel(filter, l10n),
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
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

  Widget _buildArtworkCard(
      art_model.Artwork artwork, ArtworkProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(artwork);

    return GestureDetector(
      onTap: () => _showArtworkDetails(artwork),
      child: Container(
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (artwork.isPublic
                                ? l10n.commonPublished
                                : l10n.commonDraft)
                            .toUpperCase(),
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
                          itemBuilder: (context) {
                            return [
                              if (artwork.isPublic)
                                PopupMenuItem(
                                  value: 'unpublish',
                                  child: Text(l10n.commonUnpublish),
                                )
                              else
                                PopupMenuItem(
                                  value: 'publish',
                                  child: Text(l10n.commonPublish),
                                ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                  value: 'edit', child: Text(l10n.commonEdit)),
                              PopupMenuItem(
                                  value: 'share',
                                  child: Text(l10n.commonShare)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.commonDelete)),
                            ];
                          },
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
    final coverUrl = ArtworkMediaResolver.resolveCover(artwork: artwork);
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(16));

    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: DecorationImage(
            image: NetworkImage(coverUrl),
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
    final l10n = AppLocalizations.of(context)!;
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.artistGalleryEmptyTitle,
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
                l10n.artistGalleryEmptyDescription,
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
                label: Text(l10n.artistGalleryCreateArtworkButton),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(art_model.Artwork artwork) {
    return artwork.isPublic
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;
  }

  List<art_model.Artwork> _getFilteredArtworks(
      List<art_model.Artwork> artworks) {
    final filtered = List<art_model.Artwork>.from(artworks.where((artwork) {
      switch (_selectedFilter) {
        case 'Active':
          return artwork.isPublic;
        case 'Draft':
          return !artwork.isPublic;
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
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(l10n.artistGallerySortByTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: RadioGroup<String>(
          groupValue: _sortBy,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _sortBy = value;
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                ['Newest', 'Oldest', 'Most Views', 'Most Likes'].map((option) {
              return RadioListTile<String>(
                title: Text(
                  _sortLabel(option, l10n),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                value: option,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showSearchDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(l10n.artistGallerySearchTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          decoration: InputDecoration(
            hintText: l10n.artistGallerySearchHint,
            hintStyle: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.54),
            ),
            border: const OutlineInputBorder(),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonSearch),
          ),
        ],
      ),
    );
  }

  void _showCreateArtworkDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(l10n.artistGalleryCreateNewTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          l10n.artistGalleryCreateNewDescription,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCreateRequested?.call();
            },
            child: Text(l10n.artistGalleryGoToCreateButton),
          ),
        ],
      ),
    );
  }

  void _showArtworkDetails(art_model.Artwork artwork) {
    openArtwork(context, artwork.id, source: 'artist_gallery');
  }

  Future<void> _handleArtworkAction(
    art_model.Artwork artwork,
    String action,
    ArtworkProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title = artwork.title;
    switch (action) {
      case 'publish':
        final updated = await provider.publishArtwork(artwork.id);
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(
              updated != null
                  ? l10n.artistGalleryPublishSuccessToast(title)
                  : l10n.artistGalleryPublishFailedToast(title),
            ),
          ),
        );
        break;
      case 'unpublish':
        final updated = await provider.unpublishArtwork(artwork.id);
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(
              updated != null
                  ? l10n.artistGalleryUnpublishSuccessToast(title)
                  : l10n.artistGalleryUnpublishFailedToast(title),
            ),
          ),
        );
        break;
      case 'edit':
        await openArtworkEditor(context, artwork.id, source: 'artist_gallery_menu');
        break;
      case 'share':
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.artistGallerySharingToast(title))),
        );
        break;
      case 'delete':
        _confirmDelete(artwork, provider);
        break;
    }
  }

  void _confirmDelete(art_model.Artwork artwork, ArtworkProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(l10n.artistGalleryDeleteArtworkTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          l10n.artistGalleryDeleteConfirmBody(artwork.title),
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              provider.removeArtwork(artwork.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(
                    content:
                        Text(l10n.artistGalleryDeletedToast(artwork.title))),
              );
            },
            child: Text(l10n.commonDelete,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
