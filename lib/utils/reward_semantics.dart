/// Whether a value explicitly names KUB8 as its denomination.
///
/// A generic amount/reward field is deliberately not enough to infer a token
/// unit. Only exact server/product currency labels are accepted here.
bool isExplicitKub8Currency(Object? currency) =>
    currency?.toString().trim().toUpperCase() == 'KUB8';

/// Whether a recent-activity amount has a known KUB8 unit.
///
/// Legacy achievement `rewardTokens` is accepted only for achievement
/// activities because that model's current contract defines it as KUB8.
bool hasExplicitKub8ActivityAmount(
  Map<String, dynamic> data, {
  required bool isAchievement,
  String? activityType,
}) {
  if (isExplicitKub8Currency(data['currency'] ?? data['rewardCurrency'])) {
    return true;
  }
  if (activityType?.trim().toLowerCase() == 'kub8') return true;
  return isAchievement && data['rewardTokens'] != null;
}
