import 'package:flutter/material.dart';

import '../models/artwork.dart';
import 'map_coordinate_rules.dart';
import 'map_destination_actions.dart';
import 'map_navigation.dart';

export 'map_destination_actions.dart'
    show
        ArtworkCanLaunchUri,
        ArtworkClipboardWriter,
        ArtworkExternalMapDestination,
        ArtworkLaunchUri,
        ArtworkMapOpenCallback,
        ArtworkWalkingOpenCallback,
        MapDestination;

/// Artwork-to-map adapter: the coordinate rule and the internal map view.
///
/// External navigation (provider choice, the navigate sheet, launching) has
/// one implementation, [MapDestination]. Build one for an artwork with
/// `MapDestination(id:, title:, position:)` and call its methods.
class ArtworkLocationActions {
  const ArtworkLocationActions._();

  /// The shared coordinate rule; see [isValidMapCoordinate].
  static bool hasValidLocation(Artwork artwork) =>
      isValidMapCoordinate(artwork.position);

  /// Opens the art.kubus map with the artwork ID as the authoritative target.
  ///
  /// [Artwork.arMarkerId] is passed only as a lookup hint. The map target
  /// resolver remains responsible for selecting the marker that is actually
  /// linked to [Artwork.id].
  static void showOnMap(
    BuildContext context,
    Artwork artwork, {
    ArtworkMapOpenCallback? mapOpener,
  }) {
    if (!hasValidLocation(artwork)) return;
    final markerHint = (artwork.arMarkerId ?? '').trim();
    final openMap = mapOpener ?? MapNavigation.open;
    openMap(
      context,
      center: artwork.position,
      zoom: 16,
      autoFollow: false,
      initialMarkerId: markerHint.isEmpty ? null : markerHint,
      initialArtworkId: artwork.id,
      initialTargetLabel: artwork.title,
      preserveDesktopBackStack: true,
    );
  }
}
