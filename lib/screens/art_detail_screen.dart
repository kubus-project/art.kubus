import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../providers/artwork_provider.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';

class ArtDetailScreen extends StatefulWidget {
  final String artworkId;

  const ArtDetailScreen({super.key, required this.artworkId});

  @override
  State<ArtDetailScreen> createState() => _ArtDetailScreenState();
}

class _ArtDetailScreenState extends State<ArtDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _commentController;
  late ScrollController _scrollController;
  bool _showComments = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _scrollController = ScrollController();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
    
    // Increment view count when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArtworkProvider>().incrementViewCount(widget.artworkId);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final artwork = artworkProvider.getArtworkById(widget.artworkId);
        
        if (artwork == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Artwork Not Found', style: GoogleFonts.outfit()),
            ),
            body: const Center(
              child: Text('Artwork not found'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      _buildAppBar(artwork),
                      SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildArtPreview(artwork),
                            const SizedBox(height: 24),
                            _buildArtInfo(artwork),
                            const SizedBox(height: 24),
                            _buildDescription(artwork),
                            const SizedBox(height: 24),
                            _buildSocialStats(artwork),
                            const SizedBox(height: 24),
                            _buildActionButtons(artwork),
                            const SizedBox(height: 24),
                            _buildCommentsSection(artwork, artworkProvider),
                            const SizedBox(height: 100), // Bottom padding
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: _showComments ? _buildCommentFAB(artwork) : null,
        );
      },
    );
  }

  Widget _buildAppBar(Artwork artwork) {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      actions: [
        Consumer<ArtworkProvider>(
          builder: (context, provider, child) {
            return IconButton(
              onPressed: () => provider.toggleFavorite(artwork.id),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  artwork.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: artwork.isFavorite ? Colors.red : null,
                ),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.3),
                Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Color(Artwork.getRarityColor(artwork.rarity)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                artwork.arEnabled ? Icons.view_in_ar : Icons.palette,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtPreview(Artwork artwork) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.2),
            Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Rarity badge
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(Artwork.getRarityColor(artwork.rarity)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                artwork.rarity.name.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Status badge
          if (artwork.isDiscovered)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'DISCOVERED',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // AR badge
          if (artwork.arEnabled)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_in_ar, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'AR ENABLED',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtInfo(Artwork artwork) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          artwork.title,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'by ${artwork.artist}',
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildInfoChip(Icons.category, artwork.category),
            if (artwork.averageRating != null)
              _buildInfoChip(Icons.star, '${artwork.averageRating?.toStringAsFixed(1)} (${artwork.ratingsCount})'),
            _buildInfoChip(Icons.access_time, artwork.createdAt.toString().split(' ')[0]),
          ],
        ),
        const SizedBox(height: 16),
        if (artwork.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: artwork.tags.map((tag) => _buildTag(tag)).toList(),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '#$tag',
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescription(Artwork artwork) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          artwork.description,
          style: GoogleFonts.outfit(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialStats(Artwork artwork) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.favorite, artwork.likesCount, 'Likes'),
          _buildStatItem(Icons.comment, artwork.commentsCount, 'Comments'),
          _buildStatItem(Icons.visibility, artwork.viewsCount, 'Views'),
          _buildStatItem(Icons.explore, artwork.discoveryCount, 'Discoveries'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Artwork artwork) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Consumer<ArtworkProvider>(
                builder: (context, provider, child) {
                  return ElevatedButton.icon(
                    onPressed: () => provider.toggleLike(artwork.id),
                    icon: Icon(
                      artwork.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                      color: artwork.isLikedByCurrentUser ? Colors.red : null,
                    ),
                    label: Text(
                      artwork.isLikedByCurrentUser ? 'Liked' : 'Like',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: artwork.isLikedByCurrentUser 
                          ? Colors.red.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainer,
                      foregroundColor: artwork.isLikedByCurrentUser 
                          ? Colors.red 
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showComments = !_showComments;
                  });
                },
                icon: Icon(
                  _showComments ? Icons.comment : Icons.comment_outlined,
                ),
                label: Text(
                  _showComments ? 'Hide Comments' : 'Comments',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (artwork.arEnabled)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/ar'),
                  icon: const Icon(Icons.view_in_ar),
                  label: Text(
                    'Experience AR',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (artwork.arEnabled) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showNavigationOptions(artwork),
                icon: const Icon(Icons.navigation),
                label: Text(
                  'Navigate',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsSection(Artwork artwork, ArtworkProvider provider) {
    if (!_showComments) return const SizedBox.shrink();

    final comments = provider.getComments(artwork.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${comments.length})',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (comments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No comments yet. Be the first to comment!',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...comments.map((comment) => _buildCommentItem(comment, provider)),
      ],
    );
  }

  Widget _buildCommentItem(ArtworkComment comment, ArtworkProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      comment.timeAgo,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => provider.toggleCommentLike(widget.artworkId, comment.id),
                icon: Icon(
                  comment.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: comment.isLikedByCurrentUser ? Colors.red : null,
                ),
              ),
              if (comment.likesCount > 0)
                Text(
                  comment.likesCount.toString(),
                  style: GoogleFonts.outfit(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: GoogleFonts.outfit(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentFAB(Artwork artwork) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddCommentDialog(artwork),
      icon: const Icon(Icons.add_comment),
      label: Text(
        'Add Comment',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showAddCommentDialog(Artwork artwork) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Comment',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts about this artwork...',
                    hintStyle: GoogleFonts.outfit(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _commentController.clear();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<ArtworkProvider>(
                        builder: (context, provider, child) {
                          return ElevatedButton(
                            onPressed: () => _submitComment(artwork, provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: provider.isLoading('comment_${artwork.id}')
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Post Comment',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                  ),
                          );
                        },
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

  void _submitComment(Artwork artwork, ArtworkProvider provider) async {
    if (_commentController.text.trim().isEmpty) return;

    await provider.addComment(
      artwork.id,
      _commentController.text.trim(),
      'current_user', // TODO: Get from user provider
      'Current User', // TODO: Get from user provider
    );

    if (mounted) {
      _commentController.clear();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Comment added successfully!',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showNavigationOptions(Artwork artwork) {
    final lat = artwork.position.latitude;
    final lng = artwork.position.longitude;
    final artTitle = artwork.title;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Navigate to $artTitle',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildNavigationOption(
                      icon: Icons.map,
                      title: 'Google Maps',
                      onTap: () => _openInGoogleMaps(lat, lng, artTitle),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.apple,
                      title: 'Apple Maps',
                      onTap: () => _openInAppleMaps(lat, lng, artTitle),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.location_on,
                      title: 'Other Maps',
                      onTap: () => _openInDefaultMaps(lat, lng, artTitle),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.copy,
                      title: 'Copy Coordinates',
                      onTap: () => _copyCoordinates(lat, lng),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

  Widget _buildNavigationOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final googleMapsAppUrl = 'comgooglemaps://?q=$lat,$lng';
    
    try {
      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(Uri.parse(googleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog('Could not open Google Maps');
      }
    } catch (e) {
      _showErrorDialog('Error opening Google Maps: $e');
    }
  }

  Future<void> _openInAppleMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
    final appleMapsAppUrl = 'maps://?q=$lat,$lng';
    
    try {
      if (await canLaunchUrl(Uri.parse(appleMapsAppUrl))) {
        await launchUrl(Uri.parse(appleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog('Could not open Apple Maps');
      }
    } catch (e) {
      _showErrorDialog('Error opening Apple Maps: $e');
    }
  }

  Future<void> _openInDefaultMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final defaultMapsUrl = 'geo:$lat,$lng?q=$lat,$lng($title)';
    
    try {
      if (await canLaunchUrl(Uri.parse(defaultMapsUrl))) {
        await launchUrl(Uri.parse(defaultMapsUrl));
      } else {
        // Fallback to web maps
        final webMapsUrl = 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=15';
        if (await canLaunchUrl(Uri.parse(webMapsUrl))) {
          await launchUrl(Uri.parse(webMapsUrl), mode: LaunchMode.externalApplication);
        } else {
          _showErrorDialog('Could not open maps application');
        }
      }
    } catch (e) {
      _showErrorDialog('Error opening maps: $e');
    }
  }

  Future<void> _copyCoordinates(double lat, double lng) async {
    Navigator.pop(context);
    final coordinates = '$lat, $lng';
    await Clipboard.setData(ClipboardData(text: coordinates));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coordinates copied to clipboard: $coordinates',
            style: GoogleFonts.outfit(),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Navigation Error',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
