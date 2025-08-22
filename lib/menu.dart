import 'package:art_kubus/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'web3/web3_dashboard.dart';
import 'web3/wallet/wallet_overview.dart';
import 'web3/artist/artist_studio.dart';
import 'web3/institution/institution_hub.dart';
import 'web3/marketplace/marketplace.dart';
import 'web3/dao/governance_hub.dart';
import 'community/communitymenu.dart';
import 'settings.dart';
import 'providers/web3provider.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _selectedCategory = 0;

  final List<String> _categories = ['Main', 'Web3', 'Create', 'Social'];

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
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(context),
              _buildCategoryTabs(),
              Expanded(
                child: _buildMenuContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  Theme.of(context).primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: FloatingActionButton(
              heroTag: 'ProfileFAB',
              backgroundColor: Colors.transparent,
              elevation: 0,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: const Icon(Icons.person, size: 30),
            ),
          ),
          
          // App Title
          Text(
            'art.kubus',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          
          // Wallet Button
          Consumer<Web3Provider>(
            builder: (context, web3Provider, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                  ),
                ),
                child: FloatingActionButton.extended(
                  heroTag: 'WalletFAB',
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WalletOverview()),
                    );
                  },
                  icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                  label: const Text(
                    '1000 KUB8',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 20, 
            vertical: isSmallScreen ? 8 : 10,
          ),
          child: Row(
            children: _categories.asMap().entries.map((entry) {
              int index = entry.key;
              String category = entry.value;
              bool isSelected = _selectedCategory == index;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isSelected 
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                      border: Border.all(
                        color: isSelected 
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected 
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMenuContent() {
    switch (_selectedCategory) {
      case 0:
        return _buildMainMenu();
      case 1:
        return _buildWeb3Menu();
      case 2:
        return _buildCreateMenu();
      case 3:
        return _buildSocialMenu();
      default:
        return _buildMainMenu();
    }
  }

  Widget _buildMainMenu() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20),
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? 16 : 20),
              // Featured Web3 Dashboard
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Web3Dashboard()),
                  ),
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.rocket_launch, 
                            color: Colors.white, 
                            size: isSmallScreen ? 28 : 32,
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Web3 Studio',
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Your complete blockchain creative workspace',
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 12 : 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios, 
                            color: Colors.white, 
                            size: isSmallScreen ? 16 : 20,
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickStat('Wallet', '1000 KUB8', Icons.account_balance_wallet, isSmallScreen),
                            SizedBox(width: isSmallScreen ? 16 : 20),
                            _buildQuickStat('NFTs', '5', Icons.collections, isSmallScreen),
                            SizedBox(width: isSmallScreen ? 16 : 20),
                            _buildQuickStat('Created', '12', Icons.palette, isSmallScreen),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              buildModernMenuItem(
                context,
                title: 'Community Hub',
                subtitle: 'Connect with artists worldwide',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CommunityMenu()),
                ),
                icon: Icons.people,
                gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF00E5FF)]),
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              buildModernMenuItem(
                context,
                title: 'Settings & Profile',
                subtitle: 'Customize your experience',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppSettings()),
                ),
                icon: Icons.settings,
                gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                isSmallScreen: isSmallScreen,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, bool isSmallScreen) {
    return Column(
      children: [
        Icon(
          icon, 
          color: Colors.white.withValues(alpha: 0.8), 
          size: isSmallScreen ? 16 : 20,
        ),
        SizedBox(height: isSmallScreen ? 2 : 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isSmallScreen ? 10 : 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildWeb3Menu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Main Dashboard Entry
          buildModernMenuItem(
            context,
            title: 'Web3 Studio Dashboard',
            subtitle: 'Your complete Web3 workspace',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Web3Dashboard()),
            ),
            icon: Icons.dashboard,
            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)]),
          ),
          const SizedBox(height: 24),
          // Quick Access Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                buildWeb3Card(
                  context,
                  title: 'Wallet & Assets',
                  icon: Icons.account_balance_wallet,
                  gradient: const LinearGradient(colors: [Color(0xFFFFD93D), Color(0xFFFF9A8B)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WalletOverview()),
                  ),
                ),
                buildWeb3Card(
                  context,
                  title: 'NFT Marketplace',
                  icon: Icons.store,
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFF9C27B0)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Marketplace()),
                  ),
                ),
                buildWeb3Card(
                  context,
                  title: 'Artist Studio',
                  icon: Icons.palette,
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ArtistStudio()),
                  ),
                ),
                buildWeb3Card(
                  context,
                  title: 'Institution Hub',
                  icon: Icons.location_city,
                  gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF4CAF50)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InstitutionHub()),
                  ),
                ),
                buildWeb3Card(
                  context,
                  title: 'DAO Governance',
                  icon: Icons.how_to_vote,
                  gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF00D4AA)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GovernanceHub()),
                  ),
                ),
                buildWeb3Card(
                  context,
                  title: 'Coming Soon',
                  icon: Icons.rocket_launch,
                  gradient: const LinearGradient(colors: [Color(0xFF666666), Color(0xFF999999)]),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('More Web3 features coming soon!'),
                        backgroundColor: Color(0xFF6C63FF),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Quick Access to Web3 Studio
          buildModernMenuItem(
            context,
            title: 'Web3 Creative Studio',
            subtitle: 'Access all creation tools in one place',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Web3Dashboard()),
            ),
            icon: Icons.auto_awesome,
            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)]),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: buildWeb3Card(
                  context,
                  title: 'Artist Studio',
                  icon: Icons.palette,
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ArtistStudio()),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildWeb3Card(
                  context,
                  title: 'Institution Hub',
                  icon: Icons.location_city,
                  gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF4CAF50)]),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InstitutionHub()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildModernMenuItem(
            context,
            title: 'Traditional AR Creation',
            subtitle: 'Create AR experiences without blockchain',
            onPressed: () {
              // TODO: Navigate to traditional AR creation tools
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Traditional AR tools coming soon!'),
                  backgroundColor: Color(0xFF00D4AA),
                ),
              );
            },
            icon: Icons.view_in_ar,
            gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF00E5FF)]),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          buildModernMenuItem(
            context,
            title: 'Community Feed',
            subtitle: 'Latest from the community',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommunityMenu()),
            ),
            icon: Icons.feed,
            gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF00E5FF)]),
          ),
          const SizedBox(height: 16),
          buildModernMenuItem(
            context,
            title: 'Events & Exhibitions',
            subtitle: 'Discover AR art events',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InstitutionHub()),
            ),
            icon: Icons.event,
            gradient: const LinearGradient(colors: [Color(0xFFffecd2), Color(0xFFfcb69f)]),
          ),
        ],
      ),
    );
  }

  Widget buildModernMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    required IconData icon,
    required Gradient gradient,
    bool isSmallScreen = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: isSmallScreen ? 14 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildWeb3Card(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
