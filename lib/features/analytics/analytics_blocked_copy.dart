import '../../l10n/app_localizations.dart';
import 'analytics_capability_resolver.dart';

/// Maps a typed [AnalyticsBlockedReason] to localized user-facing copy.
///
/// The capability resolver stays free of display strings; every blocked
/// state renders through these keys so EN and SL stay in lockstep.
class AnalyticsBlockedCopy {
  const AnalyticsBlockedCopy._();

  static String title(AppLocalizations l10n, AnalyticsBlockedReason reason) {
    switch (reason) {
      case AnalyticsBlockedReason.walletRequired:
        return l10n.analyticsBlockedWalletRequiredTitle;
      case AnalyticsBlockedReason.analyticsDisabled:
        return l10n.analyticsBlockedDisabledTitle;
      case AnalyticsBlockedReason.adminRequired:
        return l10n.analyticsBlockedAdminRequiredTitle;
      case AnalyticsBlockedReason.ownerRequired:
        return l10n.analyticsBlockedOwnerRequiredTitle;
      case AnalyticsBlockedReason.privateOnly:
        return l10n.analyticsBlockedPrivateOnlyTitle;
      case AnalyticsBlockedReason.artistReviewPending:
        return l10n.analyticsBlockedArtistPendingTitle;
      case AnalyticsBlockedReason.artistReviewRejected:
        return l10n.analyticsBlockedArtistRejectedTitle;
      case AnalyticsBlockedReason.artistRoleMismatch:
        return l10n.analyticsBlockedArtistRoleMismatchTitle;
      case AnalyticsBlockedReason.artistApprovalRequired:
        return l10n.analyticsBlockedArtistApprovalRequiredTitle;
      case AnalyticsBlockedReason.institutionReviewPending:
        return l10n.analyticsBlockedInstitutionPendingTitle;
      case AnalyticsBlockedReason.institutionReviewRejected:
        return l10n.analyticsBlockedInstitutionRejectedTitle;
      case AnalyticsBlockedReason.institutionRoleMismatch:
        return l10n.analyticsBlockedInstitutionRoleMismatchTitle;
      case AnalyticsBlockedReason.institutionApprovalRequired:
        return l10n.analyticsBlockedInstitutionApprovalRequiredTitle;
    }
  }

  static String description(
    AppLocalizations l10n,
    AnalyticsBlockedReason reason,
  ) {
    switch (reason) {
      case AnalyticsBlockedReason.walletRequired:
        return l10n.analyticsBlockedWalletRequiredDescription;
      case AnalyticsBlockedReason.analyticsDisabled:
        return l10n.analyticsBlockedDisabledDescription;
      case AnalyticsBlockedReason.adminRequired:
        return l10n.analyticsBlockedAdminRequiredDescription;
      case AnalyticsBlockedReason.ownerRequired:
        return l10n.analyticsBlockedOwnerRequiredDescription;
      case AnalyticsBlockedReason.privateOnly:
        return l10n.analyticsBlockedPrivateOnlyDescription;
      case AnalyticsBlockedReason.artistReviewPending:
        return l10n.analyticsBlockedArtistPendingDescription;
      case AnalyticsBlockedReason.artistReviewRejected:
        return l10n.analyticsBlockedArtistRejectedDescription;
      case AnalyticsBlockedReason.artistRoleMismatch:
        return l10n.analyticsBlockedArtistRoleMismatchDescription;
      case AnalyticsBlockedReason.artistApprovalRequired:
        return l10n.analyticsBlockedArtistApprovalRequiredDescription;
      case AnalyticsBlockedReason.institutionReviewPending:
        return l10n.analyticsBlockedInstitutionPendingDescription;
      case AnalyticsBlockedReason.institutionReviewRejected:
        return l10n.analyticsBlockedInstitutionRejectedDescription;
      case AnalyticsBlockedReason.institutionRoleMismatch:
        return l10n.analyticsBlockedInstitutionRoleMismatchDescription;
      case AnalyticsBlockedReason.institutionApprovalRequired:
        return l10n.analyticsBlockedInstitutionApprovalRequiredDescription;
    }
  }
}
