import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../onboarding/web3_onboarding.dart';
import '../onboarding/onboarding_data.dart';

class Marketplace extends StatefulWidget {
  const Marketplace({super.key});

  @override
  State<Marketplace> createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _buildFeaturedNFTs(),
      _buildTrendingNFTs(),
      _buildMyListings(),
    ]);
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(MarketplaceOnboardingData.featureName)) {
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
          featureName: MarketplaceOnboardingData.featureName,
          pages: MarketplaceOnboardingData.pages,
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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildResponsiveAppBar(),
      body: Column(
        children: [
          _buildMarketplaceHeader(),
          _buildNavigationTabs(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  AppBar _buildResponsiveAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = MediaQuery.of(context).size.width < 375;
          
          return Text(
            'NFT Marketplace',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: _showOnboarding,
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMarketplaceHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        
        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: isSmallScreen ? 50 : 60,
                    height: isSmallScreen ? 50 : 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 25 : 30),
                    ),
                    child: Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: isSmallScreen ? 24 : 30,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Digital Art Market',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Buy, sell & discover unique NFTs',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMarketStat('Total Volume', '12.5K ETH', isSmallScreen),
                  _buildMarketStat('Floor Price', '0.08 ETH', isSmallScreen),
                  _buildMarketStat('Listed', '847', isSmallScreen),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketStat(String label, String value, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 10 : 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton('Featured', Icons.star, 0),
          _buildTabButton('Trending', Icons.trending_up, 1),
          _buildTabButton('My Items', Icons.person, 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF6B6B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedNFTs() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 10,
      itemBuilder: (context, index) {
        return _buildNFTCard(index);
      },
    );
  }

  Widget _buildNFTCard(int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.3),
                    const Color(0xFF9C27B0).withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Icon(
                Icons.image,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AR Art #${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by Artist${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(index + 1) * 0.1} KUB8',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4AA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Buy',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF00D4AA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingNFTs() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'Trending NFTs - Coming Soon',
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMyListings() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'My Listings - Coming Soon',
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
