// Rows and degradation for the community search picker's `GET /api/search`.
//
// The backend answers with `results` keyed by kind (`profiles`, `artworks`,
// `institutions`, `collections`, `posts`) and an additive `degradedKinds`
// list naming kinds whose query failed. A request for one kind must read that
// same key. Reading a key the request did not ask for (such as `all`, which
// the backend never returns) makes a non-empty result look empty.

/// Rows of [kind] from a search response. Reads the kind's own key whenever
/// `results` carries it. Only when `results` has no such key does it fall back
/// to the legacy `data` shapes (a bare list, or a map keyed by kind).
List<Map<String, dynamic>> communitySearchRows(
  Map<String, dynamic> response,
  String kind,
) {
  final rows = <Map<String, dynamic>>[];

  void addEntries(Object? items) {
    if (items is! List) return;
    for (final item in items) {
      if (item is Map) rows.add(Map<String, dynamic>.from(item));
    }
  }

  final results = response['results'];
  if (results is Map && results.containsKey(kind)) {
    addEntries(results[kind]);
    return rows;
  }

  final data = response['data'];
  if (data is List) {
    addEntries(data);
  } else if (data is Map) {
    addEntries(data[kind]);
  }
  return rows;
}

/// Whether the backend reported [kind] as degraded, meaning its query failed.
/// An empty list for a degraded kind means "unavailable", not "no matches".
/// Unknown kinds and malformed `degradedKinds` values are ignored.
bool communitySearchKindDegraded(Map<String, dynamic> response, String kind) {
  final degraded = response['degradedKinds'];
  if (degraded is! List) return false;
  return degraded.any((entry) => entry == kind);
}
