import '../config/config.dart';
import 'community_interactions.dart';

const List<String> _videoExtensions = <String>[
  '.mp4',
  '.m4v',
  '.mov',
  '.webm',
  '.ogv',
];

/// Fragment key that marks a stored media reference as a video when its URL
/// carries no file extension (an IPFS gateway path, for example).
///
/// The Community API stores `mediaUrls` as plain strings with no per-item type,
/// and a fragment is never sent to a server, so the hint travels inside the
/// existing reference without any schema or storage change. Old posts have no
/// hint and keep being classified by extension.
const String kCommunityMediaVideoHint = 'kubus-media=video';

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

/// The reference to publish for an uploaded file.
///
/// A video whose URL does not already say it is one gets the explicit hint, so
/// the feed does not silently show it as a broken image. Images, and videos
/// with a recognisable extension, are published exactly as uploaded.
String communityMediaReferenceForPost(String url, {required bool isVideo}) {
  final trimmed = url.trim();
  if (!isVideo || communityMediaUrlIsVideo(trimmed)) return trimmed;
  final hashAt = trimmed.indexOf('#');
  if (hashAt < 0) return '$trimmed#$kCommunityMediaVideoHint';
  final existing = trimmed.substring(hashAt + 1);
  return existing.isEmpty
      ? '$trimmed$kCommunityMediaVideoHint'
      : '$trimmed&$kCommunityMediaVideoHint';
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
