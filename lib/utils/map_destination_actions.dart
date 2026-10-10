import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import '../l10n/app_localizations.dart';
import '../services/walking_navigation_diagnostics.dart';
import '../widgets/glass_components.dart';
import '../widgets/kubus_snackbar.dart';
import '../widgets/navigation/kubus_navigation_option_row.dart';
import 'design_tokens.dart';
import 'map_coordinate_rules.dart';
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
typedef ArtworkWalkingOpenCallback = void Function(
  BuildContext context, {
  required WalkingNavigationIntent intent,
});

enum ArtworkExternalMapDestination {
  googleMaps,
  appleMaps,
  platformDefault,
  openStreetMap,
}

/// A place a person can be sent to: an artwork, a marker, an event venue.
///
/// Carries only what leaving for a place needs (an id for the in-app walking
/// route, a label, a coordinate), so every surface that offers "navigate"
/// shares one validity rule and one set of providers instead of each
/// re-deriving them from its own model.
@immutable
class MapDestination {
  const MapDestination({
    required this.id,
    required this.title,
    required this.position,
  });

  /// The destination of an in-app walking route, so "open externally" from the
  /// route goes through this same navigation path.
  factory MapDestination.fromWalkingIntent(WalkingNavigationIntent intent) =>
      MapDestination(
        id: intent.destinationId,
        title: intent.destinationLabel,
        position: intent.destination,
      );

  final String id;
  final String title;
  final LatLng position;

  /// The shared coordinate rule; see [isValidMapCoordinate].
  static bool isValidCoordinate(LatLng position) =>
      isValidMapCoordinate(position);

  bool get isValid => isValidCoordinate(position);

  /// `lat, lng` at fixed precision, as shown in the copy action.
  String get coordinateText => '${formatMapCoordinate(position.latitude)}, '
      '${formatMapCoordinate(position.longitude)}';

  /// The one Google Maps directions form. Coordinates only: MapDestination
  /// carries no Google place id, so a place id is never sent.
  Uri _googleDirectionsWebUri({String? travelMode}) => Uri.https(
        'www.google.com',
        '/maps/dir/',
        <String, String>{
          'api': '1',
          'destination': _coordinates,
          if (travelMode != null) 'travelmode': travelMode,
        },
      );

  String get _coordinates => '${formatMapCoordinate(position.latitude)},'
      '${formatMapCoordinate(position.longitude)}';

  /// Walking directions to this place in the web directions form. Used when a
  /// walking route is handed to an external maps app.
  Uri get walkingExternalUri => _googleDirectionsWebUri(travelMode: 'walking');

