import 'artist_application.dart';
import 'institution_claim.dart';

/// Where an account stands as an artist, from the server's point of view.
enum ArtistVerificationStatus {
  notApplied,
  pending,
  approved,
  rejected,
  revoked,
}

/// How the account stands with respect to institution access.
enum InstitutionAccessStatus {
  /// No membership and no open request.
  none,

  /// A claim or presence request is waiting for an administrator.
  requestPending,

  /// At least one active membership.
  member,
}

/// One active membership of the signed-in account in a canonical institution.
///
/// The role and permissions are the server's. The app never derives them from
/// a persona, a wallet or a cached flag.
class InstitutionMembership {
  const InstitutionMembership({
    required this.memberId,
    required this.institutionId,
    required this.institutionName,
    required this.role,
    required this.permissions,
    required this.listed,
    required this.officialAccountVerified,
  });

  final String memberId;
  final String institutionId;
  final String institutionName;

  /// `owner`, `admin`, `editor` or `viewer`.
  final String role;
  final List<String> permissions;

  /// The institution is a public listing. This is not the official badge.
  final bool listed;

  /// A separate, evidenced decision. Membership never implies it.
  final bool officialAccountVerified;

  bool can(String permission) => permissions.contains(permission);
  bool get canManage => can('institution.manage');
  bool get canAdminister => can('institution.administer');

  static InstitutionMembership? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final institutionId = (raw['institutionId'] ?? '').toString().trim();
    final memberId = (raw['memberId'] ?? '').toString().trim();
    if (institutionId.isEmpty || memberId.isEmpty) return null;
    final institution = raw['institution'];
    final permissions = raw['permissions'];
    return InstitutionMembership(
      memberId: memberId,
      institutionId: institutionId.toLowerCase(),
      institutionName: (raw['institutionName'] ?? '').toString().trim(),
      role: (raw['role'] ?? 'viewer').toString().trim().toLowerCase(),
      permissions: permissions is List
          ? permissions.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      listed: institution is Map && institution['listed'] == true,
      officialAccountVerified:
          institution is Map && institution['officialAccountVerified'] == true,
    );
  }
}

/// A request for a NEW institutional presence (no listing exists to claim).
class InstitutionPresenceRequestSummary {
  const InstitutionPresenceRequestSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    this.reviewerNotes,
    this.decisionReason,
    this.createdInstitutionId,
  });

  final String id;
  final String name;
  final String kind;

  /// `submitted`, `under_review`, `approved`, `rejected`, `withdrawn`.
  final String status;
  final String? reviewerNotes;
  final String? decisionReason;
  final String? createdInstitutionId;

  bool get isOpen => status == 'submitted' || status == 'under_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  static InstitutionPresenceRequestSummary? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    String? text(String key) {
      final value = raw[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return InstitutionPresenceRequestSummary(
      id: id,
      name: (raw['name'] ?? '').toString().trim(),
      kind: (raw['kind'] ?? 'other').toString().trim().toLowerCase(),
      status: (raw['status'] ?? '').toString().trim().toLowerCase(),
      reviewerNotes: text('reviewerNotes'),
      decisionReason: text('decisionReason'),
      createdInstitutionId: text('createdInstitutionId'),
    );
  }
}

/// Everything the server says this account may do, from one read of
/// `GET /api/verification/me`.
class AccountVerificationState {
  const AccountVerificationState({
    required this.accountId,
    required this.walletLinked,
    required this.artistEffective,
    required this.artistApplication,
    required this.institutionsAvailable,
    required this.memberships,
    required this.claims,
    required this.presenceRequests,
    required this.legacyRoleWithoutMembership,
  });

  final String accountId;
  final bool walletLinked;

  /// The server's answer to "may this account publish original artworks".
  final bool artistEffective;
  final ArtistApplicationSummary? artistApplication;

  /// Whether institution applications and claims are open on this backend.
  final bool institutionsAvailable;
  final List<InstitutionMembership> memberships;
  final List<InstitutionClaimSummary> claims;
  final List<InstitutionPresenceRequestSummary> presenceRequests;

  /// An older institution role without any membership: the account should be
  /// pointed at claiming or requesting its institution.
  final bool legacyRoleWithoutMembership;

  ArtistVerificationStatus get artistStatus {
    if (artistEffective) return ArtistVerificationStatus.approved;
    final application = artistApplication;
    if (application == null) return ArtistVerificationStatus.notApplied;
    switch (application.status) {
      case 'pending':
        return ArtistVerificationStatus.pending;
      case 'approved':
        // Approved on paper but the server does not honour it (for example a
        // closed profile): treat as not effective rather than unlocking.
        return ArtistVerificationStatus.notApplied;
      case 'rejected':
        return ArtistVerificationStatus.rejected;
      case 'revoked':
        return ArtistVerificationStatus.revoked;
      default:
        return ArtistVerificationStatus.notApplied;
    }
  }

  bool get hasOpenInstitutionRequest =>
      claims.any((claim) => claim.isOpen) ||
      presenceRequests.any((request) => request.isOpen);

  static AccountVerificationState? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final accountId = (raw['accountId'] ?? '').toString().trim().toLowerCase();
    if (accountId.isEmpty) return null;
    final artist = raw['artist'];
    final institution = raw['institution'];
    final artistMap = artist is Map ? artist : const <String, Object?>{};
    final institutionMap =
        institution is Map ? institution : const <String, Object?>{};

    List<T> list<T>(Object? value, T? Function(Object?) parse) {
      if (value is! List) return const [];
      return value.map(parse).whereType<T>().toList(growable: false);
    }

    return AccountVerificationState(
      accountId: accountId,
      walletLinked: raw['walletLinked'] == true,
      artistEffective: artistMap['effective'] == true,
      artistApplication: ArtistApplicationSummary.tryParse(
        artistMap['application'],
      ),
      institutionsAvailable: institutionMap['available'] == true,
      memberships:
          list(institutionMap['memberships'], InstitutionMembership.tryParse),
      claims: list(institutionMap['claims'], InstitutionClaimSummary.tryParse),
      presenceRequests: list(institutionMap['presenceRequests'],
          InstitutionPresenceRequestSummary.tryParse),
      legacyRoleWithoutMembership:
          institutionMap['legacyRoleWithoutMembership'] == true,
    );
  }
}
