import '../models/artwork.dart';
import 'wallet_utils.dart';

/// Cultural authorship is the artwork's explicitly recorded artist.
///
/// The uploader, owner wallet, importer, photographer and image author are
/// different roles and never stand in for it. A missing author is rendered as
/// the localized "Unknown artist" by whichever surface shows it.
bool isRecordedArtistName(String? value) {
  final text = (value ?? '').trim();
  return text.isNotEmpty &&
      !WalletUtils.looksLikeWallet(text) &&
      !const {'unknown', 'unknown artist'}.contains(text.toLowerCase());
}

extension ArtworkAuthorship on Artwork {
  /// The recorded cultural author, or null when the artwork is unattributed.
  String? get recordedArtist {
    final direct = artist.trim();
    if (isRecordedArtistName(direct)) return direct;
    final meta = metadata;
    final fromMetadata =
        (meta?['artistName'] ?? meta?['artist_name'])?.toString().trim();
    return isRecordedArtistName(fromMetadata) ? fromMetadata : null;
  }
}

/// The `artistName` entry of an artwork update, or null when nothing changed.
///
/// Authorship is explicit. A blank field means "unattributed" and is sent as an
/// empty string so the backend clears it; it is never replaced with the
/// current account, and an unchanged field is not sent at all.
String? artistNameUpdateFor(Artwork artwork, String fieldText) {
  final next = fieldText.trim();
  return next == (artwork.recordedArtist ?? '') ? null : next;
}
