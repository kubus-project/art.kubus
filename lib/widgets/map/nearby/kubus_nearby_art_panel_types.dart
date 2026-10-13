import 'package:art_kubus/l10n/app_localizations.dart';

enum KubusNearbyArtPanelLayout { mobileBottomSheet, desktopSidePanel }

/// Minimum and detent sizes for the mobile Nearby sheet.
///
/// The collapsed sheet must expose its naturally laid out header. Standard
/// detents are retained only when they remain above that measured minimum.
class KubusNearbyArtSheetExtentBounds {
  factory KubusNearbyArtSheetExtentBounds({
    required double availableHeight,
    required double headerHeight,
  }) {
    final minExtent = _resolveMinimum(availableHeight, headerHeight);
    return KubusNearbyArtSheetExtentBounds._(
      minExtent,
      _resolveSnaps(minExtent),
    );
  }

  const KubusNearbyArtSheetExtentBounds._(this.minExtent, this.snapSizes);

  static const double baselineMinExtent = 0.12;
  static const double maxExtent = 0.85;
  static const List<double> _standardDetents = <double>[0.24, 0.50];

  final double minExtent;
  final List<double> snapSizes;

  static double _resolveMinimum(double availableHeight, double headerHeight) {
    if (!availableHeight.isFinite ||
        availableHeight <= 0 ||
        !headerHeight.isFinite ||
        headerHeight <= 0) {
      return baselineMinExtent;
    }
    return (headerHeight / availableHeight)
        .clamp(baselineMinExtent, maxExtent)
        .toDouble();
  }

  static List<double> _resolveSnaps(double minExtent) =>
      List<double>.unmodifiable(
        <double>[
          minExtent,
          for (final detent in _standardDetents)
            if (detent > minExtent && detent < maxExtent) detent,
        ],
      );
}

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
