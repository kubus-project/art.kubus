import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/platform_provider.dart';
import '../utils/kubus_color_roles.dart';

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
        
        return ElevatedButton.icon(
          onPressed: isSupported ? onPressed : () => _showUnsupportedMessage(context, platformProvider),
          icon: Icon(
            icon,
            color: isSupported 
              ? (color ?? Theme.of(context).primaryColor)
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
            backgroundColor: isSupported 
              ? (color ?? Theme.of(context).primaryColor)
              : Theme.of(context).colorScheme.outline,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(
              horizontal: platformProvider.defaultPadding,
              vertical: platformProvider.defaultPadding * 0.75,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(platformProvider.defaultBorderRadius),
            ),
          ),
        );
      },
    );
  }

  void _showUnsupportedMessage(BuildContext context, PlatformProvider platformProvider) {
    ScaffoldMessenger.of(context).showSnackBar(
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
        return Container(
          margin: margin ?? platformProvider.defaultMargin,
          padding: padding ?? EdgeInsets.all(platformProvider.defaultPadding),
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(platformProvider.defaultBorderRadius),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: platformProvider.isDesktop ? 1 : 0.5,
            ),
            boxShadow: platformProvider.isDesktop
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          ),
          child: child,
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


