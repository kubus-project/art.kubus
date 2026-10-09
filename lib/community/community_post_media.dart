import '../config/config.dart';
import 'community_interactions.dart';

const List<String> _videoExtensions = <String>[
  '.mp4',
  '.m4v',
  '.mov',
  '.webm',
  '.ogv',
];

/// Whether [url] points at a video file, judged by its path extension.
///
/// Query strings and fragments are ignored. A URL without a known video
/// extension renders as an image.
bool communityMediaUrlIsVideo(String url) {
  final uri = Uri.tryParse(url.trim());
  final path = (uri?.path ?? url).toLowerCase();
  return _videoExtensions.any(path.endsWith);
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
