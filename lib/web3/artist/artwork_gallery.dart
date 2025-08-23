import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

class ArtworkGallery extends StatefulWidget {
  const ArtworkGallery({super.key});

  @override
  State<ArtworkGallery> createState() => _ArtworkGalleryState();
}

class _ArtworkGalleryState extends State<ArtworkGallery> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _selectedFilter = 'All';
  String _sortBy = 'Newest';
  List<Artwork> _artworks = [];

  @override
  void initState() {
    super.initState();
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
    
    _loadArtworks();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadArtworks() {
    // Simulate loading artworks
    _artworks = [
      Artwork(
        id: '1',
        title: 'Digital Dreams',
        description: 'A vibrant digital artwork exploring the intersection of technology and creativity',
        imageUrl: 'https://picsum.photos/400/600?random=1',
        status: ArtworkStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        price: 0.5,
        views: 156,
        likes: 23,
        hasARMarker: true,
        location: 'Gallery A',
      ),
      Artwork(
        id: '2',
        title: 'Urban Landscapes',
        description: 'Contemporary cityscapes captured through digital media',
        imageUrl: 'https://picsum.photos/400/600?random=2',
        status: ArtworkStatus.draft,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        price: 0.8,
        views: 89,
        likes: 12,
        hasARMarker: false,
        location: null,
      ),
      Artwork(
        id: '3',
        title: 'Abstract Emotions',
        description: 'An exploration of human emotions through abstract forms',
        imageUrl: 'https://picsum.photos/400/600?random=3',
        status: ArtworkStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        price: 1.2,
        views: 234,
        likes: 45,
        hasARMarker: true,
        location: 'Main Hall',
      ),
      Artwork(
        id: '4',
        title: 'Nature\'s Code',
        description: 'Digital representation of natural patterns and algorithms',
        imageUrl: 'https://picsum.photos/400/600?random=4',
        status: ArtworkStatus.sold,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        price: 2.0,
        views: 567,
        likes: 89,
        hasARMarker: true,
        location: 'Sold Collection',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filteredArtworks = _getFilteredArtworks();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: const Color(0xFF0A0A0A),
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsRow(),
            _buildFilterBar(),
            Expanded(
              child: filteredArtworks.isEmpty 
                  ? _buildEmptyState() 
                  : _buildArtworkGrid(filteredArtworks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_artworks.length} artworks',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white, size: 20),
                onPressed: () => _showSortDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 20),
                onPressed: () => _showSearchDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () => _showCreateArtworkDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalViews = _artworks.fold<int>(0, (sum, artwork) => sum + artwork.views);
    final totalLikes = _artworks.fold<int>(0, (sum, artwork) => sum + artwork.likes);
    final activeCount = _artworks.where((a) => a.status == ArtworkStatus.active).length;
    
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Active', 'Draft', 'Sold'];
    
    return Padding(
      padding: const EdgeInsets.all(24),
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
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              selectedColor: Provider.of<ThemeProvider>(context).accentColor,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildArtworkGrid(List<Artwork> artworks) {
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
        return _buildArtworkCard(artworks[index]);
      },
    );
  }

  Widget _buildArtworkCard(Artwork artwork) {
    final statusColor = _getStatusColor(artwork.status);
    
    return GestureDetector(
      onTap: () => _showArtworkDetails(artwork),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      image: DecorationImage(
                        image: NetworkImage(artwork.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        artwork.status.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (artwork.hasARMarker)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        Icons.view_in_ar,
                        color: Colors.white,
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
                    Flexible(
                      child: Text(
                        artwork.title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${artwork.price} KUB8',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 10, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            artwork.views.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.favorite, size: 10, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            artwork.likes.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.white.withOpacity(0.6),
                            size: 14,
                          ),
                          onSelected: (value) => _handleArtworkAction(artwork, value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'share', child: Text('Share')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.palette,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No artworks yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first artwork to get started',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateArtworkDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Artwork'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ArtworkStatus status) {
    switch (status) {
      case ArtworkStatus.active:
        return Colors.green;
      case ArtworkStatus.draft:
        return Colors.orange;
      case ArtworkStatus.sold:
        return Colors.blue;
    }
  }

  List<Artwork> _getFilteredArtworks() {
    List<Artwork> filtered = _artworks;
    
    if (_selectedFilter != 'All') {
      filtered = filtered.where((artwork) {
        switch (_selectedFilter) {
          case 'Active':
            return artwork.status == ArtworkStatus.active;
          case 'Draft':
            return artwork.status == ArtworkStatus.draft;
          case 'Sold':
            return artwork.status == ArtworkStatus.sold;
          default:
            return true;
        }
      }).toList();
    }
    
    // Sort artworks
    switch (_sortBy) {
      case 'Newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Most Views':
        filtered.sort((a, b) => b.views.compareTo(a.views));
        break;
      case 'Most Likes':
        filtered.sort((a, b) => b.likes.compareTo(a.likes));
        break;
    }
    
    return filtered;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Sort by', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Newest', 'Oldest', 'Most Views', 'Most Likes'].map((option) {
            return RadioListTile<String>(
              title: Text(option, style: const TextStyle(color: Colors.white)),
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Search Artworks', style: TextStyle(color: Colors.white)),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter artwork title...',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            // Implement search functionality
          },
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Create New Artwork', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Navigate to the Create tab to upload and create your new artwork.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to create tab
            },
            child: const Text('Go to Create'),
          ),
        ],
      ),
    );
  }

  void _showArtworkDetails(Artwork artwork) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  artwork.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                artwork.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artwork.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDetailItem('Price', '${artwork.price} KUB8'),
                  _buildDetailItem('Views', artwork.views.toString()),
                  _buildDetailItem('Likes', artwork.likes.toString()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleArtworkAction(artwork, 'edit');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                      ),
                      child: const Text('Edit', style: TextStyle(color: Colors.white)),
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
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  void _handleArtworkAction(Artwork artwork, String action) {
    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Editing ${artwork.title}')),
        );
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sharing ${artwork.title}')),
        );
        break;
      case 'delete':
        _confirmDelete(artwork);
        break;
    }
  }

  void _confirmDelete(Artwork artwork) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Artwork', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${artwork.title}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _artworks.removeWhere((a) => a.id == artwork.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${artwork.title} deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Artwork model
class Artwork {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final ArtworkStatus status;
  final DateTime createdAt;
  final double price;
  final int views;
  final int likes;
  final bool hasARMarker;
  final String? location;

  Artwork({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.price,
    required this.views,
    required this.likes,
    required this.hasARMarker,
    this.location,
  });
}

enum ArtworkStatus {
  active,
  draft,
  sold,
}
