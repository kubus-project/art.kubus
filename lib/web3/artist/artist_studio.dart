import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../onboarding/web3_onboarding.dart';
import '../onboarding/onboarding_data.dart';
import 'marker_creator.dart';
import 'artwork_gallery.dart';
import 'artist_analytics.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

class ArtistStudio extends StatefulWidget {
  const ArtistStudio({super.key});

  @override
  State<ArtistStudio> createState() => _ArtistStudioState();
}

class _ArtistStudioState extends State<ArtistStudio> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ArtworkGallery(),
    const MarkerCreator(),
    const ArtistAnalytics(),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(ArtistStudioOnboardingData.featureName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboarding();
      });
    }
  }

  void _showOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Web3OnboardingScreen(
          featureName: ArtistStudioOnboardingData.featureName,
          pages: ArtistStudioOnboardingData.pages,
          onComplete: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Artist Studio',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon:  Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showOnboarding,
          ),
          IconButton(
            icon:  Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildStudioHeader(),
                  _buildNavigationTabs(),
                ],
              ),
            ),
          ];
        },
        body: _pages[_selectedIndex],
      ),
    );
  }

  Widget _buildStudioHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Provider.of<ThemeProvider>(context).accentColor, Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.palette,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to your Studio',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create AR markers for your artwork and share them with the world',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Gallery', Icons.collections, 0)),
          Expanded(child: _buildTabButton('Create', Icons.add_circle_outline, 1)),
          Expanded(child: _buildTabButton('Analytics', Icons.analytics, 2)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Provider.of<ThemeProvider>(context).accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Studio Settings',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // Add settings options here
          ],
        ),
      ),
    );
  }
}







