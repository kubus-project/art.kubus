import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../providers/themeprovider.dart';
import '../utils/design_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.downloadAppCouldNotOpenStoreToast(url)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 800;
    final featureName = widget.feature == 'AR Features'
        ? l10n.downloadAppDefaultFeatureName
        : widget.feature;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              themeProvider.accentColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLargeScreen ? 1000 : 600),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isLargeScreen
                      ? KubusSpacing.xl + KubusSpacing.md
                      : KubusSpacing.lg,
                ),
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
                        SizedBox(
                          height: isLargeScreen
                              ? KubusSpacing.xl + KubusSpacing.md
                              : KubusSpacing.lg,
                        ),

                        // Title
                        Text(
                          l10n.downloadAppExperienceInArTitle(featureName),
                          style: KubusTextStyles.heroTitle.copyWith(
                            fontSize: isLargeScreen
                                ? KubusHeaderMetrics.screenTitle +
                                    KubusSpacing.md
                                : KubusHeaderMetrics.screenTitle,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: KubusSpacing.md),

                        // Description
                        Text(
                          widget.description ??
                              l10n.downloadAppDefaultDescription,
                          style: KubusTextStyles.heroSubtitle.copyWith(
                            fontSize: isLargeScreen
                                ? KubusHeaderMetrics.screenTitle
                                : KubusHeaderMetrics.screenSubtitle,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                          height: isLargeScreen
                              ? KubusSpacing.xl + KubusSpacing.xl
                              : KubusSpacing.xl,
                        ),

                        // Feature highlights
                        _buildFeatureHighlights(isLargeScreen),
                        SizedBox(
                          height: isLargeScreen
                              ? KubusSpacing.xl + KubusSpacing.xl
                              : KubusSpacing.xl,
                        ),

                        // Download buttons
                        _buildDownloadButtons(themeProvider, isLargeScreen),
                        SizedBox(
                          height:
                              isLargeScreen ? KubusSpacing.xl : KubusSpacing.lg,
                        ),

                        // QR Code section
                        _buildQRSection(themeProvider, isLargeScreen),
                        SizedBox(
                          height:
                              isLargeScreen ? KubusSpacing.lg : KubusSpacing.md,
                        ),

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
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm + KubusSpacing.xxs,
              vertical: KubusSpacing.xxs + KubusSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary,
              borderRadius: BorderRadius.circular(KubusRadius.xl),
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 3,
              ),
            ),
            child: Text(
              'AR',
              style: KubusTextStyles.compactBadge.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureHighlights(bool isLargeScreen) {
    final l10n = AppLocalizations.of(context)!;
    final features = [
      {'icon': Icons.view_in_ar, 'text': l10n.downloadAppFeatureViewInAr},
      {'icon': Icons.camera_alt, 'text': l10n.downloadAppFeatureScanArtworks},
      {'icon': Icons.touch_app, 'text': l10n.downloadAppFeatureInteractive3d},
      {
        'icon': Icons.location_on,
        'text': l10n.downloadAppFeatureLocationDiscovery
      },
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing:
          isLargeScreen ? KubusSpacing.xl + KubusSpacing.xs : KubusSpacing.md,
      runSpacing: isLargeScreen ? KubusSpacing.lg : KubusSpacing.md,
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
              const SizedBox(height: KubusSpacing.md),
              Text(
                feature['text'] as String,
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  fontSize: isLargeScreen
                      ? KubusHeaderMetrics.screenSubtitle
                      : KubusHeaderMetrics.sectionSubtitle,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDownloadButtons(
      ThemeProvider themeProvider, bool isLargeScreen) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          l10n.downloadAppDownloadForLabel,
          style: KubusTextStyles.sectionTitle.copyWith(
            fontSize: isLargeScreen
                ? KubusHeaderMetrics.screenTitle
                : KubusHeaderMetrics.sectionTitle,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.md,
          children: [
            // iOS App Store button
            _buildStoreButton(
              label: l10n.commonIosLabel,
              icon: Icons.apple,
              color: Colors.black,
              onTap: () => _launchURL(
                  'https://github.com/kubus-project/art.kubus/releases'),
              isLargeScreen: isLargeScreen,
            ),
            // Android Play Store button
            _buildStoreButton(
              label: l10n.commonAndroidLabel,
              icon: Icons.android,
              color: const Color(0xFF01875F),
              onTap: () => _launchURL(
                  'https://github.com/kubus-project/art.kubus/releases'),
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
      borderRadius: BorderRadius.circular(KubusRadius.md),
      child: Container(
        width: isLargeScreen ? 200 : 160,
        padding: EdgeInsets.symmetric(
          vertical: isLargeScreen
              ? KubusSpacing.md
              : KubusSpacing.md - KubusSpacing.xxs,
          horizontal: isLargeScreen
              ? KubusSpacing.lg
              : KubusSpacing.lg - KubusSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(KubusRadius.md),
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
            Icon(icon, color: Colors.white, size: isLargeScreen ? 28 : 24),
            const SizedBox(width: KubusSpacing.md),
            Text(
              label,
              style: KubusTextStyles.sectionTitle.copyWith(
                fontSize: isLargeScreen
                    ? KubusHeaderMetrics.sectionTitle
                    : KubusHeaderMetrics.sectionSubtitle,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRSection(ThemeProvider themeProvider, bool isLargeScreen) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(
        isLargeScreen ? KubusSpacing.xl : KubusSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
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
          const SizedBox(height: KubusSpacing.md),
          Text(
            l10n.downloadAppScanQrTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              fontSize: isLargeScreen
                  ? KubusHeaderMetrics.screenTitle
                  : KubusHeaderMetrics.sectionTitle,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
          Text(
            l10n.downloadAppScanQrSubtitle,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              fontSize: isLargeScreen
                  ? KubusHeaderMetrics.screenSubtitle
                  : KubusHeaderMetrics.sectionSubtitle,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.xl,
          vertical: KubusSpacing.md,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 20, color: themeProvider.accentColor),
          const SizedBox(width: KubusSpacing.sm),
          Text(
            l10n.downloadAppContinueBrowsingButton,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: themeProvider.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
