import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../screens/activity/advanced_analytics_screen.dart';
import '../../screens/activity/advanced_stats_screen.dart';
import '../../screens/art/ar_screen.dart';
import '../../screens/community/profile_screen.dart';
import '../../screens/desktop/desktop_settings_screen.dart';
import '../../screens/onboarding/web3/onboarding_data.dart';
import '../../screens/onboarding/web3/web3_onboarding.dart' as web3;
import '../../screens/settings_screen.dart';
import '../../screens/web3/achievements/achievements_page.dart';
import '../../screens/web3/artist/artist_studio.dart';
import '../../screens/web3/dao/governance_hub.dart';
import '../../screens/web3/institution/institution_hub.dart';
import '../../screens/web3/marketplace/marketplace.dart';
import '../../screens/web3/wallet/wallet_home.dart';
import '../../providers/navigation_provider.dart';
import '../kubus_labs_feature.dart';
import 'home_quick_action_models.dart';

class HomeQuickActionRegistry {
  HomeQuickActionRegistry._();

  static final Map<String, HomeQuickActionDefinition> _definitions =
      <String, HomeQuickActionDefinition>{
    'ar': HomeQuickActionDefinition(
      key: 'ar',
      labelKey: NavigationScreenLabelKey.createAr,
      icon: Icons.add_box,
      capabilities: const <HomeQuickActionCapability>{
        HomeQuickActionCapability.arSupportedOnDevice,
      },
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildArScreen,
      ),
      desktopTarget: const HomeQuickActionTarget(
        type: HomeQuickActionTargetType.infoDialog,
        title: 'AR experience',
        message:
            'Augmented Reality features require native device capabilities.',
      ),
    ),
    'map': const HomeQuickActionDefinition(
      key: 'map',
      labelKey: NavigationScreenLabelKey.exploreMap,
      icon: Icons.explore,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.mobileTab,
        mobileTabIndex: 0,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/explore',
      ),
    ),
    'community': const HomeQuickActionDefinition(
      key: 'community',
      labelKey: NavigationScreenLabelKey.community,
      icon: Icons.people,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.mobileTab,
        mobileTabIndex: 2,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/community',
      ),
    ),
    'profile': HomeQuickActionDefinition(
      key: 'profile',
      labelKey: NavigationScreenLabelKey.profile,
      icon: Icons.person,
      capabilities: const <HomeQuickActionCapability>{
        HomeQuickActionCapability.signedIn,
      },
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildProfileScreen,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushDesktopSubscreen,
        screenBuilder: _buildProfileScreen,
        title: 'Profile',
      ),
    ),
    'marketplace': HomeQuickActionDefinition(
      key: 'marketplace',
      labelKey: NavigationScreenLabelKey.marketplace,
      icon: KubusLabsFeature.marketplace.screenIcon,
      labsFeature: KubusLabsFeature.marketplace,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildMarketplace,
      ),
      desktopTarget: const HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/marketplace',
      ),
    ),
    'wallet': HomeQuickActionDefinition(
      key: 'wallet',
      labelKey: NavigationScreenLabelKey.wallet,
      icon: Icons.account_balance_wallet,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildWalletHome,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/wallet',
      ),
    ),
    'analytics': HomeQuickActionDefinition(
      key: 'analytics',
      labelKey: NavigationScreenLabelKey.analytics,
      icon: Icons.analytics,
      capabilities: const <HomeQuickActionCapability>{
        HomeQuickActionCapability.walletConnected,
      },
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildAnalyticsScreen,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushDesktopSubscreen,
        screenBuilder: _buildEmbeddedAnalyticsScreen,
        title: 'Analytics',
      ),
    ),
    'settings': HomeQuickActionDefinition(
      key: 'settings',
      labelKey: NavigationScreenLabelKey.settings,
      icon: Icons.settings,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildSettingsScreen,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushDesktopSubscreen,
        screenBuilder: _buildDesktopSettingsScreen,
        title: 'Settings',
      ),
    ),
    'stats': HomeQuickActionDefinition(
      key: 'stats',
      labelKey: NavigationScreenLabelKey.myStats,
      icon: Icons.bar_chart,
      capabilities: const <HomeQuickActionCapability>{
        HomeQuickActionCapability.walletConnected,
      },
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildStatsScreen,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushDesktopSubscreen,
        screenBuilder: _buildEmbeddedAnalyticsScreen,
        title: 'Stats',
      ),
    ),
    'achievements': HomeQuickActionDefinition(
      key: 'achievements',
      labelKey: NavigationScreenLabelKey.achievements,
      icon: Icons.emoji_events,
      capabilities: const <HomeQuickActionCapability>{
        HomeQuickActionCapability.signedIn,
        HomeQuickActionCapability.walletConnected,
      },
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildAchievementsPage,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushDesktopSubscreen,
        screenBuilder: _buildDesktopAchievementsOnboarding,
        title: 'Achievements',
      ),
    ),
    'dao_hub': HomeQuickActionDefinition(
      key: 'dao_hub',
      labelKey: NavigationScreenLabelKey.daoHub,
      icon: KubusLabsFeature.dao.screenIcon,
      labsFeature: KubusLabsFeature.dao,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildGovernanceHub,
      ),
      desktopTarget: const HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/governance',
      ),
    ),
    'studio': HomeQuickActionDefinition(
      key: 'studio',
      labelKey: NavigationScreenLabelKey.artistStudio,
      icon: Icons.palette,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildArtistStudio,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/artist-studio',
      ),
    ),
    'institution_hub': HomeQuickActionDefinition(
      key: 'institution_hub',
      labelKey: NavigationScreenLabelKey.institutionHub,
      icon: Icons.location_city,
      mobileTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.pushScreen,
        screenBuilder: _buildInstitutionHub,
      ),
      desktopTarget: HomeQuickActionTarget(
        type: HomeQuickActionTargetType.desktopShellRoute,
        desktopShellRoute: '/institution',
      ),
    ),
  };

  static bool contains(String key) => _definitions.containsKey(key);

  static HomeQuickActionDefinition? maybeOf(String key) => _definitions[key];

  static HomeQuickActionDefinition of(String key) {
    final definition = maybeOf(key);
    if (definition == null) {
      throw ArgumentError.value(key, 'key', 'Unknown home quick action key');
    }
    return definition;
  }

  static List<String> knownKeys() => List<String>.unmodifiable(
        _definitions.keys,
      );
}

