import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/themeprovider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/ar_screen.dart';
import 'screens/community_screen.dart';
import 'screens/profile_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0; // Start with map (index 0)
  
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      const MapScreen(), // Map as first screen for art exploration
      const ARScreen(),
      const HomeScreen(), // Home moved to middle
      const CommunityScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? const Color(0xFF0A0A0A) 
          : const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        
        return Container(
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode 
                ? const Color(0xFF1A1A1A) 
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 8, 
                vertical: isSmallScreen ? 6 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.map, 'Explore', isSmallScreen),
                  _buildNavItem(1, Icons.view_in_ar, 'AR', isSmallScreen),
                  _buildNavItem(2, Icons.home, 'Home', isSmallScreen),
                  _buildNavItem(3, Icons.people, 'Community', isSmallScreen),
                  _buildNavItem(4, Icons.person, 'Profile', isSmallScreen),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isSmallScreen) {
    final isSelected = _currentIndex == index;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : 8, 
            vertical: isSmallScreen ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? themeProvider.accentColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? themeProvider.accentColor
                    : Colors.grey[600],
                size: isSmallScreen ? 18 : 22,
              ),
              SizedBox(height: isSmallScreen ? 1 : 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 8 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? themeProvider.accentColor
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