  /// Opens walking directions externally. Returns false for a destination
  /// without a valid coordinate, so nothing is launched for it.
  Future<bool> openWalkingExternally({ArtworkLaunchUri? launcher}) async {
    if (!isValid) return false;
    final open =
        launcher ?? (Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);
    try {
      return await open(walkingExternalUri, LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Apple Maps has a safe web fallback, so keep it available alongside the
  /// other external navigation providers on every platform.
  static bool shouldShowAppleMaps(TargetPlatform platform) => true;

  static bool shouldShowPlatformDefaultMaps(
    TargetPlatform platform, {
    required bool isWeb,
  }) =>
      !isWeb && platform == TargetPlatform.android;

  List<Uri> externalUris(
    ArtworkExternalMapDestination destination, {
    required TargetPlatform platform,
  }) {
    final coordinates = _coordinates;
    final latitude = formatMapCoordinate(position.latitude);
    final longitude = formatMapCoordinate(position.longitude);
    final label = title.trim().isEmpty ? coordinates : title.trim();

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
        // Web fallback is the directions form, so desktop opens route
        // planning rather than a bare search pin.
        return <Uri>[
          if (appUri != null) appUri,
          _googleDirectionsWebUri(),
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

  Future<bool> launch(
    ArtworkExternalMapDestination destination, {
    TargetPlatform? platform,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
  }) async {
    if (!isValid) return false;
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final canOpen = canLaunch ?? canLaunchUrl;
    final open =
        launcher ?? (Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);
    for (final uri in externalUris(destination, platform: resolvedPlatform)) {
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

  /// Shows the shared "navigate to this place" sheet. A no-op for a
  /// destination without a valid coordinate.
  Future<void> showNavigationOptions(
    BuildContext context, {
    TargetPlatform? platform,
    bool? isWeb,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
    ArtworkClipboardWriter? clipboardWriter,
    ArtworkWalkingOpenCallback? walkingOpener,
  }) async {
    if (!isValid) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final sheetColor = Theme.of(context).colorScheme.surface;
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final resolvedIsWeb = isWeb ?? kIsWeb;
    final options = <_NavigationOptionDefinition>[
      _NavigationOptionDefinition(
        destination: ArtworkExternalMapDestination.googleMaps,
        icon: Icons.map_outlined,
        label: l10n.artDetailNavigationGoogleMaps,
        failureMessage: l10n.artDetailNavigationCouldNotOpenGoogleMaps,
      ),
      if (shouldShowAppleMaps(resolvedPlatform))
        _NavigationOptionDefinition(
          destination: ArtworkExternalMapDestination.appleMaps,
          icon: Icons.apple,
          label: l10n.artDetailNavigationAppleMaps,
          failureMessage: l10n.artDetailNavigationCouldNotOpenAppleMaps,
        ),
      if (shouldShowPlatformDefaultMaps(
        resolvedPlatform,
        isWeb: resolvedIsWeb,
      ))
        _NavigationOptionDefinition(
          destination: ArtworkExternalMapDestination.platformDefault,
          icon: Icons.navigation_outlined,
          label: l10n.artDetailNavigationOtherMaps,
          failureMessage: l10n.artDetailNavigationCouldNotOpenMaps,
        ),
      _NavigationOptionDefinition(
        destination: ArtworkExternalMapDestination.openStreetMap,
        icon: Icons.public,
        label: 'OpenStreetMap',
        failureMessage: l10n.artDetailNavigationCouldNotOpenMaps,
      ),
    ];

    final invoker = FocusManager.instance.primaryFocus;
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
                    l10n.artDetailNavigateToTitle(title),
                    style: KubusTextStyles.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  KubusNavigationOptionRow(
                    key: const ValueKey('navigation-option-in-app'),
                    enabled: AppConfig.isFeatureEnabled(
                      'mapWalkingNavigation',
                    ),
                    icon: Icons.directions_walk_outlined,
                    label: l10n.artDetailNavigationInApp,
                    statusLabel: l10n.walkingNavigationBeta,
                    trailingIcon: Icons.chevron_right,
                    onTap: !AppConfig.isFeatureEnabled(
                      'mapWalkingNavigation',
                    )
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            WalkingNavigationDiagnostics.record(
                              'navigation_option_selected',
                              reason: 'in_app',
                            );
                            (walkingOpener ?? MapNavigation.openWalking)(
                              context,
                              intent: WalkingNavigationIntent(
                                destinationId: id,
                                destinationLabel: title,
                                destination: position,
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  for (final option in options)
                    KubusNavigationOptionRow(
                      key: ValueKey(
                        'navigation-option-${option.destination.name}',
                      ),
                      icon: option.icon,
                      label: option.label,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        WalkingNavigationDiagnostics.record(
                          'navigation_option_selected',
                          reason: option.destination.name,
                        );
                        unawaited(_launchAndReport(
                          option,
                          messenger: messenger,
                          platform: resolvedPlatform,
                          canLaunch: canLaunch,
                          launcher: launcher,
                        ));
                      },
                    ),
                  KubusNavigationOptionRow(
                    key: const ValueKey('navigation-option-copy'),
                    icon: Icons.copy_outlined,
                    label: l10n.artDetailNavigationCopyCoordinates,
                    trailingIcon: Icons.copy_outlined,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_copyAndReport(
                        messenger: messenger,
                        successMessage: l10n.artDetailCoordinatesCopiedToast(
                          coordinateText,
                        ),
                        failureMessage:
                            l10n.artDetailNavigationCouldNotCopyCoordinates,
                        clipboardWriter: clipboardWriter,
                      ));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KubusSpacing.md,
                      KubusSpacing.sm,
                      KubusSpacing.md,
                      0,
                    ),
                    child: Text(
                      l10n.walkingNavigationPreviewNotice,
                      textAlign: TextAlign.center,
                      style: KubusTypography.textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
    _returnFocus(invoker);
  }

  /// Gives keyboard focus back to the control that opened the sheet, when that
  /// control is still on screen. Flutter does not restore focus on dismissal,
  /// so without this a keyboard user loses their place in a quick card.
  static void _returnFocus(FocusNode? node) {
    final context = node?.context;
    if (node == null || context == null || !context.mounted) return;
    if (node.canRequestFocus) node.requestFocus();
  }

  Future<void> _launchAndReport(
    _NavigationOptionDefinition option, {
    required ScaffoldMessengerState messenger,
    required TargetPlatform platform,
    ArtworkCanLaunchUri? canLaunch,
    ArtworkLaunchUri? launcher,
  }) async {
    final didOpen = await launch(
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

  Future<void> _copyAndReport({
    required ScaffoldMessengerState messenger,
    required String successMessage,
    required String failureMessage,
    ArtworkClipboardWriter? clipboardWriter,
  }) async {
    final write = clipboardWriter ??
        (String text) => Clipboard.setData(ClipboardData(text: text));
    try {
      await write(coordinateText);
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

class _NavigationOptionDefinition {
  const _NavigationOptionDefinition({
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
