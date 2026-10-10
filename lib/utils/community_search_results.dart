// Rows and degradation for the community search picker's `GET /api/search`.
//
// The backend answers with `results` keyed by kind (`profiles`, `artworks`,
// `institutions`, `collections`, `posts`) and an additive `degradedKinds`
// list naming kinds whose query failed. A request for one kind must read that
// same key. Reading a key the request did not ask for (such as `all`, which
// the backend never returns) makes a non-empty result look empty.

/// Rows of [kind] from a search response, read only from `results[kind]`.
/// A missing, null or non-list key is an empty result. No other payload shape
/// is read, so rows of other kinds never appear under [kind].
List<Map<String, dynamic>> communitySearchRows(
  Map<String, dynamic> response,
  String kind,
) {
  final results = response['results'];
  final items = results is Map ? results[kind] : null;
  if (items is! List) return <Map<String, dynamic>>[];
  return [
    for (final item in items)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// Whether the backend reported [kind] as degraded, meaning its query failed.
/// An empty list for a degraded kind means "unavailable", not "no matches".
/// Unknown kinds and malformed `degradedKinds` values are ignored.
bool communitySearchKindDegraded(Map<String, dynamic> response, String kind) {
  final degraded = response['degradedKinds'];
  if (degraded is! List) return false;
  return degraded.any((entry) => entry == kind);
}
