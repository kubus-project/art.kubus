/// Shared recognition of canonical account identifiers used by chat contracts.
///
/// Wallets may appear in legacy JWT `sub` claims, so callers must not treat an
/// arbitrary non-empty claim as a user ID.
String? canonicalAccountUserId(Object? value) {
  final candidate = value?.toString().trim();
  if (candidate == null ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(candidate)) {
    return null;
  }
  return candidate.toLowerCase();
}

String? accountUserIdFromClaims(Map<String, dynamic>? claims) {
  if (claims == null) return null;
  for (final claim in <Object?>[
    claims['id'],
    claims['user_id'],
    claims['userId'],
    claims['sub'],
  ]) {
    final accountId = canonicalAccountUserId(claim);
    if (accountId != null) return accountId;
  }
  return null;
}
