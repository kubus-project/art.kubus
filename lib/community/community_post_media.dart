import '../config/config.dart';
import 'community_interactions.dart';

const List<String> _videoExtensions = <String>[
  '.mp4',
  '.m4v',
  '.mov',
  '.webm',
  '.ogv',
];

/// Still-image extensions a video poster may use.
const List<String> _posterExtensions = <String>[
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
];

/// Fragment key that marks a stored media reference as a video when its URL
/// carries no file extension (an IPFS gateway path, for example).
///
/// The Community API stores `mediaUrls` as plain strings with no per-item type,
/// and a fragment is never sent to a server, so the hint travels inside the
/// existing reference without any schema or storage change. Old posts have no
/// hint and keep being classified by extension.
const String kCommunityMediaVideoHint = 'kubus-media=video';

/// Fragment key that carries a video's poster: an accepted still-image
/// reference, percent-encoded once with `encodeURIComponent`.
///
/// It is honoured only together with [kCommunityMediaVideoHint]. Only the first
/// occurrence counts, and an unknown or invalid value means no poster.
const String kCommunityMediaPosterHintKey = 'kubus-poster';

/// Longest poster reference, measured after decoding.
const int kCommunityMediaPosterMaxLength = 2000;

/// Whether [url] points at a video, judged by an explicit video hint in its
/// fragment, or else by its path extension.
///
/// Query strings are ignored. A URL with neither renders as an image.
bool communityMediaUrlIsVideo(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasFragment) {
    final hints = uri.fragment.split('&');
    if (hints.contains(kCommunityMediaVideoHint)) return true;
  }
  final path = (uri?.path ?? trimmed).toLowerCase();
  return _videoExtensions.any(path.endsWith);
}

/// The poster declared on the video reference [url], or null.
///
/// The poster counts only when the URL also carries the video hint. The raw
/// fragment value is decoded exactly once; the decoded reference must pass
/// [communityMediaPosterReferenceIsAccepted].
String? communityMediaPosterReference(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasFragment) return null;
  final hints = uri.fragment.split('&');
  if (!hints.contains(kCommunityMediaVideoHint)) return null;
  for (final hint in hints) {
    final separator = hint.indexOf('=');
    if (separator < 0) continue;
    if (hint.substring(0, separator) != kCommunityMediaPosterHintKey) continue;
    final decoded = _decodeOnce(hint.substring(separator + 1));
    if (decoded == null) return null;
    return communityMediaPosterReferenceIsAccepted(decoded) ? decoded : null;
  }
  return null;
}

/// The video's own reference without its hints, for playback and resolution.
String communityMediaVideoSourceUrl(String url) {
  final trimmed = url.trim();
  final hashAt = trimmed.indexOf('#');
  return hashAt < 0 ? trimmed : trimmed.substring(0, hashAt);
}