Widget _buildArScreen(BuildContext context) => const ARScreen();

Widget _buildProfileScreen(BuildContext context) => const ProfileScreen();

Widget _buildMarketplace(BuildContext context) => const Marketplace();

Widget _buildWalletHome(BuildContext context) => const WalletHome();

Widget _buildAnalyticsScreen(BuildContext context) =>
    const AdvancedAnalyticsScreen(statType: 'Engagement');

Widget _buildEmbeddedAnalyticsScreen(BuildContext context) =>
    const AdvancedAnalyticsScreen(
      statType: 'Engagement',
      embedded: true,
    );

Widget _buildSettingsScreen(BuildContext context) => const SettingsScreen();

Widget _buildDesktopSettingsScreen(BuildContext context) =>
    const DesktopSettingsScreen(embeddedInShell: true);

Widget _buildStatsScreen(BuildContext context) =>
    const AdvancedStatsScreen(statType: 'Engagement');

Widget _buildAchievementsPage(BuildContext context) => const AchievementsPage();

Widget _buildDesktopAchievementsOnboarding(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return web3.Web3OnboardingScreen(
    featureKey: 'Achievements',
    featureTitle: l10n.userProfileAchievementsTitle,
    pages: Web3FeaturesOnboardingData.pages(l10n),
    onComplete: () {},
  );
}

Widget _buildGovernanceHub(BuildContext context) => const GovernanceHub();

Widget _buildArtistStudio(BuildContext context) => const ArtistStudio();

Widget _buildInstitutionHub(BuildContext context) => const InstitutionHub();
