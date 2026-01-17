import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/platform_provider.dart';
import '../utils/kubus_color_roles.dart';
import 'glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

/// A helper widget that shows platform-aware buttons and features
class PlatformAwareFeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String feature;
  final PlatformCapability requiredCapability;
  final VoidCallback? onPressed;
  final Color? color;

  const PlatformAwareFeatureButton({
    super.key,
    required this.icon,
    required this.label,
    required this.feature,
    required this.requiredCapability,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        final isSupported = platformProvider.capabilities[requiredCapability] ?? false;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        final baseColor = isSupported
            ? (color ?? Theme.of(context).primaryColor)
            : scheme.outline;

        final radius = BorderRadius.circular(platformProvider.defaultBorderRadius);
        final glassTint = baseColor.withValues(
          alpha: isSupported ? (isDark ? 0.82 : 0.88) : (isDark ? 0.22 : 0.16),
        );
        final outlineColor = baseColor.withValues(alpha: isSupported ? 0.30 : 0.22);
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: outlineColor),
            boxShadow: platformProvider.isDesktop
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            showBorder: false,
            backgroundColor: glassTint,
            child: ElevatedButton.icon(
              onPressed: isSupported
                  ? onPressed
                  : () => _showUnsupportedMessage(context, platformProvider),
              icon: Icon(
                icon,
                color: isSupported
                    ? Colors.white
                    : platformProvider.getUnsupportedFeatureColor(context),
              ),
              label: Text(
                label,
                style: GoogleFonts.inter(
                  color: isSupported
                      ? Colors.white
                      : platformProvider.getUnsupportedFeatureColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: scheme.onPrimary,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                padding: EdgeInsets.symmetric(
                  horizontal: platformProvider.defaultPadding,
                  vertical: platformProvider.defaultPadding * 0.75,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                ),
                elevation: 0,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUnsupportedMessage(BuildContext context, PlatformProvider platformProvider) {
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(platformProvider.getUnsupportedFeatureMessage(feature)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KubusColorRoles.of(context).warningAction,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// A platform-aware card that adapts its styling based on the current platform
class PlatformAwareCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const PlatformAwareCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        final radius = BorderRadius.circular(platformProvider.defaultBorderRadius);
        final glassTint = (backgroundColor ?? scheme.surface)
            .withValues(alpha: isDark ? 0.16 : 0.10);

        return Container(
          margin: margin ?? platformProvider.defaultMargin,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.18),
              width: platformProvider.isDesktop ? 1 : 0.5,
            ),
            boxShadow: platformProvider.isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: LiquidGlassPanel(
            padding: padding ?? EdgeInsets.all(platformProvider.defaultPadding),
            margin: EdgeInsets.zero,
            borderRadius: radius,
            showBorder: false,
            backgroundColor: glassTint,
            child: child,
          ),
        );
      },
    );
  }
}

/// A responsive layout helper that adapts based on platform and screen size
class PlatformAwareLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;
  final Widget? webLayout;

  const PlatformAwareLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
    this.webLayout,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            
            // Platform-specific layouts
            if (platformProvider.isWeb && webLayout != null) {
              return webLayout!;
            }
            
            if (platformProvider.isDesktop && desktopLayout != null) {
              return desktopLayout!;
            }
            
            // Screen size-based layouts
            if (platformProvider.isLargeScreen(width)) {
              return desktopLayout ?? tabletLayout ?? mobileLayout;
            }
            
            if (platformProvider.isMediumScreen(width)) {
              return tabletLayout ?? mobileLayout;
            }
            
            return mobileLayout;
          },
        );
      },
    );
  }
}

/// Shows platform capabilities for debugging
class PlatformDebugWidget extends StatelessWidget {
  const PlatformDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return ExpansionTile(
          title: Text(
            'Platform Debug Info',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform: ${platformProvider.currentPlatform}'),
                  Text('Mobile: ${platformProvider.isMobile}'),
                  Text('Desktop: ${platformProvider.isDesktop}'),
                  Text('Web: ${platformProvider.isWeb}'),
                  const SizedBox(height: 16),
                  Text(
                    'Capabilities:',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  ...platformProvider.capabilities.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Builder(
                        builder: (context) {
                          final roles = KubusColorRoles.of(context);
                          return Row(
                            children: [
                              Icon(
                                entry.value ? Icons.check : Icons.close,
                                color: entry.value
                                    ? roles.positiveAction
                                    : roles.negativeAction,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(entry.key.toString().split('.').last),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


