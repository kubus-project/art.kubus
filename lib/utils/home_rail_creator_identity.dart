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

  String get label => display.secondary == null
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
  final subtitleUsername = subtitle.startsWith('@')
      ? CreatorDisplayFormat.normalizeUsername(subtitle.substring(1))
      : null;
  final subtitleDisplayName =
      !_looksLikeCreatorFallback(subtitle) ? subtitle : null;
  final username =
      CreatorDisplayFormat.normalizeUsername(item.creatorUsername) ??
          subtitleUsername;
  final userId =
      WalletUtils.canonical(item.creatorTargetId ?? item.creatorWalletAddress);
  final display = CreatorDisplayFormat.format(
    fallbackLabel: fallbackLabel,
    displayName: CreatorDisplayFormat.normalizeDisplayName(
          item.creatorDisplayName,
        ).ifEmptyNull ??
        CreatorDisplayFormat.normalizeDisplayName(item.creatorArtistName)
            .ifEmptyNull ??
        CreatorDisplayFormat.normalizeDisplayName(subtitleDisplayName)
            .ifEmptyNull,
    username: username,
    wallet: userId.isEmpty ? null : userId,
  );
  final hasHumanIdentity = display.primary != fallbackLabel ||
      (display.secondary?.trim().isNotEmpty ?? false);
  if (!hasHumanIdentity) return null;

  return HomeRailCreatorIdentity(
    display: display,
    userId: userId.isEmpty ? null : userId,
    username: username,
  );
}

bool _looksLikeCreatorFallback(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return true;
  if (normalized.startsWith('@')) return true;
  return WalletUtils.looksLikeWallet(normalized);
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
