import 'package:art_kubus/l10n/app_localizations.dart';

enum KubusNearbyArtPanelLayout {
  mobileBottomSheet,
  desktopSidePanel,
}

enum KubusNearbyArtSort {
  nearest,
  newest,
  rewards,
  popular,
}

extension KubusNearbyArtSortLabel on KubusNearbyArtSort {
  String label(AppLocalizations l10n) {
    switch (this) {
      case KubusNearbyArtSort.nearest:
        return l10n.mapSortNearest;
      case KubusNearbyArtSort.newest:
        return l10n.mapSortNewest;
      case KubusNearbyArtSort.rewards:
        return l10n.mapSortHighestRewards;
      case KubusNearbyArtSort.popular:
        return l10n.mapSortMostViewed;
    }
  }
}
