import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../models/artwork.dart';
import '../../community/community_interactions.dart';
import '../../services/backend_api_service.dart';
import '../../utils/app_color_utils.dart';
import '../../widgets/artwork_creator_byline.dart';

enum SavedItemsCategory { artworks, posts, all }

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  SavedItemsCategory _activeCategory = SavedItemsCategory.artworks;
  Future<List<CommunityPost>>? _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = BackendApiService().getCommunityPosts(limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Saved Items',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showClearDialog,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear saved items',
          ),
        ],
      ),
      body: Consumer2<SavedItemsProvider, ArtworkProvider>(
        builder: (context, savedItemsProvider, artworkProvider, child) {
          final categoryView = _buildCategoryContent(
            category: _activeCategory,
            savedProvider: savedItemsProvider,
            artworkProvider: artworkProvider,
          );

          return Column(
            children: [
              _buildOverviewSection(savedItemsProvider),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: categoryView,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onCategorySelected(SavedItemsCategory category) {
    if (_activeCategory == category) return;
    setState(() => _activeCategory = category);
  }

  Widget _buildCategoryContent({
    required SavedItemsCategory category,
    required SavedItemsProvider savedProvider,
    required ArtworkProvider artworkProvider,
  }) {
    switch (category) {
      case SavedItemsCategory.artworks:
        return KeyedSubtree(
          key: const ValueKey('saved-artworks'),
          child: _buildArtworksList(savedProvider, artworkProvider),
        );
      case SavedItemsCategory.posts:
        return KeyedSubtree(
          key: const ValueKey('saved-posts'),
          child: _buildPostsList(savedProvider),
        );
      case SavedItemsCategory.all:
        return KeyedSubtree(
          key: const ValueKey('saved-all'),
          child: _buildAllList(savedProvider, artworkProvider),
        );
    }
  }

  Widget _buildOverviewSection(SavedItemsProvider savedProvider) {
    final theme = Theme.of(context);
    final captionColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final lastSaved = savedProvider.mostRecentSave;
    final lastSavedLabel = lastSaved != null
        ? 'Updated ${_formatTimestamp(lastSaved)}'
        : 'Save items to build your collection';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your saved collection',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastSavedLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: captionColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColorUtils.tealAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '${savedProvider.totalSavedCount} items',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColorUtils.tealAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    label: 'Artworks',
                    value: savedProvider.savedArtworksCount.toString(),
                    icon: Icons.palette_outlined,
                    isSelected: _activeCategory == SavedItemsCategory.artworks,
                    onTap: () => _onCategorySelected(SavedItemsCategory.artworks),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    label: 'Posts',
                    value: savedProvider.savedPostsCount.toString(),
                    icon: Icons.article_outlined,
                    isSelected: _activeCategory == SavedItemsCategory.posts,
                    onTap: () => _onCategorySelected(SavedItemsCategory.posts),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    label: 'Combined',
                    value: savedProvider.totalSavedCount.toString(),
                    icon: Icons.collections_bookmark_outlined,
                    isSelected: _activeCategory == SavedItemsCategory.all,
                    onTap: () => _onCategorySelected(SavedItemsCategory.all),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    final backgroundColor = isSelected
        ? AppColorUtils.tealAccent.withValues(alpha: 0.18)
        : theme.colorScheme.surfaceContainerHighest;
    final borderColor = isSelected
        ? AppColorUtils.tealAccent.withValues(alpha: 0.4)
        : theme.colorScheme.outline.withValues(alpha: 0.2);
    final iconBgColor = isSelected
        ? AppColorUtils.tealAccent.withValues(alpha: 0.24)
        : AppColorUtils.tealAccent.withValues(alpha: 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppColorUtils.tealAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworksList(
    SavedItemsProvider savedProvider,
    ArtworkProvider artworkProvider,
  ) {
    final savedArtworkIds = savedProvider.savedArtworkIds.toList();

    if (savedArtworkIds.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.palette_outlined,
        message: 'No saved artworks yet',
      );
    }

    return ListView.builder(
      key: const PageStorageKey('saved-artworks-list'),
      padding: const EdgeInsets.all(16),
      itemCount: savedArtworkIds.length,
      itemBuilder: (context, index) {
        final artworkId = savedArtworkIds[index];
        final artwork = artworkProvider.artworks
            .where((a) => a.id == artworkId)
            .firstOrNull;

        if (artwork == null) {
          return _buildPlaceholderArtworkCard(artworkId, savedProvider);
        }

        return _buildArtworkCard(artwork, savedProvider);
      },
    );
  }

  Widget _buildPostsList(SavedItemsProvider savedProvider) {
    final savedPostIds = savedProvider.savedPostIds
        .where((id) => !savedProvider.savedArtworkIds.contains(id))
        .toList();

    if (savedPostIds.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.article_outlined,
        message: 'No saved posts yet',
      );
    }

    return FutureBuilder<List<CommunityPost>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load posts',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _refreshPosts,
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        final allPosts = snapshot.data ?? const <CommunityPost>[];

        return RefreshIndicator(
          onRefresh: _refreshPosts,
          child: ListView.builder(
            key: const PageStorageKey('saved-posts-list'),
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: savedPostIds.length,
            itemBuilder: (context, index) {
              final postId = savedPostIds[index];

              final post = allPosts.where((p) => p.id == postId).firstOrNull;

              if (post == null) {
                return _buildPlaceholderPostCard(postId, savedProvider);
              }

              return _buildPostCard(post, savedProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildAllList(
    SavedItemsProvider savedProvider,
    ArtworkProvider artworkProvider,
  ) {
    final allSavedIds = savedProvider.getSortedSavedIds();

    if (allSavedIds.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.bookmark_border,
        message: 'No saved items yet',
      );
    }

    return ListView.builder(
      key: const PageStorageKey('saved-all-list'),
      padding: const EdgeInsets.all(16),
      itemCount: allSavedIds.length,
      itemBuilder: (context, index) {
        final itemId = allSavedIds[index];

        if (savedProvider.isArtworkSaved(itemId)) {
          final artwork = artworkProvider.artworks
              .where((a) => a.id == itemId)
              .firstOrNull;

          if (artwork == null) {
            return _buildPlaceholderArtworkCard(itemId, savedProvider);
          }

          return _buildArtworkCard(artwork, savedProvider);
        }

        return _buildPlaceholderPostCard(itemId, savedProvider);
      },
    );
  }

  Future<void> _refreshPosts() async {
    final future = BackendApiService().getCommunityPosts(limit: 100);
    if (mounted) {
      setState(() {
        _postsFuture = future;
      });
    } else {
      _postsFuture = future;
    }
    await future;
  }

  Widget _buildEmptyTabState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(Artwork artwork, SavedItemsProvider savedProvider) {
    final scheme = Theme.of(context).colorScheme;
    final savedTimestamp = savedProvider.getSavedTimestamp(artwork.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Show artwork details in a dialog
          _showArtworkDetails(artwork);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Artwork thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: artwork.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(artwork.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: artwork.imageUrl == null
                    ? Icon(
                        Icons.palette,
                        color: scheme.tertiary,
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Artwork details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artwork.artist,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${artwork.likesCount}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.visibility,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${artwork.viewsCount}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    if (savedTimestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Saved ${_formatTimestamp(savedTimestamp)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Unsave button
              IconButton(
                onPressed: () => _confirmUnsave(artwork.id, 'artwork', savedProvider),
                icon: Icon(
                  Icons.bookmark,
                  color: AppColorUtils.tealAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderArtworkCard(String artworkId, SavedItemsProvider savedProvider) {
    final scheme = Theme.of(context).colorScheme;
    final savedTimestamp = savedProvider.getSavedTimestamp(artworkId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.palette,
                color: scheme.tertiary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Artwork',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loading details...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (savedTimestamp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Saved ${_formatTimestamp(savedTimestamp)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmUnsave(artworkId, 'artwork', savedProvider),
              icon: Icon(
                Icons.bookmark,
                color: AppColorUtils.tealAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post, SavedItemsProvider savedProvider) {
    final scheme = Theme.of(context).colorScheme;
    final savedTimestamp = savedProvider.getSavedTimestamp(post.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.secondary.withValues(alpha: 0.2),
                  child: Text(
                    post.authorName[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: scheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        _formatTimestamp(post.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmUnsave(post.id, 'post', savedProvider),
                  icon: Icon(
                    Icons.bookmark,
                    color: AppColorUtils.tealAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: scheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: scheme.secondary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.image_not_supported,
                      color: scheme.secondary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                if (savedTimestamp != null)
                  Text(
                    'Saved ${_formatTimestamp(savedTimestamp)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPostCard(String postId, SavedItemsProvider savedProvider) {
    final scheme = Theme.of(context).colorScheme;
    final savedTimestamp = savedProvider.getSavedTimestamp(postId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.article,
                color: scheme.secondary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Post',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Community post',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (savedTimestamp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Saved ${_formatTimestamp(savedTimestamp)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmUnsave(postId, 'post', savedProvider),
              icon: Icon(
                Icons.bookmark,
                color: AppColorUtils.tealAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }

  void _confirmUnsave(String itemId, String type, SavedItemsProvider savedProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove from Saved?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove this $type from your saved items?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(),
            ),
          ),
          TextButton(
            onPressed: () {
              if (type == 'artwork') {
                savedProvider.removeArtwork(itemId);
              } else {
                savedProvider.removePost(itemId);
              }
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed from saved items'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showArtworkDetails(Artwork artwork) {
    final scheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image
              if (artwork.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    artwork.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: scheme.tertiary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.palette,
                        size: 64,
                        color: scheme.tertiary,
                      ),
                    ),
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ArtworkCreatorByline(
                      artwork: artwork,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: scheme.tertiary,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      artwork.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailStat(Icons.favorite, '${artwork.likesCount}'),
                        _buildDetailStat(Icons.visibility, '${artwork.viewsCount}'),
                        _buildDetailStat(Icons.comment, '${artwork.commentsCount}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(IconData icon, String value) {
    final scheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        Icon(
          icon,
          color: scheme.tertiary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Saved Items?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove all saved artworks and posts. This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(),
            ),
          ),
          TextButton(
            onPressed: () {
              final savedProvider = Provider.of<SavedItemsProvider>(context, listen: false);
              savedProvider.clearAll();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All saved items cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
