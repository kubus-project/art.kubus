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
  ),

  /// kubus Node keeps its own infrastructure glyph (the Node is a server you
  /// own, not a lab flask); Labs is said by the adornment beside it. It is
  /// runtime ownership, not a financial capability: the marker is identity
  /// only and never gates access or asks for a wallet.
  node(
    screenKey: 'kubus_node',
    route: '/kubus-node',
    screenIcon: Icons.dns,
    navIcon: Icons.dns_outlined,
    navActiveIcon: Icons.dns,
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
      case KubusLabsFeature.node:
        return roles.web3NodeAccent;
    }
  }

  String semanticsLabel(AppLocalizations l10n) {
    switch (this) {
      case KubusLabsFeature.dao:
        return l10n.labsDaoSemanticLabel;
      case KubusLabsFeature.marketplace:
        return l10n.labsMarketplaceSemanticLabel;
      case KubusLabsFeature.node:
        return l10n.kubusNodeEntryTitle;
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
    case 'node':
    case 'kubus_node':
    case 'kubus-node':
      return KubusLabsFeature.node;
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
    case '/kubus-node':
      return KubusLabsFeature.node;
    default:
      return null;
  }
}
