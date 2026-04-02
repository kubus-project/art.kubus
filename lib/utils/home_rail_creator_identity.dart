import '../models/promotion.dart';
import 'creator_display_format.dart';
import 'wallet_utils.dart';

class HomeRailCreatorIdentity {
  final CreatorDisplay display;
  final String? userId;
  final String? username;

  const HomeRailCreatorIdentity({
    required this.display,
    this.userId,
    this.username,
  });

  String get label =>
      display.secondary == null
          ? display.primary
          : '${display.primary} | ${display.secondary!}';

  bool get canOpenProfile => (userId ?? '').trim().isNotEmpty;
}

HomeRailCreatorIdentity? resolveArtworkHomeRailCreator(
  HomeRailItem item, {
  required String fallbackLabel,
}) {
  if (item.entityType != PromotionEntityType.artwork) return null;

  final subtitle = (item.subtitle ?? '').trim();
  final subtitleUsername =
      subtitle.startsWith('@') ? _normalizeUsername(subtitle.substring(1)) : null;
  final subtitleDisplayName =
      !_looksLikeCreatorFallback(subtitle) ? subtitle : null;
  final username =
      _normalizeUsername(item.creatorUsername) ?? subtitleUsername;
  final userId =
      WalletUtils.canonical(item.creatorTargetId ?? item.creatorWalletAddress);
  final display = CreatorDisplayFormat.format(
    fallbackLabel: fallbackLabel,
    displayName: _normalizeDisplayName(item.creatorDisplayName) ??
        _normalizeDisplayName(item.creatorArtistName) ??
        _normalizeDisplayName(subtitleDisplayName),
    username: username,
    wallet: userId.isEmpty ? null : userId,
  );
  final hasHumanIdentity =
      display.primary != fallbackLabel ||
      (display.secondary?.trim().isNotEmpty ?? false);
  if (!hasHumanIdentity) return null;

  return HomeRailCreatorIdentity(
    display: display,
    userId: userId.isEmpty ? null : userId,
    username: username,
  );
}

String? _normalizeDisplayName(String? value) {
  final normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeUsername(String? value) {
  var normalized = (value ?? '').trim();
  if (normalized.startsWith('@')) {
    normalized = normalized.substring(1).trim();
  }
  if (normalized.isEmpty || WalletUtils.looksLikeWallet(normalized)) {
    return null;
  }
  return normalized;
}

bool _looksLikeCreatorFallback(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return true;
  if (normalized.startsWith('@')) return true;
  return WalletUtils.looksLikeWallet(normalized);
}
