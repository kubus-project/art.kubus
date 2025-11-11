import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';

/// App logo widget that automatically switches between light and dark variants
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Use logo_black.png for light mode, logo.png for dark mode
        final logoAsset = themeProvider.themeMode == ThemeMode.light ||
                         (themeProvider.themeMode == ThemeMode.system &&
                          MediaQuery.of(context).platformBrightness == Brightness.light)
            ? 'assets/images/logo_black.png'
            : 'assets/images/logo.png';

        return Image.asset(
          logoAsset,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }
}

/// App logo for specific theme modes
class AppLogoStatic extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool forLightMode;

  const AppLogoStatic({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.forLightMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoAsset = forLightMode 
        ? 'assets/images/logo_black.png'
        : 'assets/images/logo.png';

    return Image.asset(
      logoAsset,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
