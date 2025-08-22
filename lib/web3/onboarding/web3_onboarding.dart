import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Web3OnboardingScreen extends StatefulWidget {
  final String featureName;
  final List<OnboardingPage> pages;
  final VoidCallback onComplete;

  const Web3OnboardingScreen({
    super.key,
    required this.featureName,
    required this.pages,
    required this.onComplete,
  });

  @override
  State<Web3OnboardingScreen> createState() => _Web3OnboardingScreenState();
}

class _Web3OnboardingScreenState extends State<Web3OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.featureName}_onboarding_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: widget.pages.length,
                        itemBuilder: (context, index) {
                          return _buildPage(widget.pages[index]);
                        },
                      ),
                    ),
                    _buildBottomNavigation(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.featureName,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 700;
        final isVerySmallScreen = constraints.maxHeight < 600;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: isVerySmallScreen ? 80 : isSmallScreen ? 100 : 120,
                  height: isVerySmallScreen ? 80 : isSmallScreen ? 100 : 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: page.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    page.icon,
                    size: isVerySmallScreen ? 40 : isSmallScreen ? 50 : 60,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isVerySmallScreen ? 20 : isSmallScreen ? 30 : 40),
                Text(
                  page.title,
                  style: GoogleFonts.inter(
                    fontSize: isVerySmallScreen ? 20 : isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isVerySmallScreen ? 8 : isSmallScreen ? 12 : 16),
                Text(
                  page.description,
                  style: GoogleFonts.inter(
                    fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isVerySmallScreen ? 16 : isSmallScreen ? 24 : 32),
                if (page.features.isNotEmpty) ...[
                  ...page.features.map((feature) => _buildFeatureItem(feature, isSmallScreen)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String feature, [bool isSmallScreen = false]) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, 
        top: isSmallScreen ? 6 : 8, 
        bottom: isSmallScreen ? 6 : 8
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 5 : 6,
            height: isSmallScreen ? 5 : 6,
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              feature,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.pages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentPage ? (isSmallScreen ? 20 : 24) : (isSmallScreen ? 6 : 8),
                    height: isSmallScreen ? 6 : 8,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),
              // Navigation buttons
              Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6C63FF)),
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Previous',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == widget.pages.length - 1 ? 'Get Started' : 'Next',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<String> features;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    this.features = const [],
  });
}

// Utility function to check if onboarding is needed
Future<bool> isOnboardingNeeded(String featureName) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('${featureName}_onboarding_completed') ?? false);
}
