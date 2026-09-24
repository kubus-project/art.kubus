import 'package:art_kubus/l10n/app_localizations.dart';

enum KubusNearbyArtPanelLayout { mobileBottomSheet, desktopSidePanel }

enum KubusNearbyArtSort { nearest, newest, popular }

extension KubusNearbyArtSortLabel on KubusNearbyArtSort {
  String label(AppLocalizations l10n) {
    switch (this) {
      case KubusNearbyArtSort.nearest:
        return l10n.mapSortNearest;
      case KubusNearbyArtSort.newest:
        return l10n.mapSortNewest;
      case KubusNearbyArtSort.popular:
        return l10n.mapSortMostViewed;
    }
  }
}
