import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum CommunityLayoutVariant {
  mobile,
  desktop,
}

@immutable
class CommunityLayoutConfig {
  final CommunityLayoutVariant variant;
  final double desktopBreakpoint;

  const CommunityLayoutConfig._(
    this.variant, {
    this.desktopBreakpoint = 900,
  });

  const CommunityLayoutConfig.mobile({
    double desktopBreakpoint = 900,
  }) : this._(
          CommunityLayoutVariant.mobile,
          desktopBreakpoint: desktopBreakpoint,
        );

  const CommunityLayoutConfig.desktop({
    double desktopBreakpoint = 900,
  }) : this._(
          CommunityLayoutVariant.desktop,
          desktopBreakpoint: desktopBreakpoint,
        );

  bool get isDesktop => variant == CommunityLayoutVariant.desktop;
}

class CommunityLayout extends StatelessWidget {
  final CommunityLayoutConfig config;
  final Widget mobile;
  final Widget desktop;

  const CommunityLayout({
    super.key,
    required this.config,
    required this.mobile,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    switch (config.variant) {
      case CommunityLayoutVariant.mobile:
        return mobile;
      case CommunityLayoutVariant.desktop:
        return desktop;
    }
  }
}

