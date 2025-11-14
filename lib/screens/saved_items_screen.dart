import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/artwork_provider.dart';
import '../models/artwork.dart';
import '../community/community_interactions.dart';
import '../services/backend_api_service.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Artworks', 'Posts', 'All'];
  Future<List<CommunityPost>>? _postsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _postsFuture = BackendApiService().getCommunityPosts(limit: 100);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Saved Items',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showClearDialog,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear saved items',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: themeProvider.accentColor,
          labelColor: themeProvider.accentColor,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<SavedItemsProvider>(
        builder: (context, savedItemsProvider, child) {
          if (savedItemsProvider.totalSavedCount == 0) {
            return _buildEmptyState();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildArtworksTab(),
              _buildPostsTab(),
              _buildAllTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No Saved Items',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Start saving artworks and posts you love to see them here',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworksTab() {
    return Consumer2<SavedItemsProvider, ArtworkProvider>(
      builder: (context, savedProvider, artworkProvider, child) {
        final savedArtworkIds = savedProvider.savedArtworkIds.toList();
        
        if (savedArtworkIds.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.palette_outlined,
            message: 'No saved artworks yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedArtworkIds.length,
          itemBuilder: (context, index) {
            final artworkId = savedArtworkIds[index];
            final artwork = artworkProvider.artworks
                .where((a) => a.id == artworkId)
                .firstOrNull;
            
            if (artwork == null) {
              // Artwork not found, show placeholder
              return _buildPlaceholderArtworkCard(artworkId, savedProvider);
            }
            
            return _buildArtworkCard(artwork, savedProvider);
          },
        );
      },
    );
  }

  Widget _buildPostsTab() {
    return Consumer<SavedItemsProvider>(
      builder: (context, savedProvider, child) {
        final savedPostIds = savedProvider.savedPostIds.toList();

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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildEmptyTabState(
                icon: Icons.error_outline,
                message: 'Failed to load posts',
              );
            }

            final allPosts = snapshot.data ?? const <CommunityPost>[];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedPostIds.length,
              itemBuilder: (context, index) {
                final postId = savedPostIds[index];

                final post = allPosts.where((p) => p.id == postId).firstOrNull;

                if (post == null) {
                  return _buildPlaceholderPostCard(postId, savedProvider);
                }

                return _buildPostCard(post, savedProvider);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAllTab() {
    return Consumer2<SavedItemsProvider, ArtworkProvider>(
      builder: (context, savedProvider, artworkProvider, child) {
        final allSavedIds = savedProvider.getSortedSavedIds();
        
        if (allSavedIds.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.bookmark_border,
            message: 'No saved items yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allSavedIds.length,
          itemBuilder: (context, index) {
            final itemId = allSavedIds[index];
            
            // Check if it's an artwork or post
            if (savedProvider.isArtworkSaved(itemId)) {
              final artwork = artworkProvider.artworks
                  .where((a) => a.id == itemId)
                  .firstOrNull;
              
              if (artwork == null) {
                return _buildPlaceholderArtworkCard(itemId, savedProvider);
              }
              
              return _buildArtworkCard(artwork, savedProvider);
            } else {
              return _buildPlaceholderPostCard(itemId, savedProvider);
            }
          },
        );
      },
    );
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final savedTimestamp = savedProvider.getSavedTimestamp(artwork.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
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
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
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
                        color: themeProvider.accentColor,
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
                  color: themeProvider.accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderArtworkCard(String artworkId, SavedItemsProvider savedProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final savedTimestamp = savedProvider.getSavedTimestamp(artworkId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
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
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.palette,
                color: themeProvider.accentColor,
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
                color: themeProvider.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post, SavedItemsProvider savedProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final savedTimestamp = savedProvider.getSavedTimestamp(post.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
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
                  backgroundColor: themeProvider.accentColor.withValues(alpha: 0.2),
                  child: Text(
                    post.authorName[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: themeProvider.accentColor,
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _formatTimestamp(post.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmUnsave(post.id, 'post', savedProvider),
                  icon: Icon(
                    Icons.bookmark,
                    color: themeProvider.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
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
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.image_not_supported,
                      color: themeProvider.accentColor,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final savedTimestamp = savedProvider.getSavedTimestamp(postId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
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
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.article,
                color: themeProvider.accentColor,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Community post',
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
              onPressed: () => _confirmUnsave(postId, 'post', savedProvider),
              icon: Icon(
                Icons.bookmark,
                color: themeProvider.accentColor,
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
          'Are you sure you want to remove this ${type} from your saved items?',
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.palette,
                        size: 64,
                        color: themeProvider.accentColor,
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
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'by ${artwork.artist}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: themeProvider.accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      artwork.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
                          backgroundColor: themeProvider.accentColor,
                          foregroundColor: Colors.white,
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return Column(
      children: [
        Icon(
          icon,
          color: themeProvider.accentColor,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
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