/// Whether [raw] (already decoded) may be used as a video poster.
///
/// Accepted forms: `https://` on a public host, `/uploads/...` on this origin,
/// and `ipfs://CID[/path]`. The path must end in .jpg, .jpeg, .png or .webp.
/// A video, a fragment, whitespace or control characters, an unsafe scheme or a
/// private host are all refused. Display still resolves through
/// `MediaUrlResolver`, which fails closed on its own rules.
bool communityMediaPosterReferenceIsAccepted(String raw) {
  if (raw.isEmpty || raw.trim() != raw) return false;
  if (raw.length > kCommunityMediaPosterMaxLength) return false;
  if (raw.contains('#') || raw.contains('\\')) return false;
  for (final unit in raw.codeUnits) {
    if (unit <= 0x20 || unit == 0x7f) return false;
  }
  // Dot segments are refused on the raw text: Uri does not keep them apart.
  if (raw.split('/').any((segment) => segment == '..' || segment == '.')) {
    return false;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  final path = uri.path.toLowerCase();
  if (_videoExtensions.any(path.endsWith)) return false;
  if (!_posterExtensions.any(path.endsWith)) return false;

  if (!uri.hasScheme) {
    // Only same-origin upload paths; no protocol-relative references.
    return raw.startsWith('/uploads/') && !raw.startsWith('//');
  }
  switch (uri.scheme.toLowerCase()) {
    case 'ipfs':
      return RegExp(r'^[A-Za-z0-9]+$').hasMatch(uri.host) && !uri.hasPort;
    case 'https':
      if (uri.userInfo.isNotEmpty || uri.host.isEmpty) return false;
      return _isPublicHost(uri.host.toLowerCase());
    default:
      return false;
  }
}

/// The reference to publish for an uploaded file.
///
/// A video gets the explicit hint when its URL does not already say it is one,
/// so the feed does not show it as a broken image. With a [posterUrl] that is
/// accepted, the video reference carries the poster hint as well. Images, and
/// videos with a recognisable extension and no poster, are published exactly as
/// uploaded.
String communityMediaReferenceForPost(
  String url, {
  required bool isVideo,
  String? posterUrl,
}) {
  final trimmed = url.trim();
  if (!isVideo) return trimmed;
  final poster = posterUrl?.trim() ?? '';
  if (poster.isNotEmpty && communityMediaPosterReferenceIsAccepted(poster)) {
    return _videoReferenceWithPoster(trimmed, poster);
  }
  if (communityMediaUrlIsVideo(trimmed)) return trimmed;
  final hashAt = trimmed.indexOf('#');
  if (hashAt < 0) return '$trimmed#$kCommunityMediaVideoHint';
  final existing = trimmed.substring(hashAt + 1);
  return existing.isEmpty
      ? '$trimmed$kCommunityMediaVideoHint'
      : '$trimmed&$kCommunityMediaVideoHint';
}

String _videoReferenceWithPoster(String url, String poster) {
  final base = communityMediaVideoSourceUrl(url);
  final encoded = Uri.encodeComponent(poster);
  return '$base#$kCommunityMediaVideoHint&$kCommunityMediaPosterHintKey=$encoded';
}

/// The still image that stands in for [post] where a picture is needed (the
/// art feed, saved items, search results).
///
/// When the first item is a video, its poster is used; with no poster, the
/// first image in the post is used instead. Otherwise the first item itself.
/// Null when no still is available.
String? communityPostPreviewImageUrl(CommunityPost post) {
  final items = <String>[];
  final legacy = post.imageUrl?.trim() ?? '';
  if (legacy.isNotEmpty) items.add(legacy);
  for (final media in post.mediaUrls) {
    final url = media.trim();
    if (url.isNotEmpty) items.add(url);
  }
  if (items.isEmpty) return null;
  final first = items.first;
  if (!communityMediaUrlIsVideo(first)) return first;
  final poster = communityMediaPosterReference(first);
  if (poster != null) return poster;
  for (final item in items.skip(1)) {
    if (!communityMediaUrlIsVideo(item)) return item;
  }
  return null;
}

/// The media shown for [post]. Uses `mediaUrls` when present, and falls back to
/// the single `imageUrl` for legacy posts. Empty values are dropped.
///
/// With multi-media off, only the first item is shown, so a post that already
/// holds several URLs renders as a single panel. The stored media is unchanged.
List<String> communityPostMediaUrls(
  CommunityPost post, {
  bool? multiMediaEnabled,
}) {
  final urls = _storedMediaUrls(post);
  final enabled =
      multiMediaEnabled ?? AppConfig.isFeatureEnabled('communityMultiMedia');
  if (enabled || urls.length <= 1) return urls;
  return List<String>.unmodifiable(<String>[urls.first]);
}

List<String> _storedMediaUrls(CommunityPost post) {
  final urls = post.mediaUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (urls.isNotEmpty) return urls;
  final legacy = post.imageUrl?.trim() ?? '';
  return legacy.isEmpty ? const <String>[] : <String>[legacy];
}

String? _decodeOnce(String raw) {
  try {
    return Uri.decodeComponent(raw);
  } on FormatException {
    return null;
  }
}

/// Refuses hosts that point at this machine or a private network. The real
/// safety boundary is the display resolver; this keeps the contract honest.
bool _isPublicHost(String host) {
  if (host.isEmpty || host.contains('[') || host.contains(':')) return false;
  if (host == 'localhost' || host.endsWith('.localhost')) return false;
  if (host.endsWith('.local') || host.endsWith('.internal')) return false;
  if (!host.contains('.')) return false;
  final ipv4 =
      RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(host);
  if (ipv4 != null) {
    final a = int.parse(ipv4.group(1)!);
    final b = int.parse(ipv4.group(2)!);
    if (a == 0 || a == 10 || a == 127) return false;
    if (a == 169 && b == 254) return false;
    if (a == 172 && b >= 16 && b <= 31) return false;
    if (a == 192 && b == 168) return false;
    if (a >= 224) return false;
  }
  return true;
}
