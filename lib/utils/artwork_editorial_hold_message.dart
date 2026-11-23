import '../l10n/app_localizations.dart';
import '../services/backend_api_service.dart';

/// The text for a publish the backend refused because an editor holds the
/// artwork. It says which hold applies; the owner cannot lift either one.
String artworkEditorialHoldMessage(
  AppLocalizations l10n,
  ArtworkEditorialHoldException hold,
) =>
    switch (hold.kind) {
      ArtworkEditorialHoldKind.withdrawn => l10n.artworkPublishHeldWithdrawn,
      ArtworkEditorialHoldKind.inReview => l10n.artworkPublishHeldInReview,
      ArtworkEditorialHoldKind.unspecified => l10n.artworkPublishHeldGeneric,
    };
