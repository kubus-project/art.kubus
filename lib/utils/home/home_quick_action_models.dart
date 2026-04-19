import 'package:flutter/material.dart';

import '../../providers/navigation_provider.dart';
import '../../utils/kubus_labs_feature.dart';

enum HomeQuickActionSurface { mobileHome, desktopHome, legacyProvider }

enum HomeQuickActionCapability {
  signedIn,
  walletConnected,
  arSupportedOnDevice,
}

enum HomeQuickActionTargetType {
  mobileTab,
  desktopShellRoute,
  pushScreen,
  pushDesktopSubscreen,
  infoDialog,
  unsupported,
}

typedef HomeQuickActionScreenBuilder = Widget Function(BuildContext context);

@immutable
class HomeQuickActionTarget {
  const HomeQuickActionTarget({
    required this.type,
    this.mobileTabIndex,
    this.desktopShellRoute,
    this.screenBuilder,
    this.title,
    this.message,
    this.initialSection,
  });

  final HomeQuickActionTargetType type;
  final int? mobileTabIndex;
  final String? desktopShellRoute;
  final HomeQuickActionScreenBuilder? screenBuilder;
  final String? title;
  final String? message;
  final String? initialSection;
}

@immutable
class HomeQuickActionDefinition {
  const HomeQuickActionDefinition({
    required this.key,
    required this.labelKey,
    required this.icon,
    required this.mobileTarget,
    required this.desktopTarget,
    this.capabilities = const <HomeQuickActionCapability>{},
    this.labsFeature,
  });

  final String key;
  final NavigationScreenLabelKey labelKey;
  final IconData icon;
  final HomeQuickActionTarget mobileTarget;
  final HomeQuickActionTarget desktopTarget;
  final Set<HomeQuickActionCapability> capabilities;
  final KubusLabsFeature? labsFeature;
}
