enum StreetArtClaimStatus {
  pendingOwnerReview,
  pendingDaoReview,
  approved,
  rejectedOwner,
  rejectedDao,
  unknown,
}

enum StreetArtClaimStage {
  ownerReview,
  daoReview,
  resolved,
  unknown,
}

enum StreetArtClaimReviewAction {
  approve,
  reject,
  escalate,
  approveDao,
  rejectDao,
}

extension StreetArtClaimReviewActionApi on StreetArtClaimReviewAction {
  String get apiValue {
    switch (this) {
      case StreetArtClaimReviewAction.approve:
        return 'approve';
      case StreetArtClaimReviewAction.reject:
        return 'reject';
      case StreetArtClaimReviewAction.escalate:
        return 'escalate';
      case StreetArtClaimReviewAction.approveDao:
        return 'approve_dao';
      case StreetArtClaimReviewAction.rejectDao:
        return 'reject_dao';
    }
  }
}

class StreetArtClaim {
  const StreetArtClaim({
    required this.id,
    required this.markerId,
    required this.claimantWallet,
    required this.reason,
    required this.status,
    required this.reviewStage,
    required this.createdAt,
    this.claimantUserId,
    this.claimantProfileName,
    this.evidenceUrl,
    this.ownerWallet,
    this.ownerUserId,
    this.ownerNote,
    this.daoNote,
    this.reviewedByWallet,
    this.reviewedByUserId,
    this.reviewedAt,
    this.resolvedAt,
    this.updatedAt,
  });

  final String id;
  final String markerId;
  final String claimantWallet;
  final String? claimantUserId;
  final String? claimantProfileName;
  final String? evidenceUrl;
  final String reason;
  final StreetArtClaimStatus status;
  final StreetArtClaimStage reviewStage;
  final String? ownerWallet;
  final String? ownerUserId;
  final String? ownerNote;
  final String? daoNote;
  final String? reviewedByWallet;
  final String? reviewedByUserId;
  final DateTime? reviewedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isResolved => reviewStage == StreetArtClaimStage.resolved;
  bool get isOpen => !isResolved;

  factory StreetArtClaim.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final value = raw.toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    String? readNullableString(List<String> keys) {
      final value = readString(keys);
      return value.isEmpty ? null : value;
    }

    DateTime? readDate(List<String> keys) {
      final value = readNullableString(keys);
      if (value == null) return null;
      return DateTime.tryParse(value);
    }

    final statusRaw = readString(const ['status']);
    final stageRaw = readString(const ['reviewStage', 'review_stage']);

    return StreetArtClaim(
      id: readString(const ['id']),
      markerId: readString(const ['markerId', 'marker_id']),
      claimantWallet: readString(const ['claimantWallet', 'claimant_wallet']),
      claimantUserId:
          readNullableString(const ['claimantUserId', 'claimant_user_id']),
      claimantProfileName: readNullableString(
        const ['claimantProfileName', 'claimant_profile_name'],
      ),
      evidenceUrl: readNullableString(const ['evidenceUrl', 'evidence_url']),
      reason: readString(const ['reason']),
      status: _parseStatus(statusRaw),
      reviewStage: _parseStage(stageRaw),
      ownerWallet: readNullableString(const ['ownerWallet', 'owner_wallet']),
      ownerUserId: readNullableString(const ['ownerUserId', 'owner_user_id']),
      ownerNote: readNullableString(const ['ownerNote', 'owner_note']),
      daoNote: readNullableString(const ['daoNote', 'dao_note']),
      reviewedByWallet:
          readNullableString(const ['reviewedByWallet', 'reviewed_by_wallet']),
      reviewedByUserId:
          readNullableString(const ['reviewedByUserId', 'reviewed_by_user_id']),
      reviewedAt: readDate(const ['reviewedAt', 'reviewed_at']),
      resolvedAt: readDate(const ['resolvedAt', 'resolved_at']),
      createdAt:
          readDate(const ['createdAt', 'created_at']) ?? DateTime.now(),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
    );
  }

  static StreetArtClaimStatus _parseStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pending_owner_review':
        return StreetArtClaimStatus.pendingOwnerReview;
      case 'pending_dao_review':
        return StreetArtClaimStatus.pendingDaoReview;
      case 'approved':
        return StreetArtClaimStatus.approved;
      case 'rejected_owner':
        return StreetArtClaimStatus.rejectedOwner;
      case 'rejected_dao':
        return StreetArtClaimStatus.rejectedDao;
      default:
        return StreetArtClaimStatus.unknown;
    }
  }

  static StreetArtClaimStage _parseStage(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'owner_review':
        return StreetArtClaimStage.ownerReview;
      case 'dao_review':
        return StreetArtClaimStage.daoReview;
      case 'resolved':
        return StreetArtClaimStage.resolved;
      default:
        return StreetArtClaimStage.unknown;
    }
  }
}
