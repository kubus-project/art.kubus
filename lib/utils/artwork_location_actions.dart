import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/artwork.dart';
import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import '../widgets/common/kubus_badge.dart';
import '../widgets/glass_components.dart';
import '../widgets/kubus_snackbar.dart';
import 'design_tokens.dart';
import 'map_navigation.dart';

typedef ArtworkMapOpenCallback = void Function(
  BuildContext context, {
  required LatLng center,
  double? zoom,
  bool autoFollow,
  String? initialMarkerId,
  String? initialArtworkId,
  String? initialSubjectId,
  String? initialSubjectType,
  String? initialTargetLabel,
  bool preserveDesktopBackStack,
});

typedef ArtworkCanLaunchUri = Future<bool> Function(Uri uri);
typedef ArtworkLaunchUri = Future<bool> Function(Uri uri, LaunchMode mode);
typedef ArtworkClipboardWriter = Future<void> Function(String text);

enum ArtworkExternalMapDestination {
  googleMaps,
  appleMaps,
  platformDefault,
  openStreetMap,
}

/// Shared internal-map and external-navigation behavior for geolocated artwork.
class ArtworkLocationActions {
  const ArtworkLocationActions._();

  static bool hasValidLocation(Artwork artwork) {
    final latitude = artwork.position.latitude;
    final longitude = artwork.position.longitude;
    return artwork.hasValidLocation &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

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
      '${artwork.position.latitude.toStringAsFixed(6)}, '
      '${artwork.position.longitude.toStringAsFixed(6)}';

  /// Apple Maps has a safe web fallback, so keep it available alongside the
  /// other external navigation providers on every platform.
  static bool shouldShowAppleMaps(TargetPlatform platform) => true;

  static bool shouldShowPlatformDefaultMaps(
    TargetPlatform platform, {
    required bool isWeb,
  }) =>
      !isWeb && platform == TargetPlatform.android;

  static List<Uri> destinationUris(
    Artwork artwork,
    ArtworkExternalMapDestination destination, {
    required TargetPlatform platform,
  }) {
    final latitude = artwork.position.latitude.toString();
    final longitude = artwork.position.longitude.toString();
    final coordinates = '$latitude,$longitude';
    final label =
        artwork.title.trim().isEmpty ? coordinates : artwork.title.trim();

    switch (destination) {
      case ArtworkExternalMapDestination.googleMaps:
        final appUri = platform == TargetPlatform.android
            ? Uri(
                scheme: 'google.navigation',
                queryParameters: <String, String>{'q': coordinates},
              )
            : shouldShowAppleMaps(platform)
                ? Uri(
                    scheme: 'comgooglemaps',
                    queryParameters: <String, String>{'q': coordinates},
                  )
                : null;
        return <Uri>[
          if (appUri != null) appUri,
          Uri.https(
            'www.google.com',
            '/maps/search/',
            <String, String>{'api': '1', 'query': coordinates},
          ),
        ];
      case ArtworkExternalMapDestination.appleMaps:
        return <Uri>[
          Uri(
            scheme: 'maps',
            queryParameters: <String, String>{
              'q': label,
              'll': coordinates,
            },
          ),
          Uri.https(
            'maps.apple.com',
            '/',
            <String, String>{'q': label, 'll': coordinates},
          ),
        ];
      case ArtworkExternalMapDestination.platformDefault:
        if (platform != TargetPlatform.android) return const <Uri>[];
        return <Uri>[
          Uri(
            scheme: 'geo',
            path: coordinates,
            queryParameters: <String, String>{
              'q': '$coordinates ($label)',
            },
          ),
        ];
      case ArtworkExternalMapDestination.openStreetMap:
        return <Uri>[
          Uri.https(
            'www.openstreetmap.org',
            '/',
            <String, String>{
              'mlat': latitude,
              'mlon': longitude,
              'zoom': '16',
            },
          ),
        ];
    }
  }

  static Future<bool> launchDestination(
    Artwork artwork,
    ArtworkExternalMapDestination destination, {
    TargetPlatform? platform,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
  }) async {
    if (!hasValidLocation(artwork)) return false;
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final canOpen = canLaunch ?? canLaunchUrl;
    final open =
        launcher ?? (Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);
    for (final uri in destinationUris(
      artwork,
      destination,
      platform: resolvedPlatform,
    )) {
      try {
        if (!await canOpen(uri)) continue;
        final mode = uri.scheme == 'https' || uri.scheme == 'http'
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault;
        if (await open(uri, mode)) return true;
      } catch (_) {
        // Continue to the next safe candidate URI.
      }
    }
    return false;
  }

  static Future<void> showNavigationOptions(
    BuildContext context,
    Artwork artwork, {
    TargetPlatform? platform,
    bool? isWeb,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
    ArtworkClipboardWriter? clipboardWriter,
  }) async {
    if (!hasValidLocation(artwork)) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final sheetColor = Theme.of(context).colorScheme.surface;
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final resolvedIsWeb = isWeb ?? kIsWeb;
    final options = <_ArtworkNavigationOptionDefinition>[
      _ArtworkNavigationOptionDefinition(
        destination: ArtworkExternalMapDestination.googleMaps,
        icon: Icons.map_outlined,
        label: l10n.artDetailNavigationGoogleMaps,
        failureMessage: l10n.artDetailNavigationCouldNotOpenGoogleMaps,
      ),
      if (shouldShowAppleMaps(resolvedPlatform))
        _ArtworkNavigationOptionDefinition(
          destination: ArtworkExternalMapDestination.appleMaps,
          icon: Icons.apple,
          label: l10n.artDetailNavigationAppleMaps,
          failureMessage: l10n.artDetailNavigationCouldNotOpenAppleMaps,
        ),
      if (shouldShowPlatformDefaultMaps(
        resolvedPlatform,
        isWeb: resolvedIsWeb,
      ))
        _ArtworkNavigationOptionDefinition(
          destination: ArtworkExternalMapDestination.platformDefault,
          icon: Icons.navigation_outlined,
          label: l10n.artDetailNavigationOtherMaps,
          failureMessage: l10n.artDetailNavigationCouldNotOpenMaps,
        ),
      _ArtworkNavigationOptionDefinition(
        destination: ArtworkExternalMapDestination.openStreetMap,
        icon: Icons.public,
        label: 'OpenStreetMap',
        failureMessage: l10n.artDetailNavigationCouldNotOpenMaps,
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        ),
      ),
      builder: (sheetContext) {
        final maxContentHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return BackdropGlassSheet(
          backgroundColor: sheetColor,
          showBorder: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.artDetailNavigateToTitle(artwork.title),
                    style: KubusTextStyles.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  ListTile(
                    enabled: AppConfig.isFeatureEnabled(
                      'mapWalkingNavigation',
                    ),
                    leading: const Icon(Icons.directions_walk_outlined),
                    title: Text(l10n.artDetailNavigationInApp),
                    subtitle: Text(l10n.walkingNavigationPreviewNotice),
                    trailing: KubusBadge(
                      text: l10n.artDetailNavigationInDevelopment,
                      variant: KubusBadgeVariant.status,
                      accent: Theme.of(sheetContext).colorScheme.primary,
                      icon: Icons.construction_outlined,
                      compact: true,
                    ),
                    onTap: !AppConfig.isFeatureEnabled(
                      'mapWalkingNavigation',
                    )
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            MapNavigation.openWalking(
                              context,
                              intent: WalkingNavigationIntent(
                                destinationId: artwork.id,
                                destinationLabel: artwork.title,
                                destination: artwork.position,
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  for (final option in options)
                    ListTile(
                      leading: Icon(option.icon),
                      title: Text(option.label),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_launchAndReport(
                          artwork,
                          option,
                          messenger: messenger,
                          platform: resolvedPlatform,
                          canLaunch: canLaunch,
                          launcher: launcher,
                        ));
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.copy_outlined),
                    title: Text(l10n.artDetailNavigationCopyCoordinates),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_copyAndReport(
                        artwork,
                        messenger: messenger,
                        successMessage: l10n.artDetailCoordinatesCopiedToast(
                          coordinateText(artwork),
                        ),
                        failureMessage:
                            l10n.artDetailNavigationCouldNotCopyCoordinates,
                        clipboardWriter: clipboardWriter,
                      ));
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _launchAndReport(
    Artwork artwork,
    _ArtworkNavigationOptionDefinition option, {
    required ScaffoldMessengerState messenger,
    required TargetPlatform platform,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
  }) async {
    final didOpen = await launchDestination(
      artwork,
      option.destination,
      platform: platform,
      canLaunch: canLaunch,
      launcher: launcher,
    );
    if (!didOpen && messenger.mounted) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(option.failureMessage)),
        tone: KubusSnackBarTone.warning,
      );
    }
  }

  static Future<void> _copyAndReport(
    Artwork artwork, {
    required ScaffoldMessengerState messenger,
    required String successMessage,
    required String failureMessage,
    ArtworkClipboardWriter? clipboardWriter,
  }) async {
    final write = clipboardWriter ??
        (String text) => Clipboard.setData(ClipboardData(text: text));
    try {
      await write(coordinateText(artwork));
      if (!messenger.mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(successMessage)),
        tone: KubusSnackBarTone.success,
      );
    } catch (_) {
      if (!messenger.mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(failureMessage)),
        tone: KubusSnackBarTone.warning,
      );
    }
  }
}

class _ArtworkNavigationOptionDefinition {
  const _ArtworkNavigationOptionDefinition({
    required this.destination,
    required this.icon,
    required this.label,
    required this.failureMessage,
  });

  final ArtworkExternalMapDestination destination;
  final IconData icon;
  final String label;
  final String failureMessage;
}
