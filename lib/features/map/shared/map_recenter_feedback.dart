import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/walking_location_service.dart';
import '../../../widgets/kubus_snackbar.dart';
import '../navigation/walking_navigation_models.dart';

/// Localized feedback for "center on me", shared by the phone and desktop maps
/// so both report the same outcome in the same words.
abstract final class MapRecenterFeedback {
  static void showLocating(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    if (messenger == null || l10n == null) return;
    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.mapCenterOnMeLocating)),
    );
  }

  static void hideLocating(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }

  /// Explains a failed explicit request and offers the action that fixes it.
  static void showUnavailable(
    BuildContext context, {
    required WalkingLocationAccessStatus status,
    required WalkingLocationApi api,
    required VoidCallback onRetry,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    if (messenger == null || l10n == null) return;

    final (String message, SnackBarAction action) = switch (status) {
      WalkingLocationAccessStatus.permissionDenied => (
          l10n.mapCenterOnMePermissionDenied,
          SnackBarAction(
            label: l10n.walkingNavigationAllowLocation,
            onPressed: onRetry,
          ),
        ),
      WalkingLocationAccessStatus.permissionDeniedPermanently => (
          l10n.mapCenterOnMePermissionBlocked,
          SnackBarAction(
            label: l10n.walkingNavigationOpenAppSettings,
            onPressed: () => unawaited(api.openAppSettings()),
          ),
        ),
      WalkingLocationAccessStatus.serviceDisabled => (
          l10n.mapCenterOnMeServicesDisabled,
          SnackBarAction(
            label: l10n.walkingNavigationOpenLocationSettings,
            onPressed: () => unawaited(api.openLocationSettings()),
          ),
        ),
      WalkingLocationAccessStatus.timedOut => (
          l10n.mapCenterOnMeTimedOut,
          SnackBarAction(
              label: l10n.walkingNavigationRetry, onPressed: onRetry),
        ),
      _ => (
          l10n.mapLocationUnavailableToast,
          SnackBarAction(
              label: l10n.walkingNavigationRetry, onPressed: onRetry),
        ),
    };

    messenger.showKubusSnackBar(
      SnackBar(content: Text(message), action: action),
      tone: KubusSnackBarTone.warning,
    );
  }
}
