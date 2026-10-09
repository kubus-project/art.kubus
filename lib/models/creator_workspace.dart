import '../utils/dao_role_verification.dart';
import 'dao.dart';

/// The two creator workspaces: Artist Studio (create) and Institution Hub
/// (organize).
///
/// Both are discoverable by everyone, guests included. Discovery is not access:
/// [resolveCreatorWorkspaceStage] decides what a viewer may do inside, and the
/// backend stays the authority for every mutation.
enum CreatorWorkspace {
  artistStudio,
  institutionHub;

  /// Canonical, deep-linkable app route. Used as the return destination of
  /// account acquisition, so a visitor who starts from the workspace comes
  /// back to it after sign-in, email verification or a page refresh.
  String get route => switch (this) {
        CreatorWorkspace.artistStudio => '/artist-studio',
        CreatorWorkspace.institutionHub => '/institution-hub',
      };

  /// Route of the workspace inside the desktop shell's navigation.
  String get desktopShellRoute => switch (this) {
        CreatorWorkspace.artistStudio => '/artist-studio',
        CreatorWorkspace.institutionHub => '/institution',
      };

  /// The DAO-reviewed role that opens this workspace.
  DaoRoleType get role => switch (this) {
        CreatorWorkspace.artistStudio => DaoRoleType.artist,
        CreatorWorkspace.institutionHub => DaoRoleType.institution,
      };

  DaoRoleType get otherRole => switch (this) {
        CreatorWorkspace.artistStudio => DaoRoleType.institution,
        CreatorWorkspace.institutionHub => DaoRoleType.artist,
      };

  /// Bounded `source_screen` value for first-party analytics.
  String get telemetrySource => switch (this) {
        CreatorWorkspace.artistStudio => 'artist_studio',
        CreatorWorkspace.institutionHub => 'institution_hub',
      };

  static CreatorWorkspace? fromRoute(String? route) {
    final path = (route ?? '').trim();
    for (final workspace in CreatorWorkspace.values) {
      if (workspace.route == path) return workspace;
    }
    return null;
  }
}

/// Where a viewer stands with one creator workspace. Each stage names the one
/// next step, so nothing is asked for in advance.
enum CreatorWorkspaceStage {
  /// No account session. The workspace explains itself and offers an account.
  discover,

  /// Signed in without a usable public profile (a display name). Applications
  /// are reviewed under a public identity.
  completeProfile,

  /// Ready to apply, but no wallet is linked and the backend still accepts
  /// applications only as a wallet-signed request. Never produced once the
  /// backend advertises account-authorised applications
  /// (`accountApplications` in [resolveCreatorWorkspaceStage]): a wallet is
  /// then not a prerequisite of applying.
  linkWalletToApply,

  /// Ready to submit the application.
  apply,

  /// The application is with the DAO.
  pending,

  /// The application was declined; it can be resubmitted.
  rejected,

  /// This wallet's single review belongs to the other role (approved or in
  /// review). The backend grants one creator role per review.
  otherRoleReview,

  /// The role is granted. The workspace's tools are open.
  open,
}

extension CreatorWorkspaceStageX on CreatorWorkspaceStage {
  bool get isOpen => this == CreatorWorkspaceStage.open;
}

/// Resolves [workspace]'s stage for one viewer. Pure, so mobile, desktop and
/// the home entry points read the same answer.
///
/// [profileGrantsRole] is the server-held role flag (`isArtist` for Artist
/// Studio, `isInstitution` for Institution Hub). The backend sets those flags
/// only from an approved DAO review or an administrator, so a granted flag
/// opens the workspace even when this wallet's review concerns the other role:
/// a person who holds both roles keeps both workspaces. Nothing here is taken
/// from a role or persona the viewer merely selected.
///
/// [accountApplications] is true when the backend accepts applications from an
/// authenticated account without a wallet signature. Then a missing wallet is
/// never a step; it stays one only against an older backend.
CreatorWorkspaceStage resolveCreatorWorkspaceStage({
  required CreatorWorkspace workspace,
  required bool hasAccountSession,
  required bool hasUsableProfile,
  required String walletAddress,
  required DAOReview? review,
  required bool profileGrantsRole,
  bool accountApplications = false,
}) {
  if (!hasAccountSession) return CreatorWorkspaceStage.discover;
  if (profileGrantsRole) return CreatorWorkspaceStage.open;

  final verification = DaoRoleVerification(
    walletAddress: walletAddress,
    review: review,
  );
  if (verification.isApprovedFor(workspace.role)) {
    return CreatorWorkspaceStage.open;
  }
  if (verification.isPendingFor(workspace.role)) {
    return CreatorWorkspaceStage.pending;
  }
  if (verification.isApprovedFor(workspace.otherRole) ||
      verification.isPendingFor(workspace.otherRole)) {
    return CreatorWorkspaceStage.otherRoleReview;
  }
  if (verification.isRejectedFor(workspace.role)) {
    return CreatorWorkspaceStage.rejected;
  }
  if (!hasUsableProfile) return CreatorWorkspaceStage.completeProfile;
  if (!accountApplications && walletAddress.trim().isEmpty) {
    return CreatorWorkspaceStage.linkWalletToApply;
  }
  return CreatorWorkspaceStage.apply;
}
