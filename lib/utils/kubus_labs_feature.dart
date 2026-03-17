import 'package:flutter/material.dart';

import '../config/config.dart';
import '../l10n/app_localizations.dart';
import 'kubus_color_roles.dart';

enum KubusLabsFeature {
  dao(
    screenKey: 'dao_hub',
    route: '/governance',
    screenIcon: Icons.how_to_vote,
    navIcon: Icons.account_balance_outlined,
    navActiveIcon: Icons.account_balance,
  ),
  marketplace(
    screenKey: 'marketplace',
    route: '/marketplace',
    screenIcon: Icons.storefront,
    navIcon: Icons.storefront_outlined,
    navActiveIcon: Icons.storefront,
  );

  const KubusLabsFeature({
    required this.screenKey,
    required this.route,
    required this.screenIcon,
    required this.navIcon,
    required this.navActiveIcon,
  });

  final String screenKey;
  final String route;
  final IconData screenIcon;
  final IconData navIcon;
  final IconData navActiveIcon;

  bool get showLabsMarker => AppConfig.isFeatureEnabled('labs');

  Color accent(KubusColorRoles roles) {
    switch (this) {
      case KubusLabsFeature.dao:
        return roles.web3DaoAccent;
      case KubusLabsFeature.marketplace:
        return roles.web3MarketplaceAccent;
    }
  }

  String semanticsLabel(AppLocalizations l10n) {
    switch (this) {
      case KubusLabsFeature.dao:
        return l10n.labsDaoSemanticLabel;
      case KubusLabsFeature.marketplace:
        return l10n.labsMarketplaceSemanticLabel;
    }
  }
}

KubusLabsFeature? kubusLabsFeatureForScreenKey(String screenKey) {
  switch (screenKey.trim().toLowerCase()) {
    case 'dao':
    case 'dao_hub':
    case 'govern':
    case 'governance':
    case 'governance_hub':
      return KubusLabsFeature.dao;
    case 'marketplace':
    case 'trade':
      return KubusLabsFeature.marketplace;
    default:
      return null;
  }
}

KubusLabsFeature? kubusLabsFeatureForRoute(String route) {
  switch (route.trim().toLowerCase()) {
    case '/governance':
      return KubusLabsFeature.dao;
    case '/marketplace':
      return KubusLabsFeature.marketplace;
    default:
      return null;
  }
}
