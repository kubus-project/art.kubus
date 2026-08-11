/// The durable public contributions a member account can make.
///
/// Mirrors `backend/src/config/contributionTypes.js`. The backend sanitiser
/// drops any value outside its own copy of this list, so a value added here
/// without one added there is silently discarded at ingest — which is exactly
/// the failure mode the free-form `String kind` parameter this replaces made
/// easy. `test/services/campaign_contract_test.dart` asserts the two lists
/// match so the drift fails a build instead of a dashboard.
///
/// Membership rule: the client has a creation path that ends in a
/// backend-confirmed durable record. Deliberately absent:
///
/// - `artist_profile` — artist standing is derived from profile fields and DAO
///   review rather than created by a one-time transaction. An artist's
///   activation is their first artwork or marker.
/// - `institution_profile` — institution identity is likewise derived from
///   profile/DAO role state. A gallery's activation is its first exhibition,
///   event or artwork.
///
/// Do not add a value for symmetry: without a real creation boundary the
/// resulting dimension can never be non-zero.
enum ContributionType {
  artwork,
  marker,
  event,
  exhibition;

  /// Value sent as `contribution_type`.
  String get wireValue => name;
}
