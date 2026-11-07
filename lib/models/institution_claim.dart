/// One claim request on an institution profile, as the backend returns it
/// (`POST /api/institutions/:id/claims`, `GET /api/institutions/claims/mine`).
///
/// Only what the app acts on is kept: whether a request is still open decides
/// if the "Claim this profile" action is offered again.
class InstitutionClaimSummary {
  const InstitutionClaimSummary({
    required this.id,
    required this.institutionId,
    required this.status,
    required this.kind,
  });

  final String id;
  final String institutionId;

  /// `submitted`, `under_review`, `approved`, `rejected`, `withdrawn`, ...
  final String status;

  /// `claim`, `transfer` or `dispute`.
  final String kind;

  /// A request an administrator has not decided yet. The backend allows one
  /// open request per claimant and institution.
  bool get isOpen => status == 'submitted' || status == 'under_review';

  static InstitutionClaimSummary? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final institutionId = value['institutionId'] ?? value['institution_id'];
    final status = value['status'];
    if (id is! String || institutionId is! String || status is! String) {
      return null;
    }
    final kind = value['kind'];
    return InstitutionClaimSummary(
      id: id,
      institutionId: institutionId.toLowerCase(),
      status: status.trim().toLowerCase(),
      kind: kind is String ? kind.trim().toLowerCase() : 'claim',
    );
  }
}
