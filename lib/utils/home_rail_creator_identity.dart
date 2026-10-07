import '../models/promotion.dart';
import 'creator_display_format.dart';
import 'wallet_utils.dart';

/// The context line of an artwork rail card.
///
/// Cultural authorship comes only from the artwork's recorded artist. The
/// uploader (`creatorDisplayName`, `creatorUsername`, `creatorWalletAddress`)
/// is contributor metadata: it never stands in for the artist and never makes
/// the line a profile link. An unattributed artwork reads as [fallbackLabel],
/// the localized "Unknown artist", exactly like the detail page.
class HomeRailCreatorIdentity {
  final CreatorDisplay display;
  final bool isRecordedArtist;

  const HomeRailCreatorIdentity({
    required this.display,
    required this.isRecordedArtist,
  });

  String get label => display.primary;

  /// Authorship is a name, not an account; no profile is implied.
  bool get canOpenProfile => false;

  String? get userId => null;
  String? get username => null;
}

HomeRailCreatorIdentity? resolveArtworkHomeRailCreator(
  HomeRailItem item, {
  required String fallbackLabel,
}) {
  if (item.entityType != PromotionEntityType.artwork) return null;

  final artist =
      _recordedArtist(item.creatorArtistName) ?? _recordedArtist(item.subtitle);
  return HomeRailCreatorIdentity(
    display: CreatorDisplay(primary: artist ?? fallbackLabel),
    isRecordedArtist: artist != null,
  );
}

String? _recordedArtist(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (text.startsWith('@')) return null;
  if (WalletUtils.looksLikeWallet(text)) return null;
  if (const {'unknown', 'unknown artist'}.contains(text.toLowerCase())) {
    return null;
  }
  return text;
}
