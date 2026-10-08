import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../services/backend_api_service.dart';

/// Maximum images and videos in one Community post, counted together.
const int kCommunityComposerMaxMediaItems = 10;

/// Longest video the picker accepts for a Community post.
const Duration kCommunityComposerMaxVideoDuration = Duration(minutes: 5);

enum CommunityComposerMediaKind { image, video }

enum CommunityComposerUploadStatus { pending, uploading, uploaded, failed }

/// A file chosen in a picker. Image bytes are read once here and reused for
/// the preview and the upload. Videos stay on disk until they are uploaded.
class CommunityComposerPickedMedia {
  const CommunityComposerPickedMedia({
    required this.file,
    required this.kind,
    this.imageBytes,
  });

  final XFile file;
  final CommunityComposerMediaKind kind;
  final Uint8List? imageBytes;
}

/// One ordered entry in the composer. Its [uploadedUrl] survives failed or
/// retried publishes, so a completed upload is never sent twice.
class CommunityComposerMediaItem {
  CommunityComposerMediaItem._({
    required this.id,
    required this.kind,
    required this.file,
    this.imageBytes,
  });

  final String id;
  final CommunityComposerMediaKind kind;
  final XFile file;

  /// Image bytes, read at selection. Null for videos.
  final Uint8List? imageBytes;

  CommunityComposerUploadStatus status = CommunityComposerUploadStatus.pending;
  String? uploadedUrl;
  Object? lastError;

  String get name => file.name;
  bool get isImage => kind == CommunityComposerMediaKind.image;
  bool get isVideo => kind == CommunityComposerMediaKind.video;
}

/// Ordered media for one Community post, shared by the mobile and desktop
/// composers. Uploads run one at a time and stop at the first failure, so
/// rate limits are not hammered and a retry resumes where it stopped.
class CommunityComposerMediaController extends ChangeNotifier {
  CommunityComposerMediaController({
    this.maxItems = kCommunityComposerMaxMediaItems,
  });

  final int maxItems;
  final List<CommunityComposerMediaItem> _items =
      <CommunityComposerMediaItem>[];
  int _sequence = 0;
  bool _uploading = false;

  List<CommunityComposerMediaItem> get items =>
      List<CommunityComposerMediaItem>.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isFull => _items.length >= maxItems;
  int get remainingSlots => maxItems - _items.length;
  bool get isUploading => _uploading;
  bool get hasImages => _items.any((item) => item.isImage);
  bool get hasVideos => _items.any((item) => item.isVideo);
  bool get hasFailedUploads => _items.any(
        (item) => item.status == CommunityComposerUploadStatus.failed,
      );
  int get unuploadedCount => _items
      .where((item) => item.status != CommunityComposerUploadStatus.uploaded)
      .length;

  /// Uploaded URLs in composer order. Only meaningful once every item uploaded.
  List<String> get uploadedUrls => _items
      .map((item) => item.uploadedUrl)
      .whereType<String>()
      .toList(growable: false);

  /// Appends picks in order and returns how many fit. Picks beyond the limit
  /// are dropped, and the caller can compare the count to report it.
  int add(Iterable<CommunityComposerPickedMedia> picked) {
    if (_uploading) return 0;
    var added = 0;
    for (final media in picked) {
      if (isFull) break;
      _items.add(
        CommunityComposerMediaItem._(
          id: 'composer-media-${_sequence++}',
          kind: media.kind,
          file: media.file,
          imageBytes: media.kind == CommunityComposerMediaKind.image
              ? media.imageBytes
              : null,
        ),
      );
      added++;
    }
    if (added > 0) notifyListeners();
    return added;
  }

  void remove(String id) {
    if (_uploading) return;
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length != before) notifyListeners();
  }

  /// Moves the item at [from] so that it ends at the final index [to].
  void reorder(int from, int to) {
    if (_uploading) return;
    if (from < 0 || from >= _items.length) return;
    if (to < 0 || to >= _items.length || to == from) return;
    final item = _items.removeAt(from);
    _items.insert(to, item);
    notifyListeners();
  }

  /// Moves the item with [id] by [delta] places (for example -1 or +1).
  void moveBy(String id, int delta) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    reorder(index, index + delta);
  }

  void clear() {
    if (_uploading || _items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  /// Uploads every item that has no URL yet, in composer order. Completed items
  /// are skipped. The first failure stops the run and is rethrown, so later
  /// items stay pending for the next attempt.
  Future<List<String>> uploadPending(
    Future<String> Function(CommunityComposerMediaItem item) upload,
  ) async {
    if (_uploading) {
      throw StateError('A media upload is already in progress.');
    }
    _uploading = true;
    notifyListeners();
    try {
      for (final item in List<CommunityComposerMediaItem>.of(_items)) {
        if (item.status == CommunityComposerUploadStatus.uploaded) continue;
        item
          ..status = CommunityComposerUploadStatus.uploading
          ..lastError = null;
        notifyListeners();
        try {
          final url = (await upload(item)).trim();
          if (url.isEmpty) {
            throw StateError('Media upload returned no URL.');
          }
          item
            ..uploadedUrl = url
            ..status = CommunityComposerUploadStatus.uploaded;
          notifyListeners();
        } catch (error) {
          item
            ..status = CommunityComposerUploadStatus.failed
            ..lastError = error;
          notifyListeners();
          rethrow;
        }
      }
      return uploadedUrls;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }
}

/// Uploads one composer item through the existing post upload endpoint.
Future<String> uploadCommunityComposerMediaItem(
  BackendApiService api,
  CommunityComposerMediaItem item, {
  Map<String, String>? metadata,
}) async {
  final bytes = item.imageBytes ?? await item.file.readAsBytes();
  final result = await api.uploadFile(
    fileBytes: bytes,
    fileName: item.name,
    fileType: item.isVideo ? 'post-video' : 'post-image',
    metadata: metadata,
  );
  final url = (result['uploadedUrl'] as String?)?.trim() ?? '';
  if (url.isEmpty) {
    throw StateError('Media upload returned no URL.');
  }
  return url;
}

/// Opens the photo picker for up to [limit] images, reading bytes once.
Future<List<CommunityComposerPickedMedia>> pickCommunityComposerPhotos({
  required int limit,
}) async {
  if (limit <= 0) return const <CommunityComposerPickedMedia>[];
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
    limit: limit,
  );
  final picked = <CommunityComposerPickedMedia>[];
  for (final file in files) {
    picked.add(
      CommunityComposerPickedMedia(
        file: file,
        kind: CommunityComposerMediaKind.image,
        imageBytes: await file.readAsBytes(),
      ),
    );
  }
  return picked;
}

/// Opens the video picker for a single clip within the duration limit.
Future<CommunityComposerPickedMedia?> pickCommunityComposerVideo() async {
  final video = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
    maxDuration: kCommunityComposerMaxVideoDuration,
  );
  if (video == null) return null;
  return CommunityComposerPickedMedia(
    file: video,
    kind: CommunityComposerMediaKind.video,
  );
}
