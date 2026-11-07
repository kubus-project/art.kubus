/// An artist application made by a signed-in account, without a wallet.
///
/// Mirrors the backend `mapAccountArtistApplication` shape returned by
/// `POST /api/dao/artist-applications` and `GET /api/dao/artist-applications/mine`.
class ArtistApplicationSummary {
  const ArtistApplicationSummary({
    required this.id,
    required this.portfolioUrl,
    required this.medium,
    required this.statement,
    required this.status,
    this.reviewerNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String portfolioUrl;
  final String medium;
  final String statement;

  /// One of `pending`, `approved`, `rejected`.
  final String status;
  final String? reviewerNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  /// Parses one application map. Returns null when there is no usable id, so
  /// a malformed body is treated as "no application" rather than a crash.
  static ArtistApplicationSummary? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = (map['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    final status = (map['status'] ?? '').toString().trim().toLowerCase();
    final notes = map['reviewerNotes']?.toString().trim();
    return ArtistApplicationSummary(
      id: id,
      portfolioUrl: (map['portfolioUrl'] ?? '').toString(),
      medium: (map['medium'] ?? '').toString(),
      statement: (map['statement'] ?? '').toString(),
      status: status,
      reviewerNotes: (notes == null || notes.isEmpty) ? null : notes,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
