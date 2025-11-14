import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import 'art_detail_screen.dart';
import 'collection_settings_screen.dart';
import '../web3/artist/marker_creator.dart';

class CollectionDetailScreen extends StatefulWidget {
  final int collectionIndex;

  const CollectionDetailScreen({
    super.key,
    required this.collectionIndex,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> collectionNames = [
    'Digital Dreams',
    'Urban AR',
    'Nature Spirits',
    'Tech Fusion',
    'Abstract Reality'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = collectionNames[widget.collectionIndex % collectionNames.length];
    final artworkCount = 3 + widget.collectionIndex;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(collectionName),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildCollectionInfo(collectionName, artworkCount),
                      const SizedBox(height: 24),
                      _buildDescription(),
                      const SizedBox(height: 24),
                      _buildArtworksGrid(artworkCount),
                      const SizedBox(height: 24),
                      _buildActions(),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(String collectionName) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _shareCollection(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.share,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _editCollection(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit,
              color: Colors.white,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.collections,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionInfo(String collectionName, int artworkCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          collectionName,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'by You',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildInfoChip(Icons.palette, '$artworkCount artworks'),
            const SizedBox(width: 12),
            _buildInfoChip(
              Icons.calendar_today, 
              'Created ${DateTime.now().subtract(Duration(days: widget.collectionIndex * 10)).year}'
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final descriptions = [
      'A curated collection of digital artworks that blur the line between dreams and reality.',
      'Street art meets augmented reality in this urban-inspired collection.',
      'Nature-themed AR sculptures that bring the outdoors into your space.',
      'Where technology and art converge to create stunning digital experiences.',
      'Abstract forms that challenge perception and reality through AR visualization.'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          descriptions[widget.collectionIndex % descriptions.length],
          style: GoogleFonts.inter(
            fontSize: 16,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildArtworksGrid(int artworkCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artworks',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: artworkCount,
          itemBuilder: (context, index) => _buildArtworkCard(index),
        ),
      ],
    );
  }

  Widget _buildArtworkCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () => _openArtworkDetail(index),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeProvider.accentColor.withValues(alpha: 0.3),
                      themeProvider.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Center(
                  child: Icon(Icons.view_in_ar, color: Colors.white, size: 32),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artwork #${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${20 + index * 3} views',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _addArtwork(),
            icon: const Icon(Icons.add),
            label: const Text('Add Artwork'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _manageCollection(),
            icon: const Icon(Icons.settings),
            label: const Text('Manage'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openArtworkDetail(int index) {
    // Create artwork data for the existing ArtDetailScreen
    final artData = {
      'title': 'Artwork #${index + 1}',
      'artist': 'You',
      'type': 'Digital Sculpture',
      'rarity': ['Common', 'Rare', 'Epic', 'Legendary'][index % 4],
      'discovered': true,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtDetailScreen(artworkId: artData['id']?.toString() ?? ''),
      ),
    );
  }

  void _shareCollection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing collection...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _editCollection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening collection editor...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addArtwork() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MarkerCreator(),
      ),
    );
  }

  void _manageCollection() {
    final collectionName = collectionNames[widget.collectionIndex % collectionNames.length];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionSettingsScreen(
          collectionIndex: widget.collectionIndex,
          collectionName: collectionName,
        ),
      ),
    );
  }
}
