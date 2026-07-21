import 'package:art_kubus/l10n/app_localizations.dart';

import 'username_policy.dart';

/// Maps a [UsernameRejection] onto its localized profile-edit message.
///
/// Kept separate from [UsernamePolicy] so the policy itself stays free of any
/// Flutter/localization dependency and can be unit-tested as pure logic. Every
/// username entry point — profile edit and onboarding — renders its errors
/// through this one mapping, so the wording never drifts between surfaces.
String? usernameRejectionMessage(
  AppLocalizations l10n,
  UsernameRejection? rejection,
) {
  switch (rejection) {
    case null:
      return null;
    case UsernameRejection.empty:
      return l10n.profileEditUsernameRequiredError;
    case UsernameRejection.tooShort:
      return l10n.profileEditUsernameMinLengthError;
    case UsernameRejection.tooLong:
      return l10n.profileEditUsernameMaxLengthError;
    case UsernameRejection.reserved:
      return l10n.profileEditUsernameReservedError;
    case UsernameRejection.walletLike:
      return l10n.profileEditUsernameWalletLikeError;
  }
}
