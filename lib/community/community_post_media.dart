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

/// The ordered media for [post]. Uses `mediaUrls` when present, and falls back
/// to the single `imageUrl` for legacy posts. Empty values are dropped.
List<String> communityPostMediaUrls(CommunityPost post) {
  final urls = post.mediaUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (urls.isNotEmpty) return urls;
  final legacy = post.imageUrl?.trim() ?? '';
  return legacy.isEmpty ? const <String>[] : <String>[legacy];
}
