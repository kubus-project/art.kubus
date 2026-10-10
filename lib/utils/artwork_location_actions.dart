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

/// Shared internal-map and external-navigation behavior for geolocated artwork.
///
/// The navigation itself lives in [MapDestination]; this adapts an [Artwork]
/// to it so artwork surfaces and the map quick card share one implementation.
class ArtworkLocationActions {
  const ArtworkLocationActions._();

  /// The shared coordinate rule; see [isValidMapCoordinate].
  static bool hasValidLocation(Artwork artwork) =>
      isValidMapCoordinate(artwork.position);

  static MapDestination destinationOf(Artwork artwork) => MapDestination(
        id: artwork.id,
        title: artwork.title,
        position: artwork.position,
      );

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

  static String coordinateText(Artwork artwork) =>
      destinationOf(artwork).coordinateText;

  static bool shouldShowAppleMaps(TargetPlatform platform) =>
      MapDestination.shouldShowAppleMaps(platform);

  static bool shouldShowPlatformDefaultMaps(
    TargetPlatform platform, {
    required bool isWeb,
  }) =>
      MapDestination.shouldShowPlatformDefaultMaps(platform, isWeb: isWeb);

  static List<Uri> destinationUris(
    Artwork artwork,
    ArtworkExternalMapDestination destination, {
    required TargetPlatform platform,
  }) =>
      destinationOf(artwork).externalUris(destination, platform: platform);

  static Future<bool> launchDestination(
    Artwork artwork,
    ArtworkExternalMapDestination destination, {
    TargetPlatform? platform,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
  }) async {
    if (!hasValidLocation(artwork)) return false;
    return destinationOf(artwork).launch(
      destination,
      platform: platform,
      canLaunch: canLaunch,
      launcher: launcher,
    );
  }

  static Future<void> showNavigationOptions(
    BuildContext context,
    Artwork artwork, {
    TargetPlatform? platform,
    bool? isWeb,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
    ArtworkClipboardWriter? clipboardWriter,
    ArtworkWalkingOpenCallback? walkingOpener,
  }) async {
    if (!hasValidLocation(artwork)) return;
    await destinationOf(artwork).showNavigationOptions(
      context,
      platform: platform,
      isWeb: isWeb,
      canLaunch: canLaunch,
      launcher: launcher,
      clipboardWriter: clipboardWriter,
      walkingOpener: walkingOpener,
    );
  }
}
