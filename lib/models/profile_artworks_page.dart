/// One page of a public profile's artworks for a single relationship scope
/// (`authored`, `documented`, or `managed`).
///
/// Older backends ignore the `relationship` query parameter and do not echo
/// it back. [relationshipHonoured] is false for those responses, and the
/// [items] then contain the legacy mixed list rather than a scoped list.
class ProfileArtworksPage {
  const ProfileArtworksPage({
    required this.items,
    required this.total,
    required this.relationshipHonoured,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool relationshipHonoured;

  /// Builds a page from a `/api/profiles/:wallet/artworks` response body.
  ///
  /// [requestedRelationship] is the scope the client asked for. The backend
  /// must echo it at the response root for the scope to count as honoured.
  factory ProfileArtworksPage.fromJson(
    Map<String, dynamic> json, {
    required String requestedRelationship,
  }) {
    final rawItems = json['data'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    var total = items.length;
    final pagination = json['pagination'];
    if (pagination is Map && pagination['total'] is num) {
      total = (pagination['total'] as num).toInt();
    }

    final echoed = json['relationship']?.toString().trim();
    return ProfileArtworksPage(
      items: items,
      total: total,
      relationshipHonoured: echoed == requestedRelationship,
    );
  }
}
