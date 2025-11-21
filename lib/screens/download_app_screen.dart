import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen shown to web users encouraging them to download the mobile app for AR features
class DownloadAppScreen extends StatefulWidget {
  final String feature;
  final String? description;

  const DownloadAppScreen({
    super.key,
    this.feature = 'AR Features',
    this.description,
  });

  @override
  State<DownloadAppScreen> createState() => _DownloadAppScreenState();
}

class _DownloadAppScreenState extends State<DownloadAppScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open store. Please visit: $url'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              themeProvider.accentColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLargeScreen ? 1000 : 600),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isLargeScreen ? 48 : 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App Icon with AR Badge
                        _buildAppIcon(themeProvider),
                        SizedBox(height: isLargeScreen ? 48 : 32),

                        // Title
                        Text(
                          'Experience ${widget.feature} in AR',
                          style: GoogleFonts.inter(
                            fontSize: isLargeScreen ? 40 : 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          widget.description ??
                              'To access augmented reality features and view digital art in your space, download the art.kubus mobile app.',
                          style: GoogleFonts.inter(
                            fontSize: isLargeScreen ? 18 : 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isLargeScreen ? 56 : 40),

                        // Feature highlights
                        _buildFeatureHighlights(isLargeScreen),
                        SizedBox(height: isLargeScreen ? 56 : 40),

                        // Download buttons
                        _buildDownloadButtons(themeProvider, isLargeScreen),
                        SizedBox(height: isLargeScreen ? 40 : 32),

                        // QR Code section
                        _buildQRSection(themeProvider, isLargeScreen),
                        SizedBox(height: isLargeScreen ? 32 : 24),

                        // Continue browsing button
                        _buildContinueButton(themeProvider),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(ThemeProvider themeProvider) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                themeProvider.accentColor.withValues(alpha: 0.3),
                themeProvider.accentColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        // App icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: themeProvider.accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: themeProvider.accentColor.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.view_in_ar,
            size: 64,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        // AR Badge
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 3,
              ),
            ),
            child: Text(
              'AR',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureHighlights(bool isLargeScreen) {
    final features = [
      {'icon': Icons.view_in_ar, 'text': 'View art in your space with AR'},
      {'icon': Icons.camera_alt, 'text': 'Scan artworks with your camera'},
      {'icon': Icons.touch_app, 'text': 'Interactive 3D experiences'},
      {'icon': Icons.location_on, 'text': 'Location-based art discovery'},
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: isLargeScreen ? 32 : 16,
      runSpacing: isLargeScreen ? 24 : 16,
      children: features.map((feature) {
        return SizedBox(
          width: isLargeScreen ? 200 : 150,
          child: Column(
            children: [
              Icon(
                feature['icon'] as IconData,
                size: isLargeScreen ? 40 : 32,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
              const SizedBox(height: 12),
              Text(
                feature['text'] as String,
                style: GoogleFonts.inter(
                  fontSize: isLargeScreen ? 14 : 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDownloadButtons(ThemeProvider themeProvider, bool isLargeScreen) {
    return Column(
      children: [
        Text(
          'Download for:',
          style: GoogleFonts.inter(
            fontSize: isLargeScreen ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            // iOS App Store button
            _buildStoreButton(
              label: 'App Store',
              icon: Icons.apple,
              color: Colors.black,
              onTap: () => _launchURL('https://github.com/kubus-project/art.kubus/releases'),
              isLargeScreen: isLargeScreen,
            ),
            // Android Play Store button
            _buildStoreButton(
              label: 'Play Store',
              icon: Icons.android,
              color: const Color(0xFF01875F),
              onTap: () => _launchURL('https://github.com/kubus-project/art.kubus/releases'),
              isLargeScreen: isLargeScreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isLargeScreen,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isLargeScreen ? 200 : 160,
        padding: EdgeInsets.symmetric(
          vertical: isLargeScreen ? 16 : 14,
          horizontal: isLargeScreen ? 24 : 20,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isLargeScreen ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRSection(ThemeProvider themeProvider, bool isLargeScreen) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 32 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeProvider.accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code,
            size: isLargeScreen ? 120 : 100,
            color: themeProvider.accentColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan QR Code',
            style: GoogleFonts.inter(
              fontSize: isLargeScreen ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Or scan this code with your mobile device',
            style: GoogleFonts.inter(
              fontSize: isLargeScreen ? 14 : 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(ThemeProvider themeProvider) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 20, color: themeProvider.accentColor),
          const SizedBox(width: 8),
          Text(
            'Continue browsing',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: themeProvider.accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
