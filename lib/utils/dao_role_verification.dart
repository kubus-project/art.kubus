import '../models/dao.dart';

enum DaoRoleType { artist, institution }

/// Centralized DAO review role verification helper.
///
/// This keeps role gating consistent across mobile and desktop flows:
/// a role is considered approved only when the wallet has an approved DAO review
/// for that exact role.
class DaoRoleVerification {
  final String walletAddress;
  final DAOReview? review;

  const DaoRoleVerification({
    required this.walletAddress,
    required this.review,
  });

  bool get hasWallet => walletAddress.trim().isNotEmpty;
  bool get hasReview => review != null;

  bool get isArtistReview => review?.isArtistApplication ?? false;
  bool get isInstitutionReview => review?.isInstitutionApplication ?? false;

  bool get _isApproved => (review?.status.toLowerCase() ?? '') == 'approved';
  bool get _isPending => (review?.status.toLowerCase() ?? '') == 'pending';
  bool get _isRejected => (review?.status.toLowerCase() ?? '') == 'rejected';

  bool _matchesRole(DaoRoleType role) {
    switch (role) {
      case DaoRoleType.artist:
        return isArtistReview;
      case DaoRoleType.institution:
        return isInstitutionReview;
    }
  }

  bool isApprovedFor(DaoRoleType role) => _matchesRole(role) && _isApproved;

  bool isPendingFor(DaoRoleType role) => _matchesRole(role) && _isPending;

  bool isRejectedFor(DaoRoleType role) => _matchesRole(role) && _isRejected;
}
