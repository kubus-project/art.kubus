import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'web3_onboarding.dart';

class DAOOnboardingData {
  static const String featureKey = 'DAO';

  static String featureTitle(AppLocalizations l10n) =>
      l10n.web3FeatureGovernanceTitle;

  static List<OnboardingPage> pages(AppLocalizations l10n) => [
        OnboardingPage(
          title: l10n.web3DaoP1Title,
          description: l10n.web3DaoP1Description,
          icon: Icons.account_balance,
          gradientColors: [const Color.fromARGB(255, 6, 89, 141), const Color(0xFF0B6E4F)],
          features: [
            l10n.web3DaoP1Feature1,
            l10n.web3DaoP1Feature2,
            l10n.web3DaoP1Feature3,
            l10n.web3DaoP1Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3DaoP2Title,
          description: l10n.web3DaoP2Description,
          icon: Icons.how_to_vote,
          gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
          features: [
            l10n.web3DaoP2Feature1,
            l10n.web3DaoP2Feature2,
            l10n.web3DaoP2Feature3,
            l10n.web3DaoP2Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3DaoP3Title,
          description: l10n.web3DaoP3Description,
          icon: Icons.lightbulb_outline,
          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
          features: [
            l10n.web3DaoP3Feature1,
            l10n.web3DaoP3Feature2,
            l10n.web3DaoP3Feature3,
            l10n.web3DaoP3Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3DaoP4Title,
          description: l10n.web3DaoP4Description,
          icon: Icons.rocket_launch,
          gradientColors: [const Color(0xFFEC4899), const Color(0xFF0B6E4F)],
          features: [
            l10n.web3DaoP4Feature1,
            l10n.web3DaoP4Feature2,
            l10n.web3DaoP4Feature3,
            l10n.web3DaoP4Feature4,
          ],
        ),
      ];
}

class ArtistStudioOnboardingData {
  static const String featureKey = 'Artist Studio';

  static String featureTitle(AppLocalizations l10n) =>
      l10n.web3FeatureArtistStudioTitle;

  static List<OnboardingPage> pages(AppLocalizations l10n) => [
        OnboardingPage(
          title: l10n.web3ArtistStudioP1Title,
          description: l10n.web3ArtistStudioP1Description,
          icon: Icons.palette,
          gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
          features: [
            l10n.web3ArtistStudioP1Feature1,
            l10n.web3ArtistStudioP1Feature2,
            l10n.web3ArtistStudioP1Feature3,
            l10n.web3ArtistStudioP1Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3ArtistStudioP2Title,
          description: l10n.web3ArtistStudioP2Description,
          icon: Icons.photo_library,
          gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
          features: [
            l10n.web3ArtistStudioP2Feature1,
            l10n.web3ArtistStudioP2Feature2,
            l10n.web3ArtistStudioP2Feature3,
            l10n.web3ArtistStudioP2Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3ArtistStudioP3Title,
          description: l10n.web3ArtistStudioP3Description,
          icon: Icons.view_in_ar,
          gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
          features: [
            l10n.web3ArtistStudioP3Feature1,
            l10n.web3ArtistStudioP3Feature2,
            l10n.web3ArtistStudioP3Feature3,
            l10n.web3ArtistStudioP3Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3ArtistStudioP4Title,
          description: l10n.web3ArtistStudioP4Description,
          icon: Icons.analytics,
          gradientColors: [const Color(0xFFEC4899), const Color(0xFF0B6E4F)],
          features: [
            l10n.web3ArtistStudioP4Feature1,
            l10n.web3ArtistStudioP4Feature2,
            l10n.web3ArtistStudioP4Feature3,
            l10n.web3ArtistStudioP4Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3ArtistStudioP5Title,
          description: l10n.web3ArtistStudioP5Description,
          icon: Icons.create,
          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
          features: [
            l10n.web3ArtistStudioP5Feature1,
            l10n.web3ArtistStudioP5Feature2,
            l10n.web3ArtistStudioP5Feature3,
            l10n.web3ArtistStudioP5Feature4,
          ],
        ),
      ];
}

class InstitutionHubOnboardingData {
  static const String featureKey = 'Institution Hub';

  static String featureTitle(AppLocalizations l10n) =>
      l10n.web3FeatureInstitutionHubTitle;

  static List<OnboardingPage> pages(AppLocalizations l10n) => [
        OnboardingPage(
          title: l10n.web3InstitutionHubP1Title,
          description: l10n.web3InstitutionHubP1Description,
          icon: Icons.museum,
          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
          features: [
            l10n.web3InstitutionHubP1Feature1,
            l10n.web3InstitutionHubP1Feature2,
            l10n.web3InstitutionHubP1Feature3,
            l10n.web3InstitutionHubP1Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3InstitutionHubP2Title,
          description: l10n.web3InstitutionHubP2Description,
          icon: Icons.event,
          gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
          features: [
            l10n.web3InstitutionHubP2Feature1,
            l10n.web3InstitutionHubP2Feature2,
            l10n.web3InstitutionHubP2Feature3,
            l10n.web3InstitutionHubP2Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3InstitutionHubP3Title,
          description: l10n.web3InstitutionHubP3Description,
          icon: Icons.create_new_folder,
          gradientColors: [const Color(0xFF072A40), const Color(0xFF0B6E4F)],
          features: [
            l10n.web3InstitutionHubP3Feature1,
            l10n.web3InstitutionHubP3Feature2,
            l10n.web3InstitutionHubP3Feature3,
            l10n.web3InstitutionHubP3Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3InstitutionHubP4Title,
          description: l10n.web3InstitutionHubP4Description,
          icon: Icons.insights,
          gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
          features: [
            l10n.web3InstitutionHubP4Feature1,
            l10n.web3InstitutionHubP4Feature2,
            l10n.web3InstitutionHubP4Feature3,
            l10n.web3InstitutionHubP4Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3InstitutionHubP5Title,
          description: l10n.web3InstitutionHubP5Description,
          icon: Icons.launch,
          gradientColors: [const Color(0xFFEC4899), const Color(0xFF06B6D4)],
          features: [
            l10n.web3InstitutionHubP5Feature1,
            l10n.web3InstitutionHubP5Feature2,
            l10n.web3InstitutionHubP5Feature3,
            l10n.web3InstitutionHubP5Feature4,
          ],
        ),
      ];
}

class MarketplaceOnboardingData {
  static const String featureKey = 'Marketplace';

  static String featureTitle(AppLocalizations l10n) =>
      l10n.web3FeatureMarketplaceTitle;

  static List<OnboardingPage> pages(AppLocalizations l10n) => [
        OnboardingPage(
          title: l10n.web3MarketplaceP1Title,
          description: l10n.web3MarketplaceP1Description,
          icon: Icons.store,
          gradientColors: [const Color(0xFF6366F1), const Color(0xFF3B82F6)],
          features: [
            l10n.web3MarketplaceP1Feature1,
            l10n.web3MarketplaceP1Feature2,
            l10n.web3MarketplaceP1Feature3,
            l10n.web3MarketplaceP1Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3MarketplaceP2Title,
          description: l10n.web3MarketplaceP2Description,
          icon: Icons.explore,
          gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
          features: [
            l10n.web3MarketplaceP2Feature1,
            l10n.web3MarketplaceP2Feature2,
            l10n.web3MarketplaceP2Feature3,
            l10n.web3MarketplaceP2Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3MarketplaceP3Title,
          description: l10n.web3MarketplaceP3Description,
          icon: Icons.sell,
          gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
          features: [
            l10n.web3MarketplaceP3Feature1,
            l10n.web3MarketplaceP3Feature2,
            l10n.web3MarketplaceP3Feature3,
            l10n.web3MarketplaceP3Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3MarketplaceP4Title,
          description: l10n.web3MarketplaceP4Description,
          icon: Icons.shopping_cart,
          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
          features: [
            l10n.web3MarketplaceP4Feature1,
            l10n.web3MarketplaceP4Feature2,
            l10n.web3MarketplaceP4Feature3,
            l10n.web3MarketplaceP4Feature4,
          ],
        ),
      ];
}

class Web3FeaturesOnboardingData {
  static const String featureKey = 'Web3 Features';

  static String featureTitle(AppLocalizations l10n) => l10n.web3FeatureWeb3Title;

  static List<OnboardingPage> pages(AppLocalizations l10n) => [
        OnboardingPage(
          title: l10n.web3FeaturesP1Title,
          description: l10n.web3FeaturesP1Description,
          icon: Icons.account_balance_wallet,
          gradientColors: [
            Colors.blue,
            const Color(0xFF3F51B5),
          ],
          features: [
            l10n.web3FeaturesP1Feature1,
            l10n.web3FeaturesP1Feature2,
            l10n.web3FeaturesP1Feature3,
            l10n.web3FeaturesP1Feature4,
          ],
        ),
        OnboardingPage(
          title: l10n.web3FeaturesP2Title,
          description: l10n.web3FeaturesP2Description,
          icon: Icons.store,
          gradientColors: [
            const Color(0xFFFF6B6B),
            const Color(0xFFE91E63),
          ],
          features: [
            l10n.web3FeaturesP2Feature1,
            l10n.web3FeaturesP2Feature2,
            l10n.web3FeaturesP2Feature3,
            l10n.web3FeaturesP2Feature4,
            l10n.web3FeaturesP2Feature5,
          ],
        ),
        OnboardingPage(
          title: l10n.web3FeaturesP3Title,
          description: l10n.web3FeaturesP3Description,
          icon: Icons.palette,
          gradientColors: [
            const Color(0xFFFF9A8B),
            const Color(0xFFFF7043),
          ],
          features: [
            l10n.web3FeaturesP3Feature1,
            l10n.web3FeaturesP3Feature2,
            l10n.web3FeaturesP3Feature3,
            l10n.web3FeaturesP3Feature4,
            l10n.web3FeaturesP3Feature5,
          ],
        ),
        OnboardingPage(
          title: l10n.web3FeaturesP4Title,
          description: l10n.web3FeaturesP4Description,
          icon: Icons.how_to_vote,
          gradientColors: [
            const Color(0xFF4ECDC4),
            const Color(0xFF26A69A),
          ],
          features: [
            l10n.web3FeaturesP4Feature1,
            l10n.web3FeaturesP4Feature2,
            l10n.web3FeaturesP4Feature3,
            l10n.web3FeaturesP4Feature4,
            l10n.web3FeaturesP4Feature5,
          ],
        ),
        OnboardingPage(
          title: l10n.web3FeaturesP5Title,
          description: l10n.web3FeaturesP5Description,
          icon: Icons.museum,
          gradientColors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
          ],
          features: [
            l10n.web3FeaturesP5Feature1,
            l10n.web3FeaturesP5Feature2,
            l10n.web3FeaturesP5Feature3,
            l10n.web3FeaturesP5Feature4,
            l10n.web3FeaturesP5Feature5,
          ],
        ),
        OnboardingPage(
          title: l10n.web3FeaturesP6Title,
          description: l10n.web3FeaturesP6Description,
          icon: Icons.monetization_on,
          gradientColors: [
            const Color(0xFFFFD700),
            const Color(0xFFFF8C00),
          ],
          features: [
            l10n.web3FeaturesP6Feature1,
            l10n.web3FeaturesP6Feature2,
            l10n.web3FeaturesP6Feature3,
            l10n.web3FeaturesP6Feature4,
            l10n.web3FeaturesP6Feature5,
          ],
        ),
      ];
}
